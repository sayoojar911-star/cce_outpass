import { Body, Controller, Get, Param, Post, Req } from '@nestjs/common';
import { OutpassService } from './outpass.service';
import { Auth } from '../common/auth.decorator';
import { DecisionDto } from './dto';

@Controller('approvals')
@Auth('TUTOR', 'HOD')
export class ApprovalsController {
  constructor(private readonly outpass: OutpassService) {}

  @Get('pending')
  async pending(@Req() req: any) {
    const status = req.user.role === 'TUTOR' ? 'PENDING_TUTOR' : 'PENDING_HOD';
    const rows = await this.outpass.listFor(req.user, status as never);
    // FR-HOD-07: emergency requests first
    return rows.sort((a, b) => (a.type === b.type ? 0 : a.type === 'EMERGENCY' ? -1 : 1));
  }

  @Post(':requestId/decision')
  decide(@Req() req: any, @Param('requestId') requestId: string, @Body() dto: DecisionDto) {
    return this.outpass.decide(req.user, requestId, dto);
  }
}
