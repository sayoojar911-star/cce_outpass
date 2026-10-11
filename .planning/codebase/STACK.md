---
last_mapped_commit: c4fce159181245c0e342cc4825e08bf487a2910c
last_mapped_at: 2026-10-11
---
# Technology Stack

**Analysis Date:** 2026-10-11

## Languages

**Primary:**
- TypeScript 5.7.2 - Backend API service (`apps/api`)
- Dart 3.12.2 - Cross-platform mobile and web client (`apps/mobile`)

**Secondary:**
- JavaScript (Node.js CommonJS) - Local tooling, verification scripts, and migration scripts (`apps/api/scripts/`, `verify-*.cjs`)
- SQL / PostgreSQL DDL - Database migrations (`apps/api/prisma/migrations/`)
- C++ (C++17) - Windows runner shell for Flutter desktop (`apps/mobile/windows/runner/`)

## Runtime

**Environment:**
- Node.js >= 20.x (`apps/api`)
- Flutter SDK >= 3.29.x / Dart SDK ^3.12.2 (`apps/mobile`)

**Package Manager:**
- npm / Node package manager (`apps/api/package.json`)
  - Lockfile: `package-lock.json` present
- pub / Flutter package manager (`apps/mobile/pubspec.yaml`)
  - Lockfile: `pubspec.lock` present

## Frameworks

**Core:**
- NestJS 10.4.15 - Modular backend framework for REST APIs, dependency injection, and guards (`apps/api/src/app.module.ts`)
- Flutter 3.x - Cross-platform declarative UI framework for Android, iOS, Web, and Desktop (`apps/mobile/lib/main.dart`)
- Prisma ORM 6.2.1 - Database modeling, schema migrations, and type-safe query client (`apps/api/prisma/schema.prisma`)

**Testing:**
- Jest 29.7.0 & ts-jest 29.2.5 - Unit, integration, and e2e testing for NestJS (`apps/api/package.json`)
- Supertest 7.0.0 - HTTP assertion library for API integration tests (`apps/api/test/gate.e2e-spec.ts`)
- Flutter Test SDK - Component, widget, and integration testing for Flutter (`apps/mobile/test/`)

**Build/Dev:**
- Nest CLI 10.4.9 (`apps/api/nest-cli.json`)
- ts-node 10.9.2 - Direct execution of TypeScript scripts and seeders (`apps/api/prisma/seed.ts`)
- embedded-postgres 18.4.0-beta.17 - Ephemeral embedded PostgreSQL instance for zero-dependency local dev/testing (`apps/api/scripts/db-start.cjs`)

## Key Dependencies

**Critical:**
- `@nestjs/jwt` 10.2.0 & `passport-jwt` 4.0.1 - Authentication, stateless token generation, and role/permission guard enforcement (`apps/api/src/common/jwt-auth.guard.ts`)
- `pointycastle` 4.0.0 & `asn1lib` 1.6.5 - ECDSA P-256 cryptographic key pair generation and token signing on mobile (`apps/mobile/lib/qr_token.dart`)
- `mobile_scanner` 7.4.2 - High-performance camera QR barcode scanning for Gate Guard portal (`apps/mobile/lib/guard_screen.dart`)
- `qr_flutter` 4.1.0 & `qr` 3.0.2 - Dynamic QR code rendering and raw QR matrix calculation for SVG generation (`apps/mobile/lib/widgets/ticket_outpass.dart`, `apps/mobile/lib/util/ticket_html_generator.dart`)
- `flutter_secure_storage` 9.2.4 - Keystore / Keychain secure hardware-backed private key storage (`apps/mobile/lib/qr_token.dart`)
- `provider` 6.1.5+1 - Global application state management and reactive UI updates (`apps/mobile/lib/app_state.dart`)

**Infrastructure:**
- `@nestjs/schedule` 4.1.2 - Cron-based scheduled background tasks for outpass expiration and overdue calculation (`apps/api/src/jobs/expiry.service.ts`)
- `@nestjs/serve-static` 4.0.2 - Static asset serving for compiled Flutter web bundles (`apps/api/src/app.module.ts`)
- `class-validator` 0.14.1 & `class-transformer` 0.5.1 - DTO validation and request transformation pipelines (`apps/api/src/auth/dto.ts`)
- `http` 1.6.0 - REST API client wrapper communicating between Flutter client and NestJS backend (`apps/mobile/lib/api_client.dart`)
- `intl` 0.20.3 - Internationalization and IST datetime formatting (`apps/mobile/lib/widgets/ticket_outpass.dart`)

## Configuration

**Environment:**
- Managed via `@nestjs/config` reading `.env` (template in `apps/api/.env.example`)
- Key configs required:
  - `DATABASE_URL` (e.g. `postgresql://outpass:outpass_dev@localhost:5433/outpass_dev?schema=public`)
  - `JWT_SECRET` (secret for access tokens)
  - `JWT_REFRESH_SECRET` (secret for refresh tokens)
  - `PORT` (default `3000`)
  - `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` (optional / dev bypass enabled)
  - `ADMIN_SECRET` / bootstrap credentials

**Build:**
- TypeScript: `apps/api/tsconfig.json` & `apps/api/tsconfig.build.json`
- Nest: `apps/api/nest-cli.json`
- Flutter Analysis: `apps/mobile/analysis_options.yaml`

## Platform Requirements

**Development:**
- Windows 10/11, macOS, or Linux
- Node.js 20+
- Flutter 3.29+ with Dart 3.12+
- Docker or Embedded Postgres for local database

**Production:**
- Backend: Containerized Node.js service (Docker / Linux server) connecting to managed PostgreSQL
- Frontend:
  - Web: Static bundle served from `/` via NestJS or Nginx/CDN
  - Android: APK / AAB target SDK 34+
  - iOS: Xcode runner bundle
  - Windows: Portable Win32 desktop application

---

*Stack analysis: 2026-10-11*
