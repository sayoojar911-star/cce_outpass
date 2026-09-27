import {
  IsArray,
  IsIn,
  IsISO8601,
  IsOptional,
  IsString,
  Length,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateOutpassDto {
  @IsISO8601()
  requestedExitAt: string;

  @IsISO8601()
  expectedReturnAt: string;

  @IsString()
  @Length(1, 120)
  destination: string;

  @IsString()
  @Length(1, 60)
  purposeCategory: string;

  @IsOptional()
  @IsString()
  @Length(0, 500)
  purposeText?: string;

  @IsOptional()
  @IsIn(['NORMAL', 'EMERGENCY'])
  type?: 'NORMAL' | 'EMERGENCY';
}

export class DecisionDto {
  @IsIn(['APPROVED', 'REJECTED'])
  decision: 'APPROVED' | 'REJECTED';

  @IsOptional()
  @IsString()
  @Length(0, 500)
  comment?: string;
}

export class CancelDto {
  @IsOptional()
  @IsString()
  @Length(0, 300)
  reason?: string;
}
