---
last_mapped_commit: c4fce159181245c0e342cc4825e08bf487a2910c
last_mapped_at: 2026-10-11
---
# Codebase Structure

**Analysis Date:** 2026-10-11

## Directory Layout

```
College-app/
├── apps/
│   ├── api/                     # NestJS backend REST API
│   │   ├── prisma/              # Prisma schema, migrations, and seeds
│   │   │   ├── migrations/      # Historical SQL migrations
│   │   │   ├── schema.prisma    # Authoritative database model
│   │   │   └── seed.ts          # Default users, roles, and department seed
│   │   ├── public/              # Production static assets (compiled Flutter web)
│   │   ├── scripts/             # Database start and administrative bootstrap scripts
│   │   ├── src/                 # Backend TypeScript source code
│   │   │   ├── admin/           # Administrative portal controllers and services
│   │   │   ├── audit/           # Hash-chained tamper-evident audit logging
│   │   │   ├── auth/            # OTP auth, JWT issuance, and device registration
│   │   │   ├── common/          # Guards, decorators, filters, and interceptors
│   │   │   ├── config/          # Dynamic system configuration service
│   │   │   ├── gate/            # Gate scanner endpoints and cryptographic verification
│   │   │   ├── jobs/            # Scheduled cron tasks (expiration, overdue tracking)
│   │   │   ├── notifications/   # User notification polling service
│   │   │   ├── outpass/         # Core outpass requests and multi-stage approvals
│   │   │   ├── app.module.ts    # Root NestJS application module
│   │   │   ├── main.ts          # API application bootstrap entry point
│   │   │   └── prisma.service.ts# Shared PrismaClient database connector
│   │   └── test/                # End-to-end Jest test suites
│   └── mobile/                  # Flutter cross-platform client app
│       ├── lib/                 # Flutter Dart source code
│       │   ├── theme/           # Color palettes, typography, and theme styling
│       │   ├── util/            # HTML ticket generator and utility helpers
│       │   ├── widgets/         # Reusable widgets (TicketOutpass, custom clippers)
│       │   ├── admin_roles_workflows.dart # Workflows & roles configuration UI
│       │   ├── admin_screen.dart# Full admin console (People, Depts, Passes, Settings)
│       │   ├── api_client.dart  # HTTP API client connecting to backend
│       │   ├── app_constants.dart # Enums and static string constants
│       │   ├── app_state.dart   # Provider ChangeNotifier managing session & state
│       │   ├── approver_screen.dart # Tutor / HOD approval queue interface
│       │   ├── async_action_helper.dart # Standardized async dialog/form runner
│       │   ├── guard_screen.dart# Security Guard QR scanner & manual lookup interface
│       │   ├── login_screen.dart# OTP phone login interface
│       │   ├── main.dart        # Flutter entry point and RootRouter
│       │   ├── qr_token.dart    # ECDSA P-256 key management and rotating tokens
│       │   ├── role_service.dart# Permission check helpers
│       │   └── student_screen.dart # Student request form, active pass, and history
│       └── test/                # Flutter unit and widget test suites
├── docs/                        # Architecture documentation and PRD specifications
│   └── PRD.md                   # PRD summary and MVP scope trace
├── graphify-out/                # Persistent code graph and community analysis
├── docker-compose.yml           # PostgreSQL container specification
├── ERRORS.md                    # Bug and issue tracking ledger
├── ONBOARDING.md                # Comprehensive repo onboarding guide
└── PROGRESS.md                  # Milestone status and verification ledger
```

## Directory Purposes

**`apps/api/src/`:**
- Purpose: NestJS backend architecture structured into cohesive domain modules.
- Key files: `apps/api/src/main.ts`, `apps/api/src/app.module.ts`, `apps/api/src/prisma.service.ts`.

**`apps/api/prisma/`:**
- Purpose: Database schemas, declarative relational models, and migrations.
- Key files: `apps/api/prisma/schema.prisma`, `apps/api/prisma/seed.ts`.

**`apps/mobile/lib/`:**
- Purpose: Flutter cross-platform user experience, screen navigation, and cryptographic tokens.
- Key files: `apps/mobile/lib/main.dart`, `apps/mobile/lib/app_state.dart`, `apps/mobile/lib/qr_token.dart`.

**`apps/mobile/lib/widgets/`:**
- Purpose: Modular visual widgets, ticket rendering, perforated edges, and dynamic QR display.
- Key files: `apps/mobile/lib/widgets/ticket_outpass.dart`.

## Key File Locations

**Entry Points:**
- API Backend: `apps/api/src/main.ts`
- Mobile Client: `apps/mobile/lib/main.dart`

**Configuration:**
- Environment Template: `apps/api/.env.example`
- TypeScript Config: `apps/api/tsconfig.json`
- Flutter Pubspec: `apps/mobile/pubspec.yaml`

**Core Logic:**
- Outpass Lifecycle: `apps/api/src/outpass/outpass.service.ts`
- Gate Verification: `apps/api/src/gate/gate.service.ts`
- Cryptographic Token Signing: `apps/mobile/lib/qr_token.dart`
- API Client Wrapper: `apps/mobile/lib/api_client.dart`

**Testing:**
- Backend Unit/E2E: `apps/api/src/**/*.spec.ts` & `apps/api/test/**/*.e2e-spec.ts`
- Mobile Widget Tests: `apps/mobile/test/*_test.dart`
- Automated Verification Scripts: Root `verify-*.cjs`

## Naming Conventions

**Files:**
- TypeScript: kebab-case with role suffix (e.g., `outpass.service.ts`, `admin.controller.ts`, `jwt-auth.guard.ts`)
- Dart: snake_case (e.g., `app_state.dart`, `ticket_outpass.dart`, `approver_screen.dart`)
- Test Specs: `*.spec.ts` (API unit/audit), `*.e2e-spec.ts` (API e2e), `*_test.dart` (Flutter test)

**Directories:**
- Plural or singular domain nouns in lowercase (`admin/`, `auth/`, `gate/`, `widgets/`, `theme/`)

## Where to Add New Code

**New API Endpoint / Feature:**
- Create or extend domain module in `apps/api/src/<domain>/`
- Implement DTO with `class-validator` annotations
- Add controller method with appropriate `@RequirePermissions()` / `@Roles()` guards
- Implement business logic in `<domain>.service.ts`
- Add unit spec in `apps/api/src/<domain>/<domain>.service.spec.ts`

**New Mobile Screen / Portal:**
- Add screen widget under `apps/mobile/lib/<feature>_screen.dart`
- Wrap asynchronous API mutations in `AsyncActionHelper.run()`
- Register route in `RootRouter` inside `apps/mobile/lib/main.dart`
- Add widget test under `apps/mobile/test/<feature>_test.dart`

**Database Schema Changes:**
- Modify `apps/api/prisma/schema.prisma`
- Generate and apply migration via `npm run prisma:migrate`
- Update `apps/api/prisma/seed.ts` if default seeds require new fields

---

*Structure analysis: 2026-10-11*
