import { Body, Controller, Get, Param, Post, Req } from '@nestjs/common';
import { OutpassService } from './outpass.service';
import { RequirePermissions } from '../common/auth.decorator';
import { DecisionDto, DirectApprovalDto, ForwardHodDto, RejectOutpassDto } from './dto';

@Controller('approvals')
@RequirePermissions('approveOutpass')
export class ApprovalsController {
  constructor(private readonly outpass: OutpassService) {}

  @Get('pending')
  async pending(@Req() req: any) {
    const rows = await this.outpass.listFor(req.user);
    return rows;
  }

  @Post(':requestId/approve-direct')
  approveDirect(
    @Req() req: any,
    @Param('requestId') requestId: string,
    @Body() dto: DirectApprovalDto,
  ) {
    return this.outpass.approveDirect(req.user, requestId, dto.comment);
  }

  @Post(':requestId/forward-hod')
  forwardToHod(
    @Req() req: any,
    @Param('requestId') requestId: string,
    @Body() dto: ForwardHodDto,
  ) {
    return this.outpass.forwardToHod(req.user, requestId, dto.comment);
  }

  @Post(':requestId/reject')
  reject(
    @Req() req: any,
    @Param('requestId') requestId: string,
    @Body() dto: RejectOutpassDto,
  ) {
    return this.outpass.reject(req.user, requestId, dto.reason || dto.comment);
  }

  @Post(':requestId/decision')
  decide(
    @Req() req: any,
    @Param('requestId') requestId: string,
    @Body() dto: DecisionDto,
  ) {
    return this.outpass.decide(req.user, requestId, dto);
  }
}
