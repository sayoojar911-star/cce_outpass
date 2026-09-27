import { Controller, Get, Post, Req } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { Auth } from '../common/auth.decorator';

@Controller('notifications')
@Auth()
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@Req() req: any) {
    return this.notifications.list(req.user);
  }

  @Post('read')
  markRead(@Req() req: any) {
    return this.notifications.markAllRead(req.user);
  }
}
