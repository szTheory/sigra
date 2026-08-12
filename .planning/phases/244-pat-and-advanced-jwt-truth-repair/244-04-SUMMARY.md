---
phase: 244-pat-and-advanced-jwt-truth-repair
plan: 04
subsystem: auth
tags: [jwt, joken, jose, validation, claims, audience]
requires:
  - phase: 243-credential-boundary-and-pipeline-foundation
    provides: "FetchJWT live-user and epoch validation boundary"
provides:
  - "Configured signer-first JWT verification with protected typ validation"
  - "Exact registered-claim, audience, and optional nbf enforcement"
  - "Server-owned JWT issuance claims and scopes"
affects: [244-05, jwt-01, jwt-02]
tech-stack:
  added: []
  patterns:
    - "Verify with the configured Joken signer before inspecting protected headers"
    - "Normalize all untrusted access-token validation failures to invalid_token"
key-files:
  created:
    - lib/sigra/jwt/validator.ex
  modified:
    - lib/sigra/config.ex
    - lib/sigra/jwt.ex
    - test/sigra/jwt_test.exs
    - test/sigra/jwt/signer_test.exs
key-decisions:
  - "JWT access verification runs Joken's configured signer and RequiredClaims hook before protected typ inspection."
  - "Configured audiences accept only exact scalar or non-empty all-string array intersections; nbf remains a temporal rule, not an identity anchor."
  - "Custom claim-builder data is merged before server-owned claims and scopes."
patterns-established:
  - "Keep JWT payload policy in a narrow internal validator while retaining epoch and live-user integration in Sigra.JWT."
requirements-completed: [JWT-01, JWT-02]
coverage:
  - id: D1
    description: "Configured signer, protected type, registered claims, exact audiences, and optional nbf are enforced for access JWTs."
    requirement: JWT-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/jwt_test.exs test/sigra/jwt/signer_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "Server-owned registered claims and scopes cannot be overridden by custom JWT claims."
    requirement: JWT-02
    verification:
      - kind: unit
        ref: "test/sigra/jwt_test.exs#advanced access-token contract prevents custom claims from overwriting server-owned fields"
        status: pass
    human_judgment: false
metrics:
  duration: 3min
  completed: 2026-08-12
  tasks: 1
  files: 5
status: complete
---

# Phase 244 Plan 04: Advanced JWT Contract Summary

**Access JWTs now bind configured signing, protected type, issuer, audiences, temporal validity, and server-owned claims into one fail-closed verification contract.**

## Accomplishments

- Added fail-fast JWT `typ` and non-empty unique audience configuration, with configured values emitted during issuance.
- Added a narrow validator that verifies against the configured Joken signer before reading protected `typ`, then enforces required payload claims, exact audience matching, expiration, and optional `nbf`.
- Prevented custom claim builders from overriding Sigra's registered claims or scopes while retaining Phase 243 live-user epoch validation.
- Added deterministic tests for the full signer/header/claim/audience/`nbf` matrix and reserved-claim protection.

## Task Commits

1. **Task 1: Verify one access JWT across signer, header, claims, and epoch (JWT-01)** — `b04e588d` (RED), `498060a7` (GREEN)

## Verification

- `MIX_ENV=test mix test test/sigra/jwt_test.exs test/sigra/jwt/signer_test.exs --trace` — passed, 31 tests / 0 failures.
- Re-ran the same focused suite after the tracer commit — passed, 31 tests / 0 failures.

## Files Created/Modified

- `lib/sigra/config.ex` — validates protected type and normalized accepted audiences.
- `lib/sigra/jwt/validator.ex` — signer-first claim/header validation and normalized failures.
- `lib/sigra/jwt.ex` — emits configured JWT metadata and preserves server-owned claims.
- `test/sigra/jwt_test.exs` — full deterministic access-token matrix.
- `test/sigra/jwt/signer_test.exs` — malformed JWT configuration contracts.

## Decisions Made

- Use Joken's `verify_and_validate` with `RequiredClaims` and the configured signer before protected-header inspection.
- Treat `nbf` only as an optional temporal constraint; it is not an identity or issuance authority input.
- Normalize every inbound signer/header/claim failure to `{:error, :invalid_token}` while preserving epoch mismatch behavior.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test Bug] Preserve intentionally missing claims in the failure matrix**
- **Found during:** Task 1 GREEN
- **Issue:** The initial test helper merged a complete baseline after deleting a required claim, which silently restored the deleted value.
- **Fix:** Added an exact-claims helper path so missing-claim cases exercise the intended absent payload field.
- **Files modified:** `test/sigra/jwt_test.exs`
- **Verification:** Focused JWT suite passed with independent missing and malformed cases.
- **Committed in:** `498060a7`

**Total deviations:** 1 auto-fixed (Rule 1 test bug). **Impact:** No production-scope expansion; the fix makes the planned negative tests truthful.

## Known Stubs

None.

## Self-Check: PASSED

All five planned source/test files exist, both RED/GREEN commits are present, and the focused deterministic verification suite passes.
