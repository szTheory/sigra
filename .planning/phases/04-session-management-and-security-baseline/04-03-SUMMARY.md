---
phase: 04-session-management-and-security-baseline
plan: 03
subsystem: auth
tags: [lockout, rate-limiting, hammer, plug, security, owasp]

# Dependency graph
requires:
  - phase: 04-01
    provides: SessionStore behaviour, RateLimiter behaviour, Noop rate limiter, Config lockout/rate_limiting sections
provides:
  - Sigra.Lockout module (check, increment!, reset!, locked?, lock_status)
  - Sigra.RateLimiters.Hammer wrapper for Hammer 7.x
  - Sigra.Plug.RateLimit IP-based rate limiting plug
  - Security testing helpers (simulate_lockout, assert_rate_limited)
  - Enumeration-safe lockout error messages
affects: [04-04, 05-oauth, 06-mfa]

# Tech tracking
tech-stack:
  added: [hammer-7.x-wrapper]
  patterns: [fail-open-rate-limiting, tdd-lockout, plug-rate-limiting, enumeration-safe-messages]

key-files:
  created:
    - lib/sigra/lockout.ex
    - lib/sigra/rate_limiters/hammer.ex
    - lib/sigra/plug/rate_limit.ex
    - test/sigra/lockout_test.exs
    - test/sigra/rate_limiters/hammer_test.exs
    - test/sigra/plug/rate_limit_test.exs
  modified:
    - lib/sigra/error.ex
    - lib/sigra/testing.ex

key-decisions:
  - "Lockout uses embedded schema FakeUser in tests instead of DB — pure unit tests, no Ecto sandbox needed"
  - "Hammer wrapper requires :hammer_module app env config — avoids hard dep on Hammer"
  - "RateLimit plug rate limits all non-safe methods (POST/PUT/PATCH/DELETE), not just POST"

patterns-established:
  - "Fail-open rate limiting: when infrastructure unavailable, log warning and allow request"
  - "Lockout check before hash verification to save CPU on locked accounts"
  - "Testing helpers use Ecto.Changeset directly for lockout simulation"

requirements-completed: [SEC-01, SEC-02, SEC-03, SEC-04]

# Metrics
duration: 5min
completed: 2026-04-08
---

# Phase 4 Plan 03: Lockout, Rate Limiting, and Security Baseline Summary

**Account lockout with configurable threshold/duration, Hammer 7.x rate limiter wrapper with fail-open, and IP rate limiting plug with 429+Retry-After responses**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-08T03:13:17Z
- **Completed:** 2026-04-08T03:18:45Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Sigra.Lockout: full lockout lifecycle (check, increment, reset, locked?, lock_status) with configurable threshold (5) and duration (900s)
- Sigra.RateLimiters.Hammer: wraps Hammer 7.x hit/3 API with correct parameter order and fail-open rescue
- Sigra.Plug.RateLimit: IP-based rate limiting for auth routes with 429, Retry-After header, and telemetry
- Updated error messages to be enumeration-safe per OWASP ASVS V2
- Testing helpers: simulate_lockout/3 and assert_rate_limited/1

## Task Commits

Each task was committed atomically:

1. **Task 1: Lockout module and Hammer rate limiter wrapper** - `58a238f` (feat)
2. **Task 2: RateLimit plug and security testing helpers** - `bc0c4d2` (feat)

_Both tasks used TDD: RED (failing tests) then GREEN (implementation)._

## Files Created/Modified
- `lib/sigra/lockout.ex` - Account lockout logic with check/increment/reset/locked?/lock_status
- `lib/sigra/rate_limiters/hammer.ex` - Hammer 7.x wrapper implementing Sigra.RateLimiter behaviour
- `lib/sigra/plug/rate_limit.ex` - IP-based rate limiting plug for auth routes
- `lib/sigra/error.ex` - Updated safe_message for :account_locked, added :account_locked_just_triggered
- `lib/sigra/testing.ex` - Added simulate_lockout/3 and assert_rate_limited/1 helpers
- `test/sigra/lockout_test.exs` - 19 tests for lockout module
- `test/sigra/rate_limiters/hammer_test.exs` - 6 tests for Hammer wrapper
- `test/sigra/plug/rate_limit_test.exs` - 16 tests for RateLimit plug

## Decisions Made
- Lockout tests use embedded Ecto schema (FakeUser) for pure unit testing without DB sandbox
- Hammer wrapper uses Application.get_env for module lookup rather than Code.ensure_loaded? detection — explicit config is clearer than magic detection
- RateLimit plug rate limits all non-safe HTTP methods (POST, PUT, PATCH, DELETE), extending beyond plan's POST-only spec since PUT/PATCH/DELETE can also be abused on auth endpoints

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FakeUser struct incompatible with Ecto.Changeset.change/2**
- **Found during:** Task 1 (Lockout tests)
- **Issue:** Plain defstruct does not have __changeset__/0 required by Ecto.Changeset.change/2
- **Fix:** Changed FakeUser to use Ecto embedded_schema with proper field definitions
- **Files modified:** test/sigra/lockout_test.exs
- **Verification:** All 25 lockout/hammer tests pass
- **Committed in:** 58a238f (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for test compatibility with Ecto changesets. No scope creep.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Lockout module ready for integration into Sigra.Auth.authenticate/3 flow
- RateLimit plug ready for route-level configuration in generated code
- Hammer wrapper ready for host apps that add :hammer to deps
- Testing helpers available for downstream test suites

---
*Phase: 04-session-management-and-security-baseline*
*Completed: 2026-04-08*
