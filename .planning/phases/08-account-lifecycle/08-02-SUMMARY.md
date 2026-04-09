---
phase: 08-account-lifecycle
plan: 02
subsystem: auth
tags: [email-change, password-change, account-deletion, ecto-multi, telemetry, hooks]

# Dependency graph
requires:
  - phase: 08-account-lifecycle
    plan: 01
    provides: Hooks engine, Config extensions (deletion, hooks, password), EmailTemplates callbacks
  - phase: 01-foundation
    provides: Token module, SessionStore behaviour, Email normalization
provides:
  - EmailChange module (request/confirm/cancel with token lifecycle)
  - PasswordChange module (change/set/force with session invalidation)
  - Deletion module (schedule/cancel/execute with 3 strategies)
  - Account orchestrator with unified delegation API
affects: [08-03, 08-04, 08-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [callback-based architecture for schema operations, embedded_schema for test structs]

key-files:
  created:
    - lib/sigra/account.ex
    - lib/sigra/account/email_change.ex
    - lib/sigra/account/password_change.ex
    - lib/sigra/account/deletion.ex
    - test/sigra/account/email_change_test.exs
    - test/sigra/account/password_change_test.exs
    - test/sigra/account/deletion_test.exs
  modified:
    - test/support/test_user.ex
    - test/support/mock_repo_behaviour.ex

key-decisions:
  - "Callback functions (email_taken_fn, build_email_token_fn, token_query_fn, find_user_by_token_fn) instead of direct schema module calls -- cleaner library pattern, easier testing"
  - "TestUser upgraded from plain defstruct to Ecto embedded_schema for Changeset compatibility"
  - "within_cooldown? accepts cancelled_at parameter rather than reading from user struct -- caller decides when cancellation happened"

patterns-established:
  - "Callback-based schema operations: library modules receive function callbacks for token/query operations rather than calling schema module functions directly"
  - "Account sub-module pattern: Sigra.Account delegates to EmailChange/PasswordChange/Deletion"

requirements-completed: [ACCT-01, ACCT-02, ACCT-03]

# Metrics
duration: 10min
completed: 2026-04-09
---

# Phase 8 Plan 02: Account Lifecycle Core Modules Summary

**EmailChange (request/confirm/cancel), PasswordChange (change/set/force), Deletion (schedule/cancel/execute with soft/hard/anonymize strategies), and Account orchestrator with unified delegation API**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-09T01:53:55Z
- **Completed:** 2026-04-09T02:03:51Z
- **Tasks:** 3
- **Files created:** 7
- **Files modified:** 2

## Accomplishments

- Built EmailChange module with request (validates uniqueness, creates token), confirm (switches email, invalidates sessions, runs hooks), and cancel (clears pending state)
- Built PasswordChange module with change (verifies current password, invalidates sessions), set_for_oauth_user (no current password), force_change_required?/require_force_change/clear_force_change for admin API
- Built Deletion module with schedule (sets 4 fields, revokes sessions/tokens, runs hooks), cancel (clears deletion state), execute (soft_delete/hard_delete/anonymize strategies)
- Built Account orchestrator that delegates all operations to sub-modules via defdelegate
- All modules have Telemetry spans for observability
- All modules integrate with Hooks engine for lifecycle callbacks

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: EmailChange + PasswordChange tests** - `6392a48` (test)
2. **Task 1 GREEN: EmailChange + PasswordChange implementation** - `601d35f` (feat)
3. **Task 2 RED: Deletion tests** - `829d411` (test)
4. **Task 2 GREEN: Deletion implementation** - `cd31c37` (feat)
5. **Task 3: Account orchestrator** - `44ea30a` (feat)

## Files Created/Modified

- `lib/sigra/account.ex` - Account orchestrator with defdelegate to all sub-modules
- `lib/sigra/account/email_change.ex` - Email change lifecycle: request/confirm/cancel
- `lib/sigra/account/password_change.ex` - Password change: change/set/force with session invalidation
- `lib/sigra/account/deletion.ex` - Deletion lifecycle: schedule/cancel/execute with 3 strategies
- `test/sigra/account/email_change_test.exs` - 7 tests for email change flows
- `test/sigra/account/password_change_test.exs` - 8 tests for password change flows
- `test/sigra/account/deletion_test.exs` - 16 tests for deletion lifecycle
- `test/support/test_user.ex` - Upgraded to Ecto embedded_schema with account lifecycle fields
- `test/support/mock_repo_behaviour.ex` - Added :one callback for uniqueness queries

## Decisions Made

- **Callback-based architecture:** Instead of calling `user_token_schema.build_email_token/2` directly, the library accepts callback functions (`build_email_token_fn`, `token_query_fn`, `email_taken_fn`, `find_user_by_token_fn`). This is cleaner for a library that doesn't own the schema modules and makes testing straightforward without needing full Ecto schema fixtures.
- **TestUser as embedded_schema:** Upgraded from plain `defstruct` to `use Ecto.Schema` + `embedded_schema` to get `Ecto.Changeset` compatibility without requiring a database table.
- **within_cooldown? as pure function:** Accepts `cancelled_at` DateTime parameter rather than reading from user struct, keeping the function pure and letting the caller decide when cancellation happened.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Refactored from direct schema calls to callback functions**
- **Found during:** Task 1
- **Issue:** Plan specified `user_token_schema.build_email_token(user, context)` but TestUserToken doesn't have build_email_token (it's defined in the EEx template, not the test support file). Similarly, `by_user_and_contexts_query` and email uniqueness queries needed real Ecto schemas.
- **Fix:** Changed to callback-based architecture: `build_email_token_fn`, `token_query_fn`, `email_taken_fn`, `find_user_by_token_fn`. This is a better library pattern regardless -- the generated context provides these callbacks.
- **Files modified:** lib/sigra/account/email_change.ex, test/sigra/account/email_change_test.exs
- **Committed in:** 601d35f

**2. [Rule 3 - Blocking] Upgraded TestUser to Ecto embedded_schema**
- **Found during:** Task 1
- **Issue:** `Ecto.Changeset.change/2` requires a struct with `__changeset__/0`, which plain `defstruct` does not provide.
- **Fix:** Converted TestUser to `use Ecto.Schema` with `embedded_schema` and added all account lifecycle fields.
- **Files modified:** test/support/test_user.ex
- **Committed in:** 601d35f

---

**Total deviations:** 2 auto-fixed (both blocking issues)
**Impact on plan:** Architecture improvement. Callback-based approach is more idiomatic for a library that doesn't own the schema modules. No scope change.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Account lifecycle library modules ready for generated context integration (Plan 03)
- Callback-based API ready for generated `MyApp.Auth` context to wire up schema-specific functions
- Deletion module ready for Oban worker integration (Plan 04/05)
- All Telemetry events ready for audit logging (Phase 9)

## Self-Check: PASSED

- All 7 created files exist on disk
- All 5 commits found in git log
- All acceptance criteria verified (module definitions, function signatures, telemetry, hooks, delegations)
- Full test suite: 1050 tests, 0 failures
- `mix compile --warnings-as-errors` passes cleanly

---
*Phase: 08-account-lifecycle*
*Completed: 2026-04-09*
