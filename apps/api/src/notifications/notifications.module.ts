import { Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { PrismaService } from '../prisma.service';
import { JwtAuthGuard } from '../common/jwt-auth.guard';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, PrismaService, JwtAuthGuard],
  exports: [NotificationsService],
})
export class NotificationsModule {}
