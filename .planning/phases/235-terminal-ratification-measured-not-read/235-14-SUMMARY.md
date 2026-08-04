---
phase: 235-terminal-ratification-measured-not-read
plan: 14
subsystem: ci-verification
tags: [bash, attestation, trusted-staging, offline-verification]
requires: [235-13]
provides: [FAST-01 trusted staging, GATE-05 trusted staging]
affects: [offline attestation verification]
tech-stack:
  added: []
  patterns: [pinned bash entrypoint, absolute utility inventory, fixed-parent staging]
key-files:
  created:
    - scripts/ci/verify-fast-01-gap-closure-attestation-offline.test.sh
  modified:
    - scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
    - scripts/ci/verify-terminal-ratification-attestation-offline.sh
    - scripts/ci/verify-terminal-ratification-attestation-offline.test.sh
    - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
    - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
decisions:
  - Pin verifier entrypoints to /bin/bash and use Bash-only script-root derivation.
  - Stage retained inputs beneath a validated fixed parent after clearing temporary overrides.
metrics:
  tasks_completed: 2
status: complete
---

# Phase 235 Plan 14: Trusted Offline Attestation Staging Summary

**FAST-01 and GATE-05 retained evidence now passes through pinned-Bash, fixed-parent trusted staging before offline provenance verification.**

## Accomplishments

- Hardened both verifier entrypoints against caller-controlled PATH and temporary-directory state.
- Added direct hostile-environment regressions that require each final positive marker and zero sentinel executions.
- Kept retained receipts, readiness input, config, and workflow-owned STATE byte-identical and unstaged.

## Verification

- `scripts/ci/verify-fast-01-gap-closure-attestation-offline.test.sh` — passed.
- `scripts/ci/verify-terminal-ratification-attestation-offline.test.sh` — passed.
- Both live offline attestation verifiers — passed their positive and adverse cases.
- `MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — passed (focused contracts; local PostgreSQL connection warnings are non-fatal test setup noise).

## Commits

- `a035e742` — FAST trusted-staging RED tests.
- `171b992e` — FAST verifier hardening.
- `b098ada8` — terminal trusted-staging RED tests.
- `db617f5f` — terminal verifier hardening.
- `91ab9d93` — reconciliation mutation coverage correction.
- `4b077966` — Darwin trusted-parent compatibility correction.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Contract assumed requirement checkboxes were already checked**
   - **Found during:** Task 1
   - **Fix:** Validate immutable FAST/GATE evidence text without requiring mutable checkbox state.
   - **Files modified:** `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs`

2. **[Rule 1 - Bug] Darwin trusted temporary parent exposes mode 0777**
   - **Found during:** Task 2
   - **Fix:** Accept the root-owned, non-symlink platform parent with mode `0777` or `01777`, while retaining a private mode-0700 work directory.
   - **Files modified:** both offline verifier scripts

**Total deviations:** 2 auto-fixed.

## Self-Check: PASSED
