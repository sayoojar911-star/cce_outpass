# Synthesized Decisions

**Source:** `docs/decisions.md`

## ADR-01: Framework and Architecture
- **source**: `docs/decisions.md` (Decision 1)
- **status**: locked (Accepted)
- **decision**: Stack is NestJS + Prisma + PostgreSQL (Docker/embedded) + Flutter (single unified client with role-based interface).

## ADR-02: Flutter Web & Multi-Platform Support
- **source**: `docs/decisions.md` (Decision 2)
- **status**: locked (Accepted)
- **decision**: Flutter targets Web first for zero-install demo/access, and native Android/iOS builds for mobile deployments.

## ADR-03: ECDSA P-256 Device Keys
- **source**: `docs/decisions.md` (Decision 3)
- **status**: locked (Accepted)
- **decision**: Student device binding uses ECDSA P-256 public/private key pairs. Web uses WebCrypto; mobile uses secure hardware storage.

## ADR-04: Rotating QR Token Specification
- **source**: `docs/decisions.md` (Decision 4)
- **status**: locked (Accepted)
- **decision**: Token format is `v1.<outpass_uuid>.<ts30s>.<ECDSA-P256-SHA256 DER, base64url>`. Server verifies signature within a ±75-second skew window and enforces monotonic counter (`last_token_ts`).

## ADR-05: DER Signature Encoding
- **source**: `docs/decisions.md` (Decision 5)
- **status**: locked (Accepted)
- **decision**: Server accepts standard DER-encoded ECDSA signatures.

## ADR-06: Atomic Database Transitions
- **source**: `docs/decisions.md` (Decision 6)
- **status**: locked (Accepted)
- **decision**: State transitions use atomic conditional updates (`UPDATE ... WHERE status = expected`) and unique constraint `(request_id, stage)` preventing double decisions.

## ADR-07: Authentication & OTP
- **source**: `docs/decisions.md` (Decision 7)
- **status**: locked (Accepted)
- **decision**: Mobile number + OTP identity flow with dev bypass for local environments.

## ADR-08: Validity Window Calculation
- **source**: `docs/decisions.md` (Decision 8)
- **status**: locked (Accepted)
- **decision**: On final approval: `valid_from = requested exit time`, `valid_until = expected return`; if return time is already in the past, window is set to now → now + 60 min.

## ADR-09: Gate Minimum Dwell Window
- **source**: `docs/decisions.md` (Decision 9)
- **status**: locked (Accepted)
- **decision**: Enforce minimum dwell time of 10 minutes between exit scan and return entry scan.
