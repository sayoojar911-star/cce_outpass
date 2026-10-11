---
last_mapped_commit: c4fce159181245c0e342cc4825e08bf487a2910c
last_mapped_at: 2026-10-11
---
<!-- refreshed: 2026-10-11 -->

# Architecture

**Analysis Date:** 2026-10-11

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    Client Applications                      │
├─────────────────────┬─────────────────────┬─────────────────┤
│   Student App       │   Approver Portal   │   Gate Guard    │
│ `apps/mobile/lib`   │ `apps/mobile/lib`   │`apps/mobile/lib`│
└──────────┬──────────┴──────────┬──────────┴────────┬────────┘
           │                     │                   │
           ▼                     ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                 NestJS REST API Gateway                     │
│               `apps/api/src/common/`                        │
│   (JWT Auth Guard · Roles Guard · Permissions Guard)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│ AuthModule   │       │OutpassModule │       │  GateModule  │
│`apps/api/auth`       │`apps/api/outpass`    │`apps/api/gate`
└──────┬───────┘       └──────┬───────┘       └──────┬───────┘
       │                      │                      │
       └──────────────────────┼──────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Prisma Data Layer                       │
│               `apps/api/src/prisma.service.ts`              │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     PostgreSQL Database                     │
│  (Users, Roles, Outpasses, Approvals, GateEvents, AuditLogs)│
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `AuthModule` / `AuthService` | User authentication, OTP generation, token verification, device key registration | `apps/api/src/auth/auth.service.ts` |
| `OutpassModule` / `OutpassService` | Outpass lifecycle: creation, cancellation, status transitions, retrieval | `apps/api/src/outpass/outpass.service.ts` |
| `ApprovalsController` | Tutor & HOD approval chain evaluation and recording decisions | `apps/api/src/outpass/approvals.controller.ts` |
| `GateModule` / `GateService` | Guard shift management, QR cryptographic token validation, exit/entry events | `apps/api/src/gate/gate.service.ts` |
| `AdminModule` / `AdminController` | People, Department, Academic Hierarchy, Roles, and Settings configuration | `apps/api/src/admin/admin.controller.ts` |
| `ExpiryService` | Scheduled background job checking and updating expired/overdue outpasses | `apps/api/src/jobs/expiry.service.ts` |
| `AuditService` | Tamper-evident hash-chained audit logging for administrative actions | `apps/api/src/audit/audit.service.ts` |
| `AppState` (Mobile) | Client reactive state, session management, permission decoding | `apps/mobile/lib/app_state.dart` |
| `ApiClient` (Mobile) | HTTP communication, token caching, API error mapping | `apps/mobile/lib/api_client.dart` |
| `DeviceKeys` (Mobile) | Client-side ECDSA P-256 key generation, hardware storage, and token signing | `apps/mobile/lib/qr_token.dart` |
| `TicketOutpass` (Mobile) | Institutional ticket UI with dynamic rotating QR and perforation notches | `apps/mobile/lib/widgets/ticket_outpass.dart` |

## Pattern Overview

**Overall:** Modular Layered Monolith (Backend) + Declarative Provider Architecture (Frontend)

**Key Characteristics:**
- **Decoupled API Modules:** NestJS dependency injection enforces clean boundaries between domains (`auth`, `outpass`, `gate`, `admin`, `audit`).
- **Cryptographic Gate Verification:** Zero-trust gate scanning where student passes rotate every 30 seconds signed with private ECDSA device keys (`v1.<passId>.<step>.<sig>`), preventing photo/screenshot sharing.
- **Dynamic Approval Chain:** Outpasses move through sequential role-based approval stages (`PENDING_TUTOR` -> `PENDING_HOD` -> `APPROVED` -> `EXITED` -> `RETURNED`).
- **Unified Reactive State:** Flutter client consumes an `AppState` ChangeNotifier to render appropriate role dashboards (`StudentScreen`, `ApproverHome`, `GuardHome`, `AdminHome`).

## Layers

