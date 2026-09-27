import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { PrismaService } from '../prisma.service';

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Append-only, hash-chained audit record (SEC-AUD-01):
   * hash_n = SHA256(prev_hash || canonical_json(record_n))
   */
  async append(
    actorId: string | null,
    actorRole: string | null,
    action: string,
    objectType: string,
    objectId: string | null,
    detail: Record<string, unknown> | null = null,
  ) {
    try {
      const last = await this.prisma.auditLog.findFirst({ orderBy: { id: 'desc' } });
      const prevHash = last?.hash ?? '';
      const canonical = JSON.stringify({
        at: new Date().toISOString(),
        actorId,
        actorRole,
        action,
        objectType,
        objectId,
        detail,
      });
      const hash = createHash('sha256').update(prevHash + canonical).digest('hex');
      await this.prisma.auditLog.create({
        data: {
          actorId,
          actorRole,
          action,
          objectType,
          objectId,
          detail: detail ? JSON.stringify(detail) : null,
          prevHash: prevHash || null,
          hash,
        },
      });
    } catch (e) {
      // Audit must never crash the business flow, but must be visible in logs.
      this.logger.error(`audit append failed: ${e}`);
    }
  }
}
