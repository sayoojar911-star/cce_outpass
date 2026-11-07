import { IsIn, IsOptional, IsString, IsUUID, Length } from 'class-validator';

export class ScanDto {
  @IsString()
  @Length(10, 2000)
  token: string;

  @IsIn(['EXIT', 'ENTRY'])
  direction: 'EXIT' | 'ENTRY';

  @IsString()
  @Length(1, 64)
  gateId: string;

  @IsUUID()
  clientScanId: string;

  @IsOptional()
  @IsString()
  deviceId?: string;
}

export class StartShiftDto {
  @IsString()
  @Length(1, 64)
  gateId: string;
}

export class ManualEntryDto {
  @IsString()
  @Length(3, 32)
  code: string;

  @IsIn(['EXIT', 'ENTRY'])
  direction: 'EXIT' | 'ENTRY';

  @IsString()
  @Length(1, 64)
  gateId: string;

  @IsUUID()
  clientScanId: string;

  @IsOptional()
  @IsString()
  deviceId?: string;
}
