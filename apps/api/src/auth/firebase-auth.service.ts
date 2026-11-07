import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

@Injectable()
export class FirebaseAuthService {
  private firebaseApp?: App;

  constructor(private readonly config: ConfigService) {}

  async verifyPhoneIdToken(idToken: string) {
    if (!idToken || typeof idToken !== 'string') {
      throw new UnauthorizedException('A valid Firebase ID token is required');
    }

    // Support testing/dev bypass tokens when TEMP_OTP_ENABLED is active
    const tempOtpEnabled = process.env.TEMP_OTP_ENABLED !== 'false';
    if (tempOtpEnabled && idToken.startsWith('test:')) {
      const raw = idToken.slice('test:'.length).trim();
      const digits = raw.replace(/\D/g, '');
      const tenDigits = digits.length >= 10 ? digits.slice(-10) : digits;
      if (/^\d{10}$/.test(tenDigits)) {
        return `+91${tenDigits}`;
      }
      throw new UnauthorizedException('Invalid test phone token');
    }

    try {
      const decoded = await getAuth(this.getFirebaseApp()).verifyIdToken(idToken);
      if (decoded.firebase?.sign_in_provider !== 'phone' || !decoded.phone_number) {
        throw new UnauthorizedException('A verified phone sign-in is required');
      }
      return decoded.phone_number;
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Invalid or expired Firebase sign-in');
    }
  }

  private getFirebaseApp() {
    if (this.firebaseApp) return this.firebaseApp;

    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    const serviceAccountJson = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!projectId || !serviceAccountJson) {
      throw new UnauthorizedException('Firebase phone authentication is not configured');
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    this.firebaseApp = getApps().find((app) => app.name === 'outpass-auth') ?? initializeApp(
      { credential: cert(serviceAccount), projectId },
      'outpass-auth',
    );
    return this.firebaseApp;
  }
}
