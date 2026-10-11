# Roadmap: Christ College of Engineering (CCE) Digital Outpass System

## Overview

The CCE Outpass roadmap guides the evolution from the core cryptographic loop through production-grade operations:
1. Hardening and verifying the complete Student → Tutor → HOD → Gate Guard core lifecycle.
2. Modularizing the administrative console and expanding academic hierarchy controls.
3. Adding production notification channels (SMS & Push alerts).
4. Delivering specialized workflows (Hostel Warden stage) and offline gate tolerance.

## Phases

- [ ] **Phase 1: Core Lifecycle & Gate Security Hardening** - Verify and lock the complete student outpass request, dual-tier faculty approval, rotating ECDSA token generation, and gate clearance loop.
- [ ] **Phase 2: Administrative Modularization & Academic Controls** - Decompose monolithic admin screens, support batch student-tutor assignments, and dynamic department workflows.
- [ ] **Phase 3: Multi-Channel Notifications** - Integrate FCM push notifications, automated parent SMS alerts on gate exit, and WhatsApp webhooks.
- [ ] **Phase 4: Warden Stage & Offline Gate Scanning** - Introduce hostel warden approvals and offline gate scanner cryptographic cache with emergency codes.

## Phase Details

### Phase 1: Core Lifecycle & Gate Security Hardening
**Goal**: Verify, test, and lock the complete end-to-end movement loop ensuring 100% cryptographic gate clearance reliability and zero security vulnerabilities.
**Depends on**: Nothing (First phase)
**Requirements**: [AUTH-01, AUTH-02, AUTH-03, STU-01, STU-02, STU-03, STU-04, APR-01, APR-02, APR-03, APR-04, SEC-01, SEC-02, SEC-03, SEC-04]
**Success Criteria** (what must be TRUE):
  1. Student can submit an outpass, view approval timeline, and see dynamic rotating QR only after tutor and HOD approve.
  2. Guard scanner verifies ECDSA cryptographic signature in ≤ 2 seconds, grants single-use exit, and correctly records return entry.
  3. Canceling or re-scanning an already-used pass immediately displays DENY with an explicit tamper-evident audit record.
  4. All unit, widget, and end-to-end automated verification scripts pass with 0 regressions.
**Plans**: 2 plans

Plans:
- [ ] 01-01: End-to-end regression validation and gate token verification test suite.
- [ ] 01-02: Ticket UI and async error handling verification across client platforms.

### Phase 2: Administrative Modularization & Academic Controls
**Goal**: Modularize the administrative console and enhance department/tutor assignment workflows.
**Depends on**: Phase 1
**Requirements**: [ADMIN-01]
**Success Criteria** (what must be TRUE):
  1. Monolithic admin screen decomposed into modular tabs (`people`, `departments`, `monitor`, `settings`).
  2. Administrators can batch-assign students to tutors by class, year, and department.
**Plans**: TBD

### Phase 3: Multi-Channel Notifications
**Goal**: Provide real-time automated alerts to students, staff, and parents upon movement events.
**Depends on**: Phase 2
**Requirements**: [NOTIF-01, NOTIF-02]
**Success Criteria** (what must be TRUE):
  1. Students receive push notifications when outpass is approved or rejected.
  2. Parents receive automated SMS notification when student exits and returns campus gate.
**Plans**: TBD

### Phase 4: Warden Stage & Offline Gate Scanning
**Goal**: Extend approval chain to hostel residents and protect against network drops at campus gates.
**Depends on**: Phase 3
**Requirements**: [WARDEN-01, OFFLINE-01]
**Success Criteria** (what must be TRUE):
  1. Hostel resident outpasses require Warden approval prior to gate clearance.
  2. Gate guards can verify authentic passes offline using public key cache and backup codes.
**Plans**: TBD
