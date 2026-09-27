import { Injectable, NotFoundException } from '@nestjs/common';
import { OutpassStatus } from '@prisma/client';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { AuthUser } from '../common/jwt-auth.guard';
import { parseQrToken, verifySignature, checkWindow } from './token-verify';
import { ScanDto } from './dto';

const MIN_DWELL_MS = 10 * 60 * 1000; // §6.9 minimum dwell between exit and entry
const PENDING: OutpassStatus[] = ['PENDING_TUTOR', 'PENDING_HOD'];

const RESULT_MESSAGE: Record<string, string> = {
  OK_EXIT: 'OUTPASS APPROVED — ALLOW EXIT',
  OK_ENTRY: 'RETURN RECORDED',
  PENDING_TUTOR: 'Tutor approval pending',
  PENDING_HOD: 'HOD approval pending',
  REJECTED: 'Request rejected',
  EXPIRED: 'Outpass expired',
  NOT_YET_VALID: 'Not valid yet',
  CANCELLED: 'Outpass cancelled',
  ALREADY_USED: 'Outpass already used',
  QR_INVALID: 'QR invalid',
  QR_STALE: 'QR expired — ask student to refresh',
  WRONG_GATE: 'Not allowed at this gate/direction',
  DEVICE_REVOKED: 'Student device revoked — contact supervisor',
  MIN_DWELL: 'Too soon after exit — minimum dwell time',
};

