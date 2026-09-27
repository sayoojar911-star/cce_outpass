import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { FirebaseTokenDto, normalizeMobile } from './dto';

describe('auth mobile normalization', () => {
  it('removes a country prefix and whitespace before validation', () => {
    expect(normalizeMobile('+91 9074121510')).toBe('9074121510');
    expect(normalizeMobile('  9000000001  ')).toBe('9000000001');
  });

  it('requires a Firebase ID token for API sign-in', async () => {
    const dto = plainToInstance(FirebaseTokenDto, { idToken: 'firebase-id-token' });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);

    const missingTokenErrors = await validate(plainToInstance(FirebaseTokenDto, {}));
    expect(missingTokenErrors).not.toHaveLength(0);
  });
});
