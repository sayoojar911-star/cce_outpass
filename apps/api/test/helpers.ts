import { generateKeyPairSync, createSign } from 'crypto';
import { UnauthorizedException } from '@nestjs/common';
import { TestingModuleBuilder } from '@nestjs/testing';
import request from 'supertest';
import { FirebaseAuthService } from '../src/auth/firebase-auth.service';

export function useTestFirebaseAuth(builder: TestingModuleBuilder) {
  builder.overrideProvider(FirebaseAuthService).useValue({
    verifyPhoneIdToken: async (idToken: string) => {
      if (!idToken.startsWith('test:')) throw new UnauthorizedException();
      return `+91${idToken.slice('test:'.length)}`;
    },
  });
  return builder;
}

export async function login(app: any, mobile: string): Promise<string> {
  const res = await request(app.getHttpServer())
    .post('/v1/auth/firebase/verify')
    .send({ idToken: `test:${mobile}` });
  expect(res.status).toBe(201);
  return res.body.accessToken;
}

export function newKeyPair() {
  const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const pem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
  return { pem, privateKey };
}

export function signToken(privateKey: any, outpassId: string, ts: number): string {
  const message = `v1.${outpassId}.${ts}`;
  const signer = createSign('sha256');
  signer.update(message);
  signer.end();
  const sig = signer.sign(privateKey).toString('base64url');
  return `${message}.${sig}`;
}

export function uuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
