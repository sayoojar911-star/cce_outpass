import { Body, Controller, Delete, Get, Post, Req } from '@nestjs/common';
import { AuthService } from './auth.service';
import { Auth } from '../common/auth.decorator';
import {
  RegisterDeviceDto,
  FirebaseTokenDto,
  RefreshDto,
  SendOtpDto,
  VerifyOtpDto,
  SendSignupOtpDto,
  VerifySignupOtpDto,
  RegisterStudentDto,
  UpdatePhotoDto,
} from './dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('otp/send')
  sendOtp(@Body() dto: SendOtpDto) {
    return this.auth.sendOtp(dto.mobile);
  }

  @Post('otp/verify')
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto.mobile, dto.code);
  }

  @Post('signup/otp/send')
  sendSignupOtp(@Body() dto: SendSignupOtpDto) {
    return this.auth.sendSignupOtp(dto.mobile);
  }

  @Post('signup/otp/verify')
  verifySignupOtp(@Body() dto: VerifySignupOtpDto) {
    return this.auth.verifySignupOtp(dto.mobile, dto.code);
  }

  @Post('register')
  register(@Body() dto: RegisterStudentDto) {
    return this.auth.registerStudent(dto);
  }

  @Post('student/register')
  registerStudent(@Body() dto: RegisterStudentDto) {
    return this.auth.registerStudent(dto);
  }

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

  @Post('profile/photo')
  @Auth()
  updateProfilePhoto(@Req() req: any, @Body() dto: UpdatePhotoDto) {
    return this.auth.updateProfilePhoto(req.user, dto.photo);
  }

  @Delete('profile/photo')
  @Auth()
  removeProfilePhoto(@Req() req: any) {
    return this.auth.removeProfilePhoto(req.user);
  }

  @Get('me')
  @Auth()
  me(@Req() req: any) {
    return this.auth.me(req.user);
  }
}
