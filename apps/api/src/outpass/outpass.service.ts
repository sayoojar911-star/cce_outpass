import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateOutpassDto, DecisionDto } from './dto';
import { AuthUser } from '../common/jwt-auth.guard';
import { Decision } from '@prisma/client';
import { OutpassStatus } from './outpass.constants';

const ACTIVE_STATUSES = [
  'PENDING',
  'PENDING_TUTOR',
  'PENDING_TUTOR_APPROVAL',
  'PENDING_HOD',
  'PENDING_HOD_APPROVAL',
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
    const dbUser = await this.prisma.user.findUnique({
      where: { id: user.userId },
      include: {
        roleRef: true,
        deptRef: true,
        tutor: true,
        student: { include: { tutor: true } },
      },
    });

    if (!dbUser) throw new NotFoundException('User profile not found');

    const permissions = dbUser.roleRef?.permissions || [];
    if (!permissions.includes('createOutpass')) {
      throw new ForbiddenException('Your current role does not have permission to request an outpass');
    }

    const exitAt = new Date(dto.requestedExitAt);
    const returnAt = new Date(dto.expectedReturnAt);
    const now = new Date();
    if (returnAt <= exitAt) {
      throw new ConflictException('Expected return must be after the requested exit time');
    }
    if (returnAt <= now) {
      throw new ConflictException('Expected return time is already in the past');
    }

    // Edge case: block overlapping active requests
    const overlapping = await this.prisma.outpassRequest.findFirst({
      where: {
        OR: [{ studentId: user.userId }, { studentUserId: user.userId }],
        status: { in: ACTIVE_STATUSES },
      },
      select: { id: true },
    });
    if (overlapping) {
      throw new ConflictException('You already have an active outpass request');
    }

    // Dynamic Outpass Type lookup from DB (strictly normal or emergency)
    const rawType = (dto.type || 'normal').trim();
    const normalizedReq = rawType.replace('→', '->');
    const typeConfig = await this.prisma.outpassTypeConfig.findFirst({
      where: {
        OR: [
          { id: rawType.toLowerCase() },
          { id: rawType },
          { label: rawType },
          { id: normalizedReq.toLowerCase() },
          { label: normalizedReq },
          { id: { equals: rawType, mode: 'insensitive' } },
          { label: { equals: rawType, mode: 'insensitive' } },
        ],
        active: true,
      },
    });

    if (!typeConfig || !['normal', 'emergency'].includes(typeConfig.id.toLowerCase())) {
      throw new BadRequestException(
        `Outpass type "${rawType}" is not recognized or has been disabled by an administrator`,
      );
    }

    if (!typeConfig.approvalChain || typeConfig.approvalChain.length === 0) {
      throw new BadRequestException(
        `Outpass type "${typeConfig.label}" has no approval workflow chain configured in the database`,
      );
    }

    const typeId = typeConfig.id.toLowerCase();

    // Check emergency mandatory explanation (at least 15 characters)
    if (typeId === 'emergency' || typeConfig.requiresExplanation) {
      const explanation = (dto.purposeText || '').trim();
      if (!explanation || explanation.length < 15) {
        throw new BadRequestException(
          'Emergency outpass requests require an explanation of at least 15 characters.',
        );
      }
    }

    const approvalChain = typeConfig.approvalChain;
    const initialStageRoleId = approvalChain[0];

    // Check tutor assignment if first stage is tutor
    let effectiveTutorId = dbUser.tutorId || dbUser.student?.tutorId;
    if (initialStageRoleId === 'tutor') {
      if (!effectiveTutorId) {
        // Check class tutor fallback
        const deptCode = dbUser.deptRef?.code || dbUser.department;
        const classTutor = await this.prisma.user.findFirst({
          where: {
            roleId: 'tutor',
            department: deptCode,
            year: dbUser.year ?? dbUser.student?.year,
            ...(dbUser.division ? { division: dbUser.division } : {}),
            active: true,
            status: 'ACTIVE',
          },
        });
        if (!classTutor) {
          throw new BadRequestException('No tutor assigned, contact admin');
        }
        effectiveTutorId = classTutor.id;
      } else {
        // Validate assigned tutor exists, has role 'tutor', and is active
        const tutorUser = await this.prisma.user.findUnique({
          where: { id: effectiveTutorId },
        });
        if (!tutorUser || tutorUser.roleId !== 'tutor' || !tutorUser.active || tutorUser.status === 'DELETED') {
          throw new BadRequestException('No tutor assigned, contact admin');
        }
      }
    }

    // Check HOD assignment if chain involves HOD
    if (approvalChain.includes('hod')) {
      const deptCode = dbUser.deptRef?.code || dbUser.department;
      const deptId = dbUser.departmentId || dbUser.deptRef?.id;
      const activeHod = await this.prisma.user.findFirst({
        where: {
          roleId: 'hod',
          status: 'ACTIVE',
          active: true,
          OR: [
            ...(deptId ? [{ departmentId: deptId }] : []),
            ...(deptCode ? [{ department: deptCode }] : []),
          ],
        },
      });
      if (!activeHod) {
        throw new BadRequestException(
          'No HOD assigned for your department. Please contact your college administrator.',
        );
      }
    }

    const displayId = await this.nextDisplayId();
    const passCode = await this.nextPassCode();
    const initialStatus = initialStageRoleId === 'tutor' ? OutpassStatus.PENDING_TUTOR : OutpassStatus.PENDING_HOD;

    const request = await this.prisma.outpassRequest.create({
      data: {
        displayId,
        passCode,
        studentId: dbUser.student ? dbUser.student.userId : dbUser.id,
        studentUserId: dbUser.id,
        tutorId: initialStageRoleId === 'tutor' ? effectiveTutorId : (effectiveTutorId ?? null),
        typeId: typeId,
        type: typeConfig.label,
        status: initialStatus,
        currentStageIndex: 0,
        currentStep: 0,
        currentStageRoleId: initialStageRoleId,
        approvalChain,
        requestedExitAt: exitAt,
        expectedReturnAt: returnAt,
        destination: dto.destination,
        purposeCategory: dto.purposeCategory,
        purposeText: dto.purposeText ?? null,
      },
    });

    console.log('[OutpassService.create] Full outpass document written:', {
      id: request.id,
      displayId: request.displayId,
      passCode: request.passCode,
      tutorId: request.tutorId,
      studentId: request.studentId,
      studentUserId: request.studentUserId,
      status: request.status,
      currentStep: request.currentStep,
      currentStageIndex: request.currentStageIndex,
      currentStageRoleId: request.currentStageRoleId,
      approvalChain: request.approvalChain,
      typeId: request.typeId,
    });

    // Notify initial stage approver(s)
    await this.notifyApproversForStage(request, initialStageRoleId, dbUser);

    await this.audit.append(
      user.userId,
      user.roleId || user.role,
      'OUTPASS_CREATED',
      'OutpassRequest',
      request.id,
      {
        displayId,
        type: request.type,
        approvalChain,
        initialStage: initialStageRoleId,
      },
    );

    return this.serialize(request);
  }

  async listFor(user: AuthUser, status?: string) {
    const where: any = {};

    const dbUser = await this.prisma.user.findUnique({
      where: { id: user.userId },
      include: { roleRef: true, deptRef: true },
    });
    const permissions = dbUser?.roleRef?.permissions || [];

    if (permissions.includes('viewAll')) {
      // Admins or institutional viewers see everything
      if (status) {
        where.status = status === 'PENDING'
          ? { in: [OutpassStatus.PENDING_TUTOR, OutpassStatus.PENDING_HOD, 'PENDING'] }
          : status;
      }
    } else if (permissions.includes('approveOutpass')) {
      // Approvers see pending passes waiting on their role
      where.currentStageRoleId = user.roleId;

      if (user.roleId === 'tutor') {
        where.currentStageRoleId = 'tutor';
        where.status = (!status || status === 'PENDING')
          ? { in: [OutpassStatus.PENDING_TUTOR, OutpassStatus.PENDING_TUTOR_APPROVAL, 'PENDING_TUTOR', 'PENDING_TUTOR_APPROVAL', 'PENDING'] }
          : status;
        where.OR = [
          { tutorId: user.userId },
          { studentUser: { tutorId: user.userId } },
          { student: { tutorId: user.userId } },
        ];
      } else if (user.roleId === 'hod') {
        where.currentStageRoleId = 'hod';
        where.status = (!status || status === 'PENDING')
          ? { in: [OutpassStatus.PENDING_HOD, OutpassStatus.PENDING_HOD_APPROVAL, 'PENDING_HOD', 'PENDING_HOD_APPROVAL', 'PENDING'] }
          : status;
        const dept = dbUser?.deptRef?.code || dbUser?.department;
        if (dept) {
          where.OR = [
            { student: { department: dept } },
            { studentUser: { department: dept } },
            { studentUser: { deptRef: { code: dept } } },
          ];
        }
      }
    } else if (permissions.includes('createOutpass')) {
      if (status) where.status = status;
      where.OR = [{ studentId: user.userId }, { studentUserId: user.userId }];
    } else {
      if (status) where.status = status;
      where.OR = [{ studentId: user.userId }, { studentUserId: user.userId }];
    }

    const rows = await this.prisma.outpassRequest.findMany({
      where,
      include: this.detailInclude(),
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    console.log(
      `[OutpassService.listFor] Approver query: userId=${user.userId}, roleId=${user.roleId}, filters=${JSON.stringify(where)}, resultsCount=${rows.length}`,
    );

    return rows.map((r) => this.serializeDetail(r));
  }

  async getOne(user: AuthUser, id: string) {
    const request = await this.prisma.outpassRequest.findUnique({
      where: { id },
      include: this.detailInclude(),
    });
    if (!request) throw new NotFoundException('Outpass not found');
    return this.serializeDetail(request);
  }

  async cancel(user: AuthUser, id: string, reason?: string) {
    const existing = await this.prisma.outpassRequest.findUnique({
      where: { id },
      include: {
        student: { include: { user: true } },
        studentUser: { include: { deptRef: true } },
        approvals: true,
      },
    });

    if (!existing) {
      throw new NotFoundException('Outpass not found');
    }

    const isAdmin = (user.roleId || user.role) === 'admin';
    const isTutor = (user.roleId || user.role) === 'tutor';
    const isHod = (user.roleId || user.role) === 'hod';
    const isStudent = (user.roleId || user.role) === 'student';

    // Verify ownership / authorization
    if (isStudent) {
      const isOwner =
        existing.studentId === user.userId || existing.studentUserId === user.userId;
      if (!isOwner) {
        throw new ForbiddenException('You can only cancel your own outpass');
      }
    } else if (isTutor) {
      const assignedTutorId =
        existing.tutorId || existing.studentUser?.tutorId || existing.student?.tutorId;
      if (assignedTutorId && assignedTutorId !== user.userId) {
        throw new ForbiddenException('You can only cancel outpasses assigned to you as tutor');
      }
    } else if (isHod) {
      const studentDept =
        existing.studentUser?.deptRef?.code ||
        existing.studentUser?.department ||
        existing.student?.department;
      if (user.department && studentDept && user.department !== studentDept) {
        throw new ForbiddenException('You can only cancel outpasses for students in your department');
      }
    } else if (!isAdmin) {
      throw new ForbiddenException('Not authorized to cancel outpass');
    }

    // Status validation: NOT allowed once returned, rejected, or already cancelled
    if (existing.status === 'CANCELLED') {
      throw new ConflictException('Outpass is already cancelled');
    }
    if (existing.status === 'RETURNED') {
      throw new ConflictException('Cannot cancel outpass after return has been recorded');
    }
    if (existing.status === 'REJECTED') {
      throw new ConflictException('Cannot cancel a rejected outpass');
    }
    if (existing.status !== 'OVERDUE' && (existing.exitAt != null || existing.status === 'EXITED')) {
      throw new ConflictException('Cannot cancel outpass after campus exit has been recorded');
    }

    const cancellableStatuses = ['PENDING', 'PENDING_TUTOR', 'PENDING_HOD', 'APPROVED', 'OVERDUE', 'EXPIRED'];
    if (!cancellableStatuses.includes(existing.status)) {
      throw new ConflictException(
        `Outpass can no longer be cancelled (current status: ${existing.status})`,
      );
    }

    const now = new Date();
    const cancelActorReason = reason || (isAdmin ? 'Cancelled by Admin' : 'Cancelled by Student');

    // Atomic transaction preventing race conditions with gate exit scans
    const updated = await this.prisma.$transaction(async (tx) => {
      const updateResult = await tx.outpassRequest.updateMany({
        where: {
          id,
          status: { in: ['PENDING', 'PENDING_TUTOR', 'PENDING_HOD', 'APPROVED', 'OVERDUE', 'EXPIRED'] },
          OR: [
            { status: 'OVERDUE' },
            { exitAt: null },
          ],
        },
        data: {
          status: 'CANCELLED',
          cancelledAt: now,
          cancelledBy: user.userId,
          cancelReason: cancelActorReason,
          version: { increment: 1 },
        },
      });

      if (updateResult.count === 0) {
        const fresh = await tx.outpassRequest.findUnique({ where: { id } });
        if (!fresh) {
          throw new NotFoundException('Outpass not found');
        }
        if (fresh.status === 'CANCELLED') {
          throw new ConflictException('Outpass is already cancelled');
        }
        if (fresh.status === 'RETURNED') {
          throw new ConflictException('Cannot cancel outpass after return has been recorded');
        }
        if (fresh.status !== 'OVERDUE' && (fresh.exitAt != null || fresh.status === 'EXITED')) {
          throw new ConflictException('Cannot cancel outpass after campus exit has been recorded');
        }
        throw new ConflictException(
          `Outpass can no longer be cancelled (current status: ${fresh.status})`,
        );
      }

      return tx.outpassRequest.findUniqueOrThrow({
        where: { id },
        include: this.detailInclude(),
      });
    });

    await this.audit.append(
      user.userId,
      user.roleId || user.role,
      isAdmin ? 'OUTPASS_CANCELLED_BY_ADMIN' : 'OUTPASS_CANCELLED',
      'OutpassRequest',
      id,
      {
        reason: reason ?? null,
        previousStatus: existing.status,
        cancelledAt: now.toISOString(),
      },
    );

    // Notify student
    const studentTargetId = existing.studentUserId || existing.studentId;
    if (studentTargetId) {
      await this.notifications.push(
        studentTargetId,
        'Outpass cancelled',
        reason ? `Reason: ${reason}` : 'Your outpass request was cancelled',
      );
    }

    // Notify tutor/HOD if they had already approved or were assigned
    for (const app of existing.approvals) {
      if (app.decision === 'APPROVED' && app.approverId && app.approverId !== user.userId) {
        await this.notifications.push(
          app.approverId,
          `Outpass cancelled — ${existing.displayId}`,
          `The outpass previously approved by you has been cancelled.`,
        );
      }
    }

    return { ok: true, outpass: this.serializeDetail(updated) };
  }

  async approveDirect(user: AuthUser, requestId: string, comment?: string) {
    if (user.roleId !== 'tutor') {
      throw new ForbiddenException('Only authorized tutors can perform direct approval');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const fresh = await tx.outpassRequest.findUnique({
        where: { id: requestId },
        include: {
          student: { include: { user: true } },
          studentUser: { include: { tutor: true, deptRef: true } },
        },
      });
      if (!fresh) throw new NotFoundException('Outpass not found');

      if (fresh.status !== 'PENDING' && !fresh.status.startsWith('PENDING')) {
        throw new ConflictException(`Outpass has already been decided (${fresh.status})`);
      }

      if (fresh.currentStageRoleId && fresh.currentStageRoleId !== 'tutor') {
        throw new ForbiddenException(
          `This outpass is currently awaiting approval from a ${fresh.currentStageRoleId}, not your role`,
        );
      }

      const assignedTutorId = fresh.tutorId || fresh.studentUser?.tutorId || fresh.student?.tutorId;
      if (assignedTutorId && assignedTutorId !== user.userId) {
        throw new ForbiddenException('You can only approve or reject outpasses assigned to you as tutor');
      }

      const existingApproval = await tx.approval.findUnique({
        where: { requestId_stage: { requestId, stage: 'tutor' } },
      });
      if (existingApproval) {
        throw new ConflictException('Approval for tutor stage has already been recorded');
      }

      const approvalComment = comment || 'Approved directly by Tutor (bypassed HOD)';

      await tx.approval.create({
        data: {
          requestId,
          stage: 'tutor',
          stageRoleId: 'tutor',
          approverId: user.userId,
          decision: Decision.APPROVED,
          comment: approvalComment,
        },
      });

      const now = new Date();
      const validFrom = fresh.requestedExitAt.getTime() <= now.getTime() ? fresh.requestedExitAt : now;

      return tx.outpassRequest.update({
        where: { id: requestId },
        data: {
          status: OutpassStatus.APPROVED,
          approvalPath: 'DIRECT',
          currentStageRoleId: null,
          currentStageIndex: (fresh.approvalChain || []).length,
          currentStep: (fresh.approvalChain || []).length,
          validFrom,
          validUntil: fresh.expectedReturnAt,
          version: { increment: 1 },
        },
        include: this.detailInclude(),
      });
    });

    const targetStudentId = updated.studentUserId || updated.studentId;
    if (targetStudentId) {
      await this.notifications.push(
        targetStudentId,
        'Outpass APPROVED — QR ready',
        'Approved by Tutor — Final Approval. Your official gate pass is ready.',
      );
    }

    await this.audit.append(user.userId, 'tutor', 'OUTPASS_DIRECT_APPROVED', 'OutpassRequest', requestId, {
      path: 'DIRECT',
      comment,
      approverId: user.userId,
    });

    return this.serializeDetail(updated);
  }

  async forwardToHod(user: AuthUser, requestId: string, comment?: string) {
    if (user.roleId !== 'tutor') {
      throw new ForbiddenException('Only authorized tutors can forward outpasses to HOD');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const fresh = await tx.outpassRequest.findUnique({
        where: { id: requestId },
        include: {
          student: { include: { user: true } },
          studentUser: { include: { tutor: true, deptRef: true } },
        },
      });
      if (!fresh) throw new NotFoundException('Outpass not found');

      if (fresh.status !== 'PENDING' && !fresh.status.startsWith('PENDING')) {
        throw new ConflictException(`Outpass has already been decided (${fresh.status})`);
      }

      if (fresh.currentStageRoleId && fresh.currentStageRoleId !== 'tutor') {
        throw new ForbiddenException(
          `This outpass is currently awaiting approval from a ${fresh.currentStageRoleId}, not your role`,
        );
      }

      const assignedTutorId = fresh.tutorId || fresh.studentUser?.tutorId || fresh.student?.tutorId;
      if (assignedTutorId && assignedTutorId !== user.userId) {
        throw new ForbiddenException('You can only approve or reject outpasses assigned to you as tutor');
      }

      const existingApproval = await tx.approval.findUnique({
        where: { requestId_stage: { requestId, stage: 'tutor' } },
      });
      if (existingApproval) {
        throw new ConflictException('Approval for tutor stage has already been recorded');
      }

      const approvalComment = comment || 'Tutor approved and forwarded to HOD';

      await tx.approval.create({
        data: {
          requestId,
          stage: 'tutor',
          stageRoleId: 'tutor',
          approverId: user.userId,
          decision: Decision.APPROVED,
          comment: approvalComment,
        },
      });

      return tx.outpassRequest.update({
        where: { id: requestId },
        data: {
          status: OutpassStatus.PENDING_HOD,
          approvalPath: 'FORWARD_HOD',
          currentStageRoleId: 'hod',
          currentStageIndex: 1,
          currentStep: 1,
          version: { increment: 1 },
        },
        include: this.detailInclude(),
      });
    });

    const targetStudentId = updated.studentUserId || updated.studentId;
    if (targetStudentId) {
      await this.notifications.push(
        targetStudentId,
        'Stage approved — forwarded to HOD',
        'Tutor Approved — Awaiting HOD Approval',
      );
    }

    const studentObj = (updated as any).studentUser || (updated as any).student?.user;
    await this.notifyApproversForStage(updated, 'hod', studentObj);

    await this.audit.append(user.userId, 'tutor', 'OUTPASS_FORWARDED_TO_HOD', 'OutpassRequest', requestId, {
      path: 'FORWARD_HOD',
      comment,
      approverId: user.userId,
    });

    return this.serializeDetail(updated);
  }

  async reject(user: AuthUser, requestId: string, reason?: string) {
    const rejectionReason = (reason || '').trim();
    if (!rejectionReason) {
      throw new ConflictException('A reason is mandatory when rejecting');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const fresh = await tx.outpassRequest.findUnique({
        where: { id: requestId },
        include: {
          student: { include: { user: true } },
          studentUser: { include: { tutor: true, deptRef: true } },
        },
      });
      if (!fresh) throw new NotFoundException('Outpass not found');

      if (fresh.status !== 'PENDING' && !fresh.status.startsWith('PENDING')) {
        throw new ConflictException(`Outpass has already been decided (${fresh.status})`);
      }

      if (fresh.currentStageRoleId && fresh.currentStageRoleId !== user.roleId) {
        throw new ForbiddenException(
          `This outpass is currently awaiting approval from a ${fresh.currentStageRoleId}, not your role`,
        );
      }

      if (user.roleId === 'tutor') {
        const assignedTutorId = fresh.tutorId || fresh.studentUser?.tutorId || fresh.student?.tutorId;
        if (assignedTutorId && assignedTutorId !== user.userId) {
          throw new ForbiddenException('You can only approve or reject outpasses assigned to you as tutor');
        }
      }

      if (user.roleId === 'hod') {
        const studentDept = fresh.studentUser?.deptRef?.code || fresh.studentUser?.department || fresh.student?.department;
        const dbUser = await tx.user.findUnique({ where: { id: user.userId }, include: { deptRef: true } });
        const hodDept = dbUser?.deptRef?.code || dbUser?.department;
        if (hodDept && studentDept && hodDept.toUpperCase() !== studentDept.toUpperCase()) {
          throw new ForbiddenException('You can only approve outpasses for students in your department');
        }
      }

      const currentStage = fresh.currentStageRoleId || user.roleId || 'stage';

      await tx.approval.create({
        data: {
          requestId,
          stage: currentStage,
          stageRoleId: currentStage,
          approverId: user.userId,
          decision: Decision.REJECTED,
          comment: rejectionReason,
        },
      });

      return tx.outpassRequest.update({
        where: { id: requestId },
        data: {
          status: OutpassStatus.REJECTED,
          currentStageRoleId: null,
          version: { increment: 1 },
        },
        include: this.detailInclude(),
      });
    });

    const targetStudentId = updated.studentUserId || updated.studentId;
    if (targetStudentId) {
      await this.notifications.push(
        targetStudentId,
        'Outpass request rejected',
        rejectionReason,
      );
    }

    await this.audit.append(user.userId, user.roleId || user.role, 'OUTPASS_REJECTED', 'OutpassRequest', requestId, {
      decision: 'REJECTED',
      stage: updated.currentStageRoleId || user.roleId,
      reason: rejectionReason,
      approverId: user.userId,
    });

    return this.serializeDetail(updated);
  }

  async decide(user: AuthUser, requestId: string, dto: DecisionDto) {
    const decision = dto.decision.toUpperCase();

    // 1. Direct approval by tutor
    if (
      decision === 'DIRECT_APPROVE' ||
      decision === 'APPROVE_DIRECT' ||
      ((decision === 'APPROVED' || decision === 'APPROVE') && dto.path === 'DIRECT')
    ) {
      return this.approveDirect(user, requestId, dto.comment);
    }

    // 2. Forward to HOD by tutor
    if (
      decision === 'FORWARD_HOD' ||
      decision === 'APPROVE_AND_FORWARD' ||
      ((decision === 'APPROVED' || decision === 'APPROVE') && (dto.path === 'FORWARD_HOD' || dto.path === 'FORWARDED'))
    ) {
      return this.forwardToHod(user, requestId, dto.comment);
    }

    // 3. Rejection
    if (decision === 'REJECTED' || decision === 'REJECT') {
      return this.reject(user, requestId, dto.comment);
    }

    // 4. Standard stage approval (e.g. HOD approval or normal sequential stage)
    const request = await this.prisma.outpassRequest.findUnique({
      where: { id: requestId },
      include: {
        student: { include: { user: true } },
        studentUser: { include: { tutor: true, deptRef: true } },
      },
    });
    if (!request) throw new NotFoundException('Outpass not found');

    if (request.status !== 'PENDING' && !request.status.startsWith('PENDING')) {
      throw new ConflictException(`Outpass has already been decided (${request.status})`);
    }

    if (request.currentStageRoleId && request.currentStageRoleId !== user.roleId) {
      throw new ForbiddenException(
        `This outpass is currently awaiting approval from a ${request.currentStageRoleId}, not your role`,
      );
    }

    if (user.roleId === 'tutor') {
      const assignedTutorId = request.tutorId || request.studentUser?.tutorId || request.student?.tutorId;
      if (assignedTutorId && assignedTutorId !== user.userId) {
        throw new ForbiddenException('You can only approve or reject outpasses assigned to you as tutor');
      }
    }

    if (user.roleId === 'hod') {
      const dbUser = await this.prisma.user.findUnique({
        where: { id: user.userId },
        include: { deptRef: true },
      });
      const hodDept = dbUser?.deptRef?.code || dbUser?.department;
      const studentDept = request.studentUser?.deptRef?.code || request.studentUser?.department || request.student?.department;
      if (hodDept && studentDept && hodDept.toUpperCase() !== studentDept.toUpperCase()) {
        throw new ForbiddenException('You can only approve outpasses for students in your department');
      }
    }

    const currentStage = request.currentStageRoleId || 'STAGE';
    const chain = request.approvalChain || [];
    const nextIndex = request.currentStageIndex + 1;
    const isFinalStage = nextIndex >= chain.length || user.roleId === 'hod';
    const nextStageRoleId = isFinalStage ? null : chain[nextIndex];

    const targetStudentId = request.studentUserId || request.studentId;

    const updated = await this.prisma.$transaction(async (tx) => {
      const existingApproval = await tx.approval.findUnique({
        where: { requestId_stage: { requestId, stage: currentStage } },
      });
      if (existingApproval) {
        throw new ConflictException(`Approval for ${currentStage} stage has already been recorded`);
      }

      await tx.approval.create({
        data: {
          requestId,
          stage: currentStage,
          stageRoleId: currentStage,
          approverId: user.userId,
          decision: Decision.APPROVED,
          comment: dto.comment ?? null,
        },
      });

      if (isFinalStage) {
        const now = new Date();
        const validFrom = request.requestedExitAt.getTime() <= now.getTime() ? request.requestedExitAt : now;
        return tx.outpassRequest.update({
          where: { id: requestId },
          data: {
            status: OutpassStatus.APPROVED,
            currentStageRoleId: null,
            currentStageIndex: nextIndex,
            currentStep: nextIndex,
            validFrom,
            validUntil: request.expectedReturnAt,
            version: { increment: 1 },
          },
          include: this.detailInclude(),
        });
      }

      return tx.outpassRequest.update({
        where: { id: requestId },
        data: {
          status: `PENDING_${nextStageRoleId!.toUpperCase()}`,
          currentStageIndex: nextIndex,
          currentStep: nextIndex,
          currentStageRoleId: nextStageRoleId,
          version: { increment: 1 },
        },
        include: this.detailInclude(),
      });
    });

    if (isFinalStage) {
      if (targetStudentId) {
        const approverTitle = user.roleId === 'hod' ? 'HOD' : 'Approver';
        await this.notifications.push(
          targetStudentId,
          'Outpass APPROVED — QR ready',
          `Approved by ${approverTitle} — Final Approval. Open your app to access your official pass ticket and gate QR code`,
        );
      }
    } else if (nextStageRoleId) {
      if (targetStudentId) {
        await this.notifications.push(
          targetStudentId,
          `Stage approved — forwarded to ${nextStageRoleId.toUpperCase()}`,
          `Your outpass is now awaiting ${nextStageRoleId.toUpperCase()} authorization`,
        );
      }
      const studentObj = (request as any).studentUser || (request as any).student?.user;
      await this.notifyApproversForStage(updated, nextStageRoleId, studentObj);
    }

    const auditAction = user.roleId === 'hod' ? 'OUTPASS_HOD_APPROVED' : 'OUTPASS_DECIDED';
    await this.audit.append(user.userId, user.roleId || user.role, auditAction, 'OutpassRequest', requestId, {
      decision: dto.decision,
      stage: currentStage,
      isFinalStage,
      approverId: user.userId,
    });

    return this.serializeDetail(updated);
  }

  private async notifyApproversForStage(outpass: any, roleId: string, studentUser: any) {
    if (!studentUser) return;

    if (roleId === 'tutor') {
      const tutorId = studentUser.tutorId || studentUser.tutor?.id;
      if (tutorId) {
        await this.notifications.push(
          tutorId,
          `New outpass request — ${studentUser.name}`,
          `${outpass.purposeCategory} · ${outpass.destination}`,
        );
      }
    } else if (roleId === 'hod') {
      const dept = studentUser.deptRef?.code || studentUser.department;
      if (dept) {
        const hod = await this.prisma.user.findFirst({
          where: { roleId: 'hod', department: dept, active: true },
        });
        if (hod) {
          await this.notifications.push(
            hod.id,
            `New outpass request for HOD authorization — ${studentUser.name}`,
            `${outpass.purposeCategory} · ${outpass.destination}`,
          );
        }
      }
    }
  }

  private detailInclude() {
    return {
      tutor: { select: { id: true, name: true, mobile: true } },
      student: {
        include: {
          user: { select: { id: true, name: true, mobile: true, department: true } },
          tutor: { select: { id: true, name: true, mobile: true } },
        },
      },
      studentUser: {
        include: {
          tutor: { select: { id: true, name: true, mobile: true } },
          deptRef: { select: { id: true, code: true, name: true } },
        },
      },
      approvals: true,
    };
  }

  private serialize(o: any) {
    return { ...o, lastTokenTs: Number(o.lastTokenTs) };
  }

  private serializeDetail(o: any) {
    const { student, studentUser, approvals, ...rest } = o;
    const effectiveStudentUser = studentUser || student?.user;
    const effectiveTutor = rest.tutor || studentUser?.tutor || student?.tutor;

    return {
      ...this.serialize(rest),
      student: {
        id: effectiveStudentUser?.id || student?.userId,
        name: effectiveStudentUser?.name || 'Student',
        registerNo: student?.registerNo || `REG-${effectiveStudentUser?.mobile?.slice(-4) || 'CCE'}`,
        department: effectiveStudentUser?.deptRef?.code || effectiveStudentUser?.department || student?.department || 'GENERAL',
        semester: student?.semester ?? 1,
        year: effectiveStudentUser?.year ?? student?.year ?? null,
        division: effectiveStudentUser?.division ?? student?.division ?? null,
        tutorName: effectiveTutor?.name ?? null,
        tutorMobile: effectiveTutor?.mobile ?? null,
      },
      approvals: (approvals || []).map((a: any) => ({
        stage: a.stage,
        stageRoleId: a.stageRoleId,
        approverId: a.approverId,
        decision: a.decision,
        comment: a.comment,
        decidedAt: a.decidedAt,
      })),
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

  private async nextPassCode(): Promise<string> {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    for (let attempt = 0; attempt < 25; attempt++) {
      let code = '';
      for (let i = 0; i < 6; i++) {
        code += chars[Math.floor(Math.random() * chars.length)];
      }
      const exists = await this.prisma.outpassRequest.findUnique({ where: { passCode: code } });
      if (!exists) return code;
    }
    return `P${Date.now().toString(36).toUpperCase().slice(-5)}`;
  }
}
