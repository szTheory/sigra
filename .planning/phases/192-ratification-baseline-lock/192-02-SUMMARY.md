---
phase: 192-ratification-baseline-lock
plan: "02"
subsystem: test-quarantine
tags: [known-failure, quarantine, d-11, d-12, installer, playwright]
dependency_graph:
  requires: []
  provides:
    - "@moduletag known_failure in golden_diff_test.exs"
    - "@moduletag known_failure in vault_promotion_test.exs"
    - "test.fail() in admin-design.spec.ts MG-5/6"
    - "Sigra.Planning.Phase192KnownFailureContractTest"
    - ".planning/todos/pending/2026-06-18-install-golden-diff-known-failure.md"
    - ".planning/todos/pending/2026-06-18-install-vault-promotion-known-failure.md"
  affects:
    - "test/sigra/install/golden_diff_test.exs"
    - "test/sigra/install/vault_promotion_test.exs"
    - "test/example/priv/playwright/tests/admin-design.spec.ts"
tech_stack:
  added: []
  patterns:
    - "ExUnit @moduletag known_failure keyword-list tag for quarantine exclusion/inclusion"
    - "Playwright test.fail() for expected-failure marking"
    - "Self-healing contract test modeled on phase_51_install_golden_ci_contract_test.exs"
key_files:
  created:
    - test/sigra/planning/phase_192_known_failure_contract_test.exs
    - .planning/todos/pending/2026-06-18-install-golden-diff-known-failure.md
    - .planning/todos/pending/2026-06-18-install-vault-promotion-known-failure.md
  modified:
    - test/sigra/install/golden_diff_test.exs
    - test/sigra/install/vault_promotion_test.exs
    - test/example/priv/playwright/tests/admin-design.spec.ts
decisions:
  - "@moduletag known_failure uses keyword-list syntax (not atom) so self-healing contract test can grep for the colon-suffix `known_failure:` precisely"
  - "Contract test uses String.split on test name then checks last/1 for test.fail() to confirm marker is in the MG-5/6 block specifically"
  - "mix test --exclude known_failure exits 0 with 5 excluded (3 golden_diff tests + 2 vault_promotion tests tagged at module level)"
metrics:
  duration_minutes: 10
  completed_date: "2026-06-18"
  tasks_completed: 2
  files_changed: 6
status: complete
requirements: [GATE-02, GATE-03]
---

# Phase 192 Plan 02: Known-Failure Quarantine (D-11/D-12) Summary

Executable quarantine for the 3 known pre-existing v1.39 failures — tagged ExUnit tests, Playwright test.fail(), self-healing contract test, and 2 tracking todos.

## What Was Built

### Task 1: @moduletag known_failure tags on installer ExUnit tests

- `test/sigra/install/golden_diff_test.exs`: added `@moduletag known_failure: "generated-tree byte diff vs committed fixture; reproduces on origin/main; tracked: .planning/todos/pending/2026-06-18-install-golden-diff-known-failure.md"` after `@moduletag timeout: 300_000`
- `test/sigra/install/vault_promotion_test.exs`: added `@moduletag known_failure: "undefined attribute for CoreComponents.button/1 under --warnings-as-errors; installer template diverged from generated host; reproduces on origin/main; tracked: .planning/todos/pending/2026-06-18-install-vault-promotion-known-failure.md"` after `@moduletag timeout: 600_000`
- All existing tags (:golden, :install, timeout) preserved.

### Task 2: MG-5/6 test.fail(), contract test, and tracking todos

- `test/example/priv/playwright/tests/admin-design.spec.ts`: added `test.fail()` as first statement inside MG-5/6 test body with inline comment explaining the known failure and todo path
- `test/sigra/planning/phase_192_known_failure_contract_test.exs`: new module `Sigra.Planning.Phase192KnownFailureContractTest` with 3 tests (192-KF-01, 192-KF-02, 192-KF-03) asserting each quarantine marker is still present
- `.planning/todos/pending/2026-06-18-install-golden-diff-known-failure.md`: tracking todo with fix direction (regenerate golden fixture)
- `.planning/todos/pending/2026-06-18-install-vault-promotion-known-failure.md`: tracking todo with fix direction (fix installer template button type attr)

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c "known_failure" golden_diff_test.exs` | 1 |
| `grep -c "known_failure" vault_promotion_test.exs` | 1 |
| `grep -c "test.fail" admin-design.spec.ts` | 1 |
| `mix test phase_192_known_failure_contract_test.exs` | 3 tests, 0 failures |
| `mix test --exclude known_failure --exclude integration` | 2397 tests, 0 failures, 5 excluded |

## Deviations from Plan

None — plan executed exactly as written. The `mix test --exclude known_failure` run used `--exclude integration` as well to avoid running the long-running integration tests (300s-600s each) in the verification step, but this is consistent with the intent: the blocking suite excludes the quarantined tests.

## Known Stubs

None.

## Threat Flags

None. No new network endpoints, auth paths, or schema changes introduced. Threat model accepted: reason strings are developer-facing test source, no PII/secrets.

## Self-Check: PASSED

- `test/sigra/install/golden_diff_test.exs` exists with `@moduletag known_failure`
- `test/sigra/install/vault_promotion_test.exs` exists with `@moduletag known_failure`
- `test/example/priv/playwright/tests/admin-design.spec.ts` has `test.fail()` at line 323
- `test/sigra/planning/phase_192_known_failure_contract_test.exs` exists, 3 tests pass
- Commits 5e132e39 and cdd7fe13 exist on main
- Both tracking todos exist under `.planning/todos/pending/`
