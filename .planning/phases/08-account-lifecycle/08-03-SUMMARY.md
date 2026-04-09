---
phase: 08-account-lifecycle
plan: 03
subsystem: auth
tags: [plug, oban, telemetry, account-lifecycle, password-change, deletion]

# Dependency graph
requires:
  - phase: 08-01
    provides: Account module foundation, Config struct, Hooks module
  - phase: 08-02
    provides: EmailChange, PasswordChange, Deletion sub-modules with public APIs
provides:
  - RequirePasswordChange plug for forced password change enforcement
  - AccountDeletion Oban worker for grace period expiry
  - Telemetry event catalog for all Phase 8 lifecycle operations
  - Auth module delegation to Account sub-modules
affects: [08-account-lifecycle, generated-router, generated-oban-config]

# Tech tracking
tech-stack:
  added: []
  patterns: [plug-based-enforcement, oban-lifecycle-worker, config-aware-delegation]

key-files:
  created:
    - lib/sigra/plug/require_password_change.ex
    - lib/sigra/workers/account_deletion.ex
    - test/sigra/plug/require_password_change_test.exs
    - test/sigra/workers/account_deletion_test.exs
  modified:
    - lib/sigra/telemetry.ex
    - lib/sigra/auth.ex

key-decisions:
  - "AccountDeletion worker uses default_changeset_fn/default_token_query_fn fallbacks when not provided via args"
  - "Telemetry events grouped into @account_events and @hook_events module attributes with accessor functions"
  - "Auth delegation uses get_session_store/1 helper to extract session store from config consistently"

patterns-established:
  - "Oban lifecycle worker pattern: sigra_lifecycle queue, Module.safe_concat for module resolution, String.to_existing_atom for strategy"
  - "Auth delegation pattern: config-aware wrapper that merges config fields into opts before delegating to Account module"

requirements-completed: [ACCT-02, ACCT-03, SESS-09]

# Metrics
duration: 4min
completed: 2026-04-09
---

# Phase 8 Plan 03: Plugs, Workers, Telemetry, and Auth Delegation Summary

**RequirePasswordChange plug, AccountDeletion Oban worker, Phase 8 telemetry event catalog, and Auth module lifecycle delegation to Account sub-modules**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-09T02:06:51Z
- **Completed:** 2026-04-09T02:10:31Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- RequirePasswordChange plug enforces forced password changes by checking must_change_password flag on user struct
- AccountDeletion Oban worker handles grace period expiry with safety checks (user existence, scheduled? guard, Module.safe_concat)
- Telemetry catalog extended with 24 new events covering email change, password operations, account deletion, and hook failures
- Auth module provides 8 new config-aware delegation functions for the full account lifecycle API

## Task Commits

Each task was committed atomically:

1. **Task 1: RequirePasswordChange plug + AccountDeletion Oban worker + tests** - `85fef5d` (test: RED), `6c26dce` (feat: GREEN)
2. **Task 2: Telemetry events + Auth module lifecycle delegation** - `34e6f2b` (feat)

## Files Created/Modified
- `lib/sigra/plug/require_password_change.ex` - Plug that halts connections for users with must_change_password=true
- `lib/sigra/workers/account_deletion.ex` - Oban worker for executing scheduled deletions after grace period
- `lib/sigra/telemetry.ex` - Extended with account_events/0, hook_events/0 and 24 new event definitions
- `lib/sigra/auth.ex` - Added 8 delegation functions for account lifecycle (email change, password, deletion)
- `test/sigra/plug/require_password_change_test.exs` - 7 tests covering all plug paths
- `test/sigra/workers/account_deletion_test.exs` - 9 tests covering worker config, perform paths, and security mitigations

## Decisions Made
- AccountDeletion worker provides default_changeset_fn and default_token_query_fn fallbacks so it can execute without host-app-specific functions in job args
- Auth delegation extracts session store via helper function get_session_store/1 with Sigra.SessionStores.Ecto as default
- Telemetry events follow existing pattern of module attribute groups with accessor functions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added default changeset_fn and token_query_fn to AccountDeletion worker**
- **Found during:** Task 1 (AccountDeletion worker implementation)
- **Issue:** Plan specified Deletion.execute/3 opts with changeset_fn and token_query_fn but these are required by the Deletion module and cannot be passed via Oban job args (they are functions)
- **Fix:** Added default_changeset_fn/2 using Ecto.Changeset.change and default_token_query_fn/2 using basic Ecto.Query
- **Files modified:** lib/sigra/workers/account_deletion.ex
- **Verification:** Tests pass, compilation clean
- **Committed in:** 6c26dce (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for worker to function since Oban args are JSON-serializable only. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All Phase 8 library code complete: Account module (Plan 01), sub-modules (Plan 02), plugs/workers/telemetry/delegation (Plan 03)
- Ready for generator/template work if planned in subsequent plans
- Host apps need to add sigra_lifecycle queue to their Oban config

## Self-Check: PASSED

All 4 created files verified on disk. All 3 commits verified in git log.

---
*Phase: 08-account-lifecycle*
*Completed: 2026-04-09*
