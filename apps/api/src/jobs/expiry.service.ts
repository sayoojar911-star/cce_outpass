import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const GRACE_MS = 15 * 60 * 1000; // §6.9 grace period, then OVERDUE

@Injectable()
export class ExpiryService {
  private readonly logger = new Logger(ExpiryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async run() {
    await this.expireApproved();
    await this.markOverdue();
  }

  private async expireApproved() {
    const stale = await this.prisma.outpassRequest.findMany({
      where: { status: 'APPROVED', validUntil: { lt: new Date() } },
      select: { id: true, studentId: true },
      take: 500,
    });
    if (stale.length === 0) return;
    const res = await this.prisma.outpassRequest.updateMany({
      where: { id: { in: stale.map((s) => s.id) }, status: 'APPROVED' },
      data: { status: 'EXPIRED', version: { increment: 1 } },
    });
    if (res.count > 0) {
      this.logger.log(`expired ${res.count} outpasses`);
      for (const s of stale) {
        await this.notifications.push(
          s.studentId,
          'Outpass expired',
          'Your outpass validity window passed without exit',
        );
      }
    }
  }

  private async markOverdue() {
    const cutoff = new Date(Date.now() - GRACE_MS);
    const stale = await this.prisma.outpassRequest.findMany({
      where: { status: 'EXITED', expectedReturnAt: { lt: cutoff } },
      select: { id: true, studentId: true },
      take: 500,
    });
    if (stale.length === 0) return;
    const res = await this.prisma.outpassRequest.updateMany({
      where: { id: { in: stale.map((s) => s.id) }, status: 'EXITED' },
      data: { status: 'OVERDUE', version: { increment: 1 } },
    });
    if (res.count > 0) {
      this.logger.log(`marked ${res.count} outpasses overdue`);
      for (const s of stale) {
        await this.notifications.push(
          s.studentId,
          'Return overdue',
          'You have not been scanned back at the gate',
        );
      }
    }
  }
}
