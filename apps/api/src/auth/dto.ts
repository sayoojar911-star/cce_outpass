import { IsNotEmpty, IsOptional, IsString, Length } from 'class-validator';

export function normalizeMobile(value: unknown): string {
  if (value === null || value === undefined) return '';
  let cleaned = String(value).trim().replace(/[\s\-\(\)]+/g, '');
  if (cleaned.startsWith('+91')) {
    cleaned = cleaned.slice(3);
  } else if (cleaned.startsWith('91') && cleaned.length === 12) {
    cleaned = cleaned.slice(2);
  } else if (cleaned.startsWith('+')) {
    cleaned = cleaned.slice(1);
  }
  return cleaned.replace(/\D/g, '');
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
