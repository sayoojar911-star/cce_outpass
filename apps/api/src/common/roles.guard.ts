import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../prisma.service';

export const ROLES_KEY = 'roles';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma?: PrismaService,
  ) {}

  canActivate(context: ExecutionContext): boolean | Promise<boolean> {
    const required = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const { user } = context.switchToHttp().getRequest();
    if (!user || (!user.userId && !user.role)) {
      throw new ForbiddenException('Insufficient role');
    }

    if (!this.prisma || !user.userId) {
      const userRoleId = (user.roleId || user.role || '').toLowerCase();
      const userRoleLegacy = (user.role || '').toLowerCase();
      const matches = required.some((r) => {
        const target = r.toLowerCase();
        return target === userRoleId || target === userRoleLegacy;
      });
      if (!matches) {
        throw new ForbiddenException('Insufficient role');
      }
      return true;
    }

    return this.validateWithPrisma(user, required);
  }

  private async validateWithPrisma(user: any, required: string[]): Promise<boolean> {
    let userRoleId = (user.roleId || user.role || '').toLowerCase();
    let userRoleLegacy = (user.role || '').toLowerCase();
    let userRoleName = '';

    try {
      const dbUser = await this.prisma!.user.findUnique({
        where: { id: user.userId },
        include: { roleRef: true },
      });

      if (dbUser) {
        if (!dbUser.active || dbUser.status !== 'ACTIVE') {
          throw new ForbiddenException('User is inactive or deleted');
        }
        userRoleId = (dbUser.roleId || userRoleId).toLowerCase();
        userRoleLegacy = (dbUser.role || userRoleLegacy).toLowerCase();
        userRoleName = (dbUser.roleRef?.name || '').toLowerCase();
      }
    } catch (err) {
      if (err instanceof ForbiddenException) throw err;
    }

    const matches = required.some((r) => {
      const target = r.toLowerCase();
      return (
        target === userRoleId ||
        target === userRoleLegacy ||
        target === userRoleName
      );
    });

    if (!matches) {
      throw new ForbiddenException('Insufficient role');
    }
    return true;
  }
}

