---
phase: 21-passkey-liveviews-post-auth-controller
plan: 10
subsystem: auth
tags: [passkeys, webauthn, wax, plug-session, ecto-session]

requires:
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: route-backed passkey tests and gap report from plan 21-09
provides:
  - server-generated WebAuthn challenge bytes for normal registration options issuance
  - server-generated WebAuthn challenge bytes for normal authentication options issuance
  - Ecto session hydration preserving persisted mfa_pending session type
affects: [phase-21, phase-21-plan-11, passkey-options-routes, mfa-passkey-completion]

tech-stack:
  added: []
  patterns:
    - Challenge builders generate cryptographically random bytes when callers do not supply deterministic bytes
    - Session type hydration remains whitelist-based for known persisted string types

key-files:
  created:
    - .planning/phases/21-passkey-liveviews-post-auth-controller/21-10-SUMMARY.md
  modified:
    - lib/sigra/passkeys/registration.ex
    - lib/sigra/passkeys/authentication.ex
    - lib/sigra/session_stores/ecto.ex
    - test/sigra/plug/passkey_challenge_test.exs
    - test/sigra/session_stores/ecto_test.exs

key-decisions:
  - "Passkey challenge byte fallback lives in the registration and authentication builders so Plug session signing never receives nil challenge bytes."
  - "Session type hydration explicitly whitelists mfa_pending while keeping unknown persisted strings mapped to :standard."

patterns-established:
  - "Use opts[:bytes] for deterministic WebAuthn tests and :crypto.strong_rand_bytes(32) for normal route-issued ceremonies."
  - "Persisted session string types are enumerated one-by-one instead of converted to arbitrary atoms."

requirements-completed: [PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-05, PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-09, PK-UX-10, PK-UX-11, PK-UX-12]

duration: 2min
completed: 2026-04-16
---

# Phase 21 Plan 10: Passkey Runtime Gap Closure Summary

**Server-issued passkey options now carry signed non-empty challenges, and persisted MFA-pending sessions hydrate as MFA-pending.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-16T00:05:55Z
- **Completed:** 2026-04-16T00:08:07Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added TDD coverage proving registration and authentication options can issue non-empty challenge bytes without caller-supplied bytes.
- Added fallback challenge generation in the WebAuthn builders while preserving explicit deterministic bytes for completion tests.
- Added Ecto session hydration coverage for `"mfa_pending"` and mapped it to `:mfa_pending` without weakening unknown-string fallback behavior.

## Task Commits

1. **Task 1 RED: Generate non-empty challenge bytes coverage** - `d4ebee1` (test)
2. **Task 1 GREEN: Generate passkey challenge bytes** - `0c82f1e` (feat)
3. **Task 2 RED: MFA-pending session hydration coverage** - `921e30d` (test)
4. **Task 2 GREEN: Preserve MFA-pending session hydration** - `0b9f551` (fix)
5. **Formatting: Focused gap closure files** - `ee7235d` (style)

**Plan metadata:** captured in final `docs(21-10)` commit

## Files Created/Modified

- `lib/sigra/passkeys/registration.ex` - Generates 32 random challenge bytes when normal registration options calls omit `bytes:`.
- `lib/sigra/passkeys/authentication.ex` - Generates 32 random challenge bytes when normal authentication options calls omit `bytes:`.
- `lib/sigra/session_stores/ecto.ex` - Hydrates persisted `"mfa_pending"` session rows as `%Sigra.Session{type: :mfa_pending}`.
- `test/sigra/plug/passkey_challenge_test.exs` - Covers generated registration/authentication challenge bytes and signed-token byte round-trip.
- `test/sigra/session_stores/ecto_test.exs` - Covers `mfa_pending`, atom passthrough, and unknown string fallback session hydration.
- `.planning/phases/21-passkey-liveviews-post-auth-controller/21-10-SUMMARY.md` - Execution summary and self-check.

## Decisions Made

- Put byte fallback at the lowest shared challenge-builder layer so every options endpoint benefits without changing Plug session slot names or token semantics.
- Kept persisted session type hydration fail-closed by adding only the needed `"mfa_pending"` whitelist branch and leaving unknown strings as `:standard`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix format` made focused formatting changes after the task commits; these were captured in a separate `style(21-10)` commit before final verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 21-11 can verify the real options endpoints and route-level MFA passkey success without the nil challenge crash or session type hydration blocker from the Phase 21 verification report.

## Known Stubs

None.

## Threat Flags

None.

## Verification

- `mix test test/sigra/plug/passkey_challenge_test.exs` - 11 tests, 0 failures
- `mix test test/sigra/session_stores/ecto_test.exs` - 24 tests, 0 failures
- `mix test test/sigra/plug/passkey_challenge_test.exs test/sigra/session_stores/ecto_test.exs` - 35 tests, 0 failures

## Self-Check: PASSED

- Files exist: all modified runtime/test files and this summary.
- Commits exist: `d4ebee1`, `0c82f1e`, `921e30d`, `0b9f551`, `ee7235d`.

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-16*
