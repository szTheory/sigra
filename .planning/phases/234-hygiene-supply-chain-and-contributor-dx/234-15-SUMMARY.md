---
phase: 234-hygiene-supply-chain-and-contributor-dx
plan: 15
subsystem: testing
tags: [elixir, phoenix, phx_new, installer, golden-fixture, contributor-dx]
requires:
  - phase: 234-hygiene-supply-chain-and-contributor-dx
    provides: "Cleanup-safe sigra.dep_off harness from Task 1"
provides:
  - "Verified deterministic installer golden/idempotency proof using phx_new 1.8.8"
  - "Verified golden fixture remains outside formatter ownership"
affects: [DX-01, installer-regressions, contributor-ci]
tech-stack:
  added: []
  patterns:
    - "Generate installer goldens through InstallFixture.setup_tmp_app/1 and normalize_tree/2, never by hand."
key-files:
  created: []
  modified: []
key-decisions:
  - "Retained the existing dev-config fixture because locked phx_new 1.8.8 generation was byte-identical."
  - "Restored the pre-existing phx_new 1.8.9 archive after the locked 1.8.8 verification run."
patterns-established:
  - "A legitimate golden reconciliation may be a verified no-op when the committed bytes already equal current locked generator output."
requirements-completed: [DX-01]
metrics:
  duration: "~10 minutes"
  completed: "2026-08-01"
status: complete
---

# Phase 234 Plan 15: Cleanup-safe dep-off and installer-golden reconciliation Summary

The contributor dep-off path is cleanup-safe, and the installer golden/idempotency gate is proven green using the plan-locked `phx_new` 1.8.8 archive.

## Accomplishments

- Verified prior Task 1 commit `4379f0c1` without repeating its implementation.
- Installed and verified `phx_new` 1.8.8, regenerated normalized `config/dev.exs` only through `Sigra.Test.InstallFixture.setup_tmp_app/1`, and confirmed it exactly matches the tracked 3,252-byte fixture.
- Confirmed the current Sigra Swoosh configuration is present once, then restored the prior `phx_new` 1.8.9 archive after verification.
- Ran the locked golden/idempotency, formatter, and hermetic dep-off cleanup gates successfully.

## Verification

- `mix archive` contained `phx_new-1.8.8` before regeneration.
- `mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` — passed (exit 0).
- `mix format --check-formatted` — passed.
- `bash scripts/ci/test-sigra-dep-off.sh` — passed (6/6 restoration assertions).
- `mix archive` contains `phx_new-1.8.9` after the task.

## Deviations from Plan

### Auto-fixed Issues

None.

### Plan Reconciliation

**1. [Verified no-op] `config/dev.exs` required no byte change**
- **Found during:** Task 2.
- **Evidence:** The normalized fixture generated via the locked `phx_new` 1.8.8 scaffold was byte-identical to `test/fixtures/install_golden/tree/config/dev.exs` (3,252 bytes); the golden and idempotency tests then passed.
- **Resolution:** No fixture bytes were changed. Task commit `d78381a4` records the successful reconciliation evidence without fabricating a source diff.

## Known Stubs

None.

## Self-Check: PASSED

- Prior Task 1 commit `4379f0c1` and Task 2 commit `d78381a4` exist.
- The Task 2 fixture remained clean because its existing bytes were already canonical.
