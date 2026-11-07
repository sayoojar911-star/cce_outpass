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
  @IsString()
  type?: string;
}

export class DecisionDto {
  @IsIn([
    'APPROVED',
    'REJECTED',
    'APPROVE',
    'REJECT',
    'DIRECT_APPROVE',
    'FORWARD_HOD',
    'APPROVE_DIRECT',
    'APPROVE_AND_FORWARD',
  ])
  decision: string;

  @IsOptional()
  @IsIn(['DIRECT', 'FORWARD_HOD', 'FORWARDED'])
  path?: string;

  @IsOptional()
  @IsString()
  @Length(0, 500)
  comment?: string;
}

export class DirectApprovalDto {
  @IsOptional()
  @IsString()
  @Length(0, 500)
  comment?: string;
}

export class ForwardHodDto {
  @IsOptional()
  @IsString()
  @Length(0, 500)
  comment?: string;
}

export class RejectOutpassDto {
  @IsOptional()
  @IsString()
  @Length(0, 500)
  reason?: string;

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
