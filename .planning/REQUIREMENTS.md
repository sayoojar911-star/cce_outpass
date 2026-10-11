# Requirements: CCE Digital Outpass System

**Defined:** 2026-10-11
**Core Value:** Zero-trust, screenshot-proof campus movement authorization that guarantees only verified, currently active student passes can exit and enter campus gates in under 2 seconds.

## v1 Requirements

Requirements for initial system stabilization and core release.

### Authentication & Device Binding

- [x] **AUTH-01**: User can log in using registered mobile number and OTP verification (`FR-AUTH-02`).
- [x] **AUTH-02**: Device registers public ECDSA P-256 key upon initial login (`FR-AUTH-03`).
- [x] **AUTH-03**: Dual-token session (JWT access + database-backed refresh token) maintains user session.

### Outpass Request & Student Portal

- [x] **STU-01**: Student can submit outpass request with departure time, return time, destination, and category (`FR-STU-02/03`).
- [x] **STU-02**: Student can view status timeline and official approval ledger (`FR-STU-04`).
- [x] **STU-03**: Student can cancel active pass before departure, invalidating pass immediately (`FR-STU-06`).
- [x] **STU-04**: Student app renders institutional ticket outpass with rotating 30s QR code (`FR-STU-08`).

### Faculty Approval Workflow

- [x] **APR-01**: Assigned tutor can view pending outpass requests for mapped students (`FR-TUT-02`).
- [x] **APR-02**: Tutor can approve or reject with mandatory reason (`FR-TUT-03/04`).
- [x] **APR-03**: Department HOD can review tutor-approved passes and grant final approval (`FR-HOD-01/03`).
- [x] **APR-04**: Approval transitions trigger validity window calculation and pass code generation.

### Gate Clearance & Security

- [x] **SEC-01**: Security guards can scan QR passes using device camera or manual token entry (`FR-SEC-01/08`).
- [x] **SEC-02**: Server cryptographically verifies ECDSA signature, valid time window, and monotonic counter in ≤ 2s (`SEC-QR`).
- [x] **SEC-03**: Gate scanner enforces single-use exit; re-scanning an exited pass displays DENY.
- [x] **SEC-04**: Guard scans returning student to mark outpass RETURNED and records arrival time.

## v2 Requirements (Roadmap Backlog)

### Communications & Alerts

- [ ] **NOTIF-01**: Real-time push notifications via Firebase Cloud Messaging on approval decisions.
- [ ] **NOTIF-02**: Production SMS gateway integration for automated parental exit/entry notifications.

### Specialized Approvals

- [ ] **WARDEN-01**: Hostel warden approval stage for hostel resident students before gate exit.

### Operations & Reliability

- [ ] **OFFLINE-01**: Offline gate scanning capability with cryptographic certificate authority check and backup codes.
- [ ] **ADMIN-01**: Advanced administrative reporting, attendance integration, and audit log exports.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Validated |
| AUTH-02 | Phase 1 | Validated |
| AUTH-03 | Phase 1 | Validated |
| STU-01 | Phase 1 | Validated |
| STU-02 | Phase 1 | Validated |
| STU-03 | Phase 1 | Validated |
| STU-04 | Phase 1 | Validated |
| APR-01 | Phase 1 | Validated |
| APR-02 | Phase 1 | Validated |
| APR-03 | Phase 1 | Validated |
| APR-04 | Phase 1 | Validated |
| SEC-01 | Phase 1 | Validated |
| SEC-02 | Phase 1 | Validated |
| SEC-03 | Phase 1 | Validated |
| SEC-04 | Phase 1 | Validated |
| NOTIF-01 | Phase 3 | Pending |
| NOTIF-02 | Phase 3 | Pending |
| WARDEN-01 | Phase 4 | Pending |
| OFFLINE-01 | Phase 4 | Pending |
| ADMIN-01 | Phase 2 | Pending |
