---
phase: 204-terminal-ratification
plan: "02"
subsystem: planning-contracts
tags: [planning, test-cleanup, doc-drift, terminal-gate]
dependency_graph:
  requires: []
  provides: [clean-planning-contract-tests, tasklane-aligned-docs]
  affects: [test/sigra/planning/, guides/introduction/demo-showcase.md, doc/llms.txt]
tech_stack:
  added: []
  patterns: [self-healing-contract-deletion, doc-drift-reconciliation]
key_files:
  created: []
  modified:
    - guides/introduction/demo-showcase.md
    - doc/llms.txt
    - test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs
  deleted:
    - test/sigra/planning/phase_192_known_failure_contract_test.exs
decisions:
  - "Delete phase_192_known_failure_contract_test.exs entirely — all 3 original known failures resolved; no live assertion remained; test.skip() quarantine marker already lifted in Phase 197 (D-11b)"
  - "Update phase148 example README assertion from 'Vaultr is the runnable...' to 'Tasklane is a fictional **project/work tracker**' — matches actual post-rename README content at line 3"
metrics:
  duration: "157s"
  completed: "2026-06-27"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 3
  files_deleted: 1
status: complete
---

# Phase 204 Plan 02: Terminal Ratification — Stale Contract Test + Doc Drift Summary

Fixed two stale planning contract tests (D-08) and reconciled Vaultr→Tasklane doc drift so both tests are green and the terminal `mix test` gate is clear.

## What Was Done

### Task 1: Delete stale Phase192 known-failure contract test (D-08)

The `phase_192_known_failure_contract_test.exs` file contained a single live test (192-KF-03) that asserted `admin-design.spec.ts` still has a `test.skip(` quarantine marker on the MG-5/6 content-equivalence test. Grep confirmed 0 occurrences of `test.skip(` in the file — the quarantine was already lifted in Phase 197 (D-11b, commit f174d84d), and the companion todo was already in `.planning/todos/resolved/`.

With all 3 original Phase192 known failures resolved and no live assertion remaining, the file was deleted.

**Verification:** `test ! -f test/sigra/planning/phase_192_known_failure_contract_test.exs` confirmed.

### Task 2: Reconcile Vaultr→Tasklane doc drift + update Phase148 contract test (D-08)

The demo app was renamed Vaultr→Tasklane (quick task 260622-jfr), but three companion artifacts still contained "Vaultr":

1. **`guides/introduction/demo-showcase.md`**: Title and all 9 persona email addresses updated:
   - `# Demo Showcase — Vaultr Example App` → `# Demo Showcase — Tasklane Example App`  
   - All `@demo.vaultr.test` → `@demo.tasklane.test` (9 persona entries)

2. **`doc/llms.txt`**: `Demo Showcase — Vaultr Example App` → `Demo Showcase — Tasklane Example App`

3. **`test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs`**: Updated 3 assertions:
   - `llms` assertion: `Vaultr Example App` → `Tasklane Example App`
   - 6 persona email expectations: `@demo.vaultr.test` → `@demo.tasklane.test`
   - example README assertion: `"Vaultr is the runnable local companion for Sigra's canonical evaluator walkthrough:"` → `"Tasklane is a fictional **project/work tracker**"` (the actual README heading at line 3, which is the canonical Tasklane identity marker)

**Email domain verified against `test/example/lib/example/demo/personas.ex`:** `@demo_domain "demo.tasklane.test"` — exact match.

**Verification:** `grep -ci vaultr` = 0 on all 4 target files; `mix test test/sigra/planning/` = 38 tests, 0 failures.

## Verification Results

```
mix test test/sigra/planning/
38 tests, 0 failures, 12 skipped

grep -ci vaultr guides/introduction/demo-showcase.md → 0
grep -ci vaultr doc/llms.txt → 0
grep -ci vaultr llms.txt → 0
grep -ci vaultr test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs → 0
```

The 3 `Sigra.UpgradeIntegrationTest` env-DB failures (D-09) are accepted known failures and were NOT touched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Phase148 example README assertion used stale Vaultr phrasing**
- **Found during:** Task 2
- **Issue:** The test asserted `"Vaultr is the runnable local companion for Sigra's canonical evaluator walkthrough:"` but the actual `test/example/README.md` (already renamed) now begins with `"Tasklane is a fictional **project/work tracker**"` and then separately says `"It is the runnable local companion..."` — the old exact string no longer appears in the file
- **Fix:** Updated assertion to `"Tasklane is a fictional **project/work tracker**"` — the opening identity marker of the renamed README, which is a stronger unique-to-Tasklane lock
- **Files modified:** `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs`
- **Commit:** 7202113b

## Self-Check: PASSED

- [x] `test/sigra/planning/phase_192_known_failure_contract_test.exs` — DELETED (confirmed)
- [x] `guides/introduction/demo-showcase.md` — exists, Tasklane-renamed
- [x] `doc/llms.txt` — exists, Tasklane-renamed
- [x] `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` — exists, Tasklane-aligned
- [x] Task 1 commit c9e5cbbb — exists
- [x] Task 2 commit 7202113b — exists
- [x] `mix test test/sigra/planning/` → 38 tests, 0 failures
