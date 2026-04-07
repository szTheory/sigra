---
phase: 03-email-flows-and-transactional-email
plan: 05
subsystem: auth
tags: [swoosh, oban, email-delivery, confirmation, password-reset, generator, hmac-tokens]

# Dependency graph
requires:
  - phase: 03-01
    provides: "Sigra.Delivery orchestration and Sigra.Mailer behaviour"
  - phase: 03-02
    provides: "Sigra.Auth confirmation/reset token generation and verification"
  - phase: 03-03
    provides: "Generated email templates (emails.ex, auth_mailer.ex)"
  - phase: 03-04
    provides: "Generated controllers and LiveViews for confirmation and reset flows"
provides:
  - "Wired auth context template connecting library functions to generated templates"
  - "Generator installs all Phase 3 templates in a single mix sigra.install run"
  - "Route injection for 8 new routes (4 confirmation + 4 reset password)"
  - "Oban queue detection/injection and Swoosh config detection"
  - "Test fixtures for email flow testing"
affects: [04-mfa, 05-oauth, 06-session-management]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Generated context delegates to Sigra.Auth library for security-critical operations"
    - "Sigra.Delivery.deliver/3 for async/sync email dispatch from generated code"
    - "confirmation_url_fun option on register_user for auto-confirmation on registration"
    - "HMAC-verified token lookup in generated get_user_by_reset_password_token"

key-files:
  created:
    - test/support/fixtures/email_fixtures.ex
    - test/sigra/install/generator_wiring_test.exs
  modified:
    - priv/templates/sigra.install/auth.ex
    - priv/templates/sigra.install/user_token.ex
    - lib/mix/tasks/sigra.install.ex
    - test/mix/tasks/sigra.install_test.exs

key-decisions:
  - "register_user accepts optional confirmation_url_fun instead of hardcoding URL pattern"
  - "deliver_user_reset_password_instructions takes email string (not user struct) for enumeration safety"
  - "Kept legacy reset_user_password/2 accepting user struct alongside new token-based version"
  - "get_user_by_reset_password_token uses direct Plug.Crypto.verify rather than non-existent Sigra.Auth.verify_reset_token"

patterns-established:
  - "Generated context -> Sigra.Auth library -> Sigra.Delivery for email flows"
  - "delivery_opts/0 centralizes mailer/mode/queue config in generated context"

requirements-completed: [CONF-01, CONF-02, CONF-04, RESET-01, RESET-02, RESET-03, RESET-04, RESET-05, EMAIL-01, EMAIL-02, EMAIL-03, EMAIL-05]

# Metrics
duration: 6min
completed: 2026-04-07
---

# Phase 3 Plan 5: Integration Wiring Summary

**Wired generated auth context to Sigra.Auth library + Sigra.Delivery for confirmation and reset email flows, updated generator to install all Phase 3 templates with route injection**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-07T03:20:15Z
- **Completed:** 2026-04-07T03:26:35Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Auth context template now sends real confirmation emails (link + 6-digit code) via Sigra.Delivery on registration
- Auth context template sends real password reset emails with enumeration prevention
- Generator installs all Phase 3 templates (emails, mailer, controllers, LiveViews) and injects 8 routes
- UserToken template handles confirm_code context with build/verify functions
- Test fixtures provide confirmation_token_fixture and reset_token_fixture helpers

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire auth context template with real email delivery** - `80ec103` (feat)
2. **Task 2: Generator updates and test fixtures** - `711409e` (feat)
3. **Task 2 fix: Add web_module binding to install test** - `08512d1` (fix)

## Files Created/Modified
- `priv/templates/sigra.install/auth.ex` - Wired confirmation and reset email delivery through Sigra.Auth + Sigra.Delivery
- `priv/templates/sigra.install/user_token.ex` - Added build_confirmation_code_token, verify_confirmation_code_query, confirm_code in days_for_context
- `lib/mix/tasks/sigra.install.ex` - Added Phase 3 templates to file list, route injection, Oban/Swoosh detection, new bindings
- `test/support/fixtures/email_fixtures.ex` - Shared test fixtures for confirmation and reset tokens
- `test/sigra/install/generator_wiring_test.exs` - 35 tests verifying template wiring, route injection, Oban/Swoosh config
- `test/mix/tasks/sigra.install_test.exs` - Fixed binding for auth context template test

## Decisions Made
- `register_user/2` accepts `confirmation_url_fun` as an option rather than hardcoding a URL path, keeping the generated context flexible for different routing configurations
- `deliver_user_reset_password_instructions/2` takes an email string (not a user struct) as its first argument, matching the enumeration-safe pattern where the caller doesn't know if the user exists
- Kept the legacy `reset_user_password(%User{}, attrs)` function alongside the new token-based `reset_user_password(signed_token, attrs)` for backward compatibility with Phase 2 code
- Used direct `Plug.Crypto.verify` + DB lookup in `get_user_by_reset_password_token` since `Sigra.Auth.verify_reset_token` is not a separate function in the library

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed install test missing web_module binding**
- **Found during:** Task 2 (verification)
- **Issue:** Pre-existing `sigra.install_test.exs` test for auth context template rendering lacked `web_module` binding, now required after Phase 3 wiring added `<%= web_module %>` references
- **Fix:** Added `web_module: "MyAppWeb"` to the test binding
- **Files modified:** test/mix/tasks/sigra.install_test.exs
- **Verification:** Test passes
- **Committed in:** 08512d1

**2. [Adaptation] Adjusted plan code to match actual library API**
- **Found during:** Task 1 (reading actual source)
- **Issue:** Plan specified `Sigra.Auth.request_password_reset` returning `{:ok, {signed_token, url, user}}` and a `Sigra.Auth.verify_reset_token` function, but actual API returns `{:ok, {encoded_token, url}}` (no user) and has no separate verify_reset_token
- **Fix:** Used `get_user_by_email` for user lookup after token generation; implemented HMAC verification directly in `get_user_by_reset_password_token` using `Plug.Crypto.verify`
- **Files modified:** priv/templates/sigra.install/auth.ex
- **Verification:** All template rendering tests pass
- **Committed in:** 80ec103

---

**Total deviations:** 2 (1 blocking fix, 1 API adaptation)
**Impact on plan:** Both necessary for correctness. No scope creep.

## Known Stubs

None. All wiring connects to real library functions implemented in Plans 01-04.

## Issues Encountered
- Pre-existing test failure in `Sigra.BehavioursTest` (assert_token_sent uses Swoosh mailbox assertion without sending email) -- not caused by this plan's changes, confirmed by running test against base commit

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 3 is now complete: all 5 plans wired together into a working confirmation and password reset system
- `mix sigra.install` will generate a complete email flow setup
- Ready for Phase 4 (MFA) which can build on the confirmation infrastructure

## Self-Check: PASSED

All 6 files verified present. All 3 commits verified in git log.

---
*Phase: 03-email-flows-and-transactional-email*
*Completed: 2026-04-07*
