---
phase: 28-user-operations-surface
plan: 1
subsystem: auth
tags: [admin, users, flop, phoenix-liveview, contracts, example-app]
requires:
  - phase: 27-admin-access-foundation
    provides: global-vs-organization admin scope, admin route split, and host-owned admin shell seams
provides:
  - Explicit Phase 28 admin-user hook behaviour and default implementation
  - Example-app display_name support with a concrete admin hook provider
  - Wave 0 library, LiveView, and Playwright contract files for later plans
affects: [28-02, 28-03, 28-04, admin-user-runtime, example-app]
tech-stack:
  added: [flop, flop_phoenix]
  patterns: [read-only host hook seam, schema-derived accounts hook resolution, contract-first wave-0 test scaffolding]
key-files:
  created:
    - lib/sigra/admin/users/hooks.ex
    - lib/sigra/admin/users/default_hooks.ex
    - test/example/lib/example/sigra_admin_users.ex
    - test/example/priv/repo/migrations/20260416193000_add_display_name_to_users.exs
    - test/sigra/admin/users_query_test.exs
    - test/sigra/admin/users_actions_test.exs
    - test/example/test/example_web/live/admin_user_index_live_test.exs
    - test/example/test/example_web/live/admin_user_filters_live_test.exs
    - test/example/test/example_web/live/admin_user_show_live_test.exs
    - test/example/priv/playwright/tests/admin-user-operations.spec.ts
  modified:
    - mix.exs
    - mix.lock
    - test/example/lib/example/accounts/user.ex
    - test/example/lib/example/accounts.ex
    - test/example/mix.lock
key-decisions:
  - "Resolved admin user hooks from the configured accounts module when present, otherwise by deriving the accounts context from config.user_schema."
  - "Kept the Phase 28 hook contract read-only and data-returning so host hooks cannot mutate scoped queries or bypass authorization."
  - "Created skipped Wave 0 contract tests now so later plans turn named scenarios green instead of inventing surface requirements late."
patterns-established:
  - "Admin user extension points live in separate behaviour and default modules to respect the no-multiple-modules-per-file rule."
  - "Example-app admin seams expose one explicit admin_user_hooks/0 helper as the host-owned source of truth."
  - "Wave 0 validation assets use compile-safe skipped tests with locked copy and scenario names."
requirements-completed: [USER-01, USER-02]
duration: 5min
completed: 2026-04-16
---

# Phase 28 Plan 1: User Operations Surface Summary

**Flop-backed admin user contracts, example-app display_name hooks, and Wave 0 validation scaffolding for the Phase 28 list and detail surface**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-16T21:35:00Z
- **Completed:** 2026-04-16T21:40:00Z
- **Tasks:** 3
- **Files modified:** 15

## Accomplishments

- Added `flop` and `flop_phoenix`, plus an explicit `Sigra.Admin.Users.Hooks` behaviour with a default no-op implementation.
- Gave the example app a real `display_name` field, migration, and `Example.SigraAdminUsers` hook provider exposed through `Example.Accounts.admin_user_hooks/0`.
- Created the six Wave 0 contract files for query, action, LiveView, and Playwright coverage so later plans inherit fixed scenarios and copy.

## Task Commits

1. **Task 1: Add the Phase 28 dependency and host hook contract** - `0fa932d` (chore)
2. **Task 2: Give the example app a real display-name implementation for D-16** - `1d6a347` (feat)
3. **Task 3: Create the Wave 0 contract files before feature implementation** - `d111aea` (test)

## Files Created/Modified

- `lib/sigra/admin/users/hooks.ex` - Phase 28 admin user hook behaviour and runtime resolver
- `lib/sigra/admin/users/default_hooks.ex` - safe default no-op hook implementation
- `mix.exs` - adds `flop` and `flop_phoenix` to the main dependency list
- `mix.lock` - records the new root dependencies
- `test/example/lib/example/accounts/user.ex` - adds `display_name` to the example user schema and registration cast
- `test/example/priv/repo/migrations/20260416193000_add_display_name_to_users.exs` - adds the example `display_name` column and index
- `test/example/lib/example/sigra_admin_users.ex` - concrete example implementation of `Sigra.Admin.Users.Hooks`
- `test/example/lib/example/accounts.ex` - exports `admin_user_hooks/0`
- `test/example/mix.lock` - records the new transitive example-app dependencies needed to compile against the updated library
- `test/sigra/admin/users_query_test.exs` - locked query/filter contract scenarios
- `test/sigra/admin/users_actions_test.exs` - locked revoke/audit action scenarios
- `test/example/test/example_web/live/admin_user_index_live_test.exs` - list contract scenarios
- `test/example/test/example_web/live/admin_user_filters_live_test.exs` - filter contract scenarios
- `test/example/test/example_web/live/admin_user_show_live_test.exs` - detail contract scenarios
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts` - browser smoke contract scenarios

## Decisions Made

- Used the existing `Sigra.Config` shape and resolved the host accounts module from `config.user_schema` when an explicit accounts module is not present.
- Kept the hook surface narrow: display, search, badges, columns, detail sections, and copy only.
- Treated the Wave 0 files as intentionally skipped contract tests so the baseline compiles while preserving the exact Phase 28 surface.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Refreshed the example-app lockfile for new library dependencies**
- **Found during:** Task 2 (Give the example app a real display-name implementation for D-16)
- **Issue:** `cd test/example && mix ecto.migrate && mix compile` failed because the example subproject had not fetched the newly added `flop` and `flop_phoenix` dependencies yet.
- **Fix:** Ran `mix deps.get` in `test/example`, which updated `test/example/mix.lock` so the example app could compile against the updated library.
- **Files modified:** `test/example/mix.lock`
- **Verification:** `cd test/example && mix ecto.migrate && mix compile`
- **Committed in:** `1d6a347`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required for correctness after adding new runtime dependencies. No scope creep.

## Issues Encountered

- Example-app verification initially failed until the subproject lockfile was refreshed for the new root library dependencies.

## User Setup Required

None - no external service configuration required.

## Known Stubs

- `test/sigra/admin/users_query_test.exs:12` - skipped Wave 0 contract test; implementation lands in Plans 28-02 through 28-04.
- `test/sigra/admin/users_actions_test.exs:12` - skipped Wave 0 contract test; implementation lands in Plans 28-03 through 28-04.
- `test/example/test/example_web/live/admin_user_index_live_test.exs:10` - skipped Wave 0 contract test; UI implementation lands in later Phase 28 plans.
- `test/example/test/example_web/live/admin_user_filters_live_test.exs:10` - skipped Wave 0 contract test; filter UI implementation lands in later Phase 28 plans.
- `test/example/test/example_web/live/admin_user_show_live_test.exs:10` - skipped Wave 0 contract test; detail UI implementation lands in later Phase 28 plans.
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts:5` - contract placeholder comment and skipped smoke scenario; browser flow implementation lands in later Phase 28 plans.

## Next Phase Readiness

- Ready for Plan 28-02 to build the real admin user query layer and list UI against an explicit hook contract and example-app name source.
- No blocker remains for the next plans beyond turning the Wave 0 contract files green.

## Self-Check: PASSED
