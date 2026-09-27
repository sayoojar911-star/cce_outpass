import { Body, Controller, Get, Param, Post, Query, Req } from '@nestjs/common';
import { OutpassService } from './outpass.service';
import { Auth } from '../common/auth.decorator';
import { CreateOutpassDto, CancelDto } from './dto';
import { OutpassStatus } from '@prisma/client';

@Controller('outpasses')
@Auth()
export class OutpassController {
  constructor(private readonly outpass: OutpassService) {}

  @Post()
  create(@Req() req: any, @Body() dto: CreateOutpassDto) {
    return this.outpass.create(req.user, dto);
  }

  @Get()
  list(@Req() req: any, @Query('status') status?: string) {
    const valid = Object.values(OutpassStatus) as string[];
    return this.outpass.listFor(
      req.user,
      status && valid.includes(status) ? (status as OutpassStatus) : undefined,
    );
  }

  @Get(':id')
  getOne(@Req() req: any, @Param('id') id: string) {
    return this.outpass.getOne(req.user, id);
  }

  @Post(':id/cancel')
  cancel(@Req() req: any, @Param('id') id: string, @Body() dto: CancelDto) {
    return this.outpass.cancel(req.user, id, dto.reason);
  }
}
