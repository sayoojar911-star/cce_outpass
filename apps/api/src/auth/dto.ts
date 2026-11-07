import { IsInt, IsNotEmpty, IsOptional, IsString, Length, Matches, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

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

export class SendSignupOtpDto {
  @IsString()
  @IsNotEmpty()
  mobile: string;
}

export class VerifySignupOtpDto {
  @IsString()
  @IsNotEmpty()
  mobile: string;

  @IsString()
  @IsNotEmpty()
  code: string;
}

export class RegisterStudentDto {
  @IsString()
  @IsNotEmpty({ message: 'Firebase ID token is required' })
  idToken: string;

  @IsString()
  @IsNotEmpty({ message: 'Full name is required' })
  @Length(2, 100, { message: 'Name must be between 2 and 100 characters' })
  name: string;

  @IsString()
  @IsNotEmpty({ message: 'College roll number is required' })
  @Matches(/^CCE[A-Z0-9]{5,10}$/i, {
    message: 'College roll number must be in CCEXXXXXXX format (e.g. CCE23CS042)',
  })
  rollNo: string;

  @Type(() => Number)
  @IsInt({ message: 'Year must be an integer between 1 and 4' })
  @Min(1, { message: 'Year must be at least 1' })
  @Max(4, { message: 'Year cannot exceed 4' })
  year: number;

  @IsString()
  @IsNotEmpty({ message: 'Department is required' })
  department: string;

  @IsString()
  @IsNotEmpty({ message: 'Student photo is required' })
  photo: string;
}

export class UpdatePhotoDto {
  @IsString()
  @IsNotEmpty({ message: 'Photo data is required' })
  photo: string;
}
