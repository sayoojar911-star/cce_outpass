import { ConflictException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { OutpassService } from './outpass.service';
import { GateService } from '../gate/gate.service';
import { AuthUser } from '../common/jwt-auth.guard';
import { Decision } from '@prisma/client';

describe('Tutor Approval Flow Integration & Unit Tests', () => {
  let prisma: PrismaService;
  let audit: AuditService;
  let notifications: NotificationsService;
  let outpassService: OutpassService;
  let gateService: GateService;

  let tutor1: { id: string; userId: string; mobile: string };
  let tutor2: { id: string; userId: string; mobile: string };
  let hodCse: { id: string; userId: string; mobile: string };
  let hodEce: { id: string; userId: string; mobile: string };
  let student1: { id: string; userId: string; mobile: string };
  let guard: { id: string; userId: string; mobile: string };
  let gate: { id: string; name: string };

  const tutor1Auth: AuthUser = {
    userId: '',
    role: 'tutor',
    roleId: 'tutor',
    name: 'Tutor 1 (CSE)',
    permissions: ['approveOutpass'],
    mobile: '9400000001',
  };

  const tutor2Auth: AuthUser = {
    userId: '',
    role: 'tutor',
    roleId: 'tutor',
    name: 'Tutor 2 (Different)',
    permissions: ['approveOutpass'],
    mobile: '9400000002',
  };

  const hodCseAuth: AuthUser = {
    userId: '',
    role: 'hod',
    roleId: 'hod',
    name: 'HOD CSE',
    permissions: ['approveOutpass'],
    mobile: '9400000003',
  };

  const hodEceAuth: AuthUser = {
    userId: '',
    role: 'hod',
    roleId: 'hod',
    name: 'HOD ECE',
    permissions: ['approveOutpass'],
    mobile: '9400000004',
  };

  const guardAuth = (id: string): AuthUser => ({
    userId: id,
    role: 'guard',
    roleId: 'guard',
    name: 'Security Guard',
    permissions: ['scanPass'],
    mobile: '9400000006',
  });

  let testCounter = 0;

  async function createTestOutpass(status = 'PENDING_TUTOR', extra: any = {}) {
    testCounter++;
    const now = new Date();
    const exitAt = extra.requestedExitAt || new Date(now.getTime() + 1800 * 1000);
    const returnAt = extra.expectedReturnAt || new Date(now.getTime() + 7200 * 1000);
    const passCode = `T${String(testCounter).padStart(5, '0')}`;

    return prisma.outpassRequest.create({
      data: {
        displayId: `TEST-TUTOR-${Date.now()}-${testCounter}`,
        passCode,
        studentId: student1.id,
        studentUserId: student1.id,
        tutorId: tutor1.id,
        destination: 'Thrissur Library',
        purposeCategory: 'ACADEMIC',
        type: 'NORMAL',
        typeId: 'normal',
        requestedExitAt: exitAt,
        expectedReturnAt: returnAt,
        status,
        approvalPath: extra.approvalPath ?? null,
        currentStageRoleId: extra.currentStageRoleId ?? (status === 'PENDING_TUTOR' ? 'tutor' : null),
        currentStageIndex: 0,
        currentStep: 0,
        approvalChain: ['tutor', 'hod'],
        validFrom: extra.validFrom ?? (status === 'APPROVED' ? now : null),
        validUntil: extra.validUntil ?? (status === 'APPROVED' ? returnAt : null),
        exitAt: extra.exitAt ?? null,
      },
    });
  }

  beforeAll(async () => {
    prisma = new PrismaService();
    await prisma.$connect();
    audit = new AuditService(prisma);
    notifications = new NotificationsService(prisma);
    outpassService = new OutpassService(prisma, audit, notifications);
    gateService = new GateService(prisma, audit);

    // Clean up past test data
    await prisma.gateEvent.deleteMany({
      where: { request: { displayId: { startsWith: 'TEST-TUTOR-' } } },
    });
    await prisma.approval.deleteMany({
      where: { request: { displayId: { startsWith: 'TEST-TUTOR-' } } },
    });
    await prisma.outpassRequest.deleteMany({
      where: { displayId: { startsWith: 'TEST-TUTOR-' } },
    });
    await prisma.student.deleteMany({
      where: { user: { mobile: { in: ['9400000001', '9400000002', '9400000003', '9400000004', '9400000005', '9400000006'] } } },
    });
    await prisma.user.deleteMany({
      where: { mobile: { in: ['9400000001', '9400000002', '9400000003', '9400000004', '9400000005', '9400000006'] } },
    });

    // Ensure Roles exist
    await prisma.role.upsert({
      where: { id: 'tutor' },
      update: {},
      create: { id: 'tutor', name: 'Tutor', permissions: ['approveOutpass'] },
    });
    await prisma.role.upsert({
      where: { id: 'hod' },
      update: {},
      create: { id: 'hod', name: 'HOD', permissions: ['approveOutpass'] },
    });
    await prisma.role.upsert({
      where: { id: 'student' },
      update: {},
      create: { id: 'student', name: 'Student', permissions: ['createOutpass'] },
    });
    await prisma.role.upsert({
      where: { id: 'guard' },
      update: {},
      create: { id: 'guard', name: 'Guard', permissions: ['scanPass'] },
    });

    // Ensure Departments exist
    await prisma.department.upsert({
      where: { code: 'CSE' },
      update: {},
      create: { code: 'CSE', name: 'Computer Science and Engineering' },
    });
    await prisma.department.upsert({
      where: { code: 'ECE' },
      update: {},
      create: { code: 'ECE', name: 'Electronics and Communication Engineering' },
    });

    // 1. Create Tutor 1 (CSE)
    const t1 = await prisma.user.create({
      data: {
        mobile: '9400000001',
        name: 'Tutor 1 (CSE)',
        roleId: 'tutor',
        department: 'CSE',
      },
    });
    tutor1 = { id: t1.id, userId: t1.id, mobile: t1.mobile };
    tutor1Auth.userId = t1.id;

    // 2. Create Tutor 2 (Other Tutor)
    const t2 = await prisma.user.create({
      data: {
        mobile: '9400000002',
        name: 'Tutor 2',
        roleId: 'tutor',
        department: 'CSE',
      },
    });
    tutor2 = { id: t2.id, userId: t2.id, mobile: t2.mobile };
    tutor2Auth.userId = t2.id;

    // 3. Create HOD CSE
    const hCse = await prisma.user.create({
      data: {
        mobile: '9400000003',
        name: 'HOD CSE',
        roleId: 'hod',
        department: 'CSE',
      },
    });
    hodCse = { id: hCse.id, userId: hCse.id, mobile: hCse.mobile };
    hodCseAuth.userId = hCse.id;

    // 4. Create HOD ECE
    const hEce = await prisma.user.create({
      data: {
        mobile: '9400000004',
        name: 'HOD ECE',
        roleId: 'hod',
        department: 'ECE',
      },
    });
    hodEce = { id: hEce.id, userId: hEce.id, mobile: hEce.mobile };
    hodEceAuth.userId = hEce.id;

    // 5. Create Student 1 assigned to Tutor 1, Department CSE
    const s1 = await prisma.user.create({
      data: {
        mobile: '9400000005',
        name: 'Test Student 1',
        roleId: 'student',
        department: 'CSE',
        tutorId: t1.id,
        student: {
          create: {
            registerNo: 'CCECSE2026',
            department: 'CSE',
            semester: 4,
            tutorId: t1.id,
          },
        },
      },
      include: { student: true },
    });
    student1 = { id: s1.id, userId: s1.id, mobile: s1.mobile };

    // 6. Create Guard
    const gUser = await prisma.user.create({
      data: {
        mobile: '9400000006',
        name: 'Main Gate Guard',
        roleId: 'guard',
      },
    });
    guard = { id: gUser.id, userId: gUser.id, mobile: gUser.mobile };

    // 7. Ensure Gate exists
    const g = await prisma.gate.findFirst();
    if (g) {
      gate = { id: g.id, name: g.name };
    } else {
      const createdGate = await prisma.gate.create({
        data: { name: 'Main Campus Gate' },
      });
      gate = { id: createdGate.id, name: createdGate.name };
    }
  });

  afterAll(async () => {
    await prisma.gateEvent.deleteMany({
      where: { request: { displayId: { startsWith: 'TEST-TUTOR-' } } },
    });
    await prisma.approval.deleteMany({
      where: { request: { displayId: { startsWith: 'TEST-TUTOR-' } } },
    });
    await prisma.outpassRequest.deleteMany({
      where: { displayId: { startsWith: 'TEST-TUTOR-' } },
    });
    await prisma.student.deleteMany({
      where: { user: { mobile: { in: ['9400000001', '9400000002', '9400000003', '9400000004', '9400000005', '9400000006'] } } },
    });
    await prisma.user.deleteMany({
      where: { mobile: { in: ['9400000001', '9400000002', '9400000003', '9400000004', '9400000005', '9400000006'] } },
    });
    await prisma.$disconnect();
  });

  // 1. Direct Tutor Approval
  it('1. permits tutor to directly approve outpass, transitioning status to APPROVED and setting approvalPath DIRECT', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');

    const res = await outpassService.approveDirect(tutor1Auth, op.id, 'Directly approved by tutor');

    expect(res.status).toBe('APPROVED');
    expect(res.approvalPath).toBe('DIRECT');
    expect(res.validFrom).toBeDefined();
    expect(res.validUntil).toBeDefined();

    // Verify DB record
    const dbOp = await prisma.outpassRequest.findUnique({
      where: { id: op.id },
      include: { approvals: true },
    });
    expect(dbOp?.status).toBe('APPROVED');
    expect(dbOp?.approvalPath).toBe('DIRECT');
    expect(dbOp?.currentStageRoleId).toBeNull();
    expect(dbOp?.approvals).toHaveLength(1);
    expect(dbOp?.approvals[0].stage).toBe('tutor');
    expect(dbOp?.approvals[0].approverId).toBe(tutor1.id);
    expect(dbOp?.approvals[0].decision).toBe(Decision.APPROVED);

    // Verify audit log
    const auditLogs = await prisma.auditLog.findMany({
      where: { objectId: op.id, action: 'OUTPASS_DIRECT_APPROVED' },
    });
    expect(auditLogs.length).toBeGreaterThanOrEqual(1);
    expect(auditLogs[0].actorId).toBe(tutor1.id);
  });

  // 2. Direct Tutor Approval: QR issuance and Gate scanning allowed
  it('2. allows guard exit scan immediately after direct tutor approval', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');
    await outpassService.approveDirect(tutor1Auth, op.id, 'Directly approved');

    const scanRes = await gateService.manualEntry(guardAuth(guard.id), {
      code: op.passCode!,
      direction: 'EXIT',
      gateId: gate.id,
      clientScanId: `scan-${Date.now()}-1`,
    });

    expect(scanRes.result).toBe('OK_EXIT');

    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('EXITED');
    expect(dbOp?.exitAt).toBeDefined();
  });

  // 3. Directly approved passes never appear in HOD pending queue
  it('3. directly approved outpass does not appear in HOD pending approvals list', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');
    await outpassService.approveDirect(tutor1Auth, op.id);

    const hodPending = await outpassService.listFor(hodCseAuth);
    const found = hodPending.find((p: any) => p.id === op.id);
    expect(found).toBeUndefined();
  });

  // 4. Tutor Approval & Forward to HOD
  it('4. permits tutor to forward outpass to HOD, transitioning status to PENDING_HOD and setting approvalPath FORWARD_HOD', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');

    const res = await outpassService.forwardToHod(tutor1Auth, op.id, 'Forwarded for HOD verification');

    expect(res.status).toBe('PENDING_HOD');
    expect(res.approvalPath).toBe('FORWARD_HOD');
    expect(res.currentStageRoleId).toBe('hod');

    // Verify DB
    const dbOp = await prisma.outpassRequest.findUnique({
      where: { id: op.id },
      include: { approvals: true },
    });
    expect(dbOp?.status).toBe('PENDING_HOD');
    expect(dbOp?.approvalPath).toBe('FORWARD_HOD');
    expect(dbOp?.currentStageRoleId).toBe('hod');
    expect(dbOp?.approvals).toHaveLength(1);
    expect(dbOp?.approvals[0].stage).toBe('tutor');
    expect(dbOp?.approvals[0].decision).toBe(Decision.APPROVED);

    // Verify audit log
    const auditLogs = await prisma.auditLog.findMany({
      where: { objectId: op.id, action: 'OUTPASS_FORWARDED_TO_HOD' },
    });
    expect(auditLogs.length).toBeGreaterThanOrEqual(1);
    expect(auditLogs[0].actorId).toBe(tutor1.id);
  });

  // 5. Forwarded to HOD appears in HOD's pending queue
  it('5. forwarded outpass appears in the assigned department HOD pending queue', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');
    await outpassService.forwardToHod(tutor1Auth, op.id);

    const hodPending = await outpassService.listFor(hodCseAuth);
    const found = hodPending.find((p: any) => p.id === op.id);
    expect(found).toBeDefined();
    expect(found?.approvalPath).toBe('FORWARD_HOD');
  });

  // 6. Forwarded pass cannot be scanned by guard before HOD approves (QR locked)
  it('6. rejects gate exit scan when pass is forwarded to HOD but not yet HOD-approved', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');
    await outpassService.forwardToHod(tutor1Auth, op.id);

    const scanRes = await gateService.manualEntry(guardAuth(guard.id), {
      code: op.passCode!,
      direction: 'EXIT',
      gateId: gate.id,
      clientScanId: `scan-${Date.now()}-2`,
    });

    expect(scanRes.result).toBe('NOT_APPROVED');

    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('PENDING_HOD');
    expect(dbOp?.exitAt).toBeNull();
  });

  // 7. HOD approves forwarded outpass -> status APPROVED, QR unlocked
  it('7. allows HOD to grant final approval for forwarded outpass and then permits gate exit', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');
    await outpassService.forwardToHod(tutor1Auth, op.id);

    const hodApproved = await outpassService.decide(hodCseAuth, op.id, {
      decision: 'APPROVED',
      comment: 'HOD final approval granted',
    });

    expect(hodApproved.status).toBe('APPROVED');
    expect(hodApproved.approvalPath).toBe('FORWARD_HOD');

    // DB verification
    const dbOp = await prisma.outpassRequest.findUnique({
      where: { id: op.id },
      include: { approvals: true },
    });
    expect(dbOp?.status).toBe('APPROVED');
    expect(dbOp?.approvals).toHaveLength(2);
    expect(dbOp?.approvals.some((a) => a.stage === 'tutor')).toBe(true);
    expect(dbOp?.approvals.some((a) => a.stage === 'hod')).toBe(true);

    // Gate scanner allows exit now
    const scanRes = await gateService.manualEntry(guardAuth(guard.id), {
      code: op.passCode!,
      direction: 'EXIT',
      gateId: gate.id,
      clientScanId: `scan-${Date.now()}-3`,
    });
    expect(scanRes.result).toBe('OK_EXIT');
  });

  // 8. Unauthorized user attempting direct approval (wrong tutor or non-tutor)
  it('8. rejects direct approval when attempted by a tutor not assigned to the student', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');

    await expect(
      outpassService.approveDirect(tutor2Auth, op.id, 'Unauthorized approval attempt'),
    ).rejects.toThrow(ForbiddenException);

    // Ensure status untouched
    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('PENDING_TUTOR');
  });

  // 9. Unauthorized HOD attempting approval (different department)
  it('9. rejects HOD approval when HOD is from a different department', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');
    await outpassService.forwardToHod(tutor1Auth, op.id);

    await expect(
      outpassService.decide(hodEceAuth, op.id, { decision: 'APPROVED' }),
    ).rejects.toThrow(ForbiddenException);

    // Ensure status untouched
    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('PENDING_HOD');
  });

  // 10. Rejection requires a mandatory reason
  it('10. requires a non-empty reason when rejecting an outpass', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');

    await expect(outpassService.reject(tutor1Auth, op.id, '')).rejects.toThrow(ConflictException);
    await expect(outpassService.reject(tutor1Auth, op.id, '   ')).rejects.toThrow(ConflictException);

    const rejected = await outpassService.reject(
      tutor1Auth,
      op.id,
      'Internal exams scheduled during requested hours',
    );
    expect(rejected.status).toBe('REJECTED');

    const dbOp = await prisma.outpassRequest.findUnique({ where: { id: op.id } });
    expect(dbOp?.status).toBe('REJECTED');

    // Gate scanner denies
    const scanRes = await gateService.manualEntry(guardAuth(guard.id), {
      code: op.passCode!,
      direction: 'EXIT',
      gateId: gate.id,
      clientScanId: `scan-${Date.now()}-4`,
    });
    expect(scanRes.result).toBe('REJECTED');
  });

  // 11. Duplicate approval attempts throw ConflictException
  it('11. throws ConflictException on duplicate direct approval', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');
    await outpassService.approveDirect(tutor1Auth, op.id);

    await expect(outpassService.approveDirect(tutor1Auth, op.id)).rejects.toThrow(ConflictException);
    await expect(outpassService.forwardToHod(tutor1Auth, op.id)).rejects.toThrow(ConflictException);
  });

  // 12. Race condition / concurrent approval attempts
  it('12. handles concurrent approval requests safely with atomic transaction', async () => {
    const op = await createTestOutpass('PENDING_TUTOR');

    const promises = [
      outpassService.approveDirect(tutor1Auth, op.id),
      outpassService.forwardToHod(tutor1Auth, op.id),
    ];

    const results = await Promise.allSettled(promises);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    // Exactly one operation must succeed, other must be rejected
    expect(fulfilled.length).toBe(1);
    expect(rejected.length).toBe(1);

    const dbOp = await prisma.outpassRequest.findUnique({
      where: { id: op.id },
      include: { approvals: true },
    });
    expect(dbOp?.approvals).toHaveLength(1);
  });
});