**Controllers (`apps/api/src/*/*.controller.ts`):**
- Purpose: Expose REST endpoints, validate incoming request DTOs, unpack `@AuthUser()`.
- Location: `apps/api/src/`
- Depends on: Services, Guards, DTOs.
- Used by: HTTP Clients (Flutter App / Mobile / Web).

**Services (`apps/api/src/*/*.service.ts`):**
- Purpose: Execute business logic, manage state transitions, enforce institutional rules.
- Depends on: `PrismaService`, other domain services.
- Used by: Controllers.

**Data Persistence (`apps/api/src/prisma.service.ts`):**
- Purpose: Relational mapping and atomic transaction execution across PostgreSQL.
- Location: `apps/api/prisma/schema.prisma`
- Used by: Domain services.

**Mobile Presentation & State (`apps/mobile/lib/`):**
- Purpose: Responsive UI rendering across Web/Mobile/Desktop with role routing.
- Location: `apps/mobile/lib/`
- Contains: UI screens, custom painters, widgets, providers.

## Data Flow

### Primary Outpass Lifecycle Path

1. **Creation:** Student submits request via `student_screen.dart` -> `ApiClient.createOutpass()` -> `POST /v1/outpasses` (`outpass.controller.ts:40`).
2. **Tutor Approval:** Tutor views pending requests in `approver_screen.dart` -> `POST /v1/approvals/:id/decision` -> `OutpassService` transitions status to `PENDING_HOD`.
3. **HOD Approval:** HOD grants final approval -> `OutpassService` sets status to `APPROVED`, generating `passCode` and defining valid departure/return windows.
4. **Token Generation:** Student app detects `APPROVED` -> `DeviceKeys.buildToken()` generates signed token `v1.<passId>.<timestamp>.<sig>` rendered in `ticket_outpass.dart`.
5. **Gate Exit Scan:** Guard scans QR in `guard_screen.dart` -> `POST /v1/gate/scans` -> `GateService.recordScan()` validates ECDSA signature against student's registered public key, enforces single-use, transitions status to `EXITED`, and records `GateEvent`.
6. **Gate Return Scan:** Student returns -> Guard scans QR again -> `GateService` verifies return, sets status to `RETURNED`, and calculates any late minutes.

## Key Abstractions

**Cryptographic Token Scheme (`apps/api/src/gate/token-verify.ts` & `apps/mobile/lib/qr_token.dart`):**
- Purpose: Prevent pass reuse, forged screenshots, or offline spoofing.
- Pattern: Rotating time-step (30s) ECDSA P-256 digital signature with monotonic counter checks (`lastTokenTs`).

**Audit Ledger (`apps/api/src/audit/audit.service.ts`):**
- Purpose: Immutable audit log for cancellations, approvals, and administrative mutations.
- Pattern: Hash-chained log entries where each row stores `hash = sha256(prevHash + action + actor + timestamp)`.

## Entry Points

**Backend Server:**
- Location: `apps/api/src/main.ts`
- Triggers: `npm run start` / `npm run start:dev`
- Responsibilities: Bootstraps NestJS app on `PORT`, registers global `ValidationPipe` and `AllExceptionsFilter`, serves static web files.

**Mobile Application:**
- Location: `apps/mobile/lib/main.dart`
- Triggers: Flutter engine launch
- Responsibilities: Initializes `AppState`, checks cached session tokens in `flutter_secure_storage`, and routes to `LoginScreen` or role-specific home (`RootRouter`).

## Architectural Constraints

- **Phone Number Normalization:** All mobile numbers must be normalized strictly to 10 digits without leading zeroes or country codes (`normalizeMobile()`) across API and mobile.
- **Atomic Operations:** Multi-table mutations (e.g., student registration + user creation, outpass status update + gate event) must be executed within `prisma.$transaction`.
- **Clock Synchronization:** Server and client rely on UTC timestamps; gate token verification permits a ±75-second skew window.

---

*Architecture analysis: 2026-10-11*
