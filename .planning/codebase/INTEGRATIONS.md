---
last_mapped_commit: c4fce159181245c0e342cc4825e08bf487a2910c
last_mapped_at: 2026-10-11
---
# External Integrations

**Analysis Date:** 2026-10-11

## APIs & External Services

**Firebase Authentication & Cloud Messaging:**
- Firebase Admin SDK (`firebase-admin` 13.10.0) - Intended for OTP verification and push notifications
  - SDK/Client: `apps/api/src/auth/auth.service.ts`
  - Auth: `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
  - Dev Bypass: Local development and test environments fallback to dev OTP logging (`code: 123456` or logged OTP) when Firebase credentials are omitted or in mock mode

## Data Storage

**Databases:**
- PostgreSQL (relational DB)
  - Connection: `DATABASE_URL`
  - Client: Prisma Client (`@prisma/client` 6.2.1) in `apps/api/src/prisma.service.ts`
  - Migrations: Managed via Prisma Migrate (`apps/api/prisma/migrations/`)
  - Dev Database: Embedded PostgreSQL on port 5433 started via `apps/api/scripts/db-start.cjs` or Docker via `docker-compose.yml`

**File Storage:**
- Local filesystem only (`apps/api/public` for Flutter web distribution and static assets)

**Caching:**
- In-memory rate limiting and token cache (`GuardRateLimitState` in `apps/api/src/gate/gate.service.ts`)
- No external Redis cache required for current single-instance architecture

## Authentication & Identity

**Auth Provider:**
- Custom JWT + Mobile OTP Identity Flow
  - Implementation: Users authenticate via registered mobile phone (`/v1/auth/otp/send` and `/v1/auth/otp/verify`).
  - Tokens: Dual token architecture (Short-lived JWT Access Token + Refresh Token Hash stored in DB `Session` table).
  - Role-based & Permission-based Access Control: Enforced via `JwtAuthGuard`, `RolesGuard`, and `PermissionsGuard` (`apps/api/src/common/`).

**Device Cryptographic Binding:**
- ECDSA P-256 public key registered upon login via `POST /v1/auth/device/register` (`Device` table).
- Outpass tokens signed using device private key (`v1.<passId>.<step>.<sig>`), cryptographically validated on gate scan (`apps/api/src/gate/gate.service.ts`).

## Monitoring & Observability

**Error Tracking:**
- Centralized exception filter: `AllExceptionsFilter` (`apps/api/src/common/all-exceptions.filter.ts`) logging structured exceptions to standard console with correlation IDs.

**Logs & Audit Trails:**
- Database-backed hash-chained audit logging: `AuditService` (`apps/api/src/audit/audit.service.ts`) storing tamper-evident entries in `AuditLog` table with `actorId`, `action`, `objectType`, `prevHash`, and `hash`.
- Security Event Monitoring: `SecurityEvent` model tracking suspicious gate scans, token replays, and permission failures.

## CI/CD & Deployment

**Hosting:**
- Docker / Docker Compose (`docker-compose.yml` defining PostgreSQL database container)
- Node.js production service (`npm run start` after `npm run build`)
- Web static output bundled into `apps/api/public/`

**CI Pipeline:**
- Local npm & flutter testing pipelines (`npm run test`, `npm run lint`, `flutter test`, `flutter analyze`)

## Environment Configuration

**Required env vars:**
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Secret for signing JWT access tokens
- `JWT_REFRESH_SECRET` - Secret for signing refresh tokens
- `PORT` - HTTP listening port (default: 3000)

**Optional env vars:**
- `FIREBASE_PROJECT_ID` - Firebase project identifier
- `FIREBASE_CLIENT_EMAIL` - Service account email
- `FIREBASE_PRIVATE_KEY` - Service account RSA key

**Secrets location:**
- `apps/api/.env` (gitignored, template in `apps/api/.env.example`)
- Client-side secrets/keys: Stored in OS secure hardware via `flutter_secure_storage`

## Webhooks & Callbacks

**Incoming:**
- None detected (system operates as an authoritative REST API for clients)

**Outgoing:**
- None detected (notifications are delivered via database-backed `Notification` polling model or future FCM push)

---

*Integration audit: 2026-10-11*
