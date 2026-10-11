# Synthesized Requirements

**Source:** `docs/PRD.md`

## Validated / Implemented MVP Scope

- **FR-AUTH-02**: Login with mobile number and OTP (dev mode return code / production SMS).
- **FR-AUTH-03**: Cryptographic device binding via registered ECDSA P-256 public key.
- **FR-STU-02/03**: Student outpass request submission with departure, return times, destination, purpose category, and validation.
- **FR-STU-04**: Real-time status timeline and approval ledger display.
- **FR-STU-06**: Cancel outpass before departure; immediately revokes token and records audit event.
- **FR-STU-08**: Dynamic rotating QR screen with 30-second expiry indicator active only in APPROVED / EXITED / OVERDUE states.
- **FR-TUT-02/03/04**: Tutor approval queue with student detail view, approval action, and rejection with mandatory reason.
- **FR-HOD-01/03**: HOD approval queue for final approval stage, triggering validity window calculation.
- **FR-SEC-01..08**: Security guard portal with camera scanning (`mobile_scanner`), manual token input fallback, scan decision in ≤ 2 seconds, and return entry scan.
- **SEC-QR**: ECDSA P-256 signed rotating token verification with replay protection and monotonic counter.
- **SEC-AC-01**: Role-based and object-level authorization (tutor to mapped tutees, HOD to department, guards to scans).
- **FR-APR-06**: Immutable audit record for all approvals storing approver ID, stage, timestamp, and optional remarks.

## Deferred to Subsequent Milestones

- **FR-NOTIF-01**: Production push notifications (FCM), SMS gateway integration, and WhatsApp alerts.
- **FR-WAR-01**: Warden approval stage for hostel residents.
- **FR-ADM-01**: Advanced administrative reporting, analytics, and bulk CSV exports.
- **FR-SEC-09**: Offline gate scanner synchronization and backup recovery codes.
- **SEC-DEV-02**: Native hardware device attestation (Google Play Integrity & Apple App Attest).
- **FR-STU-09**: Biometric authentication gate before QR generation.
