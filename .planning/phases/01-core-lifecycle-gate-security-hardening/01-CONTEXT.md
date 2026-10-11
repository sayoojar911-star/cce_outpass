# Phase 1: Core Lifecycle & Gate Security Hardening - Context

**Gathered:** 2026-10-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Verify, harden, and lock the complete end-to-end movement lifecycle ensuring 100% cryptographic gate clearance reliability and zero security vulnerabilities:
1. Student outpass request creation and status tracking.
2. Tutor and HOD multi-tier approval chain with validity window calculations.
3. Rotating ECDSA P-256 QR code token generation (`v1.<passId>.<step>.<sig>`).
4. Gate scanner clearance, debounce protection, manual pass code fallback, and minimum dwell window enforcement.

</domain>

<decisions>
## Implementation Decisions

### Gate Scanner Verdict Overlay & Feedback
- **D-01:** Full-screen verdict overlay with vibration/haptic feedback on mobile scanners.
  - **ALLOW (Green):** Large checkmark, student name, outpass display ID, type badge (`Normal` / `Emergency`), and explicit action label (`Exit OK` or `Return OK`). Auto-dismisses after 2 seconds to return straight to scanner for fast line throughput. If returning late, displays an amber warning badge: `LATE RETURN (X min)`.
  - **DENY (Red):** Large X icon, plain-language rejection reason (e.g. *"QR expired, ask the student to refresh or use their pass code"*, *"Already used at 12:26 PM"*, *"Too early, return allowed in 2 min 20 s"*, *"Pass not approved"*), plus student name when identified. **Does NOT auto-dismiss**; the guard must tap an explicit "Dismiss" button so rejections cannot be missed.
  - **Reversibility:** costly — touches gate scanner widget, overlay animations, and guard interaction loop.
- **D-02:** Scanner debouncing & concurrent scan lock. Scanner stream is debounced so a single physical frame cannot trigger duplicate API calls or double verdicts. New camera frames are ignored while the verdict modal is open.
  - **Reversibility:** reversible.
- **D-03:** Live Gate Audit View. Every scan outcome appends immediately to a rolling "Recent Gate Scans" list beneath the scanner viewfinder. All timestamps formatted in Indian Standard Time (IST). Layout must be responsive across mobile portrait and desktop/tablet browser widths.
  - **Reversibility:** reversible.

### Manual Entry & Glare Fallbacks
- **D-04:** Dedicated 6-character alphanumeric pass code input (e.g. `CCE-OP-8921` / `OP8921`) with instant lookup and guard confirmation when camera cannot scan (e.g., cracked screens or outdoor sunlight).
  - **Reversibility:** reversible.

### Minimum Dwell Time & Early-Attempt Policy
- **D-05:** Configurable Dwell Time Setting. Minimum dwell time between exit and return is a configurable database setting (`AppSetting: min_dwell_minutes`) defaulting to 5 minutes (can be set to 0 for instant testing/demo mode), replacing any hardcoded 10-minute constants. All components (constants, seed data, UI helper text, validation messages, backend guards, and tests) must read this setting dynamically.
  - **Reversibility:** costly — updates database settings, API validator, and mobile UI hints.
- **D-06:** Dwell Violation Behavior. Entry attempts prior to dwell expiry trigger a DENY verdict with a real-time countdown display (e.g. *"Too early, return allowed in 2m 20s"*). No gate override is permitted.
  - **Reversibility:** reversible.
- **D-07:** Early-Attempt Audit Logging. Every early return attempt is logged as an audit event with guard ID, outpass ID, and server UTC timestamp, visible in Admin and HOD audit portals.
  - **Reversibility:** reversible.

### Guard Shift & Location Management
- **D-08:** Gate selection (e.g., "Main Gate", "North Gate") upon guard login, persisting an active shift session until the guard explicitly taps "End Shift".
  - **Reversibility:** reversible.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Security Specs
- `docs/decisions.md` — 12 locked architectural decisions (Decisions 1–12)
- `docs/PRD.md` — §5.1 Lifecycle states & §7.2–7.5 ECDSA QR security spec
- `.planning/codebase/ARCHITECTURE.md` — System layers, token verification data flow
- `.planning/codebase/CONVENTIONS.md` — Error handling, phone normalization, transaction requirements
- `.planning/codebase/TESTING.md` — Jest and Flutter testing patterns

### Source Implementations
- `apps/api/src/gate/gate.service.ts` — Server-side gate scan processing and token verification
- `apps/api/src/gate/token-verify.ts` — Cryptographic ECDSA P-256 signature verification logic
- `apps/mobile/lib/guard_screen.dart` — Guard UI, camera scanner, and verdict presentation
- `apps/mobile/lib/qr_token.dart` — Client ECDSA token generator and key persistence

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AsyncActionHelper.run()` in `apps/mobile/lib/async_action_helper.dart` — Unified async dialog runner with 15s timeout and guaranteed error cleanup.
- `TicketOutpass` in `apps/mobile/lib/widgets/ticket_outpass.dart` — Complete institutional ticket UI with interlocking perforation notches and rotating QR code.
- `AllExceptionsFilter` in `apps/api/src/common/all-exceptions.filter.ts` — Centralized error filter returning uniform JSON error responses.

### Established Patterns
- Atomic Prisma transactions (`this.prisma.$transaction`) for state changes.
- Server-side UTC comparisons with IST presentation formatting (`intl` package).
- Phone normalization strictly to 10 digits (`normalizeMobile()`).

</code_context>

<specifics>
## Specific Ideas

- Guard full-screen Green overlay auto-dismisses after 2 seconds; Red overlay requires manual dismissal.
- Late returns highlight amber warning badge (`LATE RETURN (X min)`).
- Minimum dwell time is configurable in `AppSetting` (default: 5 min, 0 for dev/test).
- Early return attempts show live countdown (`Too early, return allowed in 2m 20s`).

</specifics>

<deferred>
## Deferred Ideas

- SMS & WhatsApp alerts to parents on gate exit (Phase 3).
- Offline gate verification cache with local signature verification and backup codes (Phase 4).
- Hostel Warden approval stage for residential students (Phase 4).

</deferred>

---

*Phase: 01-core-lifecycle-gate-security-hardening*
*Context gathered: 2026-10-11*
