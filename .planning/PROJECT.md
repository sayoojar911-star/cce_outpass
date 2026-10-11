# Christ College of Engineering (CCE) Digital Outpass System

## What This Is

A secure, multi-role campus outpass management and cryptographic gate clearance platform for Christ College of Engineering, Irinjalakuda. It digitizes student outpass requests, multi-tier faculty approvals (Tutors and HODs), and fast cryptographic gate entry/exit verification for campus security guards.

## Core Value

Zero-trust, screenshot-proof campus movement authorization that guarantees only verified, currently active student passes can exit and enter campus gates in under 2 seconds.

## Business Context

- **Customer**: Christ College of Engineering administration, faculty, security force, and student body.
- **Success metric**: 100% digital pass tracking with zero gate bottlenecks (scan verdict ≤ 2s) and zero forged or reused passes.
- **Strategy notes**: Traceable to PRD v1.0 specifications (`docs/PRD.md`) and architectural decision log (`docs/decisions.md`).

## Requirements

### Validated

- [x] **FR-AUTH-02**: Phone number OTP login flow with developer mode fallback.
- [x] **FR-AUTH-03**: Cryptographic device binding via registered ECDSA P-256 public key.
- [x] **FR-STU-02/03**: Outpass request form with departure/return schedules, destinations, and purpose validation.
- [x] **FR-STU-04**: Real-time status timeline and official approval ledger display.
- [x] **FR-STU-06**: Immediate pass cancellation before departure with audit trail.
- [x] **FR-STU-08**: Rotating ECDSA P-256 QR code screen (30s refresh) active only in approved states.
- [x] **FR-TUT-02/03/04**: Tutor approval queue with student detail view, approvals, and rejections with mandatory reasons.
- [x] **FR-HOD-01/03**: HOD approval stage triggering pass code generation and validity window calculation.
- [x] **FR-SEC-01..08**: Security guard portal with camera scanning (`mobile_scanner`), manual token input fallback, and return scans.
- [x] **SEC-QR**: Time-stepped rotating token verification (`v1.<passId>.<step>.<sig>`) with monotonic counter protection.
- [x] **SEC-AC-01**: Object-level authorization for tutors, HODs, guards, and students.
- [x] **FR-APR-06**: Tamper-evident immutable approval records with server timestamps.

### Active

- [ ] **PHASE-01**: Complete Core Lifecycle & Gate Security Hardening verification and automated regression suite.
- [ ] **PHASE-02**: Administrative Console modularization and class/tutor mapping management.
- [ ] **PHASE-03**: Real-world communication integration (SMS Gateway / WhatsApp / Firebase Push Notifications).
- [ ] **PHASE-04**: Hostel Warden stage and offline gate mode with emergency backup codes.

### Out of Scope

- Biometric fingerprint/face gate scanners — Excluded; standard campus security uses QR scanners on mobile devices.
- Native device attestation (Play Integrity / App Attest) in web demo — Deferred to dedicated mobile app store release.
- Hardware gate turnstile integration — Excluded; handheld mobile scanners operated by campus guards.

## Context

- Existing full-stack codebase with NestJS backend (`apps/api`) and Flutter cross-platform client (`apps/mobile`).
- Relational PostgreSQL database managed with Prisma ORM.
- Local dev environment supports embedded PostgreSQL cluster (`localhost:5433`).
- Complete ticket-style pass redesign already implemented in `apps/mobile/lib/widgets/ticket_outpass.dart`.

## Constraints

- **Security**: Gate scanning must verify signatures and enforce single-use tokens within ≤ 2 seconds.
- **Clock Skew**: Gate token verification allows ±75 seconds clock tolerance between client device and server.
- **Platform**: Single Flutter codebase powering Web preview, Android, iOS, and Desktop.
- **Dwell Time**: Minimum 10-minute dwell required between student exit scan and return scan.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| NestJS + Prisma + Postgres + Flutter | Type safety, rapid cross-platform delivery, unified codebase | ✓ Good |
| ECDSA P-256 rotating QR tokens | Prevents pass copying, sharing, screenshotting, or proxy exit | ✓ Good |
| Atomic conditional SQL updates | Eliminates race conditions and double-exit/double-decision vulnerabilities | ✓ Good |
| Phone OTP Authentication | Mobile-first institutional student identity verification | ✓ Good |
| 30s token rotation with ±75s window | Accommodates offline drift while preventing expired pass reuse | ✓ Good |

---
*Last updated: 2026-10-11 after initial PRD docs ingestion*
