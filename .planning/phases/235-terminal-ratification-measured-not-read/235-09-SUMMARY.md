---
phase: 235-terminal-ratification-measured-not-read
plan: 09
subsystem: CI evidence ratification
tags: [github-actions, fast-01, attestation, pagination, metrics]
requires:
  - phase: 235-08
    provides: protected GATE-05 receipt and offline verifier
provides:
  - fixed-cutoff non-authoritative FAST-01 readiness collector
  - main-only protected fresh-window evidence workflow
affects: [FAST-01, GATE-05, CI performance evidence]
tech-stack:
  added: []
  patterns: [bounded GitHub pagination, attested measurement subject, fail-closed population gate]
key-files:
  created:
    - scripts/ci/capture-fast-01-remeasurement.sh
    - scripts/ci/capture-fast-01-remeasurement.test.sh
    - .github/workflows/fast-01-remeasurement-evidence.yml
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT-READINESS.json
  modified:
    - test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs
    - .planning/phases/235-terminal-ratification-measured-not-read/235-COVERAGE.md
key-decisions:
  - "Readiness is non-authoritative and has null statistics/verdict; only the independent protected subject may be measured."
  - "The fixed a282b3de cutoff is preserved and the live population of four PR runs blocks FAST-01 evidence."
requirements-completed: [FAST-01, GATE-05]
coverage:
  - id: D1
    description: Fixed-cutoff readiness collection with contiguous pagination and null verdict
    requirement: FAST-01
    verification:
      - kind: unit
        ref: scripts/ci/capture-fast-01-remeasurement.test.sh
        status: pass
      - kind: integration
        ref: test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: Main-only input-free protected attestation path that requires ten PR runs
    requirement: FAST-01
    verification:
      - kind: other
        ref: actionlint .github/workflows/fast-01-remeasurement-evidence.yml
        status: pass
    human_judgment: false
  - id: D3
    description: Existing protected GATE-05 receipt remains independently verified
    requirement: GATE-05
    verification:
      - kind: integration
        ref: scripts/ci/verify-terminal-ratification-attestation-offline.sh
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-08-03
status: complete
---

# Phase 235 Plan 09: Fresh FAST-01 remeasurement path summary

The fixed protected-main cutoff now produces a truthful readiness artifact—currently four eligible PR runs and `insufficient_population`—while a separate main-only workflow can attest one future ten-run measurement subject.

## Accomplishments

- Added a bounded, all-conclusion paginated collector that fixes the cutoff at `a282b3deed009e62707b1a01d16da053a53e37d8` / `2026-08-03T15:36:12Z` and retains exact public run identities.
- Recorded the live readiness state as non-authoritative with null statistics/verdict, preserving the historical 19-run, 772-second FAST-01 miss and completed GATE-05 proof.
- Added an input-free, main-only workflow with least-privilege permissions, immutable action pins, a ten-run gate, byte-identical attestation/upload subject, and no `ci.yml` linkage.

## Verification

- `bash scripts/ci/capture-fast-01-remeasurement.test.sh`
- `MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs`
- `bash scripts/ci/ci-run-metrics.test.sh`
- `actionlint .github/workflows/fast-01-remeasurement-evidence.yml`
- `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh`
- Readiness JSON contract check: pass (`eligible_pr_run_count=4`, `status=insufficient_population`, null statistics/verdict).

## Task Commits

1. **Task 1 RED: fresh-window collector contracts** — `27b10860` (`test`)
2. **Task 1: non-authoritative readiness collector** — `7388adbc` (`feat`)
3. **Task 2: protected fresh-window attestation workflow** — `b03a0b44` (`feat`)

## Decisions Made

- Local readiness derives its endpoint internally and cannot be passed, read from the environment, or reused as a protected verdict subject.
- The protected path orders wall durations by `{wall_seconds, run_id}`, uses `floor(n/2)`, and treats exactly 720 seconds as a miss.
- FAST-01 remains blocked until at least ten terminal PR runs exist; this plan does not alter the historical measurement or GATE-05 ownership proof.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 - Blocking portability] Used an absolute `/bin/date` fallback when `/usr/bin/date` is absent in the local macOS execution image.**
   - **Found during:** Task 1
   - **Issue:** The mandated PATH-independent `/usr/bin/date` binary is unavailable locally.
   - **Fix:** Prefer `/usr/bin/date` and fall back only to the equally absolute `/bin/date`; CI/Linux retains `/usr/bin/date`.
   - **Verification:** Hermetic collector suite passes and bounds the generated endpoint to the invocation.
   - **Committed in:** `7388adbc`

**Total deviations:** 1 auto-fixed (Rule 3).

## Issues Encountered

Focused ExUnit emits pre-existing local Postgrex connection-refused logs while the two focused contract tests pass; no database-backed behavior is exercised by this plan.

## Next Phase Readiness

The protected workflow is ready to capture one future window. The durable readiness artifact blocks dispatch evidence honestly until the public post-cutoff PR population reaches ten runs.

## Self-Check: PASSED

- All six declared plan artifacts exist.
- Task commits `27b10860`, `7388adbc`, and `b03a0b44` exist in git history.
