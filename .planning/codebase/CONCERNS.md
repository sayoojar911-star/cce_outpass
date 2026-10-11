---
last_mapped_commit: c4fce159181245c0e342cc4825e08bf487a2910c
last_mapped_at: 2026-10-11
---
# Codebase Concerns

**Analysis Date:** 2026-10-11

## Tech Debt

**Monolithic Mobile Admin Console:**
- Issue: `apps/mobile/lib/admin_screen.dart` is over 118 KB and contains hundreds of lines of dialog state, tab handling, and modal controllers in a single file.
- Files: `apps/mobile/lib/admin_screen.dart`
- Impact: High cognitive overhead when adding new administrative features; risk of regression when modifying shared tab controllers or state variables.
- Fix approach: Refactor into separate feature widgets under `apps/mobile/lib/admin/` (e.g. `people_tab.dart`, `departments_tab.dart`, `passes_monitor_tab.dart`).

**Dev-Mode OTP Bypass:**
- Issue: In development and test environments, OTP is logged to console or returned directly, and real SMS delivery is bypassed.
- Files: `apps/api/src/auth/auth.service.ts`
- Impact: Cannot deploy to production without provisioning real SMS / WhatsApp gateway provider (e.g. Twilio, MSG91, Firebase Auth).
- Fix approach: Implement an environment-driven notification / SMS strategy provider (`SmsService` interface with `DevSmsProvider` and `FirebaseSmsProvider`).

**Role & Permissions Hybrid Model:**
- Issue: The database contains both legacy static `role` strings (e.g. `"STUDENT"`, `"TUTOR"`) and dynamic `Role` entities with customizable permission arrays (`Role.permissions`).
- Files: `apps/api/prisma/schema.prisma`, `apps/api/src/common/roles.guard.ts`, `apps/api/src/common/permissions.guard.ts`
- Impact: Codebase occasionally checks both role names and permissions, leading to dual maintenance.
- Fix approach: Fully migrate all authorization to fine-grained permission checks (`RequirePermissions(...)`) and deprecate static role string branching.

## Known Bugs & Resolved Gotchas

**Empty Tutor Assignment on Student Creation (Resolved):**
- Symptoms: When creating a student without an assigned tutor, the mobile dialog hung on "Saving..." and backend failed.
- Files: `apps/api/src/admin/admin.controller.ts`, `apps/mobile/lib/admin_screen.dart`
- Resolution: Empty strings sanitized to `null`, user & student creation wrapped in atomic `prisma.$transaction`, and `AsyncActionHelper` guaranteed `_busy = false` restoration with 15s timeout.
- Verification: Regression covered by `admin-student-registration.spec.ts` and `admin_register_person_test.dart`.

## Security Considerations

**Cryptographic Token Verification:**
- Risk: Replay attacks or forged gate passes.
- Files: `apps/api/src/gate/gate.service.ts`, `apps/api/src/gate/token-verify.ts`, `apps/mobile/lib/qr_token.dart`
- Current mitigation: Pass tokens are signed with client-side ECDSA P-256 keys, rotate every 30 seconds, enforce a strict ±75s time window, and enforce monotonic counter checks (`lastTokenTs`).
- Recommendations: Ensure devices revoke private keys on logout and implement client-side hardware attestation (Play Integrity / App Attest) before production release.

**Rate Limiting & Abuse Prevention:**
- Risk: Brute-forcing OTP codes or overwhelming gate scanner endpoints.
- Current mitigation: Basic in-memory rate limiting state in `GateService`.
- Recommendations: Implement Redis-backed rate limiting middleware using `@nestjs/throttler` for distributed deployments.

## Performance & Scalability

**Gate Scanning Latency:**
- Target: Gate check and verdict in ≤ 2 seconds at campus gates.
- Current status: Fast in-memory ECDSA verification and local database query; latency is < 200ms in local testing.
- Considerations: Ensure database indexes on `OutpassRequest(passCode)`, `OutpassRequest(status)`, and `Device(userId)` are maintained under high load during peak exit hours.

---

*Concerns analysis: 2026-10-11*
