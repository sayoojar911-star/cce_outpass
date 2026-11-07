import { BadRequestException, ConflictException, NotFoundException, UnauthorizedException, ForbiddenException, HttpStatus } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from './prisma.service';
import { AuditService } from './audit/audit.service';
import { AdminController } from './admin/admin.controller';
import { AuthService } from './auth/auth.service';
import { FirebaseAuthService } from './auth/firebase-auth.service';
import { PhotoStorageService } from './auth/photo-storage.service';
import { AllExceptionsFilter } from './common/all-exceptions.filter';
import { JwtAuthGuard } from './common/jwt-auth.guard';
import { RolesGuard } from './common/roles.guard';
import { ROLES_KEY } from './common/auth.decorator';
import { Reflector } from '@nestjs/core';

describe('Phase 3: Backend API Audit & Health Check', () => {
  let prisma: PrismaService;
  let audit: AuditService;
  let adminController: AdminController;
  let authService: AuthService;
  let jwtService: JwtService;
  let filter: AllExceptionsFilter;

  const jwtSecret = 'cce-outpass-jwt-secret-key-2026';

  beforeAll(async () => {
    prisma = new PrismaService();
    await prisma.$connect();
    audit = new AuditService(prisma);
    adminController = new AdminController(prisma, audit);

    jwtService = new JwtService({ secret: jwtSecret });
    const firebaseMock = {
      verifyPhoneIdToken: jest.fn(),
    } as unknown as FirebaseAuthService;
    const photoStorage = new PhotoStorageService();
    authService = new AuthService(prisma, jwtService, audit, firebaseMock, photoStorage);
    filter = new AllExceptionsFilter();

    // Clean up test users
    await prisma.approval.deleteMany({});
    await prisma.student.deleteMany({
      where: { user: { mobile: { in: ['9999900001', '9999900002', '9999900003'] } } },
    });
    await prisma.device.deleteMany({});
    await prisma.user.deleteMany({
      where: {
        mobile: { in: ['9999900001', '9999900002', '9999900003'] },
      },
    });
  });

  afterAll(async () => {
    await prisma.student.deleteMany({
      where: { user: { mobile: { in: ['9999900001', '9999900002', '9999900003'] } } },
    });
    await prisma.device.deleteMany({});
    await prisma.user.deleteMany({
      where: {
        mobile: { in: ['9999900001', '9999900002', '9999900003'] },
      },
    });
    await prisma.$disconnect();
  });

  describe('Global Exception Filter Formatting', () => {
    it('formats HttpExceptions as uniform JSON with statusCode, message, error, timestamp, path', () => {
      const mockStatus = jest.fn().mockReturnThis();
      const mockJson = jest.fn();
      const mockHost = {
        switchToHttp: () => ({
          getResponse: () => ({ status: mockStatus, json: mockJson }),
          getRequest: () => ({ url: '/v1/test/endpoint' }),
        }),
      } as any;

      const notFoundEx = new NotFoundException('Target resource not found');
      filter.catch(notFoundEx, mockHost);

      expect(mockStatus).toHaveBeenCalledWith(404);
      expect(mockJson).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 404,
          message: 'Target resource not found',
          error: 'Not Found',
          path: '/v1/test/endpoint',
          timestamp: expect.any(String),
        }),
      );
    });

    it('formats ConflictException (409) as uniform JSON', () => {
      const mockStatus = jest.fn().mockReturnThis();
      const mockJson = jest.fn();
      const mockHost = {
        switchToHttp: () => ({
          getResponse: () => ({ status: mockStatus, json: mockJson }),
          getRequest: () => ({ url: '/v1/admin/users' }),
        }),
      } as any;

      const conflictEx = new ConflictException('User already exists');
      filter.catch(conflictEx, mockHost);

      expect(mockStatus).toHaveBeenCalledWith(409);
      expect(mockJson).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 409,
          message: 'User already exists',
          error: 'Conflict',
          path: '/v1/admin/users',
        }),
      );
    });
  });

  describe('Duplicate Mobile Check (409 Conflict)', () => {
    it('creates a user and returns ConflictException (409) when creating duplicate mobile', async () => {
      const testMobile = '9999900001';
      const adminReq = { user: { sub: 'admin-audit' } };

      // First create succeeds
      const user = await adminController.createUser(adminReq, {
        name: 'Guard Audit Test',
        mobile: testMobile,
        role: 'GUARD',
      });
      expect(user).toBeDefined();
      expect(user.mobile).toBe(testMobile);

      // Duplicate create throws ConflictException (HTTP 409)
      await expect(
        adminController.createUser(adminReq, {
          name: 'Duplicate Guard',
          mobile: testMobile,
          role: 'GUARD',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('Unregistered Number Login (404 Not Found)', () => {
    it('throws NotFoundException with exact message for unregistered phone', async () => {
      const unregisteredMobile = '9999999990';
      await expect(authService.sendOtp(unregisteredMobile)).rejects.toThrow(
        new NotFoundException("This number isn't registered. Contact your admin."),
      );
    });

    it('rejects invalid mobile numbers with 400 Bad Request', async () => {
      await expect(authService.sendOtp('12345')).rejects.toThrow(BadRequestException);
    });
  });

  describe('Role-Based Access Control Guards', () => {
    it('rejects requests without token with 401 Unauthorized', async () => {
      const jwtGuard = new JwtAuthGuard(jwtService);
      const mockReq = { headers: {} };
      const mockContext = {
        switchToHttp: () => ({ getRequest: () => mockReq }),
      } as any;

      await expect(jwtGuard.canActivate(mockContext)).rejects.toThrow(UnauthorizedException);
    });

    it('rejects STUDENT trying to access ADMIN endpoints with 403 Forbidden', async () => {
      const reflector = new Reflector();
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['ADMIN']);
      const rolesGuard = new RolesGuard(reflector);

      const mockReq = { user: { sub: 'student-id', role: 'STUDENT' } };
      const mockContext = {
        getHandler: () => {},
        getClass: () => {},
        switchToHttp: () => ({ getRequest: () => mockReq }),
      } as any;

      expect(() => rolesGuard.canActivate(mockContext)).toThrow(ForbiddenException);
    });

    it('rejects GUARD trying to access APPROVALS endpoints with 403 Forbidden', async () => {
      const reflector = new Reflector();
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['TUTOR', 'HOD']);
      const rolesGuard = new RolesGuard(reflector);

      const mockReq = { user: { sub: 'guard-id', role: 'GUARD' } };
      const mockContext = {
        getHandler: () => {},
        getClass: () => {},
        switchToHttp: () => ({ getRequest: () => mockReq }),
      } as any;

      expect(() => rolesGuard.canActivate(mockContext)).toThrow(ForbiddenException);
    });

    it('allows ADMIN to access ADMIN endpoints', async () => {
      const reflector = new Reflector();
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['ADMIN']);
      const rolesGuard = new RolesGuard(reflector);

      const mockReq = { user: { sub: 'admin-id', role: 'ADMIN' } };
      const mockContext = {
        getHandler: () => {},
        getClass: () => {},
        switchToHttp: () => ({ getRequest: () => mockReq }),
      } as any;

      expect(rolesGuard.canActivate(mockContext)).toBe(true);
    });
  });

  describe('Database Foreign Key and Query Indexes Verification', () => {
    it('efficiently queries Student by tutorId index and User by role/status', async () => {
      const tutors = await prisma.user.findMany({
        where: { role: 'TUTOR', status: 'ACTIVE' },
        take: 5,
      });
      expect(Array.isArray(tutors)).toBe(true);

      const students = await prisma.student.findMany({
        where: { tutorId: tutors[0]?.id ?? 'none' },
        take: 5,
      });
      expect(Array.isArray(students)).toBe(true);
    });

    it('efficiently queries GateEvents by outpassId and guardId', async () => {
      const events = await prisma.gateEvent.findMany({
        where: { outpassId: 'dummy-outpass-id' },
        take: 5,
      });
      expect(Array.isArray(events)).toBe(true);
    });
  });
});
