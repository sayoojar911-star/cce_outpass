import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { AuditService } from '../audit/audit.service';
import { Auth } from '../common/auth.decorator';
import { normalizeMobile } from '../auth/dto';

@Controller('admin')
@Auth('ADMIN')
export class AdminController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  @Get('dashboard')
  async getDashboard() {
    const [students, tutors, hods, guards, admins] = await Promise.all([
      this.prisma.user.count({ where: { role: 'STUDENT', status: 'ACTIVE' } }),
      this.prisma.user.count({ where: { role: 'TUTOR', status: 'ACTIVE' } }),
      this.prisma.user.count({ where: { role: 'HOD', status: 'ACTIVE' } }),
      this.prisma.user.count({ where: { role: 'GUARD', status: 'ACTIVE' } }),
      this.prisma.user.count({ where: { role: 'ADMIN', status: 'ACTIVE' } }),
    ]);

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
        STUDENT: students,
        TUTOR: tutors,
        HOD: hods,
        GUARD: guards,
        ADMIN: admins,
        total: students + tutors + hods + guards + admins,
      },
      todayOutpasses: statusCounts,
      recentActivity: recentActivity.map((a) => ({
        ...a,
        id: a.id.toString(),
      })),
    };
  }

  @Get('users')
  async listUsers() {
    return this.prisma.user.findMany({
      include: {
        student: {
          include: {
            tutor: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  private async validateAcademicFields(
    dto: {
      name?: string;
      mobile?: string;
      role: 'STUDENT' | 'TUTOR' | 'HOD' | 'GUARD' | 'ADMIN';
      department?: string | null;
      year?: number | null;
      division?: string | null;
      tutorId?: string | null;
      replaceHod?: boolean;
    },
    existingUserId?: string,
  ) {
    if (dto.name !== undefined && !dto.name?.trim()) {
      throw new BadRequestException('Name is required');
    }

    const role = dto.role;

    if (role === 'GUARD' || role === 'ADMIN') {
      return {
        department: null,
        year: null,
        division: null,
        tutorId: null,
        existingHodToReplace: null,
      };
    }

    if (role === 'HOD') {
      if (!dto.department || !dto.department.trim()) {
        throw new BadRequestException('Department is required for HOD');
      }
      const dept = await this.prisma.department.findFirst({
        where: { code: dto.department.trim().toUpperCase() },
      });
      if (!dept) {
        throw new BadRequestException(`Department ${dto.department} does not exist`);
      }

      // Check single active HOD per department
      const existingHod = await this.prisma.user.findFirst({
        where: {
          role: 'HOD',
          department: dept.code,
          status: 'ACTIVE',
          ...(existingUserId ? { NOT: { id: existingUserId } } : {}),
        },
      });

      if (existingHod) {
        if (!dto.replaceHod) {
          throw new BadRequestException(`${dept.code} already has a HOD: ${existingHod.name}`);
        }
      }

      return {
        department: dept.code,
        year: null,
        division: null,
        tutorId: null,
        existingHodToReplace: existingHod,
      };
    }

    if (role === 'TUTOR' || role === 'STUDENT') {
      if (!dto.department || !dto.department.trim()) {
        throw new BadRequestException(`Department is required for ${role}`);
      }
      const dept = await this.prisma.department.findFirst({
        where: { code: dto.department.trim().toUpperCase() },
        include: { divisions: true },
      });
      if (!dept) {
        throw new BadRequestException(`Department ${dto.department} does not exist`);
      }

      const parsedYear = Number(dto.year);
      if (!parsedYear || parsedYear < 1 || parsedYear > 4) {
        throw new BadRequestException(`Year (1 to 4) is required for ${role}`);
      }

      let division: string | null = null;
      if (dept.divisions.length > 0) {
        if (!dto.division || !dto.division.trim()) {
          throw new BadRequestException(`Division is required for ${dept.code} ${role}`);
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
      if (role === 'STUDENT' && dto.tutorId) {
        const tutor = await this.prisma.user.findFirst({
          where: { id: dto.tutorId, role: 'TUTOR', status: 'ACTIVE' },
        });
        if (!tutor) {
          throw new BadRequestException('Selected tutor is not active or not a TUTOR');
        }
        if (tutor.department !== dept.code) {
          throw new BadRequestException(
            `Tutor belongs to department ${tutor.department}, not ${dept.code}`,
          );
        }
        if (tutor.year !== parsedYear) {
          throw new BadRequestException(
            `Tutor belongs to year ${tutor.year}, not year ${parsedYear}`,
          );
        }
        if (dept.divisions.length > 0 && tutor.division !== division) {
          throw new BadRequestException(
            `Tutor belongs to division ${tutor.division}, not division ${division}`,
          );
        }
        tutorId = tutor.id;
      }

      return {
        department: dept.code,
        year: parsedYear,
        division,
        tutorId,
        existingHodToReplace: null,
      };
    }

    throw new BadRequestException(`Invalid role: ${role}`);
  }

  @Post('users')
  async createUser(
    @Req() req: any,
    @Body()
    dto: {
      name: string;
      mobile: string;
      role: 'STUDENT' | 'TUTOR' | 'HOD' | 'GUARD' | 'ADMIN';
      department?: string;
      year?: number;
      division?: string;
      tutorId?: string;
      registerNo?: string;
      semester?: number;
      replaceHod?: boolean;
    },
  ) {
    if (!dto.name || !dto.name.trim()) {
      throw new BadRequestException('Name is required');
    }
    const mobile = normalizeMobile(dto.mobile);
    if (!/^\d{10}$/.test(mobile)) {
      throw new BadRequestException('Mobile must be exactly 10 digits');
    }

    const existing = await this.prisma.user.findUnique({ where: { mobile } });
    if (existing) {
      throw new BadRequestException(`A user with mobile ${mobile} already exists`);
    }

    const validated = await this.validateAcademicFields(dto);

    const created = await this.prisma.$transaction(async (tx) => {
      if (validated.existingHodToReplace && dto.replaceHod) {
        await tx.user.update({
          where: { id: validated.existingHodToReplace.id },
          data: { status: 'INACTIVE' },
        });
      }

      const user = await tx.user.create({
        data: {
          name: dto.name.trim(),
          mobile,
          role: dto.role,
          department: validated.department,
          year: validated.year,
          division: validated.division,
          status: 'ACTIVE',
        },
      });

      if (dto.role === 'HOD' && validated.department) {
        await tx.department.update({
          where: { code: validated.department },
          data: { hodId: user.id },
        });
      }

      if (dto.role === 'STUDENT') {
        await tx.student.create({
          data: {
            userId: user.id,
            registerNo: dto.registerNo || `CCE${Date.now().toString().slice(-6)}`,
            department: validated.department!,
            year: validated.year!,
            division: validated.division,
            semester: dto.semester || ((validated.year! - 1) * 2 + 1),
            tutorId: validated.tutorId,
          },
        });
      }

      return user;
    });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'USER_CREATED',
      'User',
      created.id,
      { name: created.name, mobile: created.mobile, role: created.role },
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
      role?: 'STUDENT' | 'TUTOR' | 'HOD' | 'GUARD' | 'ADMIN';
      department?: string | null;
      year?: number | null;
      division?: string | null;
      status?: string;
      semester?: number;
      tutorId?: string | null;
      registerNo?: string;
      replaceHod?: boolean;
    },
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: { student: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const effectiveRole = dto.role || user.role;

    // Protect against the admin locking themselves out:
    // the last active admin cannot be deleted, deactivated, or demoted.
    if (user.role === 'ADMIN') {
      const isDemoting = dto.role && dto.role !== 'ADMIN';
      const isDeactivating = dto.status && dto.status !== 'ACTIVE';
      if (isDemoting || isDeactivating) {
        const activeAdminCount = await this.prisma.user.count({
          where: { role: 'ADMIN', status: 'ACTIVE' },
        });
        if (activeAdminCount <= 1) {
          throw new BadRequestException(
            'Cannot deactivate or demote the last active admin',
          );
        }
      }
    }

    let mobile = user.mobile;
    if (dto.mobile) {
      const norm = normalizeMobile(dto.mobile);
      if (!/^\d{10}$/.test(norm)) {
        throw new BadRequestException('Mobile must be exactly 10 digits');
      }
      const conflict = await this.prisma.user.findFirst({
        where: { mobile: norm, NOT: { id } },
      });
      if (conflict) throw new BadRequestException(`Mobile ${norm} already in use`);
      mobile = norm;
    }

    const validated = await this.validateAcademicFields(
      {
        name: dto.name ?? user.name,
        role: effectiveRole,
        department: dto.department !== undefined ? dto.department : user.department,
        year: dto.year !== undefined ? dto.year : user.year,
        division: dto.division !== undefined ? dto.division : user.division,
        tutorId: dto.tutorId !== undefined ? dto.tutorId : user.student?.tutorId,
        replaceHod: dto.replaceHod,
      },
      id,
    );

    const updated = await this.prisma.$transaction(async (tx) => {
      if (validated.existingHodToReplace && dto.replaceHod) {
        await tx.user.update({
          where: { id: validated.existingHodToReplace.id },
          data: { status: 'INACTIVE' },
        });
      }

      // If user was previously HOD of a department and changed role or dept, clear old dept hodId
      if (user.role === 'HOD' && (effectiveRole !== 'HOD' || validated.department !== user.department)) {
        await tx.department.updateMany({
          where: { hodId: id },
          data: { hodId: null },
        });
      }

      const userData: any = {
        name: dto.name ? dto.name.trim() : user.name,
        mobile,
        role: effectiveRole,
        department: validated.department,
        year: validated.year,
        division: validated.division,
      };
      if (dto.status) userData.status = dto.status;

      const u = await tx.user.update({
        where: { id },
        data: userData,
      });

      if (effectiveRole === 'HOD' && validated.department) {
        await tx.department.update({
          where: { code: validated.department },
          data: { hodId: id },
        });
      }

      // Handle student record transitions
      if (effectiveRole === 'STUDENT') {
        if (!user.student) {
          await tx.student.create({
            data: {
              userId: id,
              registerNo: dto.registerNo || `CCE${Date.now().toString().slice(-6)}`,
              department: validated.department!,
              year: validated.year!,
              division: validated.division,
              semester: dto.semester || ((validated.year! - 1) * 2 + 1),
              tutorId: validated.tutorId,
            },
          });
        } else {
          await tx.student.update({
            where: { userId: id },
            data: {
              department: validated.department!,
              year: validated.year!,
              division: validated.division,
              tutorId: validated.tutorId,
              semester: dto.semester ?? user.student.semester,
              registerNo: dto.registerNo ?? user.student.registerNo,
            },
          });
        }
      } else if (user.student) {
        await tx.student.deleteMany({ where: { userId: id } });
      }

      return u;
    });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
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

    if (user.role === 'ADMIN') {
      const activeAdminCount = await this.prisma.user.count({
        where: { role: 'ADMIN', status: 'ACTIVE' },
      });
      if (activeAdminCount <= 1) {
        throw new BadRequestException('Cannot delete the last active admin');
      }
    }

    if (user.role === 'HOD') {
      await this.prisma.department.updateMany({
        where: { hodId: id },
        data: { hodId: null },
      });
    }

    await this.prisma.user.update({
      where: { id },
      data: { status: 'DELETED' },
    });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'USER_DELETED',
      'User',
      id,
      { name: user.name, mobile: user.mobile },
    );

    return { ok: true };
  }

  @Post('users/bulk')
  async bulkAddUsers(
    @Req() req: any,
    @Body() dto: { rows: Array<{ name: string; phone: string; role: string; department: string }> },
  ) {
    let count = 0;
    const errors: Array<{ row: number; error: string }> = [];

    for (let i = 0; i < (dto.rows || []).length; i++) {
      const row = dto.rows[i];
      try {
        const mobile = normalizeMobile(row.phone);
        if (!/^\d{10}$/.test(mobile)) {
          errors.push({ row: i + 1, error: `Invalid mobile number: ${row.phone}` });
          continue;
        }

        const exists = await this.prisma.user.findUnique({ where: { mobile } });
        if (exists) {
          errors.push({ row: i + 1, error: `Mobile ${mobile} already exists` });
          continue;
        }

        const role = (row.role?.toUpperCase() as any) || 'STUDENT';
        await this.prisma.$transaction(async (tx) => {
          const u = await tx.user.create({
            data: {
              name: row.name,
              mobile,
              role,
              department: row.department || 'CSE',
              status: 'ACTIVE',
            },
          });

          if (role === 'STUDENT') {
            await tx.student.create({
              data: {
                userId: u.id,
                registerNo: `CCE${Date.now().toString().slice(-6)}${i}`,
                department: row.department || 'CSE',
                semester: 1,
              },
            });
          }
        });
        count++;
      } catch (err: any) {
        errors.push({ row: i + 1, error: err.message || 'Error creating user' });
      }
    }

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'BULK_USERS_ADDED',
      'User',
      null,
      { addedCount: count, errorsCount: errors.length },
    );

    return { count, errors };
  }

  @Get('departments')
  async listDepartments() {
    return this.prisma.department.findMany({
      include: {
        divisions: {
          orderBy: { name: 'asc' },
        },
      },
      orderBy: { code: 'asc' },
    });
  }

  @Post('departments')
  async addOrUpdateDepartment(
    @Req() req: any,
    @Body() dto: { code: string; name: string; hodId?: string },
  ) {
    const dept = await this.prisma.department.upsert({
      where: { code: dto.code.toUpperCase() },
      update: {
        name: dto.name,
        hodId: dto.hodId,
      },
      create: {
        code: dto.code.toUpperCase(),
        name: dto.name,
        hodId: dto.hodId,
      },
      include: {
        divisions: true,
      },
    });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'DEPARTMENT_SAVED',
      'Department',
      dept.id,
      { code: dept.code, name: dept.name, hodId: dept.hodId },
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

    const existing = await this.prisma.division.findUnique({
      where: {
        departmentId_name: {
          departmentId: dept.id,
          name,
        },
      },
    });
    if (existing) {
      throw new BadRequestException(`Division ${name} already exists for ${dept.code}`);
    }

    const division = await this.prisma.division.create({
      data: {
        name,
        departmentId: dept.id,
      },
    });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'DIVISION_CREATED',
      'Division',
      division.id,
      { department: dept.code, name: division.name },
    );

    return division;
  }

  @Delete('departments/:id/divisions/:divisionId')
  async deleteDivision(
    @Req() req: any,
    @Param('id') id: string,
    @Param('divisionId') divisionId: string,
  ) {
    return this.removeDivision(req, id, divisionId);
  }

  @Post('departments/:id/divisions/:divisionId/delete')
  async postDeleteDivision(
    @Req() req: any,
    @Param('id') id: string,
    @Param('divisionId') divisionId: string,
  ) {
    return this.removeDivision(req, id, divisionId);
  }

  private async removeDivision(req: any, deptId: string, divisionId: string) {
    const dept = await this.prisma.department.findFirst({
      where: { OR: [{ id: deptId }, { code: deptId.toUpperCase() }] },
    });
    if (!dept) throw new NotFoundException('Department not found');

    const division = await this.prisma.division.findFirst({
      where: {
        OR: [{ id: divisionId }, { name: divisionId.toUpperCase() }],
        departmentId: dept.id,
      },
    });
    if (!division) throw new NotFoundException('Division not found');

    const peopleCount = await this.prisma.user.count({
      where: {
        department: dept.code,
        division: division.name,
        status: { not: 'DELETED' },
      },
    });
    if (peopleCount > 0) {
      throw new BadRequestException(
        `Cannot delete division ${division.name}: ${peopleCount} active person(s) assigned to it`,
      );
    }

    await this.prisma.division.delete({
      where: { id: division.id },
    });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'DIVISION_DELETED',
      'Division',
      division.id,
      { department: dept.code, name: division.name },
    );

    return { ok: true };
  }

  @Delete('departments/:id')
  async deleteDepartment(@Req() req: any, @Param('id') id: string) {
    return this.removeDepartment(req, id);
  }

  @Post('departments/:id/delete')
  async postDeleteDepartment(@Req() req: any, @Param('id') id: string) {
    return this.removeDepartment(req, id);
  }

  private async removeDepartment(req: any, id: string) {
    const dept = await this.prisma.department.findFirst({
      where: { OR: [{ id }, { code: id.toUpperCase() }] },
    });
    if (!dept) throw new NotFoundException('Department not found');

    const peopleCount = await this.prisma.user.count({
      where: { department: dept.code, status: { not: 'DELETED' } },
    });
    if (peopleCount > 0) {
      throw new BadRequestException(
        `Cannot delete department ${dept.code}: ${peopleCount} active person(s) belong to it.`,
      );
    }

    await this.prisma.department.delete({ where: { id: dept.id } });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'DEPARTMENT_DELETED',
      'Department',
      dept.id,
      { code: dept.code },
    );

    return { ok: true };
  }

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
        where: { id: dto.tutorId, role: 'TUTOR', status: 'ACTIVE' },
      });
      if (!tutor) {
        throw new BadRequestException('Selected tutor is not active or not a TUTOR');
      }
    }

    const res = await this.prisma.student.updateMany({
      where: { userId: { in: dto.studentIds } },
      data: { tutorId: dto.tutorId },
    });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'TUTORS_ASSIGNED',
      'Student',
      null,
      { count: res.count, tutorId: dto.tutorId, studentIds: dto.studentIds },
    );

    return { count: res.count };
  }

  @Get('outpasses')
  async listOutpasses() {
    return this.prisma.outpassRequest.findMany({
      include: {
        student: {
          include: {
            user: true,
            tutor: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  @Post('outpasses/:id/cancel')
  async cancelOutpass(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto?: { reason?: string },
  ) {
    const outpass = await this.prisma.outpassRequest.findUnique({ where: { id } });
    if (!outpass) throw new NotFoundException('Outpass not found');

    if (['RETURNED', 'CANCELLED', 'REJECTED'].includes(outpass.status)) {
      throw new BadRequestException(`Cannot cancel outpass with status ${outpass.status}`);
    }

    const updated = await this.prisma.outpassRequest.update({
      where: { id },
      data: { status: 'CANCELLED' },
    });

    await this.audit.append(
      req.user?.sub,
      'ADMIN',
      'OUTPASS_CANCELLED_BY_ADMIN',
      'OutpassRequest',
      id,
      { reason: dto?.reason || 'Cancelled by Admin' },
    );

    return updated;
  }

  @Get('settings')
  async getSettings() {
    const settings = await this.prisma.appSetting.findMany();
    const map: Record<string, any> = {
      collegeName: 'Christ College of Engineering, Irinjalakuda',
      minDwellMinutes: 10,
      categories: ['Medical', 'Personal', 'Official', 'Academic', 'Emergency'],
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
      req.user?.sub,
      'ADMIN',
      'SETTINGS_UPDATED',
      'AppSetting',
      null,
      { settings: dto },
    );

    return { ok: true };
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
