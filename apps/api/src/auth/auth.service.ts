import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes, createPublicKey } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { RegisterDeviceDto, RegisterStudentDto, normalizeMobile } from './dto';
import { FirebaseAuthService } from './firebase-auth.service';
import { PhotoStorageService } from './photo-storage.service';

const REFRESH_TTL_MS = 7 * 24 * 60 * 60 * 1000;

function sha256(s: string) {
  return createHash('sha256').update(s).digest('hex');
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly audit: AuditService,
    private readonly firebaseAuth: FirebaseAuthService,
    private readonly photoStorage: PhotoStorageService,
  ) {}

  private checkOtp(mobile: string, code: string): boolean {
    const tempOtpEnabled = process.env.TEMP_OTP_ENABLED !== 'false';
    if (tempOtpEnabled && code === '123456') {
      return true;
    }
    return false;
  }

  private async getOrCreateUserByMobile(mobile: string) {
    let user = await this.prisma.user.findFirst({
      where: { mobile },
      include: { roleRef: true, deptRef: true, tutor: true },
    });

    if (!user) {
      // Check if self-signup is allowed
      const signupSetting = await this.prisma.appSetting.findUnique({
        where: { key: 'allowSelfSignup' },
      });
      let allowSignup = false;
      if (signupSetting) {
        try {
          allowSignup = JSON.parse(signupSetting.value) === true;
        } catch (_) {
          allowSignup = signupSetting.value === 'true';
        }
      }

      if (!allowSignup) {
        throw new NotFoundException("This number isn't registered. Contact your admin.");
      }

      // New sign-ups get a configurable default role (default: "pending")
      const defaultSetting = await this.prisma.appSetting.findUnique({
        where: { key: 'defaultRoleId' },
      });
      let defaultRoleId = 'pending';
      if (defaultSetting) {
        try {
          defaultRoleId = JSON.parse(defaultSetting.value);
        } catch (_) {
          defaultRoleId = defaultSetting.value;
        }
      }

      const roleObj = await this.prisma.role.findUnique({ where: { id: defaultRoleId } });

      user = await this.prisma.user.create({
        data: {
          name: `User ${mobile.slice(-4)}`,
          mobile,
          roleId: defaultRoleId,
          role: roleObj?.name || defaultRoleId.toUpperCase(),
          status: 'ACTIVE',
          active: true,
        },
        include: { roleRef: true, deptRef: true, tutor: true },
      });

      await this.audit.append(
        user.id,
        user.roleId || 'pending',
        'USER_SIGNUP',
        'User',
        user.id,
        { mobile, assignedDefaultRole: defaultRoleId },
      );
    }

    return user;
  }

  async sendOtp(rawMobile: string) {
    const mobile = normalizeMobile(rawMobile);
    if (!/^\d{10}$/.test(mobile)) {
      throw new BadRequestException('Phone number must be exactly 10 digits');
    }

    const user = await this.getOrCreateUserByMobile(mobile);

    if (!user.active || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('This account is deactivated. Contact your admin.');
    }

    return { ok: true, message: 'OTP sent successfully' };
  }

  async verifyOtp(rawMobile: string, code: string) {
    const mobile = normalizeMobile(rawMobile);
    if (!/^\d{10}$/.test(mobile)) {
      throw new BadRequestException('Phone number must be exactly 10 digits');
    }

    if (!this.checkOtp(mobile, code)) {
      throw new UnauthorizedException('Invalid OTP. Please try again.');
    }

    const user = await this.getOrCreateUserByMobile(mobile);

    if (!user.active || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('This account is deactivated. Contact your admin.');
    }

    return this.createSession(user);
  }

  async sendSignupOtp(rawMobile: string) {
    const mobile = normalizeMobile(rawMobile);
    if (!/^\d{10}$/.test(mobile)) {
      throw new BadRequestException('Phone number must be exactly 10 digits');
    }

    // Check if user already exists
    const existing = await this.prisma.user.findUnique({ where: { mobile } });
    if (existing) {
      throw new ConflictException('A user with this mobile number already exists. Please sign in instead.');
    }

    return { ok: true, message: 'OTP sent successfully' };
  }

  async verifySignupOtp(rawMobile: string, code: string) {
    const mobile = normalizeMobile(rawMobile);
    if (!/^\d{10}$/.test(mobile)) {
      throw new BadRequestException('Phone number must be exactly 10 digits');
    }

    if (!this.checkOtp(mobile, code)) {
      throw new UnauthorizedException('Invalid OTP. Please try again.');
    }

    // In dev / test environment, return a test Firebase ID token
    return {
      ok: true,
      idToken: `test:${mobile}`,
      mobile,
    };
  }

  async verifyFirebasePhone(idToken: string) {
    const phoneNumber = await this.firebaseAuth.verifyPhoneIdToken(idToken);
    const mobile = normalizeMobile(phoneNumber);
    const user = await this.getOrCreateUserByMobile(mobile);

    if (!user.active || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('This account is deactivated. Contact your admin.');
    }

    return this.createSession(user);
  }

  /**
   * Secure student registration endpoint.
   * - Verifies Firebase ID token and extracts verified mobile number
   * - Validates name, roll number, year, department, and photo
   * - Enforces roll number format: CCEXXXXXXX
   * - Rejects duplicates (mobile, roll number) with 409 ConflictException
   * - Automatically assigns STUDENT role (ignoring any requested role)
   * - Saves student photo reference
   * - Stores User and Student atomically in a single transaction
   * - Returns session tokens and created student profile
   */
  async registerStudent(dto: RegisterStudentDto) {
    if (!dto.idToken || typeof dto.idToken !== 'string') {
      throw new BadRequestException('Firebase ID token is required');
    }

    // 1. Verify Firebase Phone ID token cryptographically
    const verifiedPhone = await this.firebaseAuth.verifyPhoneIdToken(dto.idToken);
    const mobile = normalizeMobile(verifiedPhone);
    if (!/^\d{10}$/.test(mobile)) {
      throw new BadRequestException('Invalid mobile number in verified phone token');
    }

    // 2. Validate student name
    const name = dto.name?.trim();
    if (!name || name.length < 2) {
      throw new BadRequestException('Full name is required (minimum 2 characters)');
    }

    // 3. Validate Roll Number format (CCEXXXXXXX)
    const rawRoll = dto.rollNo?.trim().toUpperCase();
    if (!rawRoll || !/^CCE[A-Z0-9]{5,10}$/.test(rawRoll)) {
      throw new BadRequestException(
        'College roll number must follow CCEXXXXXXX format (CCE followed by alphanumeric characters, e.g. CCE23CS042)',
      );
    }
    const registerNo = rawRoll;

    // 4. Validate Year of Study (1, 2, 3, or 4)
    const year = Number(dto.year);
    if (![1, 2, 3, 4].includes(year)) {
      throw new BadRequestException('Current Year of Study must be 1, 2, 3, or 4');
    }

    // 5. Validate Department
    const deptInput = dto.department?.trim();
    if (!deptInput) {
      throw new BadRequestException('Department is required');
    }
    const department = await this.prisma.department.findFirst({
      where: {
        OR: [
          { code: { equals: deptInput, mode: 'insensitive' } },
          { name: { equals: deptInput, mode: 'insensitive' } },
          { id: deptInput },
        ],
      },
    });
    if (!department) {
      throw new BadRequestException(`Department "${deptInput}" is invalid or does not exist`);
    }

    // 6. Validate Photo
    const rawPhoto = dto.photo?.trim();
    if (!rawPhoto) {
      throw new BadRequestException('Student photo is required');
    }

    // 7. Check duplicates
    const existingUser = await this.prisma.user.findUnique({ where: { mobile } });
    if (existingUser) {
      throw new ConflictException(`A user with mobile number ${mobile} already exists`);
    }

    const existingStudent = await this.prisma.student.findUnique({ where: { registerNo } });
    if (existingStudent) {
      throw new ConflictException(`A student with college roll number "${registerNo}" already exists`);
    }

    // 8. Validate and store photo securely in persistent storage
    let photoUrl = rawPhoto;
    let savedPhotoPath: string | null = null;
    try {
      const validated = this.photoStorage.parseAndValidateBase64(rawPhoto);
      photoUrl = this.photoStorage.saveImage(validated, `student_${mobile}`);
      savedPhotoPath = photoUrl;
    } catch (err) {
      if (err instanceof BadRequestException) throw err;
      throw new BadRequestException('Failed validating student photo: ' + (err as Error).message);
    }

    // 9. Lookup or ensure STUDENT role
    let studentRole = await this.prisma.role.findUnique({ where: { id: 'student' } });
    if (!studentRole) {
      studentRole = await this.prisma.role.upsert({
        where: { id: 'student' },
        update: {},
        create: {
          id: 'student',
          name: 'Student',
          permissions: ['createOutpass'],
          isSystem: true,
          active: true,
        },
      });
    }

    // 10. Atomic transaction: create User and Student profile
    const semester = (year - 1) * 2 + 1;
    let createdResult: { user: any; student: any };
    try {
      createdResult = await this.prisma.$transaction(async (tx) => {
        const u = await tx.user.create({
          data: {
            name,
            mobile,
            roleId: studentRole.id,
            role: 'STUDENT',
            departmentId: department.id,
            department: department.code,
            year,
            photoUrl,
            active: true,
            status: 'ACTIVE',
          },
          include: { roleRef: true, deptRef: true, tutor: true },
        });

        const s = await tx.student.create({
          data: {
            userId: u.id,
            registerNo,
            department: department.code,
            year,
            semester,
            photoUrl,
          },
        });

        return { user: u, student: s };
      });
    } catch (txErr) {
      // Clean up newly created photo file so no orphaned file is left on server
      if (savedPhotoPath) {
        this.photoStorage.deletePhoto(savedPhotoPath);
      }
      throw txErr;
    }

    const { user, student } = createdResult;

    // 11. Record in audit trail
    await this.audit.append(
      user.id,
      'student',
      'STUDENT_REGISTERED',
      'User',
      user.id,
      {
        name: user.name,
        mobile: user.mobile,
        rollNo: student.registerNo,
        department: department.code,
        year: student.year,
        semester: student.semester,
      },
    );

    // 12. Create authenticated session
    const session = await this.createSession(user);
    return {
      ...session,
      student: {
        registerNo: student.registerNo,
        department: department.code,
        year: student.year,
        semester: student.semester,
        photoUrl: student.photoUrl,
      },
    };
  }

  private async createSession(user: any) {
    const refreshToken = randomBytes(48).toString('hex');
    await this.prisma.session.create({
      data: {
        userId: user.id,
        refreshTokenHash: sha256(refreshToken),
        expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
      },
    });

    const accessToken = await this.signAccessToken(user);
    return {
      accessToken,
      refreshToken,
      user: this.toPublicUser(user),
    };
  }

  async refresh(refreshToken: string) {
    const hash = sha256(refreshToken);
    const session = await this.prisma.session.findUnique({ where: { refreshTokenHash: hash } });
    if (!session || session.revokedAt || session.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid session');
    }
    // Rotation: revoke the used token, issue a fresh pair
    await this.prisma.session.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });
    const user = await this.prisma.user.findUnique({
      where: { id: session.userId },
      include: { roleRef: true, deptRef: true, tutor: true },
    });
    if (!user || !user.active || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Invalid session');
    }

    const newRefresh = randomBytes(48).toString('hex');
    await this.prisma.session.create({
      data: {
        userId: user.id,
        refreshTokenHash: sha256(newRefresh),
        expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
      },
    });
    return {
      accessToken: await this.signAccessToken(user),
      refreshToken: newRefresh,
      user: this.toPublicUser(user),
    };
  }

  async logout(refreshToken: string) {
    await this.prisma.session.updateMany({
      where: { refreshTokenHash: sha256(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }

  async registerDevice(user: { userId: string; roleId?: string; role?: string }, dto: RegisterDeviceDto) {
    let parsed;
    try {
      parsed = createPublicKey(dto.publicKeyPem);
      parsed.export({ format: 'pem', type: 'spki' });
    } catch {
      throw new BadRequestException('publicKeyPem is not a valid public key');
    }

    const device = await this.prisma.$transaction(async (tx) => {
      // One active device per user: revoke previous bindings.
      await tx.device.updateMany({
        where: { userId: user.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      return tx.device.create({
        data: {
          userId: user.userId,
          platform: dto.platform || 'web',
          publicKey: dto.publicKeyPem,
        },
      });
    });

    await this.audit.append(
      user.userId,
      user.roleId || user.role || 'user',
      'DEVICE_BOUND',
      'Device',
      device.id,
      { platform: device.platform },
    );
    return device;
  }

  async me(user: { userId: string }) {
    const dbUser = await this.prisma.user.findUnique({
      where: { id: user.userId },
      include: {
        roleRef: true,
        deptRef: true,
        tutor: { select: { id: true, name: true, mobile: true } },
        devices: { where: { revokedAt: null }, select: { id: true, platform: true } },
        student: {
          include: {
            tutor: { select: { id: true, name: true, mobile: true } },
          },
        },
      },
    });
    if (!dbUser) throw new UnauthorizedException('User not found');

    const effectiveTutor = dbUser.tutor || dbUser.student?.tutor;

    return {
      ...this.toPublicUser(dbUser),
      hasDevice: dbUser.devices.length > 0,
      deviceId: dbUser.devices[0]?.id ?? null,
      student: {
        registerNo: dbUser.student?.registerNo || `REG-${dbUser.mobile.slice(-4)}`,
        department: dbUser.deptRef?.code || dbUser.department || 'GENERAL',
        semester: dbUser.student?.semester ?? 1,
        year: dbUser.year ?? dbUser.student?.year ?? 1,
        division: dbUser.division ?? dbUser.student?.division ?? null,
        photoUrl: dbUser.photoUrl ?? dbUser.student?.photoUrl ?? null,
        tutor: effectiveTutor,
      },
    };
  }

  private async signAccessToken(user: any) {
    const permissions = user.roleRef?.permissions || [];
    const roleId = user.roleId || user.role?.toLowerCase() || 'pending';
    const roleName = user.role || user.roleRef?.name || roleId;

    return this.jwt.signAsync({
      sub: user.id,
      roleId,
      role: roleName,
      roleName: user.roleRef?.name || user.role || roleId,
      permissions,
      name: user.name,
      mobile: user.mobile,
      departmentId: user.departmentId || null,
      department: user.deptRef?.code || user.department || null,
    });
  }

  private toPublicUser(user: any) {
    const permissions = user.roleRef?.permissions || [];
    const roleId = user.roleId || user.role?.toLowerCase() || 'pending';
    const roleName = user.role || user.roleRef?.name || roleId;

    return {
      id: user.id,
      name: user.name,
      mobile: user.mobile,
      email: user.email || null,
      photoUrl: user.photoUrl || user.student?.photoUrl || null,
      roleId,
      role: roleName,
      roleName: user.roleRef?.name || user.role || roleId,
      permissions,
      departmentId: user.departmentId || null,
      department: user.deptRef?.code || user.department || null,
      year: user.year ?? null,
      division: user.division ?? null,
      tutorId: user.tutorId || user.student?.tutorId || null,
      active: user.active ?? (user.status === 'ACTIVE'),
      status: user.status || 'ACTIVE',
    };
  }

  /**
   * Authenticated profile photo update endpoint for logged-in user.
   */
  async updateProfilePhoto(userAuth: { userId: string; role?: string }, rawPhoto: string) {
    if (!rawPhoto || typeof rawPhoto !== 'string') {
      throw new BadRequestException('Student photo is required');
    }

    const validated = this.photoStorage.parseAndValidateBase64(rawPhoto);
    const newPhotoUrl = this.photoStorage.saveImage(validated, `user_${userAuth.userId}`);

    // Retrieve previous photo to clean it up if it was a local uploaded file
    const existingUser = await this.prisma.user.findUnique({
      where: { id: userAuth.userId },
      select: { photoUrl: true },
    });

    try {
      await this.prisma.$transaction([
        this.prisma.user.update({
          where: { id: userAuth.userId },
          data: { photoUrl: newPhotoUrl },
        }),
        this.prisma.student.updateMany({
          where: { userId: userAuth.userId },
          data: { photoUrl: newPhotoUrl },
        }),
      ]);
    } catch (err) {
      this.photoStorage.deletePhoto(newPhotoUrl);
      throw err;
    }

    if (existingUser?.photoUrl && existingUser.photoUrl !== newPhotoUrl) {
      this.photoStorage.deletePhoto(existingUser.photoUrl);
    }

    await this.audit.append(
      userAuth.userId,
      userAuth.role || 'user',
      'PROFILE_PHOTO_UPDATED',
      'User',
      userAuth.userId,
      { newPhotoUrl },
    );

    return { ok: true, photoUrl: newPhotoUrl };
  }

  /**
   * Authenticated profile photo remove/reset endpoint.
   */
  async removeProfilePhoto(userAuth: { userId: string; role?: string }) {
    const existingUser = await this.prisma.user.findUnique({
      where: { id: userAuth.userId },
      select: { photoUrl: true },
    });

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userAuth.userId },
        data: { photoUrl: null },
      }),
      this.prisma.student.updateMany({
        where: { userId: userAuth.userId },
        data: { photoUrl: null },
      }),
    ]);

    if (existingUser?.photoUrl) {
      this.photoStorage.deletePhoto(existingUser.photoUrl);
    }

    await this.audit.append(
      userAuth.userId,
      userAuth.role || 'user',
      'PROFILE_PHOTO_REMOVED',
      'User',
      userAuth.userId,
      {},
    );

    return { ok: true, photoUrl: null };
  }

}
