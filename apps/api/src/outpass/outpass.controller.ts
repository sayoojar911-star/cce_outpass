import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { OutpassService } from './outpass.service';
import { JwtAuthGuard } from '../common/jwt-auth.guard';
import { RequirePermissions } from '../common/auth.decorator';
import { CreateOutpassDto, CancelDto } from './dto';

@Controller('outpasses')
@UseGuards(JwtAuthGuard)
export class OutpassController {
  constructor(private readonly outpass: OutpassService) {}

  @Post()
  @RequirePermissions('createOutpass')
  create(@Req() req: any, @Body() dto: CreateOutpassDto) {
    return this.outpass.create(req.user, dto);
  }

  @Get()
  list(@Req() req: any, @Query('status') status?: string) {
    return this.outpass.listFor(req.user, status);
  }

  @Get(':id')
  getOne(@Req() req: any, @Param('id') id: string) {
    return this.outpass.getOne(req.user, id);
  }

  @Post(':id/cancel')
  @RequirePermissions('createOutpass')
  cancel(@Req() req: any, @Param('id') id: string, @Body() dto: CancelDto) {
    return this.outpass.cancel(req.user, id, dto.reason);
  }
}