@Injectable()
export class GateService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async startShift(user: AuthUser, gateId: string) {
    const gate = await this.prisma.gate.findUnique({ where: { id: gateId } });
    if (!gate) throw new NotFoundException('Gate not found');
    await this.audit.append(user.userId, user.role, 'SHIFT_STARTED', 'Gate', gateId, null);
    return { gate: { id: gate.id, name: gate.name }, startedAt: new Date().toISOString() };
  }

  async scan(user: AuthUser, dto: ScanDto) {
    // Idempotency: same client_scan_id returns the stored result (§9).
    const existing = await this.prisma.gateEvent.findUnique({
      where: { clientScanId: dto.clientScanId },
    });
    if (existing) {
      return this.response(existing.resultCode, existing.outpassId, existing.detail, true);
    }

    const now = new Date();
    const nowSec = Math.floor(now.getTime() / 1000);
    const guardDeviceId = await this.resolveGuardDeviceId(user, dto.deviceId);

    const deny = async (code: string, outpassId: string | null, detail: Record<string, unknown>) => {
      await this.recordEvent(dto, user, guardDeviceId, code, outpassId, detail);
      return this.response(code, outpassId, detail, false);
    };

    const parsed = parseQrToken(dto.token);
    if (!parsed.ok) return deny('QR_INVALID', null, { reason: 'malformed token' });

    const request0 = await this.prisma.outpassRequest.findUnique({
      where: { id: parsed.outpassId },
      include: {
        student: {
          include: { user: { include: { devices: { where: { revokedAt: null } } } } },
        },
      },
    });
    if (!request0) return deny('QR_INVALID', null, { reason: 'unknown outpass' });
    let request: any = request0;

    const device = request.student.user.devices[0];
    if (!device) return deny('DEVICE_REVOKED', request.id, { reason: 'no active device' });

    if (!verifySignature(parsed.message, parsed.sig, device.publicKey)) {
      return deny('QR_INVALID', request.id, { reason: 'bad signature' });
    }
    if (!checkWindow(parsed.ts, nowSec)) {
      return deny('QR_STALE', request.id, { ts: parsed.ts });
    }

    const ts = BigInt(parsed.ts);
    const baseDetail = {
      student: {
        name: request.student.user.name,
        registerNo: request.student.registerNo,
        department: request.student.department,
        semester: request.student.semester,
      },
      destination: request.destination,
      purpose: request.purposeCategory,
    };

    if (dto.direction === 'EXIT') {
      if (request.status === 'APPROVED') {
        const ok = await this.prisma.$transaction(async (tx) => {
          const u = await tx.outpassRequest.updateMany({
            where: {
              id: request.id,
              status: 'APPROVED',
              lastTokenTs: { lt: ts },
              validFrom: { lte: now },
              validUntil: { gte: now },
            },
            data: {
              status: 'EXITED',
              exitAt: now,
              exitGateId: dto.gateId,
              lastTokenTs: ts,
              version: { increment: 1 },
            },
          });
          if (u.count === 0) return false;
          await tx.gateEvent.create({
            data: {
              outpassId: request.id,
              gateId: dto.gateId,
              guardId: user.userId,
              deviceId: guardDeviceId,
              direction: 'EXIT',
              resultCode: 'OK_EXIT',
              clientScanId: dto.clientScanId,
              detail: JSON.stringify(baseDetail),
            },
          });
          return true;
        });
        if (ok) {
          await this.audit.append(user.userId, user.role, 'GATE_EXIT', 'OutpassRequest', request.id, {
            displayId: request.displayId,
          });
          return this.response('OK_EXIT', request.id, baseDetail, false);
        }
        request = await this.reload(request.id);
      }
      return deny(this.mapExitDeny(request, ts, now), request.id, {
        ...baseDetail,
        status: request.status,
        exitAt: request.exitAt,
      });
    }

    // ENTRY direction
    if (request.status === 'EXITED' || request.status === 'OVERDUE') {
      const dwellOk =
        request.exitAt && now.getTime() - request.exitAt.getTime() >= MIN_DWELL_MS;
      if (!dwellOk) {
        return deny('MIN_DWELL', request.id, { ...baseDetail, exitAt: request.exitAt });
      }
      const ok = await this.prisma.$transaction(async (tx) => {
        const u = await tx.outpassRequest.updateMany({
          where: {
            id: request.id,
            status: { in: ['EXITED', 'OVERDUE'] },
            lastTokenTs: { lt: ts },
          },
          data: {
            status: 'RETURNED',
            entryAt: now,
            entryGateId: dto.gateId,
            lastTokenTs: ts,
            version: { increment: 1 },
          },
        });
        if (u.count === 0) return false;
        await tx.gateEvent.create({
          data: {
            outpassId: request.id,
            gateId: dto.gateId,
            guardId: user.userId,
            deviceId: guardDeviceId,
            direction: 'ENTRY',
            resultCode: 'OK_ENTRY',
            clientScanId: dto.clientScanId,
            detail: JSON.stringify(baseDetail),
          },
        });
        return true;
      });
      if (ok) {
        await this.audit.append(user.userId, user.role, 'GATE_ENTRY', 'OutpassRequest', request.id, {
          displayId: request.displayId,
        });
        return this.response('OK_ENTRY', request.id, baseDetail, false);
      }
      request = await this.reload(request.id);
    }
    return deny(this.mapEntryDeny(request), request.id, {
      ...baseDetail,
      status: request.status,
    });
  }

  async myScans(user: AuthUser) {
    const events = await this.prisma.gateEvent.findMany({
      where: { guardId: user.userId },
      orderBy: { scannedAt: 'desc' },
      take: 200,
    });
    return events.map((e) => ({
      id: e.id,
      direction: e.direction,
      resultCode: e.resultCode,
      scannedAt: e.scannedAt,
      detail: e.detail ? JSON.parse(e.detail) : null,
    }));
  }

  private mapExitDeny(request: any, ts: bigint, now: Date): string {
    switch (request.status) {
      case 'EXITED':
      case 'RETURNED':
        return 'ALREADY_USED';
      case 'EXPIRED':
        return 'EXPIRED';
      case 'CANCELLED':
        return 'CANCELLED';
      case 'REJECTED':
        return 'REJECTED';
      case 'PENDING_TUTOR':
        return 'PENDING_TUTOR';
      case 'PENDING_HOD':
        return 'PENDING_HOD';
      case 'APPROVED':
        if (request.lastTokenTs >= ts) return 'QR_STALE'; // replay of older window
        if (request.validUntil && request.validUntil < now) return 'EXPIRED';
        if (request.validFrom && request.validFrom > now) return 'NOT_YET_VALID';
        return 'QR_STALE';
      default:
        return 'QR_INVALID';
    }
  }

  private mapEntryDeny(request: any): string {
    switch (request.status) {
      case 'RETURNED':
        return 'ALREADY_USED';
      case 'APPROVED':
        return 'WRONG_GATE'; // not exited yet — entry gate
      case 'EXPIRED':
        return 'EXPIRED';
      case 'CANCELLED':
        return 'CANCELLED';
      case 'REJECTED':
        return 'REJECTED';
      case 'PENDING_TUTOR':
        return 'PENDING_TUTOR';
      case 'PENDING_HOD':
        return 'PENDING_HOD';
      default:
        return 'QR_INVALID';
    }
  }

  private async reload(id: string): Promise<any> {
    return this.prisma.outpassRequest.findUnique({
      where: { id },
      include: {
        student: {
          include: { user: { include: { devices: { where: { revokedAt: null } } } } },
        },
      },
    });
  }

  private async resolveGuardDeviceId(user: AuthUser, dtoDeviceId?: string) {
    if (dtoDeviceId) return dtoDeviceId;
    const device = await this.prisma.device.findFirst({
      where: { userId: user.userId, revokedAt: null },
      select: { id: true },
    });
    return device?.id ?? 'unknown';
  }

  private async recordEvent(
    dto: ScanDto,
    user: AuthUser,
    deviceId: string,
    code: string,
    outpassId: string | null,
    detail: Record<string, unknown> | null,
  ) {
    try {
      await this.prisma.gateEvent.create({
        data: {
          outpassId,
          gateId: dto.gateId,
          guardId: user.userId,
          deviceId,
          direction: dto.direction,
          resultCode: code,
          clientScanId: dto.clientScanId,
          detail: detail ? JSON.stringify(detail) : null,
        },
      });
    } catch {
      // Lost an idempotency race — the event already exists; safe to ignore.
    }
  }

  private response(code: string, outpassId: string | null, detail: any, replay: boolean) {
    return {
      result: code,
      message: RESULT_MESSAGE[code] ?? code,
      outpass: detail?.student
        ? {
            id: outpassId,
            ...detail,
          }
        : null,
      replay,
      offline: false,
    };
  }
}
