---
phase: 196-pr-fast-vs-nightly-broad-trigger-model
plan: "02"
subsystem: ci-contract-tests
tags: [ci, contract-tests, planning-tests, fix]
status: complete

dependency_graph:
  requires: [196-01]
  provides: [phase_51_green, phase_58_verified]
  affects: [test/sigra/planning/phase_51_install_golden_ci_contract_test.exs]

tech_stack:
  added: []
  patterns: [ExUnit text-contract assertion idiom (assert yml =~)]

key_files:
  created: []
  modified:
    - test/sigra/planning/phase_51_install_golden_ci_contract_test.exs

decisions:
  - Anchored on `scripts/ci/installer-milestone-audit.sh` (run command) rather than just the step name, as it is the most stable, least-likely-to-be-reworded anchor per PATTERNS.md §7
  - Updated @moduledoc and test name to reflect Phase-194 fold (job → fast_checks step) for honesty (D-15)
  - phase_58 required no edit — slicer boundary intact after Plan-01 ci.yml changes

metrics:
  duration: "1m"
  completed: "2026-06-20"
  tasks_completed: 3
  files_modified: 1
---

# Phase 196 Plan 02: Re-anchor CI Contract Tests Summary

**One-liner:** Re-anchored phase_51 from the removed `installer_milestone_audit:` job key to the surviving `scripts/ci/installer-milestone-audit.sh` run step inside `fast_checks`; confirmed phase_58 slicer undisturbed.

## What Was Built

This plan resolved D-15 (standing CI-contract todo): `phase_51_install_golden_ci_contract_test.exs` was RED on main because Phase 194 (CACHE-02) folded the standalone `installer_milestone_audit:` job into the `fast_checks` job as a step, but the test still asserted on the old job key (`assert yml =~ "installer_milestone_audit:"`).

### Changes Made

**`test/sigra/planning/phase_51_install_golden_ci_contract_test.exs`** (1 file, ~15 lines):

- **Before (RED):** `assert yml =~ "installer_milestone_audit:"` — asserted on a job key that no longer exists in ci.yml after Phase 194 fold
- **After (GREEN):** `assert yml =~ "scripts/ci/installer-milestone-audit.sh"` — anchors on the run command of the surviving `Installer milestone audit` step inside `fast_checks` (ci.yml:95)
- Updated `@moduledoc` to document the Phase-194 fold (job → step in fast_checks), replacing stale references to the removed standalone job
- Updated test name from "installer PR path detector extended and duplicated across both jobs" to "installer PR path detector extended and duplicated across fast_checks step and install_golden_contract job"
- The path-detector ×2 assertion (`Regex.scan` == 2) kept byte-identical
- The `assert yml =~ "install_golden_contract:"` assertion kept byte-identical

## Test Results

### Task 1: phase_51 re-anchored (D-15)
```
mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs
2 tests, 0 failures
```

### Task 2: phase_58 slicer re-verified (D-16)
```
mix test test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs
1 test, 0 failures
```
No edit required. The `library_tests_shard:` → `library_tests:` slicer boundary (lines 176→279 region) was undisturbed by Plan-01's 5 moved-job `if:` gates (added at lines 502/554/604/733/1156).

### Task 3: Both contract tests together (quick gate)
```
mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs
3 tests, 0 failures
```
The phase contract layer gate is satisfied.

## Deviations from Plan

None — plan executed exactly as written. The re-anchor was surgical (one line changed in the test, plus moduledoc/test-name wording updated for honesty). phase_58 required no edit as predicted.

## Known Stubs

None.

## Threat Flags

None. No new security-relevant surface introduced (test file only, reads ci.yml text).

## Self-Check: PASSED

- [x] Modified file exists: `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs`
- [x] Task 1 commit exists: `90d462a5`
- [x] Both tests green: 3 tests, 0 failures in combined run
- [x] Re-anchored assertion targets `scripts/ci/installer-milestone-audit.sh` which genuinely exists in ci.yml (line 95) — not vacuous
- [x] Path-detector ×2 and `install_golden_contract:` assertions unchanged
