import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';

export interface AuthUser {
  userId: string;
  roleId: string;
  role: string;
  permissions: string[];
  name: string;
  mobile: string;
  departmentId?: string | null;
  department?: string | null;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request & Record<string, any>>();
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) throw new UnauthorizedException('Missing bearer token');
    try {
      const payload = await this.jwt.verifyAsync(token);
      const userObj: any = {
        userId: payload.sub,
        role: payload.role || payload.roleId || 'PENDING',
        name: payload.name || '',
        mobile: payload.mobile || '',
      };
      if (payload.roleId !== undefined) userObj.roleId = payload.roleId;
      if (payload.permissions !== undefined) userObj.permissions = payload.permissions;
      if (payload.departmentId !== undefined) userObj.departmentId = payload.departmentId;
      if (payload.department !== undefined) userObj.department = payload.department;

      req['user'] = userObj as AuthUser;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
