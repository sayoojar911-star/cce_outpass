import { Module } from '@nestjs/common';
import { OutpassService } from './outpass.service';
import { OutpassController } from './outpass.controller';
import { ApprovalsController } from './approvals.controller';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [OutpassController, ApprovalsController],
  providers: [OutpassService, PrismaService, AuditService],
  exports: [OutpassService],
})
export class OutpassModule {}
