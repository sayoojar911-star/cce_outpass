import { ConflictException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { OutpassService } from './outpass.service';
import { GateService, OUTPASS_STATUS } from '../gate/gate.service';
import { AuthUser } from '../common/jwt-auth.guard';

describe('Outpass Cancellation Rules & Race Condition Tests', () => {
  let prisma: PrismaService;
  let audit: AuditService;
  let notifications: NotificationsService;
  let outpassService: OutpassService;
  let gateService: GateService;

  let studentA: { id: string; userId: string; mobile: string };
  let studentB: { id: string; userId: string; mobile: string };
  let tutorUser: { id: string; userId: string; mobile: string };
  let gate: { id: string; name: string };

  const studentUserAuth = (u: { id: string }): AuthUser => ({
    userId: u.id,
    role: 'student',
    roleId: 'student',
    name: 'Student A',
    permissions: ['createOutpass'],
    mobile: '9300000001',
  });

  const studentBAuth = (u: { id: string }): AuthUser => ({
    userId: u.id,
    role: 'student',
    roleId: 'student',
    name: 'Student B',
    permissions: ['createOutpass'],
    mobile: '9300000002',
  });

  const guardAuth = (id: string): AuthUser => ({
    userId: id,
    role: 'guard',
    roleId: 'guard',
    name: 'Guard 1',
    permissions: ['scanPass'],
    mobile: '9300000004',
  });

  beforeAll(async () => {
    prisma = new PrismaService();
    await prisma.$connect();
    audit = new AuditService(prisma);
    notifications = new NotificationsService(prisma);
    outpassService = new OutpassService(prisma, audit, notifications);
    gateService = new GateService(prisma, audit);

    // Clean up old test data
    await prisma.gateEvent.deleteMany({
      where: { request: { displayId: { startsWith: 'TEST-CANCEL-' } } },
    });
    await prisma.approval.deleteMany({
      where: { request: { displayId: { startsWith: 'TEST-CANCEL-' } } },
    });
    await prisma.outpassRequest.deleteMany({
      where: { displayId: { startsWith: 'TEST-CANCEL-' } },
    });
    await prisma.student.deleteMany({
      where: { user: { mobile: { in: ['9300000001', '9300000002', '9300000003', '9300000004'] } } },
    });
    await prisma.user.deleteMany({
      where: { mobile: { in: ['9300000001', '9300000002', '9300000003', '9300000004'] } },
    });

    // Ensure Roles exist
    await prisma.role.upsert({
      where: { id: 'student' },
      update: {},
      create: { id: 'student', name: 'Student', permissions: ['createOutpass'] },
    });
    await prisma.role.upsert({
      where: { id: 'tutor' },
      update: {},
      create: { id: 'tutor', name: 'Tutor', permissions: ['approveTutor'] },
    });
    await prisma.role.upsert({
      where: { id: 'guard' },
      update: {},
      create: { id: 'guard', name: 'Guard', permissions: ['scanPass'] },
    });

    // Create Tutor
    const tutor = await prisma.user.create({
      data: {
        mobile: '9300000003',
        name: 'Test Tutor',
        roleId: 'tutor',
      },
    });
    tutorUser = { id: tutor.id, userId: tutor.id, mobile: tutor.mobile };

    // Create Student A
    const uA = await prisma.user.create({
      data: {
        mobile: '9300000001',
        name: 'Student A',
        roleId: 'student',
        student: {
          create: {
            registerNo: 'TEST-REG-A',
            department: 'CSE',
            semester: 4,
            tutorId: tutor.id,
          },
        },
      },
      include: { student: true },
    });
    studentA = { id: uA.id, userId: uA.id, mobile: uA.mobile };

    // Create Student B
    const uB = await prisma.user.create({
      data: {
        mobile: '9300000002',
        name: 'Student B',
        roleId: 'student',
        student: {
          create: {
            registerNo: 'TEST-REG-B',
            department: 'CSE',
            semester: 4,
            tutorId: tutor.id,
          },
        },
      },
      include: { student: true },
    });
    studentB = { id: uB.id, userId: uB.id, mobile: uB.mobile };

    // Ensure Gate exists
    const g = await prisma.gate.findFirst();
    if (g) {
      gate = { id: g.id, name: g.name };
    } else {
      const createdGate = await prisma.gate.create({
        data: { name: 'Main Gate' },
      });
      gate = { id: createdGate.id, name: createdGate.name };
    }
  });

  afterAll(async () => {
    await prisma.gateEvent.deleteMany({
      where: { request: { displayId: { startsWith: 'TEST-CANCEL-' } } },
    });
    await prisma.approval.deleteMany({
      where: { request: { displayId: { startsWith: 'TEST-CANCEL-' } } },
    });
    await prisma.outpassRequest.deleteMany({
      where: { displayId: { startsWith: 'TEST-CANCEL-' } },
    });
    await prisma.student.deleteMany({
      where: { user: { mobile: { in: ['9300000001', '9300000002', '9300000003', '9300000004'] } } },
    });
    await prisma.user.deleteMany({
      where: { mobile: { in: ['9300000001', '9300000002', '9300000003', '9300000004'] } },
    });
    await prisma.$disconnect();
  });

  let counter = 0;
  async function createTestOutpass(status: string, extra: any = {}) {
    counter++;
    const now = new Date();
    const exitAt = new Date(now.getTime() + 3600 * 1000);
    const returnAt = new Date(now.getTime() + 7200 * 1000);

    return prisma.outpassRequest.create({
      data: {
        displayId: `TEST-CANCEL-${Date.now()}-${counter}`,
        studentId: studentA.userId,
        studentUserId: studentA.userId,
        tutorId: tutorUser.userId,
        status,
        destination: 'Thrissur Library',
        purposeCategory: 'ACADEMIC',
        requestedExitAt: exitAt,
        expectedReturnAt: returnAt,
        validFrom: now,
        validUntil: returnAt,
        passCode: `PC${counter.toString().padStart(4, '0')}`,
        ...extra,
      },
    });
  }

  // 1. Cancel pending request (Rule 1 & 2)
  it('1. permits student to cancel a pending request (PENDING_TUTOR / PENDING_HOD)', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');
    const res = await outpassService.cancel(studentUserAuth(studentA), op.id, 'Change of study schedule');

    expect(res.ok).toBe(true);
    expect(res.outpass.status).toBe('CANCELLED');
    expect(res.outpass.cancelReason).toBe('Change of study schedule');

    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('CANCELLED');
    expect(dbOp?.cancelledBy).toBe(studentA.userId);
  });

  // 2. Cancel approved request before exit (Rule 3)
  it('2. permits student to cancel an approved request before recording exit and ensures scanner rejects it', async () => {
    const op = await createTestOutpass('APPROVED', { exitAt: null });
    const res = await outpassService.cancel(studentUserAuth(studentA), op.id, 'No longer need to leave');

    expect(res.ok).toBe(true);
    expect(res.outpass.status).toBe('CANCELLED');

    // Verify security scanner rejects the cancelled pass immediately
    const guard = guardAuth('guard-1');
    const scanRes = await gateService.manualEntry(guard, {
      code: op.passCode!,
      direction: 'EXIT',
      gateId: gate.id,
      clientScanId: `scan-${Date.now()}-${counter}`,
    });

    expect(scanRes.result).toBe('CANCELLED');
    expect(scanRes.message).toBe('Outpass was cancelled');
  });

  // 3. Cancel overdue unused request (Rule 4)
  it('3. permits student to cancel an overdue outpass if no exit has been recorded', async () => {
    const op = await createTestOutpass('OVERDUE', { exitAt: null });
    const res = await outpassService.cancel(studentUserAuth(studentA), op.id, 'Expired before leaving');

    expect(res.ok).toBe(true);
    expect(res.outpass.status).toBe('CANCELLED');

    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('CANCELLED');
  });

  // 3b. Cancel overdue request even if exit was recorded
  it('3b. permits student to cancel an overdue outpass even after overdue with exit recorded', async () => {
    const op = await createTestOutpass('OVERDUE', { exitAt: new Date() });
    const res = await outpassService.cancel(studentUserAuth(studentA), op.id, 'Closing overdue pass');

    expect(res.ok).toBe(true);
    expect(res.outpass.status).toBe('CANCELLED');

    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('CANCELLED');
  });

  // 4. Reject cancellation during active EXITED status
  it('4. rejects cancellation while pass is actively EXITED (before becoming overdue)', async () => {
    const op = await createTestOutpass('EXITED', { exitAt: new Date() });

    await expect(
      outpassService.cancel(studentUserAuth(studentA), op.id, 'Trying to cancel while outside'),
    ).rejects.toThrow(ConflictException);

    await expect(
      outpassService.cancel(studentUserAuth(studentA), op.id),
    ).rejects.toThrow('Cannot cancel outpass after campus exit has been recorded');

    // Pass should still remain EXITED
    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('EXITED');
  });

  // 5. Reject cancellation after return (Rule 6)
  it('5. rejects cancellation after student has already returned', async () => {
    const op = await createTestOutpass('RETURNED', { exitAt: new Date(), entryAt: new Date() });

    await expect(
      outpassService.cancel(studentUserAuth(studentA), op.id),
    ).rejects.toThrow(ConflictException);

    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('RETURNED');
  });

  // 6. Reject duplicate cancellation (Rule 6)
  it('6. rejects duplicate cancellation on an already cancelled outpass', async () => {
    const op = await createTestOutpass('CANCELLED', {
      cancelledAt: new Date(),
      cancelledBy: studentA.userId,
    });

    await expect(
      outpassService.cancel(studentUserAuth(studentA), op.id),
    ).rejects.toThrow(ConflictException);

    await expect(
      outpassService.cancel(studentUserAuth(studentA), op.id),
    ).rejects.toThrow('Outpass is already cancelled');
  });

  // 7. Prevent race conditions: simultaneous cancellation and exit requests
  it('7. uses atomic database transaction to prevent race condition between cancellation and exit scanning', async () => {
    const op = await createTestOutpass('APPROVED', { exitAt: null });

    // Simulate simultaneous cancellation and exit attempt
    const cancelPromise = outpassService.cancel(studentUserAuth(studentA), op.id, 'Race condition test');
    const exitPromise = prisma.$transaction(async (tx) => {
      const u = await tx.outpassRequest.updateMany({
        where: { id: op.id, status: OUTPASS_STATUS.APPROVED, exitAt: null },
        data: { status: OUTPASS_STATUS.EXITED, exitAt: new Date() },
      });
      return u.count > 0;
    });

    await Promise.allSettled([cancelPromise, exitPromise]);

    const final = await prisma.outpassRequest.findUnique({ where: { id: op.id } });

    // The pass must be EITHER Cancelled OR Exited, never corrupted or in an inconsistent state
    expect(['CANCELLED', 'EXITED']).toContain(final?.status);

    if (final?.status === 'CANCELLED') {
      expect(final.exitAt).toBeNull();
    } else {
      expect(final?.exitAt).not.toBeNull();
    }
  });

  // 8. Ownership verification check
  it('8. rejects cancellation attempt by a student who does not own the outpass', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');

    // Student B attempts to cancel Student A's outpass
    await expect(
      outpassService.cancel(studentBAuth(studentB), op.id),
    ).rejects.toThrow(ForbiddenException);

    await expect(
      outpassService.cancel(studentBAuth(studentB), op.id),
    ).rejects.toThrow('You can only cancel your own outpass');
  });
});
