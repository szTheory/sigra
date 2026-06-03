---
phase: 153-infra-stability
plan: "01"
subsystem: infra-testing
tags: [postgres, ecto, sql-sandbox, ci, testing]
requires:
  - phase: 152-strategic-bet-evaluation-gate
    provides: strategic maintenance gate context
provides:
  - Shared SQL Sandbox harness for library live-DB tests
  - Owner-per-test rollback cleanup for shared-repo Postgres suites
  - Isolated scratch repo for storage-destructive query index proof
  - Structural Phase 153 infrastructure stability contract
affects: [library_tests, library_tests_dep_off, postgres-tests, audit-tests, admin-tests]
tech-stack:
  added: []
  patterns:
    - Sigra.Test.PostgresCase owner-per-test sandbox helper
    - Checked-out setup SQL for stable DDL outside test transactions
    - Dedicated scratch repo for storage_up/storage_down proofs
key-files:
  created:
    - test/support/postgres_case.ex
    - test/support/audit_query_index_scratch_repo.ex
    - test/sigra/planning/phase_153_infra_stability_contract_test.exs
  modified:
    - test/support/postgres_test_repo.ex
    - test/test_helper.exs
    - test/sigra/api_token_audit_atomic_test.exs
    - test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs
    - test/sigra/mfa_audit_atomicity_test.exs
    - test/sigra/auth/register_audit_atomicity_test.exs
    - test/sigra/account_audit_atomicity_test.exs
    - test/sigra/auth/login_and_lockout_audit_atomicity_test.exs
    - test/sigra/oauth/oauth_ceremony_audit_test.exs
    - test/sigra/oauth/oauth_audit_atomicity_test.exs
    - test/sigra/audit/audit_assertions_test.exs
    - test/sigra/audit/forwarders/threadline_test.exs
    - test/sigra/jwt_refresh_audit_cofate_test.exs
    - test/sigra/audit_multi_step_test.exs
    - test/sigra/admin/users_query_test.exs
    - test/sigra/admin/users_actions_test.exs
    - test/sigra/admin/audit/query_test.exs
    - test/sigra/audit/query_index_test.exs
key-decisions:
  - "Keep live library Postgres suites synchronous and route them through Sigra.Test.PostgresCase."
  - "Keep stable DDL explicit while moving per-test row isolation to SQL Sandbox owner rollback."
  - "Use a physically separate scratch repo/database for the query planner storage lifecycle proof."
patterns-established:
  - "Library live-DB tests use `use Sigra.Test.PostgresCase, async: false` and receive `repo`/`sandbox_owner` in context."
  - "Module-level DDL that runs outside a test owner uses `Sigra.Test.PostgresCase.checkout_repo!/1`."
  - "Storage-destructive tests use a dedicated repo module rather than mutating shared repo config."
requirements-completed: [INFRA-01]
duration: 72 min
completed: 2026-06-02
---

# Phase 153 Plan 01: Infrastructure Stability Summary

**Shared SQL Sandbox harness for library live-DB tests with isolated query-index scratch storage**

## Performance

- **Duration:** 72 min
- **Started:** 2026-06-02T04:38:00Z
- **Completed:** 2026-06-02T05:50:01Z
- **Tasks:** 3/3
- **Files modified:** 21

## Accomplishments

- Converted `Sigra.Test.PostgresRepo` to an Ecto SQL Sandbox repo started once from `test/test_helper.exs`.
- Added `Sigra.Test.PostgresCase`, which starts/stops one sandbox owner per live-DB test and returns both `repo` and `sandbox_owner`.
- Migrated shared-repo live Postgres suites off per-module repo startup and row `TRUNCATE` cleanup.
- Split `Sigra.Audit.QueryIndexTest` onto `Sigra.Test.AuditQueryIndexScratchRepo` so `storage_up` / `storage_down` never target the shared `sigra_test` repo.
- Added a fast structural contract that guards Phase 153 sandbox, scratch-storage, and CI-lane invariants.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the shared library sandbox harness** - `623c33f2` (`test(153-01)`)
2. **Task 2: Migrate shared-repo live-DB suites onto owner-per-test rollback cleanup** - `7040bc95` (`test(153-01)`)
3. **Task 3: Isolate the destructive query planner proof and add a fast infra contract** - `9d3303de` (`test(153-01)`)
4. **Task 3 verification fix: Make scratch repo teardown idempotent** - `7f73b569` (`fix(153-01)`)

## Files Created/Modified

