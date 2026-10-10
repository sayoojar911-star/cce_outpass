import { ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { AdminController } from './admin.controller';

describe('Admin Student Registration & Transaction Tests', () => {
  let prisma: PrismaService;
  let audit: AuditService;
  let adminController: AdminController;

  const testMobile = (suffix: string) => `92000000${suffix}`;
  const req = { user: { sub: 'admin-tester-id' } };

  beforeAll(async () => {
    prisma = new PrismaService();
    await prisma.$connect();
    audit = new AuditService(prisma);
    adminController = new AdminController(prisma, audit);

    // Clean up test data
    await prisma.student.deleteMany({
      where: { user: { mobile: { startsWith: '92000000' } } },
    });
    await prisma.user.deleteMany({
      where: { mobile: { startsWith: '92000000' } },
    });

    // Ensure CE department exists (department without divisions)
    await prisma.department.upsert({
      where: { code: 'CE' },
      update: {},
      create: { code: 'CE', name: 'Civil Engineering' },
    });

    // Ensure CSE department exists with division A
    const cse = await prisma.department.upsert({
      where: { code: 'CSE' },
      update: {},
      create: { code: 'CSE', name: 'Computer Science and Engineering' },
    });
    await prisma.division.upsert({
      where: { departmentId_name: { departmentId: cse.id, name: 'A' } },
      update: {},
      create: { departmentId: cse.id, name: 'A' },
    });
  });

  afterAll(async () => {
    await prisma.student.deleteMany({
      where: { user: { mobile: { startsWith: '92000000' } } },
    });
    await prisma.user.deleteMany({
      where: { mobile: { startsWith: '92000000' } },
    });
    await prisma.$disconnect();
  });

  it('1. registers a student WITHOUT a tutor (tutorId omitted, null, or empty string)', async () => {
    // a) tutorId omitted
    const resOmitted = await adminController.createUser(req, {
      name: 'Sayanth Omitted',
      mobile: testMobile('11'),
      role: 'STUDENT',
      department: 'CE',
      year: 1,
    });
    expect(resOmitted.role).toBe('STUDENT');
    const student1 = await prisma.student.findUnique({ where: { userId: resOmitted.id } });
    expect(student1).not.toBeNull();
    expect(student1!.tutorId).toBeNull();

    // b) tutorId as empty string
    const resEmpty = await adminController.createUser(req, {
      name: 'Sayanth Empty String',
      mobile: testMobile('12'),
      role: 'STUDENT',
      department: 'CE',
      year: 1,
      tutorId: '',
    });
    expect(resEmpty.role).toBe('STUDENT');
    const student2 = await prisma.student.findUnique({ where: { userId: resEmpty.id } });
    expect(student2).not.toBeNull();
    expect(student2!.tutorId).toBeNull();
  });

  it('2. registers a student WITH a tutor', async () => {
    // Create a tutor first
    const tutor = await adminController.createUser(req, {
      name: 'Prof. CE Tutor',
      mobile: testMobile('20'),
      role: 'TUTOR',
      department: 'CE',
      year: 1,
    });

    const resWithTutor = await adminController.createUser(req, {
      name: 'Student With Tutor',
      mobile: testMobile('21'),
      role: 'STUDENT',
      department: 'CE',
      year: 1,
      tutorId: tutor.id,
    });

    expect(resWithTutor.role).toBe('STUDENT');
    const student = await prisma.student.findUnique({ where: { userId: resWithTutor.id } });
    expect(student).not.toBeNull();
    expect(student!.tutorId).toBe(tutor.id);
  });

  it('3. rejects duplicate phone with 409 ConflictException', async () => {
    await expect(
      adminController.createUser(req, {
        name: 'Duplicate Phone',
        mobile: `+91 ${testMobile('11').slice(0, 5)} ${testMobile('11').slice(5)}`,
        role: 'STUDENT',
        department: 'CE',
        year: 1,
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('4. rolls back User creation inside transaction if Student creation fails', async () => {
    const orphanPhone = testMobile('99');

    // Spy on prisma.$transaction to simulate an error during student creation
    const originalTransaction = prisma.$transaction.bind(prisma);
    jest.spyOn(prisma, '$transaction').mockImplementationOnce(async (callback: any) => {
      return originalTransaction(async (tx) => {
        // Run callback but throw error after user.create
        const user = await tx.user.create({
          data: {
            name: 'Rollback Candidate',
            mobile: orphanPhone,
            role: 'STUDENT',
            department: 'CE',
            year: 1,
            status: 'ACTIVE',
          },
        });
        // Intentionally throw inside transaction to test rollback
        throw new Error('Simulated failure during student creation');
      });
    });

    await expect(
      adminController.createUser(req, {
        name: 'Rollback Candidate',
        mobile: orphanPhone,
        role: 'STUDENT',
        department: 'CE',
        year: 1,
      }),
    ).rejects.toThrow('Simulated failure during student creation');

    // Verify user was rolled back and leaves NO orphan row in User table
    const orphanUser = await prisma.user.findUnique({ where: { mobile: orphanPhone } });
    expect(orphanUser).toBeNull();
  });
});
