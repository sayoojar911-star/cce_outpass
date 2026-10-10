import { BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { AdminController } from './admin.controller';
import { AuthService } from '../auth/auth.service';
import { FirebaseAuthService } from '../auth/firebase-auth.service';

describe('Admin Role Registration & Login E2E', () => {
  let prisma: PrismaService;
  let audit: AuditService;
  let adminController: AdminController;
  let authService: AuthService;

  const testMobile = (suffix: string) => `91000000${suffix}`;

  beforeAll(async () => {
    prisma = new PrismaService();
    await prisma.$connect();
    audit = new AuditService(prisma);
    adminController = new AdminController(prisma, audit);

    const jwtService = new JwtService({ secret: 'cce-outpass-jwt-secret-key-2026' });
    const firebaseMock = {
      verifyPhoneIdToken: jest.fn(),
    } as unknown as FirebaseAuthService;
    authService = new AuthService(prisma, jwtService, audit, firebaseMock);

    // Clean up any old test users
    await prisma.approval.deleteMany({});
    await prisma.outpassRequest.deleteMany({});
    await prisma.student.deleteMany({});
    await prisma.session.deleteMany({});
    await prisma.device.deleteMany({});
    await prisma.user.deleteMany({
      where: {
        mobile: { startsWith: '91000000' },
      },
    });

    // Ensure departments exist
    await prisma.department.upsert({
      where: { code: 'CSE' },
      update: {},
      create: { code: 'CSE', name: 'Computer Science and Engineering' },
    });
    await prisma.department.upsert({
      where: { code: 'EC' },
      update: {},
      create: { code: 'EC', name: 'Electronics and Communication Engineering' },
    });

    // Ensure CSE divisions A, B, C, D exist
    for (const div of ['A', 'B', 'C', 'D']) {
      const existing = await prisma.division.findFirst({
        where: {
          department: { code: 'CSE' },
          name: div,
        },
      });
      if (!existing) {
        const dept = await prisma.department.findUnique({ where: { code: 'CSE' } });
        await prisma.division.create({
          data: { name: div, departmentId: dept!.id },
        });
      }
    }
  });

  afterAll(async () => {
    await prisma.student.deleteMany({});
    await prisma.session.deleteMany({});
    await prisma.device.deleteMany({});
    await prisma.user.deleteMany({
      where: {
        mobile: { startsWith: '91000000' },
      },
    });
    await prisma.$disconnect();
  });

  const req = { user: { sub: 'admin-tester-id' } };

  describe('Positive role creation', () => {
    it('creates ADMIN with name and mobile only', async () => {
      const res = await adminController.createUser(req, {
        name: 'Test Admin',
        mobile: testMobile('01'),
        role: 'ADMIN',
      });
      expect(res.role).toBe('ADMIN');
      expect(res.department).toBeNull();
      expect(res.year).toBeNull();
      expect(res.division).toBeNull();
    });

    it('creates GUARD with name and mobile only', async () => {
      const res = await adminController.createUser(req, {
        name: 'Test Gate Guard',
        mobile: testMobile('02'),
        role: 'GUARD',
      });
      expect(res.role).toBe('GUARD');
      expect(res.department).toBeNull();
      expect(res.year).toBeNull();
      expect(res.division).toBeNull();
    });

    it('creates HOD with department (CSE)', async () => {
      const res = await adminController.createUser(req, {
        name: 'Dr. CSE HOD',
        mobile: testMobile('03'),
        role: 'HOD',
        department: 'CSE',
      });
      expect(res.role).toBe('HOD');
      expect(res.department).toBe('CSE');
      expect(res.year).toBeNull();
      expect(res.division).toBeNull();
    });

    it('creates TUTOR with department, year, division', async () => {
      const res = await adminController.createUser(req, {
        name: 'Prof. Tutor CSE',
        mobile: testMobile('04'),
        role: 'TUTOR',
        department: 'CSE',
        year: 3,
        division: 'B',
      });
      expect(res.role).toBe('TUTOR');
      expect(res.department).toBe('CSE');
      expect(res.year).toBe(3);
      expect(res.division).toBe('B');
    });

    it('creates STUDENT with matched tutor and normalizes formatted phone', async () => {
      const tutor = await prisma.user.findFirst({
        where: { mobile: testMobile('04') },
      });

      const res = await adminController.createUser(req, {
        name: 'Ananya Student',
        mobile: `+91 ${testMobile('05').slice(0, 5)} ${testMobile('05').slice(5)}`,
        role: 'STUDENT',
        department: 'CSE',
        year: 3,
        division: 'B',
        tutorId: tutor!.id,
      });

      expect(res.role).toBe('STUDENT');
      expect(res.mobile).toBe(testMobile('05'));
      expect(res.department).toBe('CSE');
      expect(res.year).toBe(3);
      expect(res.division).toBe('B');

      const student = await prisma.student.findUnique({
        where: { userId: res.id },
      });
      expect(student).not.toBeNull();
      expect(student!.tutorId).toBe(tutor!.id);
      expect(student!.year).toBe(3);
      expect(student!.division).toBe('B');
    });

    it('creates TUTOR and STUDENT in department without divisions (EC)', async () => {
      const tutorRes = await adminController.createUser(req, {
        name: 'Prof. EC Tutor',
        mobile: testMobile('06'),
        role: 'TUTOR',
        department: 'EC',
        year: 2,
      });
      expect(tutorRes.division).toBeNull();

      const studentRes = await adminController.createUser(req, {
        name: 'Rahul EC Student',
        mobile: testMobile('07'),
        role: 'STUDENT',
        department: 'EC',
        year: 2,
        tutorId: tutorRes.id,
      });
      expect(studentRes.division).toBeNull();
    });
  });

  describe('Validation rejection rules', () => {
    it('rejects HOD without department', async () => {
      await expect(
        adminController.createUser(req, {
          name: 'Invalid HOD',
          mobile: testMobile('20'),
          role: 'HOD',
        }),
      ).rejects.toThrow(new BadRequestException('Department is required for HOD'));
    });

    it('rejects CSE student without division', async () => {
      await expect(
        adminController.createUser(req, {
          name: 'No Div Student',
          mobile: testMobile('21'),
          role: 'STUDENT',
          department: 'CSE',
          year: 1,
        }),
      ).rejects.toThrow(new BadRequestException('Division is required for CSE STUDENT'));
    });

    it('rejects a division from another department or invalid division', async () => {
      await expect(
        adminController.createUser(req, {
          name: 'Bad Div Student',
          mobile: testMobile('22'),
          role: 'STUDENT',
          department: 'CSE',
          year: 1,
          division: 'Z',
        }),
      ).rejects.toThrow(new BadRequestException('Division Z does not belong to CSE'));
    });

    it('rejects mismatched tutor (different year or division)', async () => {
      const tutor = await prisma.user.findFirst({
        where: { mobile: testMobile('04') }, // CSE, Year 3, Division B
      });

      // Try assigning this tutor to a student with Year 2, Division B
      await expect(
        adminController.createUser(req, {
          name: 'Mismatch Student',
          mobile: testMobile('23'),
          role: 'STUDENT',
          department: 'CSE',
          year: 2,
          division: 'B',
          tutorId: tutor!.id,
        }),
      ).rejects.toThrow(new BadRequestException('Tutor belongs to year 3, not year 2'));
    });

    it('rejects duplicate phone number across all roles', async () => {
      await expect(
        adminController.createUser(req, {
          name: 'Duplicate Phone Guy',
          mobile: testMobile('01'), // Already used by Admin
          role: 'STUDENT',
          department: 'CSE',
          year: 1,
          division: 'A',
        }),
      ).rejects.toThrow(new BadRequestException(`A user with mobile ${testMobile('01')} already exists`));
    });

    it('rejects a second HOD for the same department without replaceHod', async () => {
      await expect(
        adminController.createUser(req, {
          name: 'Second CSE HOD',
          mobile: testMobile('24'),
          role: 'HOD',
          department: 'CSE',
        }),
      ).rejects.toThrow(new BadRequestException('CSE already has a HOD: Dr. CSE HOD'));
    });

    it('rejects phone numbers with invalid digit count', async () => {
      await expect(
        adminController.createUser(req, {
          name: 'Short Phone',
          mobile: '98765',
          role: 'GUARD',
        }),
      ).rejects.toThrow(new BadRequestException('Mobile must be exactly 10 digits'));
    });
  });

  describe('Division management & Department safety', () => {
    it('allows admin to add and delete a division on a department', async () => {
      const ecDept = await prisma.department.findUnique({ where: { code: 'EC' } });
      const added = await adminController.addDivision(req, ecDept!.id, { name: 'E1' });
      expect(added.name).toBe('E1');

      // Attempting to delete when no users have division E1 succeeds
      const deleted = await adminController.deleteDivision(req, ecDept!.id, added.id);
      expect(deleted).toEqual({ ok: true });
    });

    it('blocks deleting a department with active people', async () => {
      const cseDept = await prisma.department.findUnique({ where: { code: 'CSE' } });
      await expect(
        adminController.deleteDepartment(req, cseDept!.id),
      ).rejects.toThrow(/Cannot delete department CSE/);
    });
  });

  describe('End-to-End Login for every registered role', () => {
    it('every registered role can log in with OTP 123456 and receive matching role session', async () => {
      const accounts = [
        { mobile: testMobile('01'), expectedRole: 'ADMIN' },
        { mobile: testMobile('02'), expectedRole: 'GUARD' },
        { mobile: testMobile('03'), expectedRole: 'HOD' },
        { mobile: testMobile('04'), expectedRole: 'TUTOR' },
        { mobile: testMobile('05'), expectedRole: 'STUDENT' },
      ];

      for (const account of accounts) {
        // Send OTP
        const sendRes = await authService.sendOtp(account.mobile);
        expect(sendRes.ok).toBe(true);

        // Verify OTP
        const session = await authService.verifyOtp(account.mobile, '123456');
        expect(session.accessToken).toBeDefined();
        expect(session.user.role).toBe(account.expectedRole);
        expect(session.user.mobile).toBe(account.mobile);

        // Fetch /me
        const me = await authService.me({ userId: session.user.id });
        expect(me.role).toBe(account.expectedRole);
        if (me.role === 'STUDENT') {
          expect(me.student).toBeDefined();
          expect(me.student!.year).toBe(3);
          expect(me.student!.division).toBe('B');
        }
      }
    });

    it('rejects unregistered number with expected message', async () => {
      await expect(
        authService.sendOtp('9999999999'),
      ).rejects.toThrow("This number isn't registered. Contact your admin.");
    });
  });
});
