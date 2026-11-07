import { SetMetadata, UseGuards, applyDecorators } from '@nestjs/common';
import { JwtAuthGuard } from './jwt-auth.guard';
import { PermissionsGuard, PERMISSIONS_KEY } from './permissions.guard';
import { RolesGuard, ROLES_KEY } from './roles.guard';

export { PERMISSIONS_KEY, ROLES_KEY };

export const RequirePermissions = (...permissions: string[]) =>
  applyDecorators(
    UseGuards(JwtAuthGuard, PermissionsGuard),
    SetMetadata(PERMISSIONS_KEY, permissions),
  );

export const RequireRoles = (...roles: string[]) =>
  applyDecorators(
    UseGuards(JwtAuthGuard, RolesGuard),
    SetMetadata(ROLES_KEY, roles),
  );

export function Auth(...roles: string[]) {
  if (roles.length > 0) {
    return applyDecorators(UseGuards(JwtAuthGuard, RolesGuard), SetMetadata(ROLES_KEY, roles));
  }
  return applyDecorators(UseGuards(JwtAuthGuard));
}
