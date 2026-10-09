import { IsNotEmpty, IsOptional, IsString, Length } from 'class-validator';

export function normalizeMobile(value: unknown): string {
  const cleaned = String(value ?? '').replace(/\s+/g, '').replace(/^\+91/, '');
  return cleaned.replace(/[^0-9]/g, '');
}

export class SendOtpDto {
  @IsString()
  @IsNotEmpty()
  mobile: string;
}

export class VerifyOtpDto {
  @IsString()
  @IsNotEmpty()
  mobile: string;

  @IsString()
  @IsNotEmpty()
  code: string;
}

export class FirebaseTokenDto {
  @IsString()
  @IsNotEmpty()
  idToken: string;
}

export class RefreshDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  @Length(50, 500)
  publicKeyPem: string;

  @IsOptional()
  @IsString()
  platform?: string;
}
