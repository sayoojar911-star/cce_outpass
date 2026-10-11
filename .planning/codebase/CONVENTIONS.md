---
last_mapped_commit: c4fce159181245c0e342cc4825e08bf487a2910c
last_mapped_at: 2026-10-11
---
# Coding Conventions

**Analysis Date:** 2026-10-11

## Naming Patterns

**Files:**
- Backend: kebab-case with type suffix (`auth.service.ts`, `all-exceptions.filter.ts`, `schema.prisma`)
- Frontend: snake_case for all Dart files (`ticket_outpass.dart`, `async_action_helper.dart`)

**Functions & Methods:**
- camelCase in both TypeScript and Dart (`normalizeMobile()`, `recordScan()`, `buildToken()`)
- Private Dart functions and variables prefixed with leading underscore (`_submit()`, `_busy`, `_tabController`)

**Variables & Properties:**
- camelCase (`tutorId`, `expectedReturnAt`, `clientScanId`, `accessToken`)

**Types & Classes:**
- PascalCase for TypeScript classes, interfaces, enums, and Dart widgets (`OutpassService`, `Approval`, `ScanDirection`, `TicketOutpass`, `AppState`)

## Code Style

**Formatting:**
- TypeScript: Standard Prettier / NestJS formatting (2 spaces, double quotes, trailing commas where appropriate)
- Dart: `dart format` (2 spaces, trailing commas in widget build trees for optimal multi-line formatting)

**Linting:**
- Backend: TypeScript strict checking (`tsc --noEmit` via `npm run lint`)
- Frontend: `flutter_lints` 6.0.0 (`analysis_options.yaml`) with 0 warnings enforced

## Import Organization

**TypeScript (`apps/api`):**
1. External framework packages (`@nestjs/common`, `@nestjs/core`, `@nestjs/jwt`)
2. Third-party libraries (`class-validator`, `crypto`, `rxjs`)
3. Internal shared modules & decorators (`../common/auth.decorator.ts`)
4. Local module services & DTOs (`./dto`, `./outpass.service.ts`)

**Dart (`apps/mobile`):**
1. Dart core and SDK packages (`dart:async`, `dart:convert`, `dart:math`)
2. Flutter framework (`package:flutter/material.dart`)
3. External pub dependencies (`package:provider/provider.dart`, `package:qr_flutter/qr_flutter.dart`)
4. Internal project files (`package:cce_outpass/theme/app_theme.dart`, `widgets/ticket_outpass.dart`)

## Error Handling

**Backend (`apps/api`):**
- Standard NestJS HTTP exceptions (`ConflictException`, `BadRequestException`, `NotFoundException`, `ForbiddenException`, `UnauthorizedException`)
- Global catch-all filter `AllExceptionsFilter` (`apps/api/src/common/all-exceptions.filter.ts`) guaranteeing uniform JSON error responses:
  ```json
  {
    "statusCode": 409,
    "timestamp": "2026-10-11T09:00:00.000Z",
    "path": "/v1/admin/users",
    "message": "A user with mobile 9895061553 already exists"
  }
  ```
- Atomic transaction rollbacks: multi-step database mutations must use `this.prisma.$transaction(async (tx) => { ... })`.

**Frontend (`apps/mobile`):**
- Unified async execution helper: `AsyncActionHelper.run(context, ...)` (`apps/mobile/lib/async_action_helper.dart`).
- Standard 15-second timeouts with `try/catch/finally` blocks ensuring busy spinners are reset even upon network failure.
- User-facing error notifications via styled `SnackBar` dialogs.

## Logging

**Framework:**
- Backend: Built-in NestJS `Logger` (`new Logger(ServiceName.name)`)
- Frontend: `debugPrint()` or structured UI status indicators

## Function Design

**Size:**
- Single responsibility; business logic isolated in service methods.
- UI build methods broken down into focused helper widgets or private builder functions (`_buildDetailTile()`, `_buildApprovalLedger()`).

**Sanitization & Validation:**
- Strict input sanitization at the boundary:
  - Phone normalization: `normalizeMobile(mobile)` strips non-digits, country code `+91`, and enforces exactly 10 digits.
  - Foreign keys: empty string IDs sanitized to `null` (`tutorId === "" ? null : tutorId`).

---

*Convention analysis: 2026-10-11*
