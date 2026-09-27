# Decision Log

| # | Decision | Rationale / PRD ref |
|---|----------|---------------------|
| 1 | Guide stack: NestJS + Prisma + Postgres (Docker) + Flutter (one app, role switcher) | Build guide §C1 |
| 2 | Flutter demo runs as Flutter Web; native Android/iOS builds later | No Flutter SDK/Xcode on machine at build time; same codebase targets stores later |
| 3 | Device keys: ECDSA P-256. On web, WebCrypto software keys (flagged in code comments); Keystore/Secure Enclave native plugin deferred to mobile phase | PRD §7.2; simulator/web cannot use secure hardware |
| 4 | QR token: `v1.<outpass_uuid>.<ts30s>.<ECDSA-P256-SHA256 DER, base64url>`; server verifies signature, ±75 s window, monotonic `last_token_ts` guard inside the same atomic UPDATE | PRD §7.3–7.4 |
| 5 | Server accepts DER-encoded ECDSA signatures (iOS/Android produce DER natively); Flutter web converts WebCrypto raw R‖S to DER client-side | Build guide §D4 cross-platform note |
| 6 | Atomic transitions via conditional `UPDATE ... WHERE status = expected` (Prisma `updateMany`, count-checked); approval uniqueness on `(request_id, stage)` prevents double decisions | PRD §5.2, §SEC-API-05, build guide §D3 |
| 7 | Firebase Phone Authentication sends/verifies SMS; API validates Firebase ID tokens and issues its own app session | Firebase handles OTP lifecycle; server trusts only verified phone-provider tokens |
| 8 | Validity window on approval: `valid_from = requested exit time`, `valid_until = expected return`; if expected return already past, window = now → now + 60 min so demos/tests never produce a dead QR | Edge case §14 row 3 |
| 9 | Min dwell between exit and entry scan: 10 minutes | §6.9 |
| 10 | Postgres on host port 5433 (5432 avoided for clashes); API on 3000; static web on 8090 | local env |
| 11 | Guard "camera scan" uses mobile_scanner; a manual token-paste field is provided as the demo-safe fallback (camera permission may be unavailable in embedded previews) | PRD FR-SEC-08 fallback spirit |
| 12 | Git repo initialized inside the project folder (parent folder is a personal repo where this project was untracked) | workspace isolation |
