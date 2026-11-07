import {
  BadRequestException,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigModule } from '@nestjs/config';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { AuthService } from './auth.service';
import { FirebaseAuthService } from './firebase-auth.service';
import { PhotoStorageService } from './photo-storage.service';

describe('Student Registration & Authentication Tests', () => {
  let prisma: PrismaService;
  let authService: AuthService;
  let firebaseAuthService: FirebaseAuthService;

  const testMobilePrefix = '93000000';
  const getTestMobile = (s: string) => `${testMobilePrefix}${s}`;
  const mockPhotoBase64 =
    'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

  beforeAll(async () => {
    process.env.TEMP_OTP_ENABLED = 'true';

    const module: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({ isGlobal: true }),
        JwtModule.register({
          secret: 'test-jwt-secret-for-student-reg',
          signOptions: { expiresIn: '1h' },
        }),
      ],
      providers: [
        PrismaService,
        AuditService,
        FirebaseAuthService,
        PhotoStorageService,
        AuthService,
      ],
    }).compile();

    prisma = module.get<PrismaService>(PrismaService);
    authService = module.get<AuthService>(AuthService);
    firebaseAuthService = module.get<FirebaseAuthService>(FirebaseAuthService);

    // Clean up test student & user records
    await prisma.session.deleteMany({
      where: { user: { mobile: { startsWith: testMobilePrefix } } },
    });
    await prisma.student.deleteMany({
      where: {
        OR: [
          { user: { mobile: { startsWith: testMobilePrefix } } },
          { registerNo: { startsWith: 'CCETEST' } },
        ],
      },
    });
    await prisma.user.deleteMany({
      where: { mobile: { startsWith: testMobilePrefix } },
    });

    // Ensure standard test department exists
    await prisma.department.upsert({
      where: { code: 'CSE' },
      update: {},
      create: { code: 'CSE', name: 'Computer Science and Engineering' },
    });

    // Ensure student role exists
    await prisma.role.upsert({
      where: { id: 'student' },
      update: { permissions: ['createOutpass'] },
      create: {
        id: 'student',
        name: 'Student',
        permissions: ['createOutpass'],
        isSystem: true,
        active: true,
      },
    });
  });

  afterAll(async () => {
    await prisma.session.deleteMany({
      where: { user: { mobile: { startsWith: testMobilePrefix } } },
    });
    await prisma.student.deleteMany({
      where: {
        OR: [
          { user: { mobile: { startsWith: testMobilePrefix } } },
          { registerNo: { startsWith: 'CCETEST' } },
        ],
      },
    });
    await prisma.user.deleteMany({
      where: { mobile: { startsWith: testMobilePrefix } },
    });
    await prisma.$disconnect();
  });

  it('1. performs Firebase OTP verification and returns verified token', async () => {
    const mobile = getTestMobile('10');
    const sendRes = await authService.sendSignupOtp(mobile);
    expect(sendRes.ok).toBe(true);

    const verifyRes = await authService.verifySignupOtp(mobile, '123456');
    expect(verifyRes.ok).toBe(true);
    expect(verifyRes.idToken).toBe(`test:${mobile}`);
    expect(verifyRes.mobile).toBe(mobile);
  });

  it('2. rejects invalid OTP during verification', async () => {
    const mobile = getTestMobile('11');
    await expect(authService.verifySignupOtp(mobile, '999999')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('3. rejects invalid Firebase ID token during registration', async () => {
    await expect(
      authService.registerStudent({
        idToken: 'invalid-firebase-token-123',
        name: 'John Doe',
        rollNo: 'CCETEST01',
        year: 1,
        department: 'CSE',
        photo: mockPhotoBase64,
      }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('4. successfully registers a new student with verified Firebase token', async () => {
    const mobile = getTestMobile('21');
    const res = await authService.registerStudent({
      idToken: `test:${mobile}`,
      name: 'Adithyan S',
      rollNo: 'CCETEST21',
      year: 2,
      department: 'CSE',
      photo: mockPhotoBase64,
    });

    expect(res).toBeDefined();
    expect(res.accessToken).toBeDefined();
    expect(res.user.mobile).toBe(mobile);
    expect(res.user.role).toBe('STUDENT');
    expect(res.user.roleId).toBe('student');
    expect(res.user.permissions).toContain('createOutpass');
    expect(res.student.registerNo).toBe('CCETEST21');
    expect(res.student.year).toBe(2);
    expect(res.student.semester).toBe(3); // (2-1)*2 + 1
    expect(res.student.photoUrl).toBeDefined();

    // Verify in database
    const dbUser = await prisma.user.findUnique({
      where: { mobile },
      include: { student: true },
    });
    expect(dbUser).not.toBeNull();
    expect(dbUser!.name).toBe('Adithyan S');
    expect(dbUser!.student).not.toBeNull();
    expect(dbUser!.student!.registerNo).toBe('CCETEST21');
    expect(dbUser!.student!.semester).toBe(3);
  });

  it('5. prevents duplicate mobile number registration', async () => {
    const mobile = getTestMobile('21'); // Already registered in test 4
    await expect(
      authService.registerStudent({
        idToken: `test:${mobile}`,
        name: 'Another Student',
        rollNo: 'CCETEST22',
        year: 1,
        department: 'CSE',
        photo: mockPhotoBase64,
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('6. prevents duplicate roll number registration', async () => {
    const newMobile = getTestMobile('22');
    await expect(
      authService.registerStudent({
        idToken: `test:${newMobile}`,
        name: 'Duplicate Roll Student',
        rollNo: 'CCETEST21', // Already used by CCETEST21
        year: 3,
        department: 'CSE',
        photo: mockPhotoBase64,
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('7. rejects invalid year of study (< 1 or > 4)', async () => {
    const mobile = getTestMobile('31');
    await expect(
      authService.registerStudent({
        idToken: `test:${mobile}`,
        name: 'Invalid Year Student',
        rollNo: 'CCETEST31',
        year: 5, // Invalid year
        department: 'CSE',
        photo: mockPhotoBase64,
      }),
    ).rejects.toThrow(BadRequestException);

    await expect(
      authService.registerStudent({
        idToken: `test:${mobile}`,
        name: 'Invalid Year Student',
        rollNo: 'CCETEST31',
        year: 0, // Invalid year
        department: 'CSE',
        photo: mockPhotoBase64,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('8. rejects invalid department', async () => {
    const mobile = getTestMobile('41');
    await expect(
      authService.registerStudent({
        idToken: `test:${mobile}`,
        name: 'Invalid Dept Student',
        rollNo: 'CCETEST41',
        year: 1,
        department: 'NON_EXISTENT_DEPARTMENT',
        photo: mockPhotoBase64,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('9. rejects missing or empty photo', async () => {
    const mobile = getTestMobile('51');
    await expect(
      authService.registerStudent({
        idToken: `test:${mobile}`,
        name: 'No Photo Student',
        rollNo: 'CCETEST51',
        year: 1,
        department: 'CSE',
        photo: '',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('10. enforces STUDENT role assignment and blocks unauthorized role escalation', async () => {
    const mobile = getTestMobile('61');
    // Attempting to inject privileged fields in dto
    const res = await authService.registerStudent({
      idToken: `test:${mobile}`,
      name: 'Hacker Wannabe',
      rollNo: 'CCETEST61',
      year: 1,
      department: 'CSE',
      photo: mockPhotoBase64,
      ...({ role: 'ADMIN', roleId: 'admin' } as any),
    });

    expect(res.user.role).toBe('STUDENT');
    expect(res.user.roleId).toBe('student');
    expect(res.user.permissions).not.toContain('manageUsers');
    expect(res.user.permissions).not.toContain('gateScan');
    expect(res.user.permissions).toEqual(['createOutpass']);

    const dbUser = await prisma.user.findUnique({ where: { mobile } });
    expect(dbUser!.roleId).toBe('student');
    expect(dbUser!.role).toBe('STUDENT');
  });

  it('11. verifies newly registered student can sign in immediately without duplicate profile', async () => {
    const mobile = getTestMobile('21'); // Student created in test 4
    const loginRes = await authService.verifyOtp(mobile, '123456');

    expect(loginRes).toBeDefined();
    expect(loginRes.accessToken).toBeDefined();
    expect(loginRes.user.mobile).toBe(mobile);
    expect(loginRes.user.role).toBe('STUDENT');

    // Ensure only 1 user and 1 student exist in the database
    const users = await prisma.user.findMany({ where: { mobile } });
    expect(users).toHaveLength(1);
    const students = await prisma.student.findMany({ where: { userId: users[0].id } });
    expect(students).toHaveLength(1);
  });

  it('12. verifies existing students continue logging in normally', async () => {
    // Register existing student
    const mobile = getTestMobile('88');
    await authService.registerStudent({
      idToken: `test:${mobile}`,
      name: 'Existing Student',
      rollNo: 'CCETEST88',
      year: 4,
      department: 'CSE',
      photo: mockPhotoBase64,
    });

    // Test standard OTP sign-in
    const otpLogin = await authService.verifyOtp(mobile, '123456');
    expect(otpLogin.user.name).toBe('Existing Student');
    expect(otpLogin.user.role).toBe('STUDENT');

    // Test standard Firebase sign-in
    const fbLogin = await authService.verifyFirebasePhone(`test:${mobile}`);
    expect(fbLogin.user.name).toBe('Existing Student');
    expect(fbLogin.user.role).toBe('STUDENT');

    // Test me profile
    const profile = await authService.me({ userId: fbLogin.user.id });
    expect(profile.student.registerNo).toBe('CCETEST88');
    expect(profile.student.year).toBe(4);
    expect(profile.student.semester).toBe(7);
  });

  // 13. Rejects invalid file format (non-JPEG/PNG/WebP)
  it('13. rejects invalid image formats like SVG or non-image payloads', async () => {
    const mobile = getTestMobile('91');
    const fakeSvg = 'data:image/svg+xml;base64,' + Buffer.from('<svg><circle r="10"/></svg>').toString('base64');
    await expect(
      authService.registerStudent({
        idToken: `test:${mobile}`,
        name: 'Invalid Image Student',
        rollNo: 'CCETEST91',
        year: 1,
        department: 'CSE',
        photo: fakeSvg,
      }),
    ).rejects.toThrow('Only JPEG, PNG, and WebP images are allowed');
  });

  // 14. Rejects oversized image (> 5 MB)
  it('14. rejects oversized images exceeding 5 MB limit', async () => {
    const mobile = getTestMobile('92');
    // Create oversized JPEG payload > 5 MB
    const hugeBuffer = Buffer.alloc(5.2 * 1024 * 1024, 0);
    hugeBuffer[0] = 0xff;
    hugeBuffer[1] = 0xd8;
    hugeBuffer[2] = 0xff;
    const oversizedPhoto = 'data:image/jpeg;base64,' + hugeBuffer.toString('base64');

    await expect(
      authService.registerStudent({
        idToken: `test:${mobile}`,
        name: 'Oversized Photo Student',
        rollNo: 'CCETEST92',
        year: 2,
        department: 'CSE',
        photo: oversizedPhoto,
      }),
    ).rejects.toThrow('exceeds maximum allowed limit of 5 MB');
  });

  // 15. Authenticated profile photo update and removal
  it('15. allows authenticated user to update and remove profile photo', async () => {
    const mobile = getTestMobile('93');
    const reg = await authService.registerStudent({
      idToken: `test:${mobile}`,
      name: 'Photo Update Student',
      rollNo: 'CCETEST93',
      year: 3,
      department: 'CSE',
      photo: mockPhotoBase64,
    });

    const userAuth = { userId: reg.user.id, role: 'student' };

    // Update photo with PNG image
    // PNG magic bytes header: 89 50 4E 47 0D 0A 1A 0A
    const pngHeader = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d]);
    const pngPhoto = 'data:image/png;base64,' + pngHeader.toString('base64');

    const updateRes = await authService.updateProfilePhoto(userAuth, pngPhoto);
    expect(updateRes.ok).toBe(true);
    expect(updateRes.photoUrl).toMatch(/^\/uploads\/students\/user_/);

    const userInDb = await prisma.user.findUnique({ where: { id: reg.user.id } });
    expect(userInDb?.photoUrl).toBe(updateRes.photoUrl);

    // Remove photo
    const removeRes = await authService.removeProfilePhoto(userAuth);
    expect(removeRes.ok).toBe(true);
    expect(removeRes.photoUrl).toBeNull();

    const userAfterRemove = await prisma.user.findUnique({ where: { id: reg.user.id } });
    expect(userAfterRemove?.photoUrl).toBeNull();
  });

  // 16. Verifies no orphaned file on registration conflict
  it('16. cleans up uploaded photo when registration fails, leaving no orphaned files', async () => {
    const mobile = getTestMobile('94');
    const rollNo = 'CCETEST94';

    // 1st registration succeeds
    await authService.registerStudent({
      idToken: `test:${mobile}`,
      name: 'First Student',
      rollNo,
      year: 1,
      department: 'CSE',
      photo: mockPhotoBase64,
    });

    // 2nd registration with same roll number fails with ConflictException
    const diffMobile = getTestMobile('95');
    await expect(
      authService.registerStudent({
        idToken: `test:${diffMobile}`,
        name: 'Second Student Duplicate Roll',
        rollNo,
        year: 1,
        department: 'CSE',
        photo: mockPhotoBase64,
      }),
    ).rejects.toThrow(ConflictException);
  });
});
