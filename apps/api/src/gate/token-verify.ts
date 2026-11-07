import { createPublicKey, verify as cryptoVerify } from 'crypto';

export const ACCEPT_WINDOW_SECONDS = 75;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type ParsedToken =
  | { ok: true; outpassId: string; ts: number; message: Buffer; sig: Buffer }
  | { ok: false; code: 'QR_INVALID' };

export type TokenResult =
  | { ok: true; outpassId: string; ts: number }
  | { ok: false; code: 'QR_INVALID' | 'QR_STALE' };

/**
 * Parse `v1.<outpass_id>.<ts>.<signature>` (PRD §7.3).
 * ts: unix seconds rounded to a 30 s step. sig: ECDSA P-256/SHA-256 DER, base64url.
 */
export function parseQrToken(token: string): ParsedToken {
  if (typeof token !== 'string') return { ok: false, code: 'QR_INVALID' };
  const parts = token.split('.');
  if (parts.length !== 4 || parts[0] !== 'v1') return { ok: false, code: 'QR_INVALID' };
  const [, outpassId, tsStr, sigB64] = parts;
  if (!UUID_RE.test(outpassId)) return { ok: false, code: 'QR_INVALID' };
  if (!/^\d{10}$/.test(tsStr)) return { ok: false, code: 'QR_INVALID' };
  const ts = Number(tsStr);
  let sig: Buffer;
  try {
    sig = Buffer.from(sigB64, 'base64url');
  } catch {
    return { ok: false, code: 'QR_INVALID' };
  }
  if (sig.length < 8) return { ok: false, code: 'QR_INVALID' };
  const message = Buffer.from(`v1.${outpassId}.${tsStr}`, 'utf8');
  return { ok: true, outpassId, ts, message, sig };
}

/** DER-encoded ECDSA P-256 signature over message, verified with the device public key. */
export function verifySignature(message: Buffer, sig: Buffer, publicKeyPem: string): boolean {
  try {
    return cryptoVerify(
      'sha256',
      message,
      { key: createPublicKey(publicKeyPem), dsaEncoding: 'der' },
      sig,
    );
  } catch {
    return false;
  }
}

export function checkWindow(ts: number, nowSec: number, windowSeconds = ACCEPT_WINDOW_SECONDS): boolean {
  return Math.abs(nowSec - ts) <= windowSeconds;
}

/** Combined verification (used by tests; the scan flow uses the pieces individually). */
export function verifyQrToken(
  token: string,
  publicKeyPem: string,
  nowSec: number,
  windowSeconds = ACCEPT_WINDOW_SECONDS,
): TokenResult {
  const parsed = parseQrToken(token);
  if (!parsed.ok) return parsed;
  if (!verifySignature(parsed.message, parsed.sig, publicKeyPem)) {
    return { ok: false, code: 'QR_INVALID' };
  }
  if (!checkWindow(parsed.ts, nowSec, windowSeconds)) return { ok: false, code: 'QR_STALE' };
  return { ok: true, outpassId: parsed.outpassId, ts: parsed.ts };
}
