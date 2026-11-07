import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class ConfigService {
  constructor(private readonly prisma: PrismaService) {}

  async getRoles() {
    return this.prisma.role.findMany({
      where: { active: true },
      orderBy: { name: 'asc' },
    });
  }

  async getDepartments() {
    return this.prisma.department.findMany({
      where: { active: true },
      include: {
        divisions: { orderBy: { name: 'asc' } },
        hodUser: { select: { id: true, name: true, mobile: true } },
      },
      orderBy: { name: 'asc' },
    });
  }

  async getPurposeCategories() {
    return this.prisma.purposeCategory.findMany({
      where: { active: true },
      orderBy: { label: 'asc' },
    });
  }

  async getOutpassTypes() {
    return this.prisma.outpassTypeConfig.findMany({
      where: { active: true },
      orderBy: { label: 'asc' },
    });
  }

  async getSettings() {
    const rows = await this.prisma.appSetting.findMany();
    const map: Record<string, any> = {
      collegeName: 'Christ College of Engineering, Irinjalakuda',
      minDwellMinutes: 10,
      defaultDurationHours: 3,
      defaultRoleId: 'pending',
      allowedStartTime: '06:00',
      allowedEndTime: '21:00',
    };
    for (const r of rows) {
      try {
        map[r.key] = JSON.parse(r.value);
      } catch (_) {
        map[r.key] = r.value;
      }
    }
    return map;
  }

  async getAllConfig() {
    const [roles, departments, categories, outpassTypes, settings] = await Promise.all([
      this.getRoles(),
      this.getDepartments(),
      this.getPurposeCategories(),
      this.getOutpassTypes(),
      this.getSettings(),
    ]);

    return {
      roles,
      departments,
      categories,
      purposeCategories: categories,
      outpassTypes,
      settings,
    };
  }
}
