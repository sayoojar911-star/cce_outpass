import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { AuthUser } from '../common/jwt-auth.guard';
import { parseQrToken, verifySignature, checkWindow } from './token-verify';
import { ScanDto, ManualEntryDto } from './dto';

// Outpass Lifecycle State Constants
export const OUTPASS_STATUS = {
  PENDING_TUTOR: 'PENDING_TUTOR',
  PENDING_TUTOR_APPROVAL: 'PENDING_TUTOR_APPROVAL',
  PENDING_HOD: 'PENDING_HOD',
  PENDING_HOD_APPROVAL: 'PENDING_HOD_APPROVAL',
  APPROVED: 'APPROVED',
  EXITED: 'EXITED',
  RETURNED: 'RETURNED',
  OVERDUE: 'OVERDUE',
  EXPIRED: 'EXPIRED',
  CANCELLED: 'CANCELLED',
  REJECTED: 'REJECTED',
} as const;

export function formatISTTime(date: Date | string | null | undefined): string {
  if (!date) return '';
  const d = typeof date === 'string' ? new Date(date) : date;
  if (isNaN(d.getTime())) return '';
  return d.toLocaleTimeString('en-IN', {
    timeZone: 'Asia/Kolkata',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

export function formatISTDateTime(date: Date | string | null | undefined): string {
  if (!date) return '';
  const d = typeof date === 'string' ? new Date(date) : date;
  if (isNaN(d.getTime())) return '';
  return d.toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

interface GuardRateLimitState {
  failures: number;
  lockedUntil?: Date;
}

@Injectable()
export class GateService {
  // In-memory guard rate limiting for manual entry (5 wrong attempts -> 2 min lockout)
  private readonly guardLockouts = new Map<string, GuardRateLimitState>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async getSettings(): Promise<{ minDwellMinutes: number; qrValidityWindowSeconds: number }> {
    const rows = await this.prisma.appSetting.findMany({
      where: { key: { in: ['minDwellMinutes', 'qrValidityWindowSeconds'] } },
    });
    let minDwellMinutes = 10;
    let qrValidityWindowSeconds = 120; // 60s skew + 30s token step + buffer

    for (const r of rows) {
      let val: any;
      try {
        val = JSON.parse(r.value);
      } catch {
        val = r.value;
      }
      const num = Number(val);
      if (!isNaN(num)) {
        if (r.key === 'minDwellMinutes') minDwellMinutes = Math.max(0, num);
        if (r.key === 'qrValidityWindowSeconds') qrValidityWindowSeconds = Math.max(30, num);
      }
    }
    return { minDwellMinutes, qrValidityWindowSeconds };
  }

  async startShift(user: AuthUser, gateId: string) {
    const gate = await this.prisma.gate.findUnique({ where: { id: gateId } });
    if (!gate) throw new NotFoundException('Gate not found');
    await this.audit.append(user.userId, user.role, 'SHIFT_STARTED', 'Gate', gateId, null);
    return { gate: { id: gate.id, name: gate.name }, startedAt: new Date().toISOString() };
  }

  /**
   * QR Token Scan Handler
   */
  async scan(user: AuthUser, dto: ScanDto) {
    console.log(`[GateScan] Mode: QR | Guard: ${user.userId} | Direction: ${dto.direction} | Gate: ${dto.gateId}`);

    // Idempotency check: same clientScanId returns stored result
    const existing = await this.prisma.gateEvent.findUnique({
      where: { clientScanId: dto.clientScanId },
    });
    if (existing) {
      console.log(`[GateScan] Idempotent replay hit for clientScanId: ${dto.clientScanId}`);
      return this.response(
        existing.resultCode,
        existing.outpassId,
        existing.detail ? JSON.parse(existing.detail) : null,
        true,
      );
    }

    const settings = await this.getSettings();
    const now = new Date();
    const nowSec = Math.floor(now.getTime() / 1000);
    const guardDeviceId = await this.resolveGuardDeviceId(user, dto.deviceId);

    const deny = async (code: string, outpassId: string | null, detail: Record<string, unknown>) => {
      console.log(`[GateScan] REJECTED Code: ${code} | Outpass: ${outpassId} | Detail:`, detail);
      await this.recordEvent(dto.direction, dto.gateId, dto.clientScanId, user, guardDeviceId, code, outpassId, detail);
      return this.response(code, outpassId, detail, false);
    };

    const parsed = parseQrToken(dto.token);
    if (!parsed.ok) {
      return deny('QR_INVALID', null, { reason: 'Malformed QR token format' });
    }

    const request0 = await this.prisma.outpassRequest.findUnique({
      where: { id: parsed.outpassId },
      include: {
        student: {
          include: { user: { include: { devices: { where: { revokedAt: null } } } } },
        },
      },
    });
    if (!request0) {
      return deny('QR_INVALID', null, { reason: 'Unknown outpass ID' });
    }
    let request: any = request0;

    const device = request.student.user.devices[0];
    if (!device) {
      return deny('DEVICE_REVOKED', request.id, { reason: 'No active device registered for student' });
    }

    if (!verifySignature(parsed.message, parsed.sig, device.publicKey)) {
      return deny('QR_INVALID', request.id, { reason: 'Cryptographic signature verification failed' });
    }

    // Check QR window with configurable settings (default 120s with 60s clock skew tolerance)
    if (!checkWindow(parsed.ts, nowSec, settings.qrValidityWindowSeconds)) {
      return deny('QR_STALE', request.id, {
        ts: parsed.ts,
        nowSec,
        windowSeconds: settings.qrValidityWindowSeconds,
        reason: 'QR timestamp outside validity window',
      });
    }

    const ts = BigInt(parsed.ts);
    const baseDetail = this.buildBaseDetail(request);

    // ==========================================
    // DIRECTION: EXIT
    // ==========================================
    if (dto.direction === 'EXIT') {
      if (request.status === OUTPASS_STATUS.APPROVED) {
        const ok = await this.prisma.$transaction(async (tx) => {
          const u = await tx.outpassRequest.updateMany({
            where: {
              id: request.id,
              status: OUTPASS_STATUS.APPROVED,
              lastTokenTs: { lt: ts },
              validFrom: { lte: now },
              validUntil: { gte: now },
            },
            data: {
              status: OUTPASS_STATUS.EXITED,
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
          console.log(`[GateScan] EXIT SUCCESS: Outpass ${request.displayId} EXITED at ${now.toISOString()}`);
          await this.audit.append(user.userId, user.role, 'GATE_EXIT', 'OutpassRequest', request.id, {
            displayId: request.displayId,
            exitAt: now.toISOString(),
          });
          return this.response('OK_EXIT', request.id, { ...baseDetail, exitAt: now.toISOString() }, false);
        }
        request = await this.reload(request.id);
      }

      const denyCode = this.mapExitDeny(request, ts, now);
      return deny(denyCode, request.id, {
        ...baseDetail,
        status: request.status,
        exitAt: request.exitAt,
        exitTimeIST: formatISTTime(request.exitAt),
      });
    }

    // ==========================================
    // DIRECTION: ENTRY (CAMPUS RETURN)
    // ==========================================
    if (request.status === OUTPASS_STATUS.EXITED || request.status === OUTPASS_STATUS.OVERDUE) {
      // Check MIN_DWELL configurable setting
      const minDwellMs = settings.minDwellMinutes * 60 * 1000;
      const dwellMs = request.exitAt ? now.getTime() - request.exitAt.getTime() : minDwellMs;

      if (dwellMs < minDwellMs) {
        const remainingSec = Math.ceil((minDwellMs - dwellMs) / 1000);
        const mins = Math.floor(remainingSec / 60);
        const secs = remainingSec % 60;
        const remainingText = mins > 0 ? `${mins} min ${secs} s` : `${secs} s`;

        return deny('MIN_DWELL', request.id, {
          ...baseDetail,
          exitAt: request.exitAt,
          exitTimeIST: formatISTTime(request.exitAt),
          remainingSeconds: remainingSec,
          remainingText,
        });
      }

      // Check Late Return: if returning after expectedReturnAt / validUntil
      const returnDeadline = request.validUntil || request.expectedReturnAt;
      const isLate = returnDeadline ? now.getTime() > returnDeadline.getTime() : false;
      const lateMinutes = isLate
        ? Math.max(1, Math.ceil((now.getTime() - returnDeadline.getTime()) / (60 * 1000)))
        : 0;

      const ok = await this.prisma.$transaction(async (tx) => {
        const u = await tx.outpassRequest.updateMany({
          where: {
            id: request.id,
            status: { in: [OUTPASS_STATUS.EXITED, OUTPASS_STATUS.OVERDUE] },
          },
          data: {
            status: OUTPASS_STATUS.RETURNED,
            entryAt: now,
            entryGateId: dto.gateId,
            lastTokenTs: ts,
            isLate,
            lateMinutes,
            version: { increment: 1 },
          },
        });
        if (u.count === 0) return false;

        const returnDetail = {
          ...baseDetail,
          entryAt: now.toISOString(),
          entryTimeIST: formatISTTime(now),
          isLate,
          lateMinutes,
        };

        await tx.gateEvent.create({
          data: {
            outpassId: request.id,
            gateId: dto.gateId,
            guardId: user.userId,
            deviceId: guardDeviceId,
            direction: 'ENTRY',
            resultCode: 'OK_ENTRY',
            clientScanId: dto.clientScanId,
            detail: JSON.stringify(returnDetail),
          },
        });
        return true;
      });

      if (ok) {
        console.log(`[GateScan] ENTRY SUCCESS: Outpass ${request.displayId} RETURNED at ${now.toISOString()} (Late: ${isLate})`);
        await this.audit.append(user.userId, user.role, 'GATE_ENTRY', 'OutpassRequest', request.id, {
          displayId: request.displayId,
          entryAt: now.toISOString(),
          isLate,
          lateMinutes,
        });
        return this.response('OK_ENTRY', request.id, {
          ...baseDetail,
          entryAt: now.toISOString(),
          entryTimeIST: formatISTTime(now),
          isLate,
          lateMinutes,
        }, false);
      }
      request = await this.reload(request.id);
    }

    const entryDenyCode = this.mapEntryDeny(request);
    return deny(entryDenyCode, request.id, {
      ...baseDetail,
      status: request.status,
      entryAt: request.entryAt,
      entryTimeIST: formatISTTime(request.entryAt),
    });
  }

  /**
   * Manual Pass Code Entry Handler (Stable 6-char Crockford Pass Code)
   */
  async manualEntry(user: AuthUser, dto: ManualEntryDto) {
    console.log(`[GateManual] Mode: MANUAL | Guard: ${user.userId} | Direction: ${dto.direction} | Code: ${dto.code}`);

    // Check Guard Rate Limit Lockout (5 failed attempts -> 2 min lockout)
    const rateLimit = this.guardLockouts.get(user.userId);
    const now = new Date();
    if (rateLimit?.lockedUntil && rateLimit.lockedUntil > now) {
      const remainingSec = Math.ceil((rateLimit.lockedUntil.getTime() - now.getTime()) / 1000);
      console.log(`[GateManual] Guard ${user.userId} is currently LOCKED OUT. Remaining: ${remainingSec}s`);
      return this.response('LOCKOUT', null, { remainingSeconds: remainingSec }, false);
    }

    // Idempotency check: same clientScanId
    const existing = await this.prisma.gateEvent.findUnique({
      where: { clientScanId: dto.clientScanId },
    });
    if (existing) {
      console.log(`[GateManual] Idempotent replay hit for clientScanId: ${dto.clientScanId}`);
      return this.response(
        existing.resultCode,
        existing.outpassId,
        existing.detail ? JSON.parse(existing.detail) : null,
        true,
      );
    }

    const settings = await this.getSettings();
    const guardDeviceId = await this.resolveGuardDeviceId(user, dto.deviceId);
    const normalizedCode = dto.code.trim().toUpperCase();

    const deny = async (code: string, outpassId: string | null, detail: Record<string, unknown>) => {
      console.log(`[GateManual] REJECTED Code: ${code} | Outpass: ${outpassId} | Detail:`, detail);
      await this.recordEvent(dto.direction, dto.gateId, dto.clientScanId, user, guardDeviceId, code, outpassId, detail);
      return this.response(code, outpassId, detail, false);
    };

    // Lookup by passCode OR displayId OR id (normalized uppercase)
    const request0 = await this.prisma.outpassRequest.findFirst({
      where: {
        OR: [
          { passCode: normalizedCode },
          { displayId: normalizedCode },
          { id: normalizedCode },
        ],
      },
      include: {
        student: {
          include: { user: true },
        },
      },
    });

    if (!request0) {
      // Record failed attempt for rate limiting
      const currentFailures = (rateLimit?.failures ?? 0) + 1;
      if (currentFailures >= 5) {
        const lockoutUntil = new Date(now.getTime() + 120 * 1000); // 2 minutes
        this.guardLockouts.set(user.userId, { failures: currentFailures, lockedUntil: lockoutUntil });
        console.log(`[GateManual] Guard ${user.userId} exceeded 5 attempts -> LOCKED OUT until ${lockoutUntil.toISOString()}`);
        await this.audit.append(user.userId, user.role, 'GATE_LOCKOUT', 'User', user.userId, {
          failures: currentFailures,
          lockedUntil: lockoutUntil.toISOString(),
        });
        return deny('LOCKOUT', null, { remainingSeconds: 120, codeEntered: normalizedCode });
      } else {
        this.guardLockouts.set(user.userId, { failures: currentFailures });
      }

      return deny('NOT_FOUND', null, {
        codeEntered: normalizedCode,
        attemptsRemaining: 5 - currentFailures,
        reason: 'Outpass code not found',
      });
    }

    // Valid code found -> reset rate limit failures
    this.guardLockouts.delete(user.userId);

    let request: any = request0;
    const baseDetail = this.buildBaseDetail(request);

    // ==========================================
    // DIRECTION: EXIT (Manual)
    // ==========================================
    if (dto.direction === 'EXIT') {
      if (request.status === OUTPASS_STATUS.APPROVED) {
        if (request.validUntil && request.validUntil < now) {
          return deny('EXPIRED', request.id, {
            ...baseDetail,
            validUntil: request.validUntil,
            expiredAtIST: formatISTDateTime(request.validUntil),
          });
        }
        if (request.validFrom && request.validFrom > now) {
          return deny('NOT_YET_VALID', request.id, {
            ...baseDetail,
            validFrom: request.validFrom,
            validFromIST: formatISTDateTime(request.validFrom),
          });
        }

        const ok = await this.prisma.$transaction(async (tx) => {
          const u = await tx.outpassRequest.updateMany({
            where: {
              id: request.id,
              status: OUTPASS_STATUS.APPROVED,
            },
            data: {
              status: OUTPASS_STATUS.EXITED,
              exitAt: now,
              exitGateId: dto.gateId,
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
              detail: JSON.stringify({ ...baseDetail, method: 'MANUAL' }),
            },
          });
          return true;
        });

        if (ok) {
          console.log(`[GateManual] EXIT SUCCESS: Outpass ${request.displayId} EXITED via manual code at ${now.toISOString()}`);
          await this.audit.append(user.userId, user.role, 'GATE_EXIT_MANUAL', 'OutpassRequest', request.id, {
            displayId: request.displayId,
            passCode: normalizedCode,
          });
          return this.response('OK_EXIT', request.id, { ...baseDetail, exitAt: now.toISOString(), method: 'MANUAL' }, false);
        }
        request = await this.reload(request.id);
      }

      const denyCode = this.mapExitDeny(request, BigInt(0), now);
      return deny(denyCode, request.id, {
        ...baseDetail,
        status: request.status,
        exitAt: request.exitAt,
        exitTimeIST: formatISTTime(request.exitAt),
      });
    }

    // ==========================================
    // DIRECTION: ENTRY (Manual Campus Return)
    // ==========================================
    if (request.status === OUTPASS_STATUS.EXITED || request.status === OUTPASS_STATUS.OVERDUE) {
      // Check MIN_DWELL
      const minDwellMs = settings.minDwellMinutes * 60 * 1000;
      const dwellMs = request.exitAt ? now.getTime() - request.exitAt.getTime() : minDwellMs;

      if (dwellMs < minDwellMs) {
        const remainingSec = Math.ceil((minDwellMs - dwellMs) / 1000);
        const mins = Math.floor(remainingSec / 60);
        const secs = remainingSec % 60;
        const remainingText = mins > 0 ? `${mins} min ${secs} s` : `${secs} s`;

        return deny('MIN_DWELL', request.id, {
          ...baseDetail,
          exitAt: request.exitAt,
          exitTimeIST: formatISTTime(request.exitAt),
          remainingSeconds: remainingSec,
          remainingText,
        });
      }

      // Check Late Return
      const returnDeadline = request.validUntil || request.expectedReturnAt;
      const isLate = returnDeadline ? now.getTime() > returnDeadline.getTime() : false;
      const lateMinutes = isLate
        ? Math.max(1, Math.ceil((now.getTime() - returnDeadline.getTime()) / (60 * 1000)))
        : 0;

      const ok = await this.prisma.$transaction(async (tx) => {
        const u = await tx.outpassRequest.updateMany({
          where: {
            id: request.id,
            status: { in: [OUTPASS_STATUS.EXITED, OUTPASS_STATUS.OVERDUE] },
          },
          data: {
            status: OUTPASS_STATUS.RETURNED,
            entryAt: now,
            entryGateId: dto.gateId,
            isLate,
            lateMinutes,
            version: { increment: 1 },
          },
        });
        if (u.count === 0) return false;

        const returnDetail = {
          ...baseDetail,
          method: 'MANUAL',
          entryAt: now.toISOString(),
          entryTimeIST: formatISTTime(now),
          isLate,
          lateMinutes,
        };

        await tx.gateEvent.create({
          data: {
            outpassId: request.id,
            gateId: dto.gateId,
            guardId: user.userId,
            deviceId: guardDeviceId,
            direction: 'ENTRY',
            resultCode: 'OK_ENTRY',
            clientScanId: dto.clientScanId,
            detail: JSON.stringify(returnDetail),
          },
        });
        return true;
      });

      if (ok) {
        console.log(`[GateManual] ENTRY SUCCESS: Outpass ${request.displayId} RETURNED via manual code at ${now.toISOString()} (Late: ${isLate})`);
        await this.audit.append(user.userId, user.role, 'GATE_ENTRY_MANUAL', 'OutpassRequest', request.id, {
          displayId: request.displayId,
          passCode: normalizedCode,
          isLate,
          lateMinutes,
        });
        return this.response('OK_ENTRY', request.id, {
          ...baseDetail,
          entryAt: now.toISOString(),
          entryTimeIST: formatISTTime(now),
          isLate,
          lateMinutes,
        }, false);
      }
      request = await this.reload(request.id);
    }

    const entryDenyCode = this.mapEntryDeny(request);
    return deny(entryDenyCode, request.id, {
      ...baseDetail,
      status: request.status,
      entryAt: request.entryAt,
      entryTimeIST: formatISTTime(request.entryAt),
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

  private buildBaseDetail(request: any) {
    const studentUser = request.student?.user ?? request.studentUser;
    return {
      displayId: request.displayId,
      passCode: request.passCode,
      type: request.type,
      student: {
        name: studentUser?.name ?? 'Unknown Student',
        registerNo: request.student?.registerNo ?? '',
        department: request.student?.department ?? '',
        semester: request.student?.semester ?? '',
        photoUrl: request.student?.photoUrl ?? studentUser?.photoUrl ?? null,
      },
      destination: request.destination,
      purpose: request.purposeCategory,
      validFrom: request.validFrom,
      validUntil: request.validUntil,
      expectedReturnAt: request.expectedReturnAt,
    };
  }

  private mapExitDeny(request: any, ts: bigint, now: Date): string {
    switch (request.status) {
      case OUTPASS_STATUS.EXITED:
      case OUTPASS_STATUS.RETURNED:
        return 'ALREADY_USED';
      case OUTPASS_STATUS.EXPIRED:
        return 'EXPIRED';
      case OUTPASS_STATUS.CANCELLED:
        return 'CANCELLED';
      case OUTPASS_STATUS.REJECTED:
        return 'REJECTED';
      case OUTPASS_STATUS.PENDING_TUTOR:
      case OUTPASS_STATUS.PENDING_TUTOR_APPROVAL:
      case OUTPASS_STATUS.PENDING_HOD:
      case OUTPASS_STATUS.PENDING_HOD_APPROVAL:
      case 'PENDING':
        return 'NOT_APPROVED';
      case OUTPASS_STATUS.APPROVED:
        if (ts > BigInt(0) && request.lastTokenTs >= ts) return 'QR_STALE';
        if (request.validUntil && request.validUntil < now) return 'EXPIRED';
        if (request.validFrom && request.validFrom > now) return 'NOT_YET_VALID';
        return 'QR_STALE';
      default:
        return 'WRONG_STATE';
    }
  }

  private mapEntryDeny(request: any): string {
    switch (request.status) {
      case OUTPASS_STATUS.RETURNED:
        return 'ALREADY_USED';
      case OUTPASS_STATUS.APPROVED:
        return 'WRONG_STATE'; // Not exited yet
      case OUTPASS_STATUS.EXPIRED:
        return 'EXPIRED';
      case OUTPASS_STATUS.CANCELLED:
        return 'CANCELLED';
      case OUTPASS_STATUS.REJECTED:
        return 'REJECTED';
      case OUTPASS_STATUS.PENDING_TUTOR:
      case OUTPASS_STATUS.PENDING_TUTOR_APPROVAL:
      case OUTPASS_STATUS.PENDING_HOD:
      case OUTPASS_STATUS.PENDING_HOD_APPROVAL:
      case 'PENDING':
        return 'NOT_APPROVED';
      default:
        return 'WRONG_STATE';
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
    direction: 'EXIT' | 'ENTRY',
    gateId: string,
    clientScanId: string,
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
          gateId,
          guardId: user.userId,
          deviceId,
          direction,
          resultCode: code,
          clientScanId,
          detail: detail ? JSON.stringify(detail) : null,
        },
      });
    } catch {
      // Idempotency conflict is safe to ignore
    }
  }

  private response(code: string, outpassId: string | null, detail: any, replay: boolean) {
    let message = code;

    switch (code) {
      case 'OK_EXIT':
        message = 'OUTPASS APPROVED — ALLOW EXIT';
        break;
      case 'OK_ENTRY':
        if (detail?.isLate) {
          message = `RETURN RECORDED (LATE BY ${detail.lateMinutes} MIN)`;
        } else {
          message = 'CAMPUS RETURN RECORDED';
        }
        break;
      case 'QR_STALE':
        message = 'QR expired, ask the student to refresh or use their pass code';
        break;
      case 'ALREADY_USED': {
        const timeStr = detail?.exitTimeIST || detail?.entryTimeIST;
        message = timeStr
          ? `This pass was already used at ${timeStr}`
          : 'This pass was already used';
        break;
      }
      case 'MIN_DWELL':
        message = detail?.remainingText
          ? `Too early. Return allowed in ${detail.remainingText}`
          : 'Too early. Minimum dwell time not reached';
        break;
      case 'NOT_FOUND':
        message = 'Outpass code not found. Please verify the code.';
        break;
      case 'LOCKOUT':
        message = `Too many failed manual attempts. Guard locked out for ${detail?.remainingSeconds ?? 120} seconds.`;
        break;
      case 'WRONG_STATE':
        message = 'Invalid pass state for this operation (e.g. not exited yet)';
        break;
      case 'NOT_APPROVED':
        message = 'Outpass has not been approved yet';
        break;
      case 'EXPIRED':
        message = detail?.expiredAtIST
          ? `Outpass expired at ${detail.expiredAtIST}`
          : 'Outpass has expired';
        break;
      case 'CANCELLED':
        message = 'Outpass was cancelled';
        break;
      case 'REJECTED':
        message = 'Outpass was rejected';
        break;
      case 'NOT_YET_VALID':
        message = 'Outpass is not valid yet';
        break;
      case 'DEVICE_REVOKED':
        message = 'Student device revoked — contact supervisor';
        break;
      case 'QR_INVALID':
        message = 'Invalid QR code';
        break;
      default:
        message = code;
    }

    return {
      result: code,
      message,
      outpass: detail?.student || detail?.displayId
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
