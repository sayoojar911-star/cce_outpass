import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';

@Module({
  controllers: [AdminController],
  providers: [PrismaService, AuditService],
})
export class AdminModule {}
