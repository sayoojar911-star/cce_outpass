import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import { AuthService } from './auth.service';
import { Auth } from '../common/auth.decorator';
import { RegisterDeviceDto, FirebaseTokenDto, RefreshDto } from './dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('firebase/verify')
  verifyFirebasePhone(@Body() dto: FirebaseTokenDto) {
    return this.auth.verifyFirebasePhone(dto.idToken);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto.refreshToken);
  }

  @Post('logout')
  logout(@Body() dto: RefreshDto) {
    return this.auth.logout(dto.refreshToken);
  }

  @Post('device/register')
  @Auth()
  registerDevice(@Req() req: any, @Body() dto: RegisterDeviceDto) {
    return this.auth.registerDevice(req.user, dto);
  }

  @Get('me')
  @Auth()
  me(@Req() req: any) {
    return this.auth.me(req.user);
  }
}
