import { Module } from '@nestjs/common';
import { ConfigController } from './config.controller';
import { ConfigService } from './config.service';
import { PrismaService } from '../prisma.service';
import { JwtModule } from '@nestjs/jwt';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'cce-outpass-jwt-secret-key-2026',
    }),
  ],
  controllers: [ConfigController],
  providers: [ConfigService, PrismaService],
  exports: [ConfigService],
})
export class AppConfigModule {}
