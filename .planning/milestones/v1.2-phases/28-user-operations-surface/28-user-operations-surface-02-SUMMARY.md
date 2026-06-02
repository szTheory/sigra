---
phase: 28
plan: 2
subsystem: admin
tags: [admin, users, liveview, query, example-app]
requires:
  - phase: 28-user-operations-surface
    provides: phase-27 admin scope and shell foundation
provides:
  - canonical admin user query contract with validated URL params
  - global and organization-scoped admin user index liveview routes
  - example-app coverage for list state preservation and scope-safe filters
affects: [phase-28-user-operations-surface-03, phase-29-secure-impersonation, phase-30-audit]
tech-stack:
  added: []
  patterns: [Flop-validated URL params, library-owned admin liveview, membership-scoped admin user queries]
key-files:
  created:
    - lib/sigra/admin/users/query.ex
    - lib/sigra/admin/live/users_index_live.ex
  modified:
    - lib/sigra/admin/live/index_live.ex
    - lib/sigra/admin/live/organization_live.ex
    - test/example/lib/example_web/router.ex
    - test/example/lib/example_web/components/admin_shell.ex
    - test/sigra/admin/users_query_test.exs
    - test/example/test/example_web/live/admin_user_index_live_test.exs
    - test/example/test/example_web/live/admin_user_filters_live_test.exs
key-decisions:
  - "The admin user list stays URL-driven through handle_params/3 and carries return_to state forward in rendered Open user links."
  - "Organization membership lookup is constrained to the active admin scope so org routes cannot pivot into other organization memberships."
duration: 34 min
completed: 2026-04-16T22:14:00Z
---

# Phase 28 Plan 2: User Operations Surface Summary

**Scope-safe admin user index with validated filters, desktop/mobile list rendering, and example-host route coverage**

## Performance

- **Duration:** 34 min
- **Completed:** 2026-04-16T22:14:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added `Sigra.Admin.Users.Query` as the canonical validated query contract for search, membership lookup, status filters, provider handling, pagination, sorting, and summary counts.
- Added `Sigra.Admin.Live.UsersIndexLive` and routed it at `/admin/users` plus `/admin/organizations/:org/users`, with desktop table and mobile card presentations over the same query contract.
- Redirected the Phase 27 placeholder admin landing LiveViews into the user index and turned `Users` into a real admin navigation link in the example shell.
- Replaced the Wave 0 placeholder tests with focused query and example-route coverage for preserved `return_to` params, quick filters, more-filters controls, and org-scope containment.

## Task Commits

1. **Task 1: Implement the canonical scope-safe admin user query** - `5c47984` (feat)
2. **Task 2: Build the users index LiveView and route it as the admin landing** - `49407cb` (feat)
3. **Verification fix: Keep the query decorator database-portable during focused checks** - `47fe1ae` (fix)

## Verification

- `mix test test/sigra/admin/users_query_test.exs --max-failures 1`
- `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_filters_live_test.exs --max-failures 1`

Both commands passed.

## Decisions Made

- Used the app runtime config from `Application.get_env(otp_app, :sigra_config)` so the library-owned LiveView can load the same config struct as the host app.
- Kept the user list detail link route-less for now and carried the exact list state in `return_to`, leaving actual detail-route ownership to Plan 28-03.
- Kept organization membership filtering structural inside the query module instead of letting the LiveView trim cross-org matches after loading rows.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced Postgres-only organization name aggregation in the query summary decorator**
- **Found during:** Task 1
- **Issue:** The first implementation used `string_agg`, which would make the library query module Postgres-specific.
- **Fix:** Switched organization summary reduction into Elixir after a plain membership/name query.
- **Files modified:** `lib/sigra/admin/users/query.ex`
- **Verification:** `mix test test/sigra/admin/users_query_test.exs --max-failures 1`
- **Commit:** `47fe1ae`

**2. [Rule 3 - Blocking] Created the expected local `sigra_test` database for the focused query verification repo**
- **Found during:** Task 1 verification
- **Issue:** `Sigra.Test.PostgresRepo` could not connect because the local `sigra_test` database did not exist.
- **Fix:** Created the database with the project-standard local Postgres credentials and reran the focused query tests.
- **Files modified:** None
- **Verification:** `mix test test/sigra/admin/users_query_test.exs --max-failures 1`
- **Commit:** Not applicable (environment-only)

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact:** No scope expansion in the repo. One fix improved portability, and the other restored the expected local verification environment.

## Known Stubs

None.

## Self-Check: PASSED

- Found `.planning/phases/28-user-operations-surface/28-user-operations-surface-02-SUMMARY.md`
- Found commit `5c47984`
- Found commit `49407cb`
- Found commit `47fe1ae`
