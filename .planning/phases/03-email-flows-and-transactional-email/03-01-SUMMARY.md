---
phase: 03-email-flows-and-transactional-email
plan: 01
subsystem: infra
tags: [oban, swoosh, email, delivery, config, nimble_options]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: Config struct with NimbleOptions validation, Error module, Mailer behaviour, Telemetry spans
  - phase: 02-core-auth
    provides: Token module for hashed token generation and verification
provides:
  - Extended Config with confirmation/reset/email option groups
  - Sigra.Delivery module for async/sync email routing
  - Sigra.Workers.EmailDelivery Oban worker with exponential backoff
  - Sigra.Workers.TokenCleanup Oban cron worker for expired token pruning
  - AlreadyConfirmed and Unconfirmed error types
  - Safe message clauses for confirmation/reset error atoms
  - Multipart body type on Mailer callback
affects: [03-02, 03-03, 03-04, 03-05]

# Tech tracking
tech-stack:
  added: [oban (workers)]
  patterns: [async-with-sync-fallback, oban-worker-with-injectable-insert, build-job-for-testability]

key-files:
  created:
    - lib/sigra/delivery.ex
    - lib/sigra/workers/email_delivery.ex
    - lib/sigra/workers/token_cleanup.ex
    - test/sigra/delivery_test.exs
    - test/sigra/workers/email_delivery_test.exs
    - test/sigra/workers/token_cleanup_test.exs
  modified:
    - lib/sigra/config.ex
    - lib/sigra/error.ex
    - lib/sigra/mailer.ex
    - test/sigra/config_test.exs
    - test/sigra/error_test.exs
    - test/test_helper.exs

key-decisions:
  - "Oban.insert injected via :oban option for testability without running Oban instance"
  - "build_job/3 exposed as public API for changeset inspection in tests"
  - "Token cleanup includes session context with 60-day TTL alongside email token contexts"

patterns-established:
  - "Injectable Oban: pass :oban option to delivery functions for test isolation"
  - "Minimal job args: store only email_type + user_id + token/code/url in Oban jobs (T-3-INFRA-01)"
  - "Module-level test fakes: define fake modules at module level, not inside test blocks, to avoid async race conditions"

requirements-completed: [CONF-03, EMAIL-05]

# Metrics
duration: 7min
completed: 2026-04-07
---

# Phase 3 Plan 1: Email Delivery Infrastructure Summary

**Email delivery orchestration with async/sync routing via Oban, NimbleOptions config for confirmation/reset/email, and token cleanup worker**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-07T03:03:45Z
- **Completed:** 2026-04-07T03:11:07Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Config validates confirmation (unconfirmed_access, code_length, rate limits), reset (max_requests, window), and email (delivery_mode, oban_queue, concurrency) option groups via NimbleOptions
- Delivery module routes emails through async (Oban) or sync (direct mailer call) paths with auto-detection of Oban presence
- EmailDelivery Oban worker stores only minimal args in jobs table (email_type + user_id + token), with exponential backoff (3 attempts)
- TokenCleanup Oban worker prunes expired tokens across all contexts (confirm, reset, magic_link, session) with conservative TTLs
- Error module extended with AlreadyConfirmed, Unconfirmed exceptions and 5 new safe_message clauses
- Mailer behaviour evolved to accept multipart body (html + text)

## Task Commits

Each task was committed atomically:

1. **Task 1: Config extensions, Error additions, Mailer evolution** - `2b3dd73` (feat)
2. **Task 2: Delivery module and Oban workers** - `5a97de1` (feat)
3. **Task 2 fix: Async test flake resolution** - `e38ee82` (fix)

## Files Created/Modified
- `lib/sigra/config.ex` - Extended NimbleOptions schema with confirmation/reset/email sections
- `lib/sigra/error.ex` - AlreadyConfirmed, Unconfirmed exceptions + 5 safe_message clauses
- `lib/sigra/mailer.ex` - Multipart body type on deliver callback
- `lib/sigra/delivery.ex` - Email delivery orchestration (async/sync/auto routing)
- `lib/sigra/workers/email_delivery.ex` - Oban worker for async email delivery
- `lib/sigra/workers/token_cleanup.ex` - Oban cron worker for expired token cleanup
- `test/sigra/config_test.exs` - Tests for confirmation/reset/email config sections
- `test/sigra/error_test.exs` - Tests for new error types and safe_message clauses
- `test/sigra/delivery_test.exs` - Tests for all delivery paths
- `test/sigra/workers/email_delivery_test.exs` - Tests for worker, backoff, changeset
- `test/sigra/workers/token_cleanup_test.exs` - Tests for worker attributes and exports
- `test/test_helper.exs` - Added MockMailer for Sigra.Mailer behaviour

## Decisions Made
- Injected Oban module via `:oban` option in deliver_async to enable testing without a running Oban instance. This avoids requiring Oban.Testing setup in the library's own tests.
- Exposed `build_job/3` as a public function so tests and callers can inspect the Oban changeset before insertion.
- Added session context (60-day TTL) to TokenCleanup alongside email token contexts for comprehensive cleanup.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed async test race conditions**
- **Found during:** Task 2 (Delivery module tests)
- **Issue:** `defmodule` inside test blocks caused module redefinition race conditions when running tests async. `function_exported?` checks failed intermittently when modules weren't loaded yet.
- **Fix:** Moved FakeOban modules to module level in test file. Added `Code.ensure_loaded!` before `function_exported?` checks.
- **Files modified:** test/sigra/delivery_test.exs, test/sigra/workers/token_cleanup_test.exs
- **Verification:** 5 consecutive full test suite runs with 0 failures
- **Committed in:** e38ee82

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Test reliability fix only. No scope creep.

## Issues Encountered
None beyond the test flake addressed above.

## Known Stubs

- `lib/sigra/workers/email_delivery.ex` perform/1: Returns `{:ok, :delivered}` without actual email reconstruction/delivery. This is intentional -- the worker will be wired to the host app's email module in Plan 04 when the generator creates the callback integration. The stub is documented inline.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Delivery infrastructure ready for Plan 02 (email confirmation flow) and Plan 03 (password reset flow)
- Both plans can use `Sigra.Delivery.deliver/3` for email dispatch
- Config sections for confirmation and reset are validated and available
- Error types for confirmation/reset flows are defined

---
*Phase: 03-email-flows-and-transactional-email*
*Completed: 2026-04-07*
