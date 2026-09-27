import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes, createPublicKey } from 'crypto';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { RegisterDeviceDto, normalizeMobile } from './dto';
import { FirebaseAuthService } from './firebase-auth.service';

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
  ) {}

  async verifyFirebasePhone(idToken: string) {
    const phoneNumber = await this.firebaseAuth.verifyPhoneIdToken(idToken);
    const mobile = normalizeMobile(phoneNumber);
    const user = await this.prisma.user.findFirst({
      where: { mobile, status: 'ACTIVE' },
    });
    if (!user) throw new NotFoundException('No active account for this number');

    return this.createSession(user);
  }

  private async createSession(user: {
    id: string;
    name: string;
    role: string;
    mobile: string;
    department: string | null;
  }) {
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
    const user = await this.prisma.user.findUnique({ where: { id: session.userId } });
    if (!user) throw new UnauthorizedException('Invalid session');

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

  async registerDevice(user: { userId: string; role: string }, dto: RegisterDeviceDto) {
    let parsed;
    try {
      parsed = createPublicKey(dto.publicKeyPem);
      parsed.export({ format: 'pem', type: 'spki' });
    } catch {
      throw new BadRequestException('publicKeyPem is not a valid public key');
    }

    const device = await this.prisma.$transaction(async (tx) => {
      // One active device per user (SEC-DEV-01): revoke previous bindings.
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

    await this.audit.append(user.userId, user.role, 'DEVICE_BOUND', 'Device', device.id, {
      platform: device.platform,
    });
    return device;
  }

  async me(user: { userId: string }) {
    const dbUser = await this.prisma.user.findUnique({
      where: { id: user.userId },
      include: {
        devices: { where: { revokedAt: null }, select: { id: true, platform: true } },
        student: true,
      },
    });
    if (!dbUser) throw new UnauthorizedException();
    return {
      ...this.toPublicUser(dbUser),
      hasDevice: dbUser.devices.length > 0,
      deviceId: dbUser.devices[0]?.id ?? null,
      student: dbUser.student
        ? {
            registerNo: dbUser.student.registerNo,
            department: dbUser.student.department,
            semester: dbUser.student.semester,
          }
        : null,
    };
  }

  private async signAccessToken(user: { id: string; role: string; name: string; mobile: string }) {
    return this.jwt.signAsync({
      sub: user.id,
      role: user.role,
      name: user.name,
      mobile: user.mobile,
    });
  }

  private toPublicUser(user: {
    id: string;
    name: string;
    role: string;
    mobile: string;
    department: string | null;
  }) {
    return {
      id: user.id,
      name: user.name,
      role: user.role,
      mobile: user.mobile,
      department: user.department ?? null,
    };
  }
}
