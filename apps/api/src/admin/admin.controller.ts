import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { Auth } from '../common/auth.decorator';
import { normalizeMobile } from '../auth/dto';

@Controller('admin')
@Auth('ADMIN')
export class AdminController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('users')
  async listUsers() {
    return this.prisma.user.findMany({
      include: {
        student: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Post('users')
  async createUser(
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
    const existing = await this.prisma.user.findUnique({ where: { mobile } });
    if (existing) {
      throw new BadRequestException(`A user with mobile ${mobile} already exists`);
    }

    return this.prisma.$transaction(async (tx) => {
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
  }

  @Post('users/:id')
  async updateUser(
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
    },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');

    const data: any = {};
    if (dto.name) data.name = dto.name;
    if (dto.role) data.role = dto.role;
    if (dto.department !== undefined) data.department = dto.department;
    if (dto.status) data.status = dto.status;
    if (dto.mobile) {
      const mobile = normalizeMobile(dto.mobile);
      const conflict = await this.prisma.user.findFirst({
        where: { mobile, NOT: { id } },
      });
      if (conflict) throw new BadRequestException(`Mobile ${mobile} already in use`);
      data.mobile = mobile;
    }

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.user.update({ where: { id }, data });
      if (user.role === 'STUDENT' && (dto.semester !== undefined || dto.tutorId !== undefined)) {
        await tx.student.updateMany({
          where: { userId: id },
          data: {
            ifSemester: dto.semester,
            ifTutorId: dto.tutorId,
          } as any,
        });
      }
      return updated;
    });
  }

  @Post('users/:id/delete')
  async deleteUser(@Param('id') id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    await this.prisma.user.update({
      where: { id },
      data: { status: 'DELETED' },
    });
    return { ok: true };
  }

  @Post('users/bulk')
  async bulkAddUsers(
    @Body() dto: { rows: Array<{ name: string; phone: string; role: string; department: string }> },
  ) {
    let count = 0;
    for (const row of dto.rows || []) {
      try {
        const mobile = normalizeMobile(row.phone);
        const exists = await this.prisma.user.findUnique({ where: { mobile } });
        if (exists) continue;

        await this.prisma.user.create({
          data: {
            name: row.name,
            mobile,
            role: (row.role?.toUpperCase() as any) || 'STUDENT',
            department: row.department || 'CSE',
            status: 'ACTIVE',
          },
        });
        count++;
      } catch (_) {}
    }
    return { count };
  }

  @Get('departments')
  async listDepartments() {
    return this.prisma.department.findMany({
      orderBy: { code: 'asc' },
    });
  }

  @Post('departments')
  async addOrUpdateDepartment(
    @Body() dto: { code: string; name: string; hodId?: string },
  ) {
    return this.prisma.department.upsert({
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
  }

  @Get('outpasses')
  async listOutpasses() {
    return this.prisma.outpassRequest.findMany({
      include: {
        student: {
          include: {
            user: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
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
  async updateSettings(@Body() dto: Record<string, any>) {
    for (const [key, val] of Object.entries(dto)) {
      await this.prisma.appSetting.upsert({
        where: { key },
        update: { value: JSON.stringify(val) },
        create: { key, value: JSON.stringify(val) },
      });
    }
    return { ok: true };
  }
}
