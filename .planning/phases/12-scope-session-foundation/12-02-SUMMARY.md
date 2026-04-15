---
phase: 12-scope-session-foundation
plan: 02
subsystem: install-generator
tags: [migration, active-organization-id, user-sessions, generator]
dependency_graph:
  requires: [11-generator-feature-system]
  provides: [active_org_column_migration_slot, active_org_column_template]
  affects: [mix-sigra-install, golden-diff-fixture]
tech_stack:
  added: []
  patterns: [additive-alter-migration, migration-slot-insertion]
key_files:
  created:
    - priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs
    - test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_add_active_organization_id_to_user_sessions.exs
  modified:
    - lib/sigra/install/features/core.ex
    - test/sigra/install/features/core_test.exs
    - test/sigra/install/templates_layout_test.exs
    - test/sigra/install/isolation_test.exs
    - test/fixtures/install_golden/STDOUT.txt
decisions:
  - "Standalone ALTER migration instead of modifying primary migration.exs -- preserves Phase 11 byte-identity invariant (D-01) and enables Phase 18 upgrade reuse"
metrics:
  duration: "530s (~9 min)"
  completed: "2026-04-12T04:08:22Z"
  tasks: 2
  files: 7
---

# Phase 12 Plan 02: Active Organization Column Migration Slot Summary

Add :active_org_column migration slot to Features.Core so `mix sigra.install` emits a 4th migration adding active_organization_id to user_sessions, without touching the Phase 11 byte-identical primary migration template.

## What Was Done

### Task 1: Create ALTER migration EEx template

Created `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs` -- a dialect-agnostic ALTER TABLE template that adds `active_organization_id :binary_id` to the `user_sessions` table. Uses only the `repo_module` binding. 9 lines, single trailing newline.

Per D-03: no index, no FK reference, no default. Phase 14 or 18 adds those when the `organizations` table exists.

**Commit:** 53ba09b

### Task 2: Wire slot into Features.Core manifest + base_files + update tests

**Source changes (lib/sigra/install/features/core.ex):**
- `migrations/1`: Inserted `:active_org_column` 3-tuple between `:primary` and `:api_token` (canonical order preserved)
- `base_files/1`: Added `active_org_column_migration` binding after `primary_migration`, threaded into returned list at position 1 (before "Core schemas + context")

**Test updates (5 assertion sites in core_test.exs):**
1. Slot count: 3 -> 4, pattern match includes `:active_org_column`
2. Basename match: added `:active_org_column` clause
3. Source presence: added `"core/add_active_organization_id_to_user_sessions.exs" in sources`
4. Default file count: 36 -> 37 (26 base_files + 9 ui_files + 3 inlined migrations)
5. No-live file count: 30 -> 31 (26 base + 3 controller-mode UI + 3 inlined migrations)

**Sibling test updates:**
- `templates_layout_test.exs`: manifest + count 45 -> 46
- `isolation_test.exs`: count 45 -> 46
- Golden diff fixture: `STDOUT.txt` + new `TIMESTAMP_add_active_organization_id_to_user_sessions.exs` tree file

**Commit:** f7fbd16

## Verification Results

- `mix test test/sigra/install/features/core_test.exs` -- 26 tests, 0 failures
- `mix test test/sigra/install/` -- 330 tests, 0 failures (includes golden diff)
- `migration.exs` byte-identity invariant: confirmed unchanged (`git status` clean)
- New template EEx rendering: confirmed via `EEx.eval_file/2`
- `base_files` insert position: immediately after `primary_migration` (Pitfall 3 satisfied)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated sibling test files not listed in plan**
- **Found during:** Task 2, step 4
- **Issue:** `templates_layout_test.exs` and `isolation_test.exs` enumerate core/ template count (45) which broke with the new file. Golden diff fixtures (`STDOUT.txt` + tree/) also needed updating.
- **Fix:** Updated manifest list, count assertions (45 -> 46), STDOUT fixture (inserted new `* creating` line), and added rendered golden fixture migration file.
- **Files modified:** `test/sigra/install/templates_layout_test.exs`, `test/sigra/install/isolation_test.exs`, `test/fixtures/install_golden/STDOUT.txt`, `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_add_active_organization_id_to_user_sessions.exs`
- **Commit:** f7fbd16

## Key Numbers for Downstream Plans

| Metric | Old | New |
|--------|-----|-----|
| Migration slots (Core) | 3 | 4 |
| Default files (live=true, api=false, jwt=false) | 36 | 37 |
| No-live files (live=false, api=false, jwt=false) | 30 | 31 |
| Templates on disk (core/) | 45 | 46 |

## Self-Check: PASSED

- All created files verified present on disk (3/3)
- All commits verified in git log (2/2)
