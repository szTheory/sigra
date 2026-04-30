---
phase: 95-optional-dep-boot-validation-mix-sigra-doctor-hard-02
plan: 2
subsystem: auth
tags: [optional-deps, oban, bcrypt, eqrcode, mfa, email]
requires:
  - phase: 95-01
    provides: registry-backed optional dependency metadata and tagged missing-dependency errors
provides:
  - "Registry-backed async email enforcement that only blocks explicit queue-backed delivery"
  - "Strict bcrypt migration verification that raises tagged Sigra errors at the real verification boundary"
  - "Strict TOTP QR rendering enforcement that raises instead of returning nil SVGs"
affects: [mix-sigra-doctor, optional-dependencies, email-delivery, password-verification, mfa]
tech-stack:
  added: []
  patterns: [first-use optional dependency enforcement, always-defined worker boundary, explicit non-blocking auto fallback]
key-files:
  created: []
  modified:
    - lib/sigra/delivery.ex
    - lib/sigra/workers/email_delivery.ex
    - lib/sigra/hashers/bcrypt.ex
    - lib/sigra/crypto.ex
    - lib/sigra/mfa.ex
    - test/sigra/delivery_test.exs
    - test/sigra/crypto_test.exs
    - test/sigra/mfa_test.exs
key-decisions:
  - "Kept `delivery_mode: :auto` synchronous unless Oban is actually running, while treating direct async boundaries as explicit proof that `:async_email` is enabled."
  - "Moved the email worker from disappearing compile-time gating to an always-defined module whose `new/2` enforces the registry before touching Oban."
  - "Preserved the bcrypt no-user timing-equalization fallback while making real bcrypt-hash verification and TOTP QR rendering fail with tagged Sigra dependency errors."
patterns-established:
  - "Runtime-critical optional features should call `Sigra.OptionalDeps.ensure_available!/2` at the first real use boundary instead of soft-failing or relying on missing modules."
  - "Optional async paths may degrade from `:auto` to sync only when the host did not explicitly choose async behavior."
requirements-completed: [HARD-02]
duration: 7 min
completed: 2026-04-30
---

# Phase 95 Plan 2: Runtime Optional-Dependency Enforcement Summary

**Tagged first-use dependency errors for async email, bcrypt migration verification, and TOTP QR enrollment without breaking the allowed sync and timing fallbacks**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-30T21:00:00Z
- **Completed:** 2026-04-30T21:06:53Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added registry-backed enforcement to explicit async delivery while preserving the `:auto` synchronous fallback when Oban is not running.
- Replaced the disappearing email worker pattern with an always-defined worker module that raises a tagged Sigra error on first queue-backed use if Oban is missing.
- Promoted bcrypt migration verification and TOTP QR rendering to strict tagged missing-dependency failures while keeping the no-user bcrypt timing path permissive.

## Task Commits

Each task was committed atomically:

1. **Task 1: Enforce the async email boundary without making `:auto` globally blocking** - `fd0292f` (`feat`)
2. **Task 2: Tighten bcrypt and TOTP QR runtime enforcement while preserving the one allowed fallback** - `e13f349` (`feat`)

## Files Created/Modified

- `lib/sigra/delivery.ex` - Enforces `:async_email` before job building or Oban insertion and keeps `:auto` tied to actual Oban runtime availability.
- `lib/sigra/workers/email_delivery.ex` - Keeps the worker module loadable while enforcing the registry at `new/2` instead of hiding behind compile-time conditional compilation.
- `lib/sigra/hashers/bcrypt.ex` - Routes bcrypt hasher operations through the optional-deps registry and preserves the Argon2 timing fallback for `no_user_verify/0`.
- `lib/sigra/crypto.ex` - Removes the soft missing-bcrypt `false` path and raises tagged Sigra dependency errors when real bcrypt verification is requested.
- `lib/sigra/mfa.ex` - Replaces silent QR `nil` behavior with strict `:totp_qr` enforcement during MFA enrollment.
- `test/sigra/delivery_test.exs` - Covers explicit async failure, `:auto` sync fallback, and worker-boundary enforcement.
- `test/sigra/crypto_test.exs` - Covers tagged bcrypt-migration failure instead of soft invalid-password behavior.
- `test/sigra/mfa_test.exs` - Requires real SVG output when available and asserts tagged `:totp_qr` failure when EQRCode is missing.

## Decisions Made

- Used direct async-path invocation itself as proof that async email is enabled, rather than letting `:auto` semantics make the entire delivery surface blocking.
- Kept the worker module defined even without Oban so missing dependencies fail at use time with Sigra-owned errors instead of via missing modules.
- Limited the remaining permissive bcrypt fallback to `no_user_verify/0`, which preserves the anti-enumeration timing contract without weakening real password verification.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Overriding the Oban worker `new/2` callback initially produced compile warnings because of default-argument interaction with `use Oban.Worker`. Rewriting the override without a duplicate `new/1` resolved the warning without changing behavior.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 95 runtime-critical optional dependency paths now share the same tagged-error contract established in `95-01`.
- Remaining Phase 95 plans can build on these boundaries for `mix sigra.doctor`, compile-warning proofs, and matrix validation without reintroducing ad hoc `Code.ensure_loaded?` policy checks.

## Self-Check

PASSED

- Found `.planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-02-SUMMARY.md`.
- Verified task commits `fd0292f` and `e13f349` in `git log --oneline --all`.

---
*Phase: 95-optional-dep-boot-validation-mix-sigra-doctor-hard-02*
*Completed: 2026-04-30*
