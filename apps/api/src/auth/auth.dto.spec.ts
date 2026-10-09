import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { FirebaseTokenDto, SendOtpDto, VerifyOtpDto, normalizeMobile } from './dto';

describe('auth mobile normalization', () => {
  it('removes a country prefix and whitespace before validation', () => {
    expect(normalizeMobile('+91 9074121510')).toBe('9074121510');
    expect(normalizeMobile('  9000000001  ')).toBe('9000000001');
  });

  it('validates SendOtpDto and VerifyOtpDto fields', async () => {
    const validSend = plainToInstance(SendOtpDto, { mobile: '9000000001' });
    expect(await validate(validSend)).toHaveLength(0);

    const invalidSend = plainToInstance(SendOtpDto, {});
    expect(await validate(invalidSend)).not.toHaveLength(0);

    const validVerify = plainToInstance(VerifyOtpDto, { mobile: '9000000001', code: '123456' });
    expect(await validate(validVerify)).toHaveLength(0);

    const invalidVerify = plainToInstance(VerifyOtpDto, { mobile: '9000000001' });
    expect(await validate(invalidVerify)).not.toHaveLength(0);
  });

  it('requires a Firebase ID token for API sign-in', async () => {
    const dto = plainToInstance(FirebaseTokenDto, { idToken: 'firebase-id-token' });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);

    const missingTokenErrors = await validate(plainToInstance(FirebaseTokenDto, {}));
    expect(missingTokenErrors).not.toHaveLength(0);
  });
});
