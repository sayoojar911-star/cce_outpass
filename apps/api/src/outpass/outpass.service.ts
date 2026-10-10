import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, OutpassStatus, Decision } from '@prisma/client';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuthUser } from '../common/jwt-auth.guard';
import { CreateOutpassDto, DecisionDto } from './dto';

const ACTIVE_STATUSES: OutpassStatus[] = [
  'PENDING_TUTOR',
  'PENDING_HOD',
  'APPROVED',
  'EXITED',
  'OVERDUE',
];

@Injectable()
export class OutpassService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
  ) {}

  async create(user: AuthUser, dto: CreateOutpassDto) {
    const student = await this.prisma.student.findUnique({
      where: { userId: user.userId },
      include: { user: true },
    });
    if (!student) throw new ForbiddenException('Only students can create outpasses');

    const exitAt = new Date(dto.requestedExitAt);
    const returnAt = new Date(dto.expectedReturnAt);
    const now = new Date();
    if (returnAt <= exitAt) {
      throw new ConflictException('Expected return must be after the requested exit time');
    }
    if (returnAt <= now) {
      throw new ConflictException('Expected return time is already in the past');
    }

    // Edge case PRD §14: block overlapping active requests.
    const overlapping = await this.prisma.outpassRequest.findFirst({
      where: { studentId: user.userId, status: { in: ACTIVE_STATUSES } },
      select: { id: true },
    });
    if (overlapping) {
      throw new ConflictException('You already have an active outpass request');
    }

    const displayId = await this.nextDisplayId();

    const request = await this.prisma.outpassRequest.create({
      data: {
        displayId,
        studentId: user.userId,
        type: dto.type === 'EMERGENCY' ? 'EMERGENCY' : 'NORMAL',
        status: 'PENDING_TUTOR',
        requestedExitAt: exitAt,
        expectedReturnAt: returnAt,
        destination: dto.destination,
        purposeCategory: dto.purposeCategory,
        purposeText: dto.purposeText ?? null,
      },
    });

    if (student.tutorId) {
      await this.notifications.push(
        student.tutorId,
        `New outpass request — ${student.user.name}`,
        `${dto.purposeCategory} · ${dto.destination}`,
      );
    }
    if (request.type === 'EMERGENCY') {
      // FR-APR-04: emergency notifies tutor and HOD simultaneously.
      const hod = await this.prisma.user.findFirst({
        where: { role: 'HOD', department: student.department },
      });
      if (hod) {
        await this.notifications.push(
          hod.id,
          `EMERGENCY outpass request — ${student.user.name}`,
          `${dto.purposeCategory} · ${dto.destination}`,
        );
      }
    }

    await this.audit.append(user.userId, user.role, 'OUTPASS_CREATED', 'OutpassRequest', request.id, {
      displayId,
      type: request.type,
    });
    return this.serialize(request);
  }

  async listFor(user: AuthUser, status?: OutpassStatus) {
    const where: Prisma.OutpassRequestWhereInput = { ...(status ? { status } : {}) };
    if (user.role === 'STUDENT') {
      where.studentId = user.userId;
    } else if (user.role === 'TUTOR') {
      const tutor = await this.prisma.user.findUnique({ where: { id: user.userId } });
      if (tutor && tutor.department && tutor.year) {
        where.student = {
          department: tutor.department,
          year: tutor.year,
          ...(tutor.division ? { division: tutor.division } : {}),
        };
      } else {
        where.student = { tutorId: user.userId };
      }
    } else if (user.role === 'HOD') {
      // HOD sees requests of their department (student.department == HOD.department)
      const dept = await this.departmentOf(user);
      if (!dept) throw new ForbiddenException('No department assigned');
      where.student = { department: dept };
    } else if (user.role === 'GUARD') {
      throw new ForbiddenException('Guards access outpasses only through gate scans');
    }
    const rows = await this.prisma.outpassRequest.findMany({
      where,
      include: this.detailInclude(),
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((r) => this.serializeDetail(r));
  }

  async getOne(user: AuthUser, id: string) {
    const request = await this.prisma.outpassRequest.findUnique({
      where: { id },
      include: this.detailInclude(),
    });
    if (!request) throw new NotFoundException('Outpass not found');
    await this.assertCanView(user, request);
    return this.serializeDetail(request);
  }

  async cancel(user: AuthUser, id: string, reason?: string) {
    const res = await this.prisma.outpassRequest.updateMany({
      where: {
        id,
        studentId: user.userId,
        status: { in: ['PENDING_TUTOR', 'PENDING_HOD', 'APPROVED'] },
      },
      data: { status: 'CANCELLED', version: { increment: 1 } },
    });
    if (res.count === 0) {
      throw new ConflictException('Outpass can no longer be cancelled (already exited or final)');
    }
    await this.audit.append(user.userId, user.role, 'OUTPASS_CANCELLED', 'OutpassRequest', id, {
      reason: reason ?? null,
    });
    await this.notifications.push(user.userId, 'Outpass cancelled', 'Your QR is now invalid');
    return { ok: true };
  }

  async decide(user: AuthUser, requestId: string, dto: DecisionDto) {
    const request = await this.prisma.outpassRequest.findUnique({
      where: { id: requestId },
      include: { student: { include: { user: true } } },
    });
    if (!request) throw new NotFoundException('Outpass not found');

    const expectedStage: OutpassStatus | null =
      user.role === 'TUTOR' ? 'PENDING_TUTOR' : user.role === 'HOD' ? 'PENDING_HOD' : null;
    if (!expectedStage) throw new ForbiddenException('Not an approver');

    if (user.role === 'TUTOR' && request.student.tutorId !== user.userId) {
      throw new ForbiddenException('Student is not mapped to you');
    }
    if (user.role === 'HOD') {
      const dept = await this.departmentOf(user);
      if (!dept || request.student.department !== dept) {
        throw new ForbiddenException('Student is not in your department');
      }
    }
    if (dto.decision === 'REJECTED' && !dto.comment) {
      throw new ConflictException('A reason is mandatory when rejecting');
    }

    try {
      const updated = await this.prisma.$transaction(async (tx) => {
        // FR-APR-06 + race protection: unique (requestId, stage) means the second
        // concurrent decision for the same stage fails here.
        await tx.approval.create({
          data: {
            requestId,
            stage: expectedStage,
            approverId: user.userId,
            decision: dto.decision === 'APPROVED' ? Decision.APPROVED : Decision.REJECTED,
            comment: dto.comment ?? null,
          },
        });

        const res = await tx.outpassRequest.updateMany({
          where: { id: requestId, status: expectedStage },
          data: this.transitionData(expectedStage, dto.decision, request),
        });
        if (res.count === 0) {
          throw new ConflictException('Already decided');
        }
        return tx.outpassRequest.findUnique({
          where: { id: requestId },
          include: this.detailInclude(),
        });
      });

      if (dto.decision === 'APPROVED' && expectedStage === 'PENDING_TUTOR') {
        await this.notifications.push(
          request.studentId,
          'Tutor approved — sent to HOD',
          'Your outpass is now awaiting HOD approval',
        );
        const hod = await this.prisma.user.findFirst({
          where: { role: 'HOD', department: request.student.department },
        });
        if (hod) {
          await this.notifications.push(
            hod.id,
            `New outpass request — ${request.student.user.name}`,
            `${request.purposeCategory} · ${request.destination}`,
          );
        }
      }
      if (dto.decision === 'APPROVED' && expectedStage === 'PENDING_HOD') {
        await this.notifications.push(
          request.studentId,
          'Outpass APPROVED — QR ready',
          'Open the app and show the QR at the gate',
        );
      }
      if (dto.decision === 'REJECTED') {
        await this.notifications.push(
          request.studentId,
          'Outpass rejected',
          dto.comment || 'Rejected by approver',
        );
      }

      await this.audit.append(user.userId, user.role, 'OUTPASS_DECIDED', 'OutpassRequest', requestId, {
        stage: expectedStage,
        decision: dto.decision,
        comment: dto.comment ?? null,
      });
      return this.serializeDetail(updated);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Already decided');
      }
      throw e;
    }
  }

  private transitionData(stage: OutpassStatus, decision: string, request: any) {
    if (decision === 'REJECTED') {
      return { status: OutpassStatus.REJECTED, version: { increment: 1 } };
    }
    if (stage === 'PENDING_TUTOR') {
      return { status: OutpassStatus.PENDING_HOD, version: { increment: 1 } };
    }
    // HOD approval → APPROVED with validity window (decision #8 in docs/decisions.md)
    // PRD §7.4: the QR is active once approved — if the student asked for a later
    // exit, approval starts the window now rather than leaving NOT_YET_VALID.
    const now = new Date();
    const validFrom =
      (request.requestedExitAt as Date).getTime() <= now.getTime()
        ? (request.requestedExitAt as Date)
        : now;
    return {
      status: OutpassStatus.APPROVED,
      validFrom,
      validUntil: request.expectedReturnAt as Date,
      version: { increment: 1 },
    };
  }

  private async nextDisplayId(): Promise<string> {
    const day = new Date();
    const stamp =
      `${day.getFullYear()}` +
      `${String(day.getMonth() + 1).padStart(2, '0')}` +
      `${String(day.getDate()).padStart(2, '0')}`;
    for (let attempt = 0; attempt < 5; attempt++) {
      const count = await this.prisma.outpassRequest.count({
        where: { createdAt: { gte: new Date(day.getFullYear(), day.getMonth(), day.getDate()) } },
      });
      const displayId = `OP${stamp}${String(count + 1).padStart(4, '0')}`;
      const exists = await this.prisma.outpassRequest.findUnique({ where: { displayId } });
      if (!exists) return displayId;
    }
    return `OP${stamp}${Date.now() % 10000}`;
  }

  private async departmentOf(user: AuthUser): Promise<string | null> {
    const u = await this.prisma.user.findUnique({ where: { id: user.userId } });
    return u?.department ?? null;
  }

  private async assertCanView(user: AuthUser, request: any) {
    if (user.role === 'STUDENT') {
      if (request.studentId !== user.userId) throw new ForbiddenException();
      return;
    }
    if (user.role === 'TUTOR') {
      if (request.student.tutorId === user.userId) return;
      const tutor = await this.prisma.user.findUnique({ where: { id: user.userId } });
      if (
        tutor &&
        tutor.department === request.student.department &&
        tutor.year === request.student.year &&
        (!tutor.division || tutor.division === request.student.division)
      ) {
        return;
      }
      throw new ForbiddenException();
    }
    if (user.role === 'HOD') {
      const dept = await this.departmentOf(user);
      if (request.student.department !== dept) throw new ForbiddenException();
      return;
    }
    if (user.role === 'ADMIN') return;
    throw new ForbiddenException('Guards access outpasses only through gate scans');
  }

  private detailInclude() {
    return {
      student: { include: { user: { select: { name: true } } } },
      approvals: true,
    };
  }

  private serialize(o: any) {
    return { ...o, lastTokenTs: Number(o.lastTokenTs) };
  }

  private serializeDetail(o: any) {
    const { student, approvals, ...rest } = o;
    return {
      ...this.serialize(rest),
      student: {
        id: student.userId,
        name: student.user.name,
        registerNo: student.registerNo,
        department: student.department,
        semester: student.semester,
        year: student.year ?? null,
        division: student.division ?? null,
      },
      approvals: approvals.map((a: any) => ({
        stage: a.stage,
        decision: a.decision,
        comment: a.comment,
        decidedAt: a.decidedAt,
      })),
    };
  }
}
