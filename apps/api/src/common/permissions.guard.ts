import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../prisma.service';

export const PERMISSIONS_KEY = 'permissions';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<string[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!required || required.length === 0) return true;

    const req = context.switchToHttp().getRequest();
    const user = req.user;
    if (!user || !user.userId) {
      throw new UnauthorizedException('Authentication required');
    }

    // Always fetch live user and role from database to ensure immediate permission changes
    const dbUser = await this.prisma.user.findUnique({
      where: { id: user.userId },
      include: { roleRef: true },
    });

    if (!dbUser || !dbUser.active || dbUser.status !== 'ACTIVE') {
      throw new UnauthorizedException('User account is inactive or not found');
    }

    const permissions = dbUser.roleRef?.permissions || [];
    // User must have at least one or all required permissions
    const hasPermission = required.some((p) => permissions.includes(p));

    console.log(
      `[PermissionsGuard] User: ${dbUser.name} (${dbUser.id}) | RoleId: ${dbUser.roleId} | Required: [${required.join(
        ', ',
      )}] | UserPerms: [${permissions.join(', ')}] | Allowed: ${hasPermission}`,
    );

    if (!hasPermission) {
      throw new ForbiddenException(
        `Insufficient permissions. Required one of: ${required.join(', ')}`,
      );
    }

    // Attach fresh user info to request
    req.user.roleId = dbUser.roleId || 'pending';
    req.user.permissions = permissions;
    req.user.departmentId = dbUser.departmentId;

    return true;
  }
}
