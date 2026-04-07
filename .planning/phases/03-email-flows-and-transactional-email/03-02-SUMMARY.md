---
phase: 03-email-flows-and-transactional-email
plan: 02
subsystem: auth
tags: [hmac, confirmation, password-reset, ecto-multi, telemetry, rate-limiting, enumeration-prevention]

requires:
  - phase: 02-core-auth
    provides: "Sigra.Auth register/authenticate/magic-link, Sigra.Token, Sigra.Crypto, Sigra.RateLimiter"
provides:
  - "Sigra.Auth.generate_confirmation_token/3 -- HMAC-signed link + 6-digit code"
  - "Sigra.Auth.confirm_user/3 -- atomic confirmation via link token"
  - "Sigra.Auth.verify_confirmation_code/3 -- rate-limited 6-digit code confirmation"
  - "Sigra.Auth.request_password_reset/3 -- enumeration-safe reset with dummy timing"
  - "Sigra.Auth.reset_password/4 -- atomic password change + full session invalidation"
  - "Telemetry events for email delivery, confirmation, and reset operations"
  - "Testing helpers: assert_email_sent, extract_confirmation_token, extract_reset_token"
affects: [03-03-email-templates, 03-04-generated-context, 03-05-integration]

tech-stack:
  added: []
  patterns: ["Ecto.Multi for atomic multi-step auth operations", "HMAC-signed tokens with Plug.Crypto.sign/verify for URL-safe tokens", "Dual token strategy: link token + 6-digit code generated together", "Enumeration prevention via dummy Argon2 hash timing on non-existent emails"]

key-files:
  created: []
  modified:
    - lib/sigra/auth.ex
    - lib/sigra/telemetry.ex
    - lib/sigra/testing.ex
    - test/sigra/auth_test.exs
    - test/sigra/telemetry_test.exs
    - test/support/mock_repo_behaviour.ex

key-decisions:
  - "Used Ecto.Multi with Multi.run/3 for atomic confirmation and reset operations to ensure token cleanup and user update happen in same transaction"
  - "Token structs built via struct!/2 on user_token_schema for type safety"
  - "Rate limiter key format: sigra:confirm_code:{user_id} and sigra:reset:{email} for distinct rate limit buckets"
  - "extract_confirmation_token and extract_reset_token use List.last on path segments for flexibility with different URL structures"

patterns-established:
  - "Ecto.Multi pattern: Multi.run for operations needing conditional logic (check confirmed_at), Multi.run for cleanup (delete_all tokens)"
  - "HMAC token flow: generate raw bytes -> Plug.Crypto.sign -> Base.url_encode64 for URLs; reverse on verify"
  - "Confirmation dual-mode: link-first with code fallback, both generated together with shared cleanup"

requirements-completed: [CONF-01, CONF-02, CONF-04, CONF-06, RESET-01, RESET-02, RESET-03]

duration: 6min
completed: 2026-04-07
---

# Phase 3 Plan 02: Confirmation and Reset Auth Functions Summary

**HMAC-signed confirmation (link + 6-digit code) and enumeration-safe password reset with atomic Ecto.Multi transactions, rate limiting, and telemetry**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-07T03:04:02Z
- **Completed:** 2026-04-07T03:10:31Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added 5 new public functions to Sigra.Auth for confirmation and password reset flows
- HMAC-signed tokens via Plug.Crypto for URL-safe confirmation and reset links
- Atomic Ecto.Multi transactions ensure token cleanup and user updates happen together
- Enumeration prevention on password reset with dummy Argon2 hash timing
- Rate limiting on confirmation code attempts and reset requests
- Extended telemetry catalog with 7 new events for email/confirmation/reset operations
- Added email assertion helpers and URL token extraction to Sigra.Testing

## Task Commits

Each task was committed atomically:

1. **Task 1: Sigra.Auth confirmation and reset functions** (TDD)
   - `6cce67a` (test: failing tests for 5 new functions)
   - `3633f58` (feat: implement all 5 functions, all 34 tests pass)
2. **Task 2: Telemetry catalog and Testing helpers** (TDD)
   - `0971870` (test: failing tests for telemetry events and testing helpers)
   - `974fcfb` (feat: extend telemetry catalog and add testing helpers)

## Files Created/Modified
- `lib/sigra/auth.ex` - Added generate_confirmation_token/3, confirm_user/3, verify_confirmation_code/3, request_password_reset/3, reset_password/4
- `lib/sigra/telemetry.ex` - Extended @logged_events with 7 new events, added Email Delivery and Confirmation sections to moduledoc
- `lib/sigra/testing.ex` - Added assert_email_sent/1, extract_confirmation_token/1, extract_reset_token/1, filled assert_token_sent/2 stub
- `test/sigra/auth_test.exs` - 15 new tests for confirmation and reset functions (34 total)
- `test/sigra/telemetry_test.exs` - 8 new tests for Phase 3 telemetry events and testing helpers (18 total)
- `test/support/mock_repo_behaviour.ex` - Added transaction/1 and delete_all/1 callbacks

## Decisions Made
- Used Ecto.Multi with Multi.run/3 (not Multi.update/Multi.delete_all) because confirmation requires conditional logic (check confirmed_at before updating)
- Rate limiter key format uses prefixed keys (sigra:confirm_code:, sigra:reset:) to separate rate limit buckets
- Token extraction helpers use List.last on path segments rather than hardcoded path patterns for flexibility

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed rate_limited? helper to accept key parameter**
- **Found during:** Task 1 (implementing request_password_reset)
- **Issue:** The existing rate_limited?/4 helper hardcoded "magic_link:#{email}" as the key, preventing reuse for password reset rate limiting
- **Fix:** Changed parameter name from `email` to `key` and moved key construction to callers
- **Files modified:** lib/sigra/auth.ex
- **Verification:** Existing magic link rate limiting test still passes, new reset rate limiting test passes
- **Committed in:** 3633f58 (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Minor refactor to existing private helper for reusability. No scope creep.

## Issues Encountered
None

## Known Stubs
None - all functions are fully implemented with real logic.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Confirmation and reset library functions are ready for Plan 03 (email templates) and Plan 04 (generated context code)
- The generated Auth context will delegate to these functions
- Telemetry events are in place for email delivery tracking

---
*Phase: 03-email-flows-and-transactional-email*
*Completed: 2026-04-07*
