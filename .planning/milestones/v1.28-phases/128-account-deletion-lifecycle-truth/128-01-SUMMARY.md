---
phase: 128-account-deletion-lifecycle-truth
plan: 01
subsystem: account-lifecycle
tags: [account-deletion, oban, lifecycle, ecto, security]

requires:
  - phase: 127-versioned-auth-data-export
    provides: Lifecycle status export delegates to Sigra.Account.Deletion.status/1
provides:
  - Executable proof for scheduled account-deletion worker enqueue shape
  - Safe missing-job-context degradation proof for deletion scheduling
  - Active-scheduled stale-worker no-op proof
  - Soft-delete finalization proof that clears pending state while preserving deleted_at
affects: [128-account-deletion-lifecycle-truth, 129-generated-host-lifecycle-parity, data-lifecycle]

tech-stack:
  added: []
  patterns:
    - Post-transaction Oban enqueue remains non-fatal for optional infrastructure
    - Account deletion workers gate execution through Deletion.scheduled?/1
    - Soft-delete finalization clears lifecycle staging fields without hard-deleting the user row

key-files:
  created:
    - .planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md
  modified:
    - test/sigra/account/deletion_test.exs
    - test/sigra/workers/account_deletion_test.exs

key-decisions:
  - "Kept account-deletion enqueue ownership in Sigra.Account.Deletion.schedule/3."
  - "Kept missing job context as safe no-op degradation rather than failing scheduling."
  - "Kept soft-delete finalization row-preserving and deleted_at-preserving."

patterns-established:
  - "Generated-host lifecycle context should be passed into Sigra.Auth/Sigra.Account wrappers, with the library owning enqueue and execution truth."
  - "Stale background deletion jobs should return {:ok, :not_scheduled} after cancellation or finalization."

requirements-completed: [LIFE-01, LIFE-02, LIFE-03]

duration: 8min
completed: 2026-05-27
---

# Phase 128 Plan 01: Account Deletion Lifecycle Truth Summary

**Account deletion lifecycle truth is now pinned by tests for Oban enqueue shape, safe missing-context degradation, stale worker no-ops, and row-preserving soft-delete finalization.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-27T08:22:05Z
- **Completed:** 2026-05-27T08:30:08Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Added a full-context schedule proof that asserts the inserted Oban changeset uses `Sigra.Workers.AccountDeletion`, queue `sigra_lifecycle`, the computed scheduled timestamp, replacement rules, and serialized generated-host context.
- Added missing-context schedule proof that returns `{:ok, updated_user, scheduled_at}` without requiring `repo.insert/1`.
- Strengthened soft-delete execution proof to inspect the `Ecto.Multi` user update and assert `scheduled_deletion_at`, `pending_email`, and `original_email` are cleared while `deleted_at` is untouched.
- Added worker proof that finalized soft-deleted stale jobs return `{:ok, :not_scheduled}`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add lifecycle truth proof tests** - `58929d0` (test)
2. **Task 2: Repair schedule enqueue and generated-host context propagation** - `1c70394` (chore, no-change verification)
3. **Task 3: Harden active-scheduled and soft-delete finalization truth** - `aac092c` (chore, no-change verification)

**Plan metadata:** pending final docs commit

## Files Created/Modified

- `test/sigra/account/deletion_test.exs` - Adds schedule enqueue/degradation tests and strengthens soft-delete finalization assertions.
- `test/sigra/workers/account_deletion_test.exs` - Adds finalized soft-delete stale-job no-op proof.
- `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md` - Records execution, verification, decisions, and self-check.

## Decisions Made

- Kept production code unchanged for Tasks 2 and 3 because the current implementation already satisfied the plan contract after Task 1 proof was added.
- Used no-change verification commits for Tasks 2 and 3 to preserve the requested per-task atomic commit trail without introducing cosmetic production edits.
- Compared scheduled timestamps semantically in the enqueue test to avoid microsecond precision differences between the Ecto changeset field and returned `DateTime`.

## Verification

- `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --max-failures 1` - passed, 35 tests, 0 failures.
- `mix test test/sigra/account/deletion_test.exs --max-failures 1` - passed, 20 tests, 0 failures.
- `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs test/sigra/account_audit_atomicity_test.exs test/sigra/data_export_test.exs` - passed, 56 tests, 0 failures.
- `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs` - passed, 35 tests, 0 failures.
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` - passed, 33 doctests, 3 properties, 2200 tests, 0 failures.
- Acceptance `rg` checks for Task 1, Task 2, and Task 3 all passed.

## Deviations from Plan

None - plan executed within the requested scope. The implementation repair tasks were satisfied by existing production code, so no production edits were needed.

## Issues Encountered

- A first version of the enqueue test compared DateTime structs directly and hit a microsecond precision mismatch inside the non-fatal enqueue path. The assertion was corrected to use `DateTime.compare/2` before the task commit.

## Known Stubs

None. Stub-pattern scan found no placeholder or hardcoded empty UI/data stubs in modified lifecycle proof files.

## Threat Flags

None. The plan already covered the touched security-relevant surface: generated-host context serialization, optional Oban degradation, stale worker no-op gating, and soft-delete field clearing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 129 can align generated-host templates, example app behavior, install golden fixtures, and public docs to this now-pinned library contract.

---
*Phase: 128-account-deletion-lifecycle-truth*
*Completed: 2026-05-27*

## Self-Check: PASSED

- Found `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`.
- Found `test/sigra/account/deletion_test.exs`.
- Found `test/sigra/workers/account_deletion_test.exs`.
- Found task commit `58929d0`.
- Found task commit `1c70394`.
- Found task commit `aac092c`.
