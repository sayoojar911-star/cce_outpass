import { ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RolesGuard } from './roles.guard';
import { ROLES_KEY } from './auth.decorator';

function createMockContext(headers: Record<string, string>, user?: any): ExecutionContext {
  const req = {
    headers,
    user,
  };
  return {
    switchToHttp: () => ({
      getRequest: () => req,
      getResponse: () => ({}),
      getNext: () => ({}),
    }),
    getHandler: () => ({}),
    getClass: () => ({}),
  } as unknown as ExecutionContext;
}

describe('Authentication & Authorization Guards', () => {
  const jwtSecret = 'test-jwt-secret-key';
  let jwtService: JwtService;
  let jwtGuard: JwtAuthGuard;
  let reflector: Reflector;
  let rolesGuard: RolesGuard;

  beforeEach(() => {
    jwtService = new JwtService({ secret: jwtSecret });
    jwtGuard = new JwtAuthGuard(jwtService);
    reflector = new Reflector();
    rolesGuard = new RolesGuard(reflector);
  });

  describe('JwtAuthGuard', () => {
    it('throws UnauthorizedException when authorization header is missing', async () => {
      const ctx = createMockContext({});
      await expect(jwtGuard.canActivate(ctx)).rejects.toThrow(
        new UnauthorizedException('Missing bearer token'),
      );
    });

    it('throws UnauthorizedException when bearer token is malformed', async () => {
      const ctx = createMockContext({ authorization: 'Basic dXNlcjpwYXNz' });
      await expect(jwtGuard.canActivate(ctx)).rejects.toThrow(
        new UnauthorizedException('Missing bearer token'),
      );
    });

    it('throws UnauthorizedException when token signature is invalid', async () => {
      const otherJwt = new JwtService({ secret: 'different-secret' });
      const token = await otherJwt.signAsync({ sub: 'u1', role: 'STUDENT' });
      const ctx = createMockContext({ authorization: `Bearer ${token}` });

      await expect(jwtGuard.canActivate(ctx)).rejects.toThrow(
        new UnauthorizedException('Invalid or expired token'),
      );
    });

    it('throws UnauthorizedException when token is expired', async () => {
      const token = await jwtService.signAsync(
        { sub: 'u1', role: 'STUDENT', name: 'Test', mobile: '9000000000' },
        { expiresIn: '-1s' },
      );
      const ctx = createMockContext({ authorization: `Bearer ${token}` });

      await expect(jwtGuard.canActivate(ctx)).rejects.toThrow(
        new UnauthorizedException('Invalid or expired token'),
      );
    });

    it('populates req.user and allows request with valid active token', async () => {
      const token = await jwtService.signAsync({
        sub: 'u-student-1',
        role: 'STUDENT',
        name: 'Ananya S',
        mobile: '9000000010',
      });
      const ctx = createMockContext({ authorization: `Bearer ${token}` });

      const allowed = await jwtGuard.canActivate(ctx);
      expect(allowed).toBe(true);
      const req = ctx.switchToHttp().getRequest();
      expect(req.user).toEqual({
        userId: 'u-student-1',
        role: 'STUDENT',
        name: 'Ananya S',
        mobile: '9000000010',
      });
    });
  });

  describe('RolesGuard (RBAC)', () => {
    it('allows request when no roles metadata is defined', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(undefined);
      const ctx = createMockContext({}, { role: 'STUDENT' });
      expect(rolesGuard.canActivate(ctx)).toBe(true);
    });

    it('allows STUDENT to access STUDENT-restricted endpoints', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['STUDENT']);
      const ctx = createMockContext({}, { role: 'STUDENT' });
      expect(rolesGuard.canActivate(ctx)).toBe(true);
    });

    it('rejects unauthorized roles (TUTOR, HOD, GUARD) from STUDENT-restricted endpoints', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['STUDENT']);

      for (const unauthorizedRole of ['TUTOR', 'HOD', 'GUARD', 'GUEST']) {
        const ctx = createMockContext({}, { role: unauthorizedRole });
        expect(() => rolesGuard.canActivate(ctx)).toThrow(
          new ForbiddenException('Insufficient role'),
        );
      }
    });

    it('rejects STUDENT from TUTOR or HOD approval endpoints', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['TUTOR', 'HOD']);
      const studentCtx = createMockContext({}, { role: 'STUDENT' });
      expect(() => rolesGuard.canActivate(studentCtx)).toThrow(
        new ForbiddenException('Insufficient role'),
      );

      const tutorCtx = createMockContext({}, { role: 'TUTOR' });
      expect(rolesGuard.canActivate(tutorCtx)).toBe(true);

      const hodCtx = createMockContext({}, { role: 'HOD' });
      expect(rolesGuard.canActivate(hodCtx)).toBe(true);
    });

    it('rejects unauthenticated (no user on request) access when role is required', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['STUDENT']);
      const ctx = createMockContext({}, undefined);
      expect(() => rolesGuard.canActivate(ctx)).toThrow(
        new ForbiddenException('Insufficient role'),
      );
    });
  });
});
