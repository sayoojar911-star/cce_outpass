# CCE Outpass — PRD Summary (MVP scope)

Client: Christ College of Engineering, Irinjalakuda. Full PRD v1.0 provided separately by the client.
This document condenses the requirements implemented in the MVP core loop, with the
requirement IDs used for traceability. Open questions and non-goals remain as in the original PRD.

## MVP core loop

Student requests an outpass → Tutor approves → HOD approves → rotating signed QR →
Guard scans at gate (ALLOW / DENY) → single-use exit → return scan → RETURNED.

## Lifecycle states implemented (PRD §5.1)

`PENDING_TUTOR → PENDING_HOD → APPROVED → EXITED → RETURNED`, plus
`REJECTED` (reason mandatory), `CANCELLED` (before exit), `EXPIRED` (validity passed),
`OVERDUE` (exit, not returned within expected return + 15 min grace).
Deferred: `DRAFT`, `PENDING_WARDEN`, `CLOSED_MANUAL`.

## Requirements implemented in this MVP

| ID | Requirement | Where |
|----|-------------|-------|
| FR-AUTH-02 | Login = register/staff identity + OTP (dev mode: code returned/logged; real SMS deferred) | `apps/api/src/auth` |
| FR-AUTH-03 | Device binding; account bound to device key | `POST /v1/auth/device/register` |
| FR-STU-02/03 | Request form: times, destination, purpose, type; validation | student app + `POST /v1/outpasses` |
| FR-STU-04 | Status timeline | student app |
| FR-STU-06 | Cancel before exit invalidates QR immediately | `POST /v1/outpasses/:id/cancel` |
| FR-STU-08 | QR screen only when APPROVED/EXITED/OVERDUE; 30 s rotation | student app `qr_screen.dart` |
| FR-TUT-02/03/04 | Pending list, detail, approve / reject with mandatory reason | approver app + `POST /v1/approvals/:requestId/decision` |
| FR-HOD-01/03 | HOD stage decision triggers APPROVED + validity window | approvals API |
| FR-SEC-01..08 | Gate modes, scan → result ≤ 2 s, green/red screens with reason, reuse protection, return scan | guard app + `POST /v1/gate/scans` |
| SEC-QR (§7.2–7.5) | ECDSA P-256 device key, token `v1.<id>.<ts>.<sig>`, 30 s step, ±75 s window, monotonic counter, result codes | `apps/api/src/gate/token-verify.ts` + atomic update |
| SEC-AC-01 | Object-level authorization (tutor→mapped students, HOD→department, guard→scan only) | services |
| FR-APR-06 | Every approval records approver, role, stage, comment, server timestamp | `approvals` table |
| FR-ADM-12 (partial) | Cancel by student audited | audit log |
| §7.6 offline | **Deferred** | — |
| FR-STU-15 | English only (Malayalam deferred) | — |

## Explicit MVP cuts (each maps to a PRD ID for later phases)

Admin dashboard (FR-ADM-*), warden stage (FR-WAR-*), push/SMS/WhatsApp (FR-* notifications via
channels), offline gate mode (§7.6), backup codes (§7.7), Play Integrity / App Attest (SEC-DEV-02),
biometric QR gate (FR-STU-09), policy engine (§6.9), attachments (FR-STU-02), exports (FR-ADM-06),
rate limiting (SEC-API-04), MFA for admins (SEC-AUTH-03).
