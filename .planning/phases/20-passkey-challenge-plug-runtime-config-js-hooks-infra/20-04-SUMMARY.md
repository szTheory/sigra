---
phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
plan: 04
subsystem: auth
tags: [passkeys, plug, tokens, tests, webauthn]
requires:
  - phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
    provides: PK-06 passkey challenge issue/verify flow and focused verifier coverage
provides:
  - Deterministic tamper regression coverage for `Sigra.Plug.PasskeyChallenge.verify/5`
  - Explicit invalid-token early return before challenge reconstruction or callback execution
affects: [phase-20-verification, phase-21-passkey-ui, passkeys, plug-session]
tech-stack:
  added: []
  patterns:
    - Tamper regressions mutate the stored signed token bytes directly and prove callback non-execution with an explicit side effect assertion
    - Passkey challenge verification isolates signed-token decoding before rebuilding `Wax.Challenge`
key-files:
  created:
    - .planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-04-SUMMARY.md
  modified:
    - lib/sigra/plug/passkey_challenge.ex
    - test/sigra/plug/passkey_challenge_test.exs
key-decisions:
  - "The PK-06 regression now flips a byte in the stored signed token itself instead of replacing a trailing character, making tamper rejection deterministic."
  - "verify/5 now routes signed-token verification through a dedicated helper so invalid-token exits stay explicit before challenge reconstruction and callback execution."
patterns-established:
  - "Signed-token tamper tests should prove callback non-execution with a local side effect assertion, not only a `flunk/1` branch."
requirements-completed: [PK-06]
duration: 10min
completed: 2026-04-15
---

# Phase 20 Plan 04: PK-06 Tamper Regression Summary

**Deterministic signed-token tamper coverage for passkey challenge verification, with an explicit early-return path before callback execution**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-15T17:51:00Z
- **Completed:** 2026-04-15T18:01:11Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Replaced the flaky PK-06 tamper test with a deterministic byte-flip mutation against the stored signed token.
- Added an explicit callback-boundary proof via `send/2` plus `refute_received`, while keeping the preserved-session assertion intact.
- Clarified `Sigra.Plug.PasskeyChallenge.verify/5` so signed-token failures return before challenge reconstruction or callback invocation.

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace the flaky tamper regression with a deterministic callback-boundary proof** - `b899deb` (test)
2. **Task 2: Tighten the verify path only if needed to keep tamper rejection unambiguous** - `9865e69` (fix)

## Files Created/Modified
- `test/sigra/plug/passkey_challenge_test.exs` - Deterministic tamper regression using a raw-token byte flip, strict `:invalid` expectation, and a callback side-effect assertion.
- `lib/sigra/plug/passkey_challenge.ex` - Early signed-token verification helper that keeps invalid-token exits explicit before challenge reconstruction.

## Decisions Made
- Mutated the stored signed token directly because `Sigra.Token.generate/4` returns the raw `Plug.Crypto` token, not a base64 wrapper.
- Kept the implementation change narrow and behavior-preserving: success-path contracts, slot names, and delete-on-success semantics are unchanged.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- The first draft of the new tamper spec assumed the stored token was base64-encoded; the RED run proved it was the raw signed token, so the final deterministic mutation flips a byte in the stored token itself.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- PK-06 is re-verified in the focused Phase 20 subset with deterministic tamper coverage.
- Phase 20 verification can now rely on an explicit proof that invalid signed challenge tokens never cross the callback boundary.

## Self-Check: PASSED

- Verified `.planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-04-SUMMARY.md` exists.
- Verified task commits `b899deb` and `9865e69` exist in git history.

---
*Phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra*
*Completed: 2026-04-15*
