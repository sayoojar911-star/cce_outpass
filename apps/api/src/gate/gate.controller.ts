import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import { GateService } from './gate.service';
import { Auth } from '../common/auth.decorator';
import { ScanDto, StartShiftDto } from './dto';

@Controller('gate')
@Auth('GUARD')
export class GateController {
  constructor(private readonly gate: GateService) {}

  @Post('session/start')
  startShift(@Req() req: any, @Body() dto: StartShiftDto) {
    return this.gate.startShift(req.user, dto.gateId);
  }

  @Post('scans')
  scan(@Req() req: any, @Body() dto: ScanDto) {
    return this.gate.scan(req.user, dto);
  }

  @Get('scans/mine')
  myScans(@Req() req: any) {
    return this.gate.myScans(req.user);
  }
}
