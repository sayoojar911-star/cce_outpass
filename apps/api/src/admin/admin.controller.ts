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

  @Post('users')
  async createUser(
    @Req() req: any,
    @Body()
    dto: {
      name: string;
      mobile: string;
      role: 'STUDENT' | 'TUTOR' | 'HOD' | 'GUARD' | 'ADMIN';
      department?: string;
      registerNo?: string;
      semester?: number;
      tutorId?: string;
    },
  ) {
    const mobile = normalizeMobile(dto.mobile);
    if (!/^\d{10}$/.test(mobile)) {
      throw new BadRequestException('Mobile must be exactly 10 digits');
    }

    const existing = await this.prisma.user.findUnique({ where: { mobile } });
    if (existing) {
      throw new BadRequestException(`A user with mobile ${mobile} already exists`);
    }

    const created = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          name: dto.name,
          mobile,
          role: dto.role,
          department: dto.department,
          status: 'ACTIVE',
        },
      });

      if (dto.role === 'STUDENT') {
        await tx.student.create({
          data: {
            userId: user.id,
            registerNo: dto.registerNo || `CCE${Date.now().toString().slice(-6)}`,
            department: dto.department || 'CSE',
            semester: dto.semester || 1,
            tutorId: dto.tutorId,
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
      department?: string;
      status?: string;
      semester?: number;
      tutorId?: string;
      registerNo?: string;
    },
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: { student: true },
    });
    if (!user) throw new NotFoundException('User not found');

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

    const data: any = {};
    if (dto.name) data.name = dto.name;
    if (dto.role) data.role = dto.role;
    if (dto.department !== undefined) data.department = dto.department;
    if (dto.status) data.status = dto.status;
    if (dto.mobile) {
      const mobile = normalizeMobile(dto.mobile);
      if (!/^\d{10}$/.test(mobile)) {
        throw new BadRequestException('Mobile must be exactly 10 digits');
      }
      const conflict = await this.prisma.user.findFirst({
        where: { mobile, NOT: { id } },
      });
      if (conflict) throw new BadRequestException(`Mobile ${mobile} already in use`);
      data.mobile = mobile;
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const u = await tx.user.update({ where: { id }, data });

      // Handle transition to STUDENT role
      if (dto.role === 'STUDENT' && !user.student) {
        await tx.student.create({
          data: {
            userId: id,
            registerNo: dto.registerNo || `CCE${Date.now().toString().slice(-6)}`,
            department: dto.department || user.department || 'CSE',
            semester: dto.semester || 1,
            tutorId: dto.tutorId,
          },
        });
      } else if (u.role === 'STUDENT' && user.student) {
        const studentUpdate: any = {};
        if (dto.semester !== undefined) studentUpdate.semester = dto.semester;
        if (dto.tutorId !== undefined) studentUpdate.tutorId = dto.tutorId;
        if (dto.registerNo !== undefined) studentUpdate.registerNo = dto.registerNo;
        if (dto.department !== undefined) studentUpdate.department = dto.department;
        if (Object.keys(studentUpdate).length > 0) {
          await tx.student.update({
            where: { userId: id },
            data: studentUpdate,
          });
        }
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
