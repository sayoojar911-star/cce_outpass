import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import { GateService } from './gate.service';
import { RequirePermissions } from '../common/auth.decorator';
import { ScanDto, StartShiftDto, ManualEntryDto } from './dto';

@Controller('gate')
@RequirePermissions('gateScan')
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

  @Post('manual-entry')
  manualEntry(@Req() req: any, @Body() dto: ManualEntryDto) {
    return this.gate.manualEntry(req.user, dto);
  }

  @Get('scans/mine')
  myScans(@Req() req: any) {
    return this.gate.myScans(req.user);
  }
}
