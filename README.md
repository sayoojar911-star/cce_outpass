# CCE Outpass — MVP

Digital outpass system for Christ College of Engineering, Irinjalakuda.
Implements the PRD's core loop end to end: **student requests → tutor approves →
HOD approves → rotating signed QR → guard scans (allow/deny) → single-use exit →
return scan**.

## Quick start

```bash
# 1. Database (Postgres 16, project-local data dir)
cd apps/api
LC_ALL="en_US.UTF-8" /opt/homebrew/opt/postgresql@16/bin/pg_ctl \
  -D .pgdata -l .pg.log -o "-p 5433" -w start

# 2. API (also serves the web app at /)
npm install && npx prisma migrate deploy && npx prisma db seed
npm run build
node scripts/daemon.cjs        # http://localhost:3000

# 3. Web app (only after changing Flutter code)
cd ../mobile
flutter pub get && flutter build web \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN"
rm -rf ../api/public && cp -r build/web ../api/public
```

Open **http://localhost:3000** — the Preview tab shows the app.

## Phone sign-in setup

SMS login uses Firebase Authentication's Phone provider. Firebase Cloud
Messaging (FCM) is for push notifications and cannot send SMS OTPs.

1. In Firebase Console, enable **Authentication → Phone** and add the app's web
  domain to Authorized domains. Use Firebase's test phone numbers during
  development to avoid sending real SMS messages.
2. Set `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON` in
  `apps/api/.env`. The service account must belong to the same Firebase project
  used by the Flutter app and must be kept private.
3. Build the Flutter web app with that Firebase project's public app settings:

  ```bash
  cd apps/mobile
  flutter build web \
    --dart-define=FIREBASE_API_KEY=... \
    --dart-define=FIREBASE_APP_ID=... \
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
    --dart-define=FIREBASE_PROJECT_ID=... \
    --dart-define=FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
  ```

The Firebase-verified phone must match an active user already present in the
outpass database. Firebase sends and verifies the SMS; the API verifies the
Firebase ID token before issuing its own app session.

## Initial Admin Account

The database seed creates ONLY the system administrator account:

| Role | Mobile | Name | Temporary OTP |
|------|--------|------|---------------|
| **Admin** | `8921578838` | System Administrator | `123456` |

All other roles (Tutors, HODs, Guards, Students) are created dynamically via the Admin Console.
Unregistered phone numbers cannot log in.


Walkthrough: log in as the student → request an outpass → log in as the tutor
(approve) → the HOD (approve) → the student (Show QR) → the guard (scan the QR
with the camera; the big green/red result follows PRD §7.5). Scanning the same
pass again returns `ALREADY_USED`; a screenshot older than 75 s dies as
`QR_STALE`.

## Layout

```
apps/api      NestJS + Prisma + Postgres — /v1 API, static web host
apps/mobile   Flutter (web today; Android/iOS with the same code)
docs/         PRD summary + decision log with requirement IDs
```

## Tests

```bash
cd apps/api && npm test          # token unit tests
npm run test:e2e                 # API e2e incl. race conditions (needs DB up)
cd ../mobile && dart run test/e2e_live.dart   # live cross-implementation check
```

The live Dart checks need a current Firebase phone-auth ID token for each
seeded account, passed as `FIREBASE_ID_TOKEN_<mobile>` environment variables.

`apps/mobile/test/e2e_live.dart` drives the running server through the full
lifecycle while signing QR tokens with **the same Dart crypto module the app
ships** — proving client and server implementations agree on ECDSA P-256.

## Security posture (MVP)

Implemented: device-bound ECDSA P-256 keys, rotating single-use QR (30 s step,
±75 s window, monotonic replay counter), object-level authorisation, atomic
state transitions guarded by current status, Firebase Phone Authentication
with server-verified ID tokens, rate limits on auth/scan endpoints, append-only
hash-chained audit log, security events for invalid-QR attempts.

Deliberately cut for the MVP (see `docs/decisions.md`): push notifications,
attestation
(Play Integrity/App Attest), secure-hardware keys (Keystore/Secure Enclave),
offline gate mode, WhatsApp, warden stage, admin dashboard, policy
engine, biometric unlock.
