import { Controller, Get, UseGuards } from '@nestjs/common';
import { ConfigService } from './config.service';
import { JwtAuthGuard } from '../common/jwt-auth.guard';

@Controller('config')
@UseGuards(JwtAuthGuard)
export class ConfigController {
  constructor(private readonly config: ConfigService) {}

  @Get('all')
  getAll() {
    return this.config.getAllConfig();
  }

  @Get('roles')
  getRoles() {
    return this.config.getRoles();
  }

  @Get('departments')
  getDepartments() {
    return this.config.getDepartments();
  }

  @Get('purpose-categories')
  getPurposeCategories() {
    return this.config.getPurposeCategories();
  }

  @Get('outpass-types')
  getOutpassTypes() {
    return this.config.getOutpassTypes();
  }

  @Get('settings')
  getSettings() {
    return this.config.getSettings();
  }
}
