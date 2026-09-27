import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async push(userId: string, title: string, body: string) {
    await this.prisma.notification.create({ data: { userId, title, body } });
  }

  async list(user: { userId: string }) {
    return this.prisma.notification.findMany({
      where: { userId: user.userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markAllRead(user: { userId: string }) {
    await this.prisma.notification.updateMany({
      where: { userId: user.userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { ok: true };
  }
}
