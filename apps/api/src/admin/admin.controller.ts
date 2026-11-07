import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  NotFoundException,
  Param,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { RequirePermissions } from '../common/auth.decorator';
import { normalizeMobile } from '../auth/dto';

@Controller('admin')
@RequirePermissions('manageUsers', 'manageRoles', 'manageDepartments', 'manageOutpassConfig')
export class AdminController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  @Get('dashboard')
  async getDashboard() {
    const [totalUsers, activeUsers, roles, departments] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { active: true, status: 'ACTIVE' } }),
      this.prisma.role.findMany({ select: { id: true, name: true } }),
      this.prisma.department.count({ where: { active: true } }),
    ]);

    const roleCounts: Record<string, number> = {};
    for (const r of roles) {
      roleCounts[r.id] = await this.prisma.user.count({
        where: { roleId: r.id, active: true },
      });
    }

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const todayOutpasses = await this.prisma.outpassRequest.findMany({
      where: { createdAt: { gte: todayStart } },
      select: { status: true },
    });

    const statusCounts: Record<string, number> = {};
    for (const o of todayOutpasses) {
      statusCounts[o.status] = (statusCounts[o.status] || 0) + 1;
    }

    const recentActivity = await this.prisma.auditLog.findMany({
      orderBy: { id: 'desc' },
      take: 10,
    });

    return {
      counts: {
        total: totalUsers,
        active: activeUsers,
        roles: roleCounts,
        departments,
      },
      todayOutpasses: statusCounts,
      recentActivity: recentActivity.map((a) => ({
        ...a,
        id: a.id.toString(),
      })),
    };
  }

  // ==========================================
  // USERS MANAGEMENT
  // ==========================================

  @Get('users')
  async listUsers() {
    const users = await this.prisma.user.findMany({
      include: {
        roleRef: true,
        deptRef: true,
        tutor: { select: { id: true, name: true, mobile: true } },
        student: {
          include: { tutor: { select: { id: true, name: true, mobile: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return users.map((u) => ({
      id: u.id,
      name: u.name,
      email: u.email,
      mobile: u.mobile,
      roleId: u.roleId || 'pending',
      role: u.roleRef?.name || u.roleId || 'Pending',
      permissions: u.roleRef?.permissions || [],
      departmentId: u.departmentId,
      department: u.deptRef?.code || u.department || null,
      year: u.year,
      division: u.division,
      tutorId: u.tutorId || u.student?.tutorId,
      tutor: u.tutor || u.student?.tutor,
      active: u.active ?? (u.status === 'ACTIVE'),
      status: u.status,
      createdAt: u.createdAt,
    }));
  }

  private async validateAcademicFields(
    dto: {
      name?: string;
      mobile?: string;
      roleId?: string;
      role?: string;
      department?: string | null;
      departmentId?: string | null;
      year?: number | null;
      division?: string | null;
      tutorId?: string | null;
      replaceHod?: boolean;
    },
    existingUserId?: string,
  ) {
    const roleIdLower = (dto.roleId || '').toLowerCase();
    const roleStr = (dto.role || '').toUpperCase();
    const isHodRole = roleIdLower === 'hod' || roleStr === 'HOD' || roleStr.includes('HEAD OF DEPARTMENT');
    const isGuardRole = roleIdLower === 'guard' || roleStr === 'GUARD' || roleStr.includes('GUARD');
    const isAdminRole = roleIdLower === 'admin' || roleStr === 'ADMIN' || roleStr.includes('ADMIN');
    const isTutorRole = roleIdLower === 'tutor' || roleStr === 'TUTOR' || roleStr.includes('TUTOR');
    const isStudentRole = roleIdLower === 'student' || roleStr === 'STUDENT' || roleStr.includes('STUDENT');
    const rawRole = isStudentRole ? 'STUDENT' : isTutorRole ? 'TUTOR' : isHodRole ? 'HOD' : (dto.role || dto.roleId || '').toUpperCase();

    if (isGuardRole || isAdminRole) {
      return {
        department: null,
        departmentId: null,
        year: null,
        division: null,
        tutorId: null,
        existingHodToReplace: null,
      };
    }

    if (isHodRole) {
      const deptCode = dto.department?.trim()?.toUpperCase();
      if (!deptCode && !dto.departmentId) {
        throw new BadRequestException('Department is required for HOD');
      }
      const dept = await this.prisma.department.findFirst({
        where: dto.departmentId
          ? { id: dto.departmentId }
          : { code: deptCode },
      });
      if (!dept) {
        throw new BadRequestException(`Department ${dto.department || dto.departmentId} does not exist`);
      }

      // Ignore inactive, deactive, or deleted users when checking existing HOD
      const existingHod = await this.prisma.user.findFirst({
        where: {
          OR: [
            { roleId: 'hod' },
            { role: 'HOD' },
            { role: { contains: 'HOD', mode: 'insensitive' } },
            { role: { contains: 'Head of Department', mode: 'insensitive' } },
            ...(dept.hodUserId ? [{ id: dept.hodUserId }] : []),
          ],
          department: dept.code,
          active: true,
          status: 'ACTIVE',
          ...(existingUserId ? { NOT: { id: existingUserId } } : {}),
        },
      });

      if (existingHod && !dto.replaceHod) {
        throw new BadRequestException(`${dept.code} already has an HOD: ${existingHod.name} (ACTIVE)`);
      }

      return {
        department: dept.code,
        departmentId: dept.id,
        year: null,
        division: null,
        tutorId: null,
        existingHodToReplace: existingHod,
      };
    }

    if (isTutorRole || isStudentRole) {
      const deptCode = dto.department?.trim()?.toUpperCase();
      if (!deptCode && !dto.departmentId) {
        throw new BadRequestException(`Department is required for ${rawRole}`);
      }
      const dept = await this.prisma.department.findFirst({
        where: dto.departmentId
          ? { id: dto.departmentId }
          : { code: deptCode },
        include: { divisions: true },
      });
      if (!dept) {
        throw new BadRequestException(`Department ${dto.department || dto.departmentId} does not exist`);
      }

      const parsedYear = Number(dto.year);
      if (!parsedYear || parsedYear < 1 || parsedYear > 4) {
        throw new BadRequestException(`Year (1 to 4) is required for ${rawRole}`);
      }

      let division: string | null = null;
      if (dept.divisions && dept.divisions.length > 0) {
        if (!dto.division || !dto.division.trim()) {
          throw new BadRequestException(`Division is required for ${dept.code} ${rawRole}`);
        }
        const match = dept.divisions.find(
          (d) => d.name.toUpperCase() === dto.division!.trim().toUpperCase(),
        );
        if (!match) {
          throw new BadRequestException(
            `Division ${dto.division} does not belong to ${dept.code}`,
          );
        }
        division = match.name;
      }

      let tutorId: string | null = null;
      const cleanTutorId =
        typeof dto.tutorId === 'string' && dto.tutorId.trim().length > 0
          ? dto.tutorId.trim()
          : null;
      if (rawRole === 'STUDENT' && cleanTutorId) {
        const tutor = await this.prisma.user.findFirst({
          where: { id: cleanTutorId, active: true },
          include: { roleRef: true },
        });
        if (!tutor) {
          throw new BadRequestException('Selected tutor is not active or does not exist');
        }
        if (tutor.department && tutor.department !== dept.code) {
          throw new BadRequestException(
            `Tutor belongs to department ${tutor.department}, not ${dept.code}`,
          );
        }
        if (tutor.year && tutor.year !== parsedYear) {
          throw new BadRequestException(
            `Tutor belongs to year ${tutor.year}, not year ${parsedYear}`,
          );
        }
        if (dept.divisions && dept.divisions.length > 0 && tutor.division && tutor.division !== division) {
          throw new BadRequestException(
            `Tutor belongs to division ${tutor.division}, not division ${division}`,
          );
        }
        tutorId = tutor.id;
      }

      return {
        department: dept.code,
        departmentId: dept.id,
        year: parsedYear,
        division,
        tutorId,
        existingHodToReplace: null,
      };
    }

    return {
      department: dto.department || null,
      departmentId: dto.departmentId || null,
      year: dto.year || null,
      division: dto.division || null,
      tutorId: dto.tutorId || null,
      existingHodToReplace: null,
    };
  }

  @Post('users')
  async createUser(
    @Req() req: any,
    @Body()
    dto: {
      name: string;
      mobile: string;
      email?: string;
      roleId?: string;
      role?: string;
      departmentId?: string | null;
      department?: string | null;
      year?: number | null;
      division?: string | null;
      tutorId?: string | null;
      registerNo?: string;
      semester?: number;
      replaceHod?: boolean;
      active?: boolean;
    },
  ) {
    const name = dto.name?.trim();
    if (!name) throw new BadRequestException('Name is required');

    const mobile = normalizeMobile(dto.mobile);
    if (!/^\d{10}$/.test(mobile)) {
      throw new BadRequestException('Mobile must be exactly 10 digits');
    }

    const exists = await this.prisma.user.findUnique({ where: { mobile } });
    if (exists) {
      throw new ConflictException(`A user with mobile ${mobile} already exists`);
    }

    const targetRoleId = (dto.roleId || dto.role?.toLowerCase() || 'pending').trim();

    // Validate role exists or lookup case-insensitively
    let role = await this.prisma.role.findUnique({ where: { id: targetRoleId } });
    if (!role && dto.role) {
      role = await this.prisma.role.findFirst({
        where: {
          OR: [
            { id: { equals: dto.role.toLowerCase() } },
            { name: { equals: dto.role, mode: 'insensitive' } },
          ],
        },
      });
    }
    if (!role) {
      throw new BadRequestException(`Role ID "${targetRoleId}" does not exist`);
    }

    const validated = await this.validateAcademicFields(dto);

    const created = await this.prisma.$transaction(async (tx) => {
      if (validated.existingHodToReplace && dto.replaceHod) {
        await tx.user.update({
          where: { id: validated.existingHodToReplace.id },
          data: { status: 'INACTIVE', active: false },
        });
      }

      const u = await tx.user.create({
        data: {
          name,
          mobile,
          email: dto.email?.trim() || null,
          roleId: role.id,
          role: dto.role || role.id.toUpperCase(),
          departmentId: validated.departmentId || null,
          department: validated.department || null,
          year: validated.year || null,
          division: validated.division?.trim() || null,
          tutorId: validated.tutorId || null,
          active: dto.active !== false,
          status: dto.active === false ? 'DEACTIVATED' : 'ACTIVE',
        },
        include: { roleRef: true, deptRef: true, tutor: true },
      });

      const isNewHod = role.id === 'hod' || (dto.role || '').toUpperCase().includes('HOD') || (dto.role || '').toUpperCase().includes('HEAD OF DEPARTMENT');
      if (isNewHod && (validated.department || validated.departmentId)) {
        await tx.department.updateMany({
          where: {
            OR: [
              ...(validated.departmentId ? [{ id: validated.departmentId }] : []),
              ...(validated.department ? [{ code: validated.department }] : []),
            ],
          },
          data: { hodId: u.id, hodUserId: u.id },
        });
      }

      // Maintain Student row if student permission exists
      if (role.permissions.includes('createOutpass') || dto.role === 'STUDENT' || role.id === 'student') {
        await tx.student.create({
          data: {
            userId: u.id,
            registerNo: dto.registerNo || `REG-${mobile.slice(-4)}-${Date.now().toString().slice(-4)}`,
            department: validated.department || 'GENERAL',
            semester: dto.semester || (validated.year ? (validated.year - 1) * 2 + 1 : 1),
            year: validated.year || null,
            division: validated.division?.trim() || null,
            tutorId: validated.tutorId || null,
          },
        });
      }

      return u;
    });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'USER_CREATED',
      'User',
      created.id,
      { name, mobile, roleId: role.id, departmentId: validated.departmentId },
    );

    return created;
  }

  @Post('users/:id')
  async updateUser(
    @Req() req: any,
    @Param('id') id: string,
    @Body()
    dto: {
      name?: string;
      mobile?: string;
      email?: string;
      roleId?: string;
      role?: string;
      departmentId?: string | null;
      department?: string | null;
      year?: number | null;
      division?: string | null;
      tutorId?: string | null;
      active?: boolean;
    },
  ) {
    const existing = await this.prisma.user.findUnique({
      where: { id },
      include: { roleRef: true },
    });
    if (!existing) throw new NotFoundException('User not found');

    const effectiveRoleId = dto.roleId || (dto.role ? dto.role.toLowerCase() : undefined);

    // Rule: Users must not be able to change their own role
    if (
      req.user?.userId === id &&
      effectiveRoleId !== undefined &&
      effectiveRoleId !== existing.roleId
    ) {
      throw new ForbiddenException('Users are not permitted to modify their own role');
    }

    // Rule: Prevent removing the last admin
    if (
      existing.roleId === 'admin' &&
      ((effectiveRoleId !== undefined && effectiveRoleId !== 'admin') || dto.active === false)
    ) {
      const activeAdminCount = await this.prisma.user.count({
        where: { roleId: 'admin', active: true, status: 'ACTIVE' },
      });
      if (activeAdminCount <= 1) {
        throw new BadRequestException('Cannot demote or deactivate the last active administrator');
      }
    }

    // Resolve department
    let departmentId = dto.departmentId !== undefined ? dto.departmentId : existing.departmentId;
    let deptCode = dto.department !== undefined ? dto.department : existing.department;
    if (dto.departmentId) {
      const d = await this.prisma.department.findUnique({ where: { id: dto.departmentId } });
      if (d) deptCode = d.code;
    } else if (dto.department) {
      const d = await this.prisma.department.findUnique({ where: { code: dto.department } });
      if (d) departmentId = d.id;
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      let roleName = existing.role;
      if (effectiveRoleId) {
        const role = await tx.role.findUnique({ where: { id: effectiveRoleId } });
        if (role) roleName = role.name;
      }

      const u = await tx.user.update({
        where: { id },
        data: {
          name: dto.name !== undefined ? dto.name.trim() : undefined,
          mobile: dto.mobile !== undefined ? normalizeMobile(dto.mobile) : undefined,
          email: dto.email !== undefined ? (dto.email.trim() || null) : undefined,
          roleId: effectiveRoleId !== undefined ? effectiveRoleId : undefined,
          role: roleName,
          departmentId: departmentId || null,
          department: deptCode || null,
          year: dto.year !== undefined ? dto.year : undefined,
          division: dto.division !== undefined ? (dto.division?.trim() || null) : undefined,
          tutorId: dto.tutorId !== undefined ? (dto.tutorId || null) : undefined,
          active: dto.active !== undefined ? dto.active : undefined,
          status: dto.active === false ? 'DEACTIVATED' : 'ACTIVE',
        },
        include: { roleRef: true, deptRef: true, tutor: true },
      });

      // Update Student row if exists
      const student = await tx.student.findUnique({ where: { userId: id } });
      if (student) {
        await tx.student.update({
          where: { userId: id },
          data: {
            department: deptCode || student.department,
            year: dto.year !== undefined ? dto.year : student.year,
            division: dto.division !== undefined ? (dto.division?.trim() || null) : student.division,
            tutorId: dto.tutorId !== undefined ? (dto.tutorId || null) : student.tutorId,
          },
        });
      } else if (dto.roleId === 'student') {
        await tx.student.create({
          data: {
            userId: id,
            registerNo: `REG-${u.mobile.slice(-4)}`,
            department: deptCode || 'GENERAL',
            semester: dto.year ? dto.year * 2 - 1 : 1,
            year: dto.year || null,
            division: dto.division?.trim() || null,
            tutorId: dto.tutorId || null,
          },
        });
      }

      const safeRoleUpper = (roleName ?? '').toUpperCase();
      const isUpdatedHod = (effectiveRoleId || existing.roleId) === 'hod' || safeRoleUpper.includes('HOD') || safeRoleUpper.includes('HEAD OF DEPARTMENT');
      if (isUpdatedHod && (deptCode || departmentId)) {
        await tx.department.updateMany({
          where: {
            OR: [
              ...(departmentId ? [{ id: departmentId }] : []),
              ...(deptCode ? [{ code: deptCode }] : []),
            ],
          },
          data: { hodId: u.id, hodUserId: u.id },
        });
      }

      return u;
    });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'USER_UPDATED',
      'User',
      id,
      { changes: dto },
    );

    return updated;
  }

  @Post('users/:id/delete')
  async deleteUser(@Req() req: any, @Param('id') id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');

    if (user.roleId === 'admin') {
      const activeAdminCount = await this.prisma.user.count({
        where: { roleId: 'admin', active: true, status: 'ACTIVE' },
      });
      if (activeAdminCount <= 1) {
        throw new BadRequestException('Cannot delete the last active administrator');
      }
    }

    await this.prisma.user.update({
      where: { id },
      data: { active: false, status: 'DELETED' },
    });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'USER_DELETED',
      'User',
      id,
      { name: user.name, mobile: user.mobile },
    );

    return { ok: true };
  }

  // ==========================================
  // ROLES & PERMISSIONS MANAGEMENT
  // ==========================================

  @Get('roles')
  async listRoles() {
    const roles = await this.prisma.role.findMany({
      include: {
        _count: { select: { users: true } },
      },
      orderBy: { name: 'asc' },
    });

    return roles.map((r) => ({
      id: r.id,
      name: r.name,
      description: r.description,
      permissions: r.permissions,
      isSystem: r.isSystem,
      active: r.active,
      userCount: r._count.users,
      createdAt: r.createdAt,
    }));
  }

  @Post('roles')
  async createRole(
    @Req() req: any,
    @Body()
    dto: {
      id?: string;
      name: string;
      description?: string;
      permissions: string[];
    },
  ) {
    const name = dto.name?.trim();
    if (!name) throw new BadRequestException('Role name is required');

    const id = (dto.id?.trim() || name.toLowerCase().replace(/[^a-z0-9_-]/g, '-')).trim();

    const exists = await this.prisma.role.findUnique({ where: { id } });
    if (exists) {
      throw new ConflictException(`Role with ID "${id}" already exists`);
    }

    const created = await this.prisma.role.create({
      data: {
        id,
        name,
        description: dto.description?.trim() || null,
        permissions: Array.isArray(dto.permissions) ? dto.permissions : [],
        isSystem: false,
        active: true,
      },
    });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'ROLE_CREATED',
      'Role',
      created.id,
      { name, permissions: dto.permissions },
    );

    return created;
  }

  @Post('roles/:id')
  async updateRole(
    @Req() req: any,
    @Param('id') id: string,
    @Body()
    dto: {
      name?: string;
      description?: string;
      permissions?: string[];
      active?: boolean;
    },
  ) {
    const role = await this.prisma.role.findUnique({ where: { id } });
    if (!role) throw new NotFoundException('Role not found');

    if (role.id === 'admin') {
      if (dto.active === false) {
        throw new BadRequestException('The System Administrator role cannot be disabled');
      }
      if (dto.permissions && !dto.permissions.includes('manageRoles')) {
        throw new BadRequestException('The System Administrator role must retain manageRoles permission');
      }
    }

    const updated = await this.prisma.role.update({
      where: { id },
      data: {
        name: dto.name !== undefined ? dto.name.trim() : undefined,
        description: dto.description !== undefined ? (dto.description?.trim() || null) : undefined,
        permissions: dto.permissions !== undefined ? dto.permissions : undefined,
        active: dto.active !== undefined ? dto.active : undefined,
      },
    });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'ROLE_UPDATED',
      'Role',
      id,
      { changes: dto },
    );

    return updated;
  }

  @Delete('roles/:id')
  async deleteRole(@Req() req: any, @Param('id') id: string) {
    return this.removeRole(req, id);
  }

  @Post('roles/:id/delete')
  async postDeleteRole(@Req() req: any, @Param('id') id: string) {
    return this.removeRole(req, id);
  }

  private async removeRole(req: any, id: string) {
    const role = await this.prisma.role.findUnique({ where: { id } });
    if (!role) throw new NotFoundException('Role not found');

    if (role.isSystem || role.id === 'admin') {
      throw new BadRequestException('System protected roles cannot be deleted');
    }

    const assignedCount = await this.prisma.user.count({
      where: { roleId: id, active: true },
    });
    if (assignedCount > 0) {
      throw new BadRequestException(
        `Cannot delete role "${role.name}": ${assignedCount} active user(s) currently hold this role`,
      );
    }

    await this.prisma.role.delete({ where: { id } });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'ROLE_DELETED',
      'Role',
      id,
      { name: role.name },
    );

    return { ok: true };
  }

  // ==========================================
  // DEPARTMENTS & HOD MANAGEMENT
  // ==========================================

  @Get('departments')
  async listDepartments() {
    return this.prisma.department.findMany({
      include: {
        divisions: { orderBy: { name: 'asc' } },
        hodUser: { select: { id: true, name: true, mobile: true } },
      },
      orderBy: { code: 'asc' },
    });
  }

  @Post('departments')
  async addOrUpdateDepartment(
    @Req() req: any,
    @Body() dto: { id?: string; code: string; name: string; hodUserId?: string | null },
  ) {
    const code = dto.code.trim().toUpperCase();
    const name = dto.name.trim();
    if (!code || !name) throw new BadRequestException('Department code and name are required');

    let dept = await this.prisma.department.findFirst({
      where: { OR: [{ code }, ...(dto.id ? [{ id: dto.id }] : [])] },
    });

    if (dept) {
      dept = await this.prisma.department.update({
        where: { id: dept.id },
        data: {
          code,
          name,
          hodUserId: dto.hodUserId || null,
          hodId: dto.hodUserId || null,
        },
        include: { divisions: true, hodUser: true },
      });
    } else {
      dept = await this.prisma.department.create({
        data: {
          code,
          name,
          hodUserId: dto.hodUserId || null,
          hodId: dto.hodUserId || null,
        },
        include: { divisions: true, hodUser: true },
      });
    }

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'DEPARTMENT_SAVED',
      'Department',
      dept.id,
      { code, name, hodUserId: dto.hodUserId },
    );

    return dept;
  }

  @Post('departments/:id/divisions')
  async addDivision(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: { name: string },
  ) {
    const dept = await this.prisma.department.findFirst({
      where: { OR: [{ id }, { code: id.toUpperCase() }] },
    });
    if (!dept) throw new NotFoundException('Department not found');

    const name = (dto.name || '').trim().toUpperCase();
    if (!name) throw new BadRequestException('Division name is required');

    const division = await this.prisma.division.upsert({
      where: {
        departmentId_name: {
          departmentId: dept.id,
          name,
        },
      },
      update: {},
      create: {
        departmentId: dept.id,
        name,
      },
    });

    return division;
  }

  @Post('departments/:id/divisions/:divisionId/delete')
  async deleteDivision(
    @Req() req: any,
    @Param('id') id: string,
    @Param('divisionId') divisionId: string,
  ) {
    const dept = await this.prisma.department.findFirst({
      where: { OR: [{ id }, { code: id.toUpperCase() }] },
    });
    if (!dept) throw new NotFoundException('Department not found');

    const division = await this.prisma.division.findFirst({
      where: {
        OR: [{ id: divisionId }, { name: divisionId.toUpperCase() }],
        departmentId: dept.id,
      },
    });
    if (!division) throw new NotFoundException('Division not found');

    await this.prisma.division.delete({ where: { id: division.id } });
    return { ok: true };
  }

  @Post('departments/:id/delete')
  async deleteDepartment(@Req() req: any, @Param('id') id: string) {
    const dept = await this.prisma.department.findFirst({
      where: { OR: [{ id }, { code: id.toUpperCase() }] },
    });
    if (!dept) throw new NotFoundException('Department not found');

    const count = await this.prisma.user.count({
      where: { departmentId: dept.id, active: true },
    });
    if (count > 0) {
      throw new BadRequestException(
        `Cannot delete department ${dept.code}: ${count} active user(s) assigned to it.`,
      );
    }

    await this.prisma.department.delete({ where: { id: dept.id } });
    return { ok: true };
  }

  // ==========================================
  // PURPOSE CATEGORIES MANAGEMENT
  // ==========================================

  @Get('purpose-categories')
  async listPurposeCategories() {
    return this.prisma.purposeCategory.findMany({
      orderBy: { label: 'asc' },
    });
  }

  @Post('purpose-categories')
  async savePurposeCategory(
    @Req() req: any,
    @Body() dto: { id?: string; label: string; active?: boolean },
  ) {
    const label = dto.label?.trim();
    if (!label) throw new BadRequestException('Category label is required');

    let cat;
    if (dto.id) {
      cat = await this.prisma.purposeCategory.update({
        where: { id: dto.id },
        data: { label, active: dto.active !== false },
      });
    } else {
      cat = await this.prisma.purposeCategory.upsert({
        where: { label },
        update: { active: dto.active !== false },
        create: { label, active: dto.active !== false },
      });
    }

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'PURPOSE_CATEGORY_SAVED',
      'PurposeCategory',
      cat.id,
      { label, active: cat.active },
    );

    return cat;
  }

  @Post('purpose-categories/:id/delete')
  async deletePurposeCategory(@Req() req: any, @Param('id') id: string) {
    await this.prisma.purposeCategory.delete({ where: { id } });
    return { ok: true };
  }

  // ==========================================
  // OUTPASS TYPES & APPROVAL CHAINS
  // ==========================================

  @Get('outpass-types')
  async listOutpassTypes() {
    return this.prisma.outpassTypeConfig.findMany({
      orderBy: { label: 'asc' },
    });
  }

  @Post('outpass-types')
  async saveOutpassType(
    @Req() req: any,
    @Body()
    dto: {
      id?: string;
      label: string;
      approvalChain: string[];
      active?: boolean;
    },
  ) {
    const label = dto.label?.trim();
    if (!label) throw new BadRequestException('Type label is required');

    if (!Array.isArray(dto.approvalChain) || dto.approvalChain.length === 0) {
      throw new BadRequestException('Approval chain must contain at least one role ID in sequence');
    }

    // Verify all roles in chain exist
    const roles = await this.prisma.role.findMany({
      where: { id: { in: dto.approvalChain } },
    });
    const foundIds = roles.map((r) => r.id);
    const missing = dto.approvalChain.filter((r) => !foundIds.includes(r));
    if (missing.length > 0) {
      throw new BadRequestException(`Role(s) in approval chain do not exist: ${missing.join(', ')}`);
    }

    const typeId = (dto.id || '').toLowerCase().trim();
    if (!typeId || !['normal', 'emergency'].includes(typeId)) {
      throw new BadRequestException(
        'Outpass types are restricted to exactly "normal" and "emergency". Adding new types is not permitted.',
      );
    }

    const outpassType = await this.prisma.outpassTypeConfig.update({
      where: { id: typeId },
      data: {
        label,
        approvalChain: dto.approvalChain,
        active: dto.active !== false,
      },
    });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'OUTPASS_TYPE_SAVED',
      'OutpassTypeConfig',
      outpassType.id,
      { label, approvalChain: dto.approvalChain },
    );

    return outpassType;
  }

  @Post('outpass-types/:id/delete')
  async deleteOutpassType(@Req() req: any, @Param('id') id: string) {
    throw new BadRequestException(
      'Default outpass types ("normal" and "emergency") cannot be deleted. You may disable them by updating their active status.',
    );
  }

  // ==========================================
  // SETTINGS MANAGEMENT
  // ==========================================

  @Get('settings')
  async getSettings() {
    const settings = await this.prisma.appSetting.findMany();
    const map: Record<string, any> = {
      collegeName: 'Christ College of Engineering, Irinjalakuda',
      minDwellMinutes: 10,
      defaultDurationHours: 3,
      defaultRoleId: 'pending',
      allowedStartTime: '06:00',
      allowedEndTime: '21:00',
    };
    for (const s of settings) {
      try {
        map[s.key] = JSON.parse(s.value);
      } catch (_) {
        map[s.key] = s.value;
      }
    }
    return map;
  }

  @Post('settings')
  async updateSettings(@Req() req: any, @Body() dto: Record<string, any>) {
    for (const [key, val] of Object.entries(dto)) {
      await this.prisma.appSetting.upsert({
        where: { key },
        update: { value: JSON.stringify(val) },
        create: { key, value: JSON.stringify(val) },
      });
    }

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'SETTINGS_UPDATED',
      'AppSetting',
      null,
      { settings: dto },
    );

    return { ok: true };
  }

  // ==========================================
  // TUTOR ASSIGNMENT & PASSES AUDIT
  // ==========================================

  @Post('tutors/assign')
  async assignTutors(
    @Req() req: any,
    @Body() dto: { studentIds: string[]; tutorId: string | null },
  ) {
    if (!dto.studentIds || dto.studentIds.length === 0) {
      throw new BadRequestException('studentIds must be provided');
    }

    if (dto.tutorId) {
      const tutor = await this.prisma.user.findFirst({
        where: { id: dto.tutorId, active: true },
        include: { roleRef: true },
      });
      if (!tutor) {
        throw new BadRequestException('Selected tutor is not active or does not exist');
      }
    }

    const res = await this.prisma.user.updateMany({
      where: { id: { in: dto.studentIds } },
      data: { tutorId: dto.tutorId },
    });

    await this.prisma.student.updateMany({
      where: { userId: { in: dto.studentIds } },
      data: { tutorId: dto.tutorId },
    });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'TUTORS_ASSIGNED',
      'User',
      null,
      { count: res.count, tutorId: dto.tutorId, studentIds: dto.studentIds },
    );

    return { count: res.count };
  }

  @Get('outpasses')
  async listOutpasses() {
    const outpasses = await this.prisma.outpassRequest.findMany({
      include: {
        student: { include: { user: true, tutor: true } },
        studentUser: { select: { id: true, name: true, mobile: true, department: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return outpasses.map((o) => ({
      ...o,
      lastTokenTs: Number(o.lastTokenTs),
    }));
  }

  @Post('outpasses/:id/cancel')
  async cancelOutpass(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto?: { reason?: string },
  ) {
    const outpass = await this.prisma.outpassRequest.findUnique({
      where: { id },
      include: {
        student: { include: { user: true } },
        approvals: true,
      },
    });
    if (!outpass) throw new NotFoundException('Outpass not found');

    if (outpass.status === 'CANCELLED') {
      throw new ConflictException('Outpass is already cancelled');
    }
    if (outpass.status === 'RETURNED') {
      throw new ConflictException('Cannot cancel outpass after return has been recorded');
    }
    if (outpass.status === 'REJECTED') {
      throw new ConflictException('Cannot cancel a rejected outpass');
    }
    if (outpass.status !== 'OVERDUE' && (outpass.exitAt != null || outpass.status === 'EXITED')) {
      throw new ConflictException('Cannot cancel outpass after campus exit has been recorded');
    }

    const cancellableStatuses = ['PENDING', 'PENDING_TUTOR', 'PENDING_HOD', 'APPROVED', 'OVERDUE', 'EXPIRED'];
    if (!cancellableStatuses.includes(outpass.status)) {
      throw new ConflictException(
        `Outpass can no longer be cancelled (current status: ${outpass.status})`,
      );
    }

    const now = new Date();
    const reason = dto?.reason || 'Cancelled by Admin';

    const updated = await this.prisma.$transaction(async (tx) => {
      const updateResult = await tx.outpassRequest.updateMany({
        where: {
          id,
          status: { in: ['PENDING', 'PENDING_TUTOR', 'PENDING_HOD', 'APPROVED', 'OVERDUE', 'EXPIRED'] },
          OR: [
            { status: 'OVERDUE' },
            { exitAt: null },
          ],
        },
        data: {
          status: 'CANCELLED',
          cancelledAt: now,
          cancelledBy: req.user?.userId || 'admin',
          cancelReason: reason,
          version: { increment: 1 },
        },
      });

      if (updateResult.count === 0) {
        const fresh = await tx.outpassRequest.findUnique({ where: { id } });
        if (!fresh) throw new NotFoundException('Outpass not found');
        if (fresh.status === 'CANCELLED') throw new ConflictException('Outpass is already cancelled');
        if (fresh.status === 'RETURNED') {
          throw new ConflictException('Cannot cancel outpass after return has been recorded');
        }
        if (fresh.status !== 'OVERDUE' && (fresh.exitAt != null || fresh.status === 'EXITED')) {
          throw new ConflictException('Cannot cancel outpass after campus exit has been recorded');
        }
        throw new ConflictException(`Outpass can no longer be cancelled (current status: ${fresh.status})`);
      }

      return tx.outpassRequest.findUniqueOrThrow({ where: { id } });
    });

    await this.audit.append(
      req.user?.userId,
      req.user?.roleId || 'admin',
      'OUTPASS_CANCELLED_BY_ADMIN',
      'OutpassRequest',
      id,
      {
        reason,
        previousStatus: outpass.status,
        cancelledAt: now.toISOString(),
      },
    );

    return { ...updated, lastTokenTs: Number(updated.lastTokenTs) };
  }

  @Get('audit')
  async listAudit(@Query('limit') limit?: string, @Query('offset') offset?: string) {
    const take = Math.min(Number(limit) || 50, 100);
    const skip = Number(offset) || 0;
    const logs = await this.prisma.auditLog.findMany({
      orderBy: { id: 'desc' },
      take,
      skip,
    });

    return logs.map((l) => ({
      ...l,
      id: l.id.toString(),
    }));
  }
}
