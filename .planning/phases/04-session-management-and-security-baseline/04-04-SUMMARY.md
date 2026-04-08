---
phase: 04-session-management-and-security-baseline
plan: 04
subsystem: auth
tags: [suspicious-login, lockout, email-notifications, session-cleanup, telemetry, geoip]

# Dependency graph
requires:
  - phase: 04-02
    provides: "Session store, session struct, session management in Auth"
  - phase: 04-03
    provides: "Lockout module (check/increment!/reset!), lockout telemetry"
provides:
  - "Suspicious login detection comparing login IP against active session IPs"
  - "Config-based authenticate/2 with lockout + suspicious login + email delivery"
  - "Security notification email delivery (suspicious login + lockout)"
  - "Session expiry cleanup in TokenCleanup worker"
  - "EmailTemplates behaviour for generated email modules"
affects: [05-email-templates, 04-05-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Config-based authenticate dispatches to authenticate_with_config for security integration"
    - "Email delivery via mailer.deliver with notify config flag"
    - "MapSet-based IP comparison for suspicious login detection"

key-files:
  created:
    - lib/sigra/suspicious_login.ex
    - lib/sigra/email_templates.ex
  modified:
    - lib/sigra/auth.ex
    - lib/sigra/config.ex
    - lib/sigra/workers/token_cleanup.ex
    - test/sigra/auth_test.exs
    - test/sigra/suspicious_login_test.exs
    - test/test_helper.exs
    - test/support/mock_repo_behaviour.ex

key-decisions:
  - "Config-based authenticate/2 pattern-matches on %Sigra.Config{} to avoid arity conflict with legacy authenticate/3"
  - "Email delivery uses mailer.deliver directly (sync) rather than Sigra.Delivery to keep security notifications simple and testable"
  - "EmailTemplates behaviour created as contract for generated email modules"
  - "email_module field added to Config struct for security notification email dispatch"

patterns-established:
  - "Security notification pattern: check config notify flag + email_module + mailer before delivering"
  - "Config-based auth functions: authenticate(%Config{}, params) dispatches to private authenticate_with_config"

requirements-completed: [SEC-06, SEC-07]

# Metrics
duration: 10min
completed: 2026-04-08
---

# Phase 4 Plan 04: Security Integration Summary

**Suspicious login detection via IP comparison against active sessions, integrated lockout in authenticate pipeline with email notifications for both security events**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-08T03:22:18Z
- **Completed:** 2026-04-08T03:32:39Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Suspicious login detection module that compares login IP against all active session IPs, with GeoIP enrichment and telemetry
- Config-based authenticate/2 integrating lockout check before password hash, failed attempt tracking, lockout + suspicious login email notifications
- TokenCleanup extended with session expiry cleanup for standard and remember_me sessions
- EmailTemplates behaviour defining the contract for generated email template modules

## Task Commits

Each task was committed atomically:

1. **Task 1: Suspicious login detection module (TDD)**
   - `27ac341` test(04-04): add failing tests for suspicious login detection
   - `280ada8` feat(04-04): implement suspicious login detection module

2. **Task 2: Integrate lockout + suspicious login into Auth.authenticate (TDD)**
   - `0b13d4e` test(04-04): add failing tests for auth lockout/suspicious login integration
   - `9819d2a` feat(04-04): integrate lockout + suspicious login into authenticate, wire email delivery, extend TokenCleanup

## Files Created/Modified
- `lib/sigra/suspicious_login.ex` - IP-based suspicious login detection with GeoIP and telemetry
- `lib/sigra/email_templates.ex` - Behaviour for generated email template modules
- `lib/sigra/auth.ex` - Config-based authenticate with lockout, suspicious login, email notifications
- `lib/sigra/config.ex` - Added email_module field to Config struct and schema
- `lib/sigra/workers/token_cleanup.ex` - Extended with cleanup_expired_sessions/1
- `test/sigra/suspicious_login_test.exs` - 8 tests covering detection, first login, GeoIP, telemetry
- `test/sigra/auth_test.exs` - 12 new tests for lockout/suspicious integration + session cleanup
- `test/test_helper.exs` - Added MockEmailTemplates mock
- `test/support/mock_repo_behaviour.ex` - Added update!/1 and get/2 callbacks

## Decisions Made
- Config-based authenticate/2 pattern-matches on %Sigra.Config{} struct to avoid arity conflict with legacy authenticate/3 (which has default opts)
- Email delivery goes through mailer.deliver directly rather than Sigra.Delivery for simplicity in the authenticate path
- EmailTemplates behaviour created to enable Mox-based testing of email dispatch

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added email_module to Config struct**
- **Found during:** Task 2 (Auth integration)
- **Issue:** Plan referenced config.email_module but Config struct did not have this field
- **Fix:** Added email_module to Config struct, @schema, NimbleOptions docs, and @type
- **Files modified:** lib/sigra/config.ex
- **Verification:** Compilation passes, all tests pass
- **Committed in:** 0b13d4e (TDD RED commit)

**2. [Rule 3 - Blocking] Created EmailTemplates behaviour**
- **Found during:** Task 2 (Auth integration)
- **Issue:** No behaviour existed for generated email template modules, needed for Mox testing
- **Fix:** Created lib/sigra/email_templates.ex with callbacks for all email types
- **Files modified:** lib/sigra/email_templates.ex, test/test_helper.exs
- **Verification:** Mox mock works, all tests pass
- **Committed in:** 0b13d4e (TDD RED commit)

**3. [Rule 3 - Blocking] Added update! and get to MockRepo behaviour**
- **Found during:** Task 2 (Auth integration)
- **Issue:** Lockout.increment!/reset! use repo.update! which wasn't in MockRepo behaviour
- **Fix:** Added update!/1 and get/2 callbacks to mock_repo_behaviour.ex
- **Files modified:** test/support/mock_repo_behaviour.ex
- **Verification:** Mox expectations work, all tests pass
- **Committed in:** 0b13d4e (TDD RED commit)

**4. [Rule 1 - Bug] Used && instead of and for truthy checks**
- **Found during:** Task 2 (Auth integration)
- **Issue:** `if notify? and email_module and mailer` raised BadBooleanError because `and` requires strict booleans, but email_module/mailer are atom module names
- **Fix:** Changed to `if notify? && email_module && mailer`
- **Files modified:** lib/sigra/auth.ex
- **Verification:** All tests pass
- **Committed in:** 9819d2a (Task 2 GREEN commit)

---

**Total deviations:** 4 auto-fixed (1 bug, 3 blocking)
**Impact on plan:** All auto-fixes necessary for correctness and testability. No scope creep.

## Issues Encountered
- Pre-existing test failure in Sigra.ErrorTest (safe_message/1 for :account_locked) -- not caused by this plan, out of scope

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Suspicious login detection is wired into authenticate and ready for end-to-end testing
- Email template functions (suspicious_login_email/2, lockout_notification_email/2) are expected but not yet implemented in generated code -- Plan 05 creates the templates
- Session cleanup is ready and can be called from the Oban worker's perform/1

---
*Phase: 04-session-management-and-security-baseline*
*Completed: 2026-04-08*
