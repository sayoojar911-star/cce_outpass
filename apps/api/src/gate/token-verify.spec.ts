import { generateKeyPairSync, createSign } from 'crypto';
import { verifyQrToken, parseQrToken } from './token-verify';

const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pem = publicKey.export({ type: 'spki', format: 'pem' }).toString();

const OUTPASS_ID = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

function sign(id: string, ts: number) {
  const message = `v1.${id}.${ts}`;
  const signer = createSign('sha256');
  signer.update(message);
  signer.end();
  const sig = signer.sign(privateKey); // DER by default
  return `${message}.${sig.toString('base64url')}`;
}

describe('verifyQrToken', () => {
  const nowSec = 1_790_000_000;

  it('accepts a fresh valid token', () => {
    const token = sign(OUTPASS_ID, nowSec - (nowSec % 30));
    const res = verifyQrToken(token, pem, nowSec);
    expect(res).toEqual({ ok: true, outpassId: OUTPASS_ID, ts: nowSec - (nowSec % 30) });
  });

  it('rejects a tampered signature', () => {
    const token = sign(OUTPASS_ID, nowSec);
    const parts = token.split('.');
    const sig = Buffer.from(parts[3], 'base64url');
    sig[sig.length - 1] ^= 0x01;
    const tampered = `${parts[0]}.${parts[1]}.${parts[2]}.${sig.toString('base64url')}`;
    expect(verifyQrToken(tampered, pem, nowSec)).toEqual({ ok: false, code: 'QR_INVALID' });
  });

  it('rejects a token signed by a different key', () => {
    const other = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
    const message = `v1.${OUTPASS_ID}.${nowSec}`;
    const signer = createSign('sha256');
    signer.update(message);
    signer.end();
    const sig = signer.sign(other.privateKey).toString('base64url');
    expect(verifyQrToken(`${message}.${sig}`, pem, nowSec)).toEqual({
      ok: false,
      code: 'QR_INVALID',
    });
  });

  it('rejects a stale token (older than 75 s)', () => {
    const token = sign(OUTPASS_ID, nowSec - 300);
    expect(verifyQrToken(token, pem, nowSec)).toEqual({ ok: false, code: 'QR_STALE' });
  });

  it('rejects a token from the future beyond the window', () => {
    const token = sign(OUTPASS_ID, nowSec + 300);
    expect(verifyQrToken(token, pem, nowSec)).toEqual({ ok: false, code: 'QR_STALE' });
  });

  it('rejects malformed tokens', () => {
    expect(verifyQrToken('garbage', pem, nowSec).ok).toBe(false);
    expect(verifyQrToken('v2.abc.123.sig', pem, nowSec).ok).toBe(false);
    expect(verifyQrToken('v1.notauuid.123.sig', pem, nowSec).ok).toBe(false);
    expect(verifyQrToken(`v1.${OUTPASS_ID}.notanumber.sig`, pem, nowSec).ok).toBe(false);
    expect(parseQrToken('').ok).toBe(false);
  });
});
