---
phase: 235-terminal-ratification-measured-not-read
plan: 03
subsystem: ci-evidence
tags: [github-actions, ci-metrics, fast-01, gate-05, contributor-dx]
requires:
  - phase: 235-02
    provides: immutable terminal CI measurement ledger and strict FAST-01 verdict
provides:
  - contract-checked contributor CI topology
  - reconciled SEED-005 and CI-PERF terminal records
  - one owned residual for the measured FAST-01 miss
affects: [ci-efficiency, fast-01, gate-05, contributor-documentation]
tech-stack:
  added: []
  patterns: [ledger-backed planning closeout, direct-owner versus aggregate contributor documentation]
key-files:
  created:
    - .planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md
  modified:
    - CONTRIBUTING.md
    - .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
    - .planning/MILESTONE-ARC.md
    - .planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json
    - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
key-decisions:
  - "FAST-01 remains unmet: 19 retained PR runs produced a 772-second p50, which is not strictly less than 720 seconds."
  - "GATE-05 is reconciled only after one focused contract validates the contributor topology and both closeout records against the terminal ledger."
  - "The sole FAST-01 residual points to the recorded Library tests and admin-checkpoints binding-pole receipts; no unrelated pending todo was folded in."
patterns-established:
  - "Documentation topology claims are tested against live workflow, Mix, Playwright config, and package sources."
  - "Measured misses close honestly with one ledger-linked owner/follow-up residual."
requirements-completed: [GATE-05]
coverage:
  - id: D1
    description: "Contributor topology distinguishes direct CI owners, terminal aggregates, Playwright reproduction, and non-PR signals."
    requirement: GATE-05
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs#contributor topology"
        status: pass
    human_judgment: false
  - id: D2
    description: "SEED-005, CI-PERF, and the terminal ledger reconcile exactly to the measured result."
    requirement: GATE-05
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs#terminal closeout"
        status: pass
    human_judgment: false
  - id: D3
    description: "FAST-01 has an evidence-backed residual because the strict target was missed."
    requirement: FAST-01
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs#terminal closeout"
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-08-02
status: complete
---

# Phase 235 Plan 03: Terminal Closeout Summary

**Contributor topology and planning records now reconcile to the measured 19-run, 772-second FAST-01 miss, with one binding-pole residual and GATE-05 closed.**

## Performance

- **Duration:** 5min
- **Started:** 2026-08-02T18:14:55Z
- **Completed:** 2026-08-02T18:19:46Z
- **Tasks:** 2/2
- **Files modified:** 6

## Accomplishments

- Published direct CI owner versus terminal aggregate topology, all five Playwright seams, supported local reproduction, and non-PR signal boundaries in `CONTRIBUTING.md`.
- Appended an immutable-ledger addendum to SEED-005 and reconciled the stale CI-PERF active framing while preserving the historical audit and baseline.
- Recorded the exact FAST-01 miss — 19 retained PR runs, 772-second p50, strict target `< 720` unmet — in one owner-assigned residual with both binding-pole receipts.
- Set the terminal ledger closeout to `records_reconciled` and GATE-05 to `reconciled` only after the unified contract passed.

## Measured Result

| Event | Runs | p50 seconds | Outcomes |
| --- | ---: | ---: | --- |
| pull_request | 19 | 772 | 13 success / 6 non-success |
| push | 2 | 1439 | 1 success / 1 non-success |
| schedule | 2 | 1546 | 0 success / 2 non-success |

FAST-01 is not complete: 772 seconds is not strictly less than 720 seconds. GATE-05 is complete; the terminal ownership artifact and closeout records are reconciled.

## Task Commits

1. **Task 1 RED: Specify contributor topology contract** — `d26d06bd` (test)
2. **Task 1 GREEN: Reconcile contributor CI topology** — `62333f3d` (feat)
3. **Task 2 RED: Specify ledger-backed closeout** — `605a8cb8` (test)
4. **Task 2 GREEN: Reconcile terminal CI records** — `94d6ec34` (feat)

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — pass (11 tests)
- `MIX_ENV=test mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs` — pass (6 tests)
- `bash scripts/ci/ci-run-metrics.test.sh` — pass (9 checks)
- `MIX_ENV=test mix test test/sigra/planning/` — pass (106 tests, 12 skipped)
- Terminal-ledger `jq` reconciliation assertion — pass

## Files Created/Modified

- `CONTRIBUTING.md` — current direct-owner, aggregate, reproduction, and non-PR CI guidance.
- `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` — dated terminal addendum preserving prior audit history.
- `.planning/MILESTONE-ARC.md` — CI-PERF reconciliation preserving the original baseline.
- `.planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md` — owned residual with run/job receipt links.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` — reconciled closeout pointers and state.
- `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — topology and closeout contradiction contract.

## Decisions Made

- Do not reinterpret the strict FAST-01 threshold: the target remains unmet at the measured 772-second p50.
- Preserve SEED-005 and CI-PERF history, adding a terminal reconciliation rather than rewriting prior audit records.
- Keep the residual scoped to the ledger-backed performance miss; no timeout, retry, workflow, or unrelated todo change is part of this plan.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Focused planning tests emit expected Postgrex connection-refused logs while the test harness starts without a local database; all focused and planning-contract tests pass because they do not require database access.

## Known Stubs

None.

## Next Phase Readiness

- GATE-05 is reconciled and ready for final phase verification.
- FAST-01 remains open only through `.planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md`; its measured result must not be represented as a pass.

## Self-Check: PASSED

- All six key files exist.
- Task commits `d26d06bd`, `62333f3d`, `605a8cb8`, and `94d6ec34` exist in Git history.