- `test/support/postgres_test_repo.ex` - SQL Sandbox pool and ownership timeout for shared library repo.
- `test/test_helper.exs` - Central repo startup and manual sandbox mode.
- `test/support/postgres_case.ex` - Owner-per-test helper plus checked-out setup helper for stable DDL.
- `test/support/audit_query_index_scratch_repo.ex` - Dedicated scratch repo for storage lifecycle proof.
- `test/sigra/audit/query_index_test.exs` - Uses scratch repo without shared config mutation.
- `test/sigra/planning/phase_153_infra_stability_contract_test.exs` - Structural contract for Phase 153 invariants.
- Shared live-DB suites under `test/sigra/` - Migrated to `Sigra.Test.PostgresCase`.

## Decisions Made

- Kept migrated live-DB tests `async: false` for this stabilization pass.
- Preserved example app sandbox files unchanged.
- Used one-time checked-out setup for admin DDL because `setup_all` runs outside a per-test owner.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added checked-out setup helper for admin DDL**
- **Found during:** Task 2 verification.
- **Issue:** Admin `setup_all` callbacks ran DDL while the shared repo was in manual sandbox mode, causing `DBConnection.OwnershipError`.
- **Fix:** Added `Sigra.Test.PostgresCase.checkout_repo!/1` and used it for module-level admin DDL.
- **Files modified:** `test/support/postgres_case.ex`, admin query/action/audit tests.
- **Verification:** Focused phase command passed with 107 tests, 0 failures.
- **Committed in:** `7040bc95`

**2. [Rule 3 - Blocking] Made scratch repo teardown idempotent**
- **Found during:** Final focused verification after metadata close-out.
- **Issue:** `Sigra.Audit.QueryIndexTest` could call `GenServer.stop/3` after the scratch repo process had already exited, causing an on-exit failure.
- **Fix:** Wrapped scratch repo teardown so an already-stopped process is tolerated before `storage_down/1`.
- **Files modified:** `test/sigra/audit/query_index_test.exs`.
- **Verification:** Fresh focused phase command passed with 107 tests, 0 failures.
- **Committed in:** `7f73b569`

---

**Total deviations:** 2 auto-fixed blocking issues.
**Impact on plan:** The fix is within the planned sandbox harness boundary and improves the stable-DDL path without changing runtime code.

## Issues Encountered

- Full `MIX_ENV=test mix test` did not reach a terminal result in this local run. It was interrupted after repeated unrelated startup retries from `Chimeway.Repo` with `missing the :database key in options for Chimeway.Repo`. The focused Phase 153 proof passed before this blocker.
- A one-time manual local cleanup of known old test rows was performed before rerunning the migrated suites because the previous pre-sandbox harness had left residue in the local `sigra_test` database. The migrated tests no longer depend on per-test destructive cleanup.

## Verification

- `rg -n "pool: Ecto.Adapters.SQL.Sandbox|ownership_timeout|Sandbox.mode\\(Sigra\\.Test\\.PostgresRepo, :manual\\)|start_owner!|stop_owner|sandbox_owner" ...` - passed.
- `rg -n "start_supervised!\\(\\{(PostgresRepo|Sigra\\.Test\\.PostgresRepo|@repo)|TRUNCATE TABLE|DROP TABLE|Application\\.put_env\\(:sigra" ...` - no matches in migrated/scratch test files.
- `MIX_ENV=test mix test test/sigra/api_token_audit_atomic_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs test/sigra/oauth/oauth_ceremony_audit_test.exs test/sigra/audit/audit_assertions_test.exs test/sigra/audit/forwarders/threadline_test.exs test/sigra/jwt_refresh_audit_cofate_test.exs test/sigra/audit_multi_step_test.exs test/sigra/admin/users_query_test.exs test/sigra/admin/users_actions_test.exs test/sigra/admin/audit/query_test.exs test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs test/sigra/mfa_audit_atomicity_test.exs test/sigra/auth/register_audit_atomicity_test.exs test/sigra/account_audit_atomicity_test.exs test/sigra/oauth/oauth_audit_atomicity_test.exs test/sigra/audit/query_index_test.exs test/sigra/planning/phase_153_infra_stability_contract_test.exs` - 107 tests, 0 failures.
- `MIX_ENV=test mix test` - interrupted due unrelated `Chimeway.Repo` retry loop described above.

## User Setup Required

None - no external service configuration required beyond the existing local Postgres prerequisite.

## Next Phase Readiness

Phase 153's focused INFRA-01 proof is complete. Before using full-suite `mix test` as a final release gate in this local environment, investigate the unrelated `Chimeway.Repo` missing database configuration retry loop.

## Self-Check: PASSED

- Key created files exist.
- All three task commits exist with `153-01` in the commit subject.
- Focused Phase 153 verification passed.
- Full-suite limitation is documented as an issue rather than silently ignored.

---
*Phase: 153-infra-stability*
*Completed: 2026-06-02*
