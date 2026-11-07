import { PhotoStorageService } from './photo-storage.service';
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { JwtAuthGuard } from '../common/jwt-auth.guard';
import { FirebaseAuthService } from './firebase-auth.service';

@Module({
  imports: [
    JwtModule.registerAsync({
      global: true,
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET', 'dev-only-secret'),
        signOptions: { expiresIn: config.get<string>('JWT_EXPIRES_IN', '15m') },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, PrismaService, AuditService, JwtAuthGuard, FirebaseAuthService, PhotoStorageService],
  exports: [AuthService, PhotoStorageService],
})
export class AuthModule {}
