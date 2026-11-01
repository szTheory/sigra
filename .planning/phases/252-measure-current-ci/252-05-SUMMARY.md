---
phase: 252-measure-current-ci
plan: 05
subsystem: testing
tags: [github-actions, playwright, exunit, ci-measurements, source-replay]
requires:
  - phase: 252-03
    provides: opt-in ExUnit timing reporter and measured formatter overhead
  - phase: 252-04
    provides: normalized Playwright JSON reports and seven unique destinations
provides:
  - Existing CI owners retain per-run timing and runtime/cache metadata
  - Offline replay ranks measured job wait, runner cost, steps, tests, and artifact facts
  - Bounded current failure analysis keeps unsupported or missing evidence unknown
affects: [252-06, phase-252-verification, ci-performance]
actuals:
  tokens: 26679
  tasks: 3
  commits: 12
tech-stack:
  added: []
  patterns:
    - Source-bound report joins validate run, attempt, SHA, job, seam, and archive digest before ranking
    - Missing samples carry explicit unknown or insufficient-data status instead of numeric zero
key-files:
  created:
    - scripts/ci/ci-run-metrics-replay.test.mjs
    - .planning/phases/252-measure-current-ci/252-05-task1-red-evidence.json
    - .planning/phases/252-measure-current-ci/252-05-task2-red-evidence.json
    - .planning/phases/252-measure-current-ci/252-05-task2-single-red-evidence.json
    - .planning/phases/252-measure-current-ci/252-05-task3-red-evidence.json
    - .planning/phases/252-measure-current-ci/252-05-MIX-CI-DIAGNOSTIC.json
    - .planning/phases/252-measure-current-ci/252-05-STATE-PRESERVATION.json
  modified:
    - .github/workflows/ci.yml
    - scripts/ci/ci-measure-workflow.test.mjs
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci-run-metrics.test.sh
    - .planning/WINDOWS.md
key-decisions:
  - "Keep CI ownership and selection unchanged; measurement files are always retained from their existing jobs."
  - "Rank measured wait and total runner time separately; missing timestamps and versions remain unknown."
  - "A single failure or cancellation without proof of a superseding run does not count as a recurring flake."
requirements-completed: []
coverage:
  - id: D1
    description: Existing CI jobs retain ExUnit and seven Playwright reports with run metadata, actual runtime output, cache results, and runner image.
    verification:
      - kind: unit
        ref: scripts/ci/ci-measure-workflow.test.mjs
        status: pass
      - kind: other
        ref: actionlint .github/workflows/ci.yml
        status: pass
    human_judgment: false
  - id: D2
    description: Offline replay computes source-bound wait, runner, stage, cache, image, version, and separate test measurements.
    verification:
      - kind: integration
        ref: scripts/ci/ci-run-metrics.test.sh#Test V2
        status: pass
      - kind: unit
        ref: scripts/ci/ci-run-metrics-replay.test.mjs
        status: pass
    human_judgment: false
  - id: D3
    description: Current failure analysis is bounded, identity-linked, and distinguishes recurring evidence from unknown diagnostics.
    verification:
      - kind: integration
        ref: scripts/ci/ci-run-metrics.test.sh#Test V3
        status: pass
      - kind: unit
        ref: scripts/ci/ci-run-metrics-replay.test.mjs
        status: pass
    human_judgment: false
duration: 32min
completed: 2026-10-12
status: complete
commits: 12
plan_head_before: 9bde55eda32d730c2ce8ca8427719b947be1bc80
plan_head_after: 6807e6fe6ce665986bd1d4107b39719912f52263
---

# Phase 252 Plan 05: Current CI Measurement Summary

**Existing CI jobs now retain source-identifiable timing and runtime facts, and offline replay reports wait, runner cost, test rows, and a bounded current failure shortlist.**

## Performance

- **Duration:** 32 minutes
- **Started:** 2026-10-12T19:05:34Z
- **Completed:** 2026-10-12T19:37:13Z
- **Tasks:** 3
- **Files modified or created:** 13

## Accomplishments

- Kept the single `mix ci` library owner and all five Playwright selections, including seven distinct JSON destinations; added always-retained timing and job metadata with configured pins separate from command-observed versions.
- Added offline replay rankings by job wait and summed runner time, measured step categories, cache outcomes, runner image, actual versions, separate ExUnit and Playwright test rows, suite elapsed time, and instrumentation overhead disclosures.
- Added current failure analysis capped at four families per event and twelve overall, with at most three recurring signatures. Missing logs remain `unknown`; an empty eligible set reports `no_current_flake_identified`.

## Task Commits

1. **Task 1: Retain timing and cache provenance** — RED `5f0476060`; GREEN `0a0ca2e6f`; compatibility fix `085143ff0`.
2. **Task 2: Rank source-backed critical wait and summed runner costs** — RED `62a2a9be0`; GREEN `b296382cc`; single-observation RED `2ffb1610d`; GREEN `6807e6fe6`.
3. **Task 3: Produce a bounded current failure-signature shortlist** — RED `d8d6ca042`; GREEN `1ee3197e5`; additional empty-versus-unknown test `3fef4bac2`.

Additional plan records: summary `6354cc45d`; exact SDK state transition preservation `428183e85`.

## TDD Gate Compliance

| Task | RED evidence | GREEN commit | Result |
|---|---|---|---|
| 1 | `252-05-task1-red-evidence.json` — `RED_EVIDENCE_OK` | `0a0ca2e6f` | Passed |
| 2 | `252-05-task2-red-evidence.json` — `RED_EVIDENCE_OK` | `b296382cc` | Passed |
| 3 | `252-05-task3-red-evidence.json` — `RED_EVIDENCE_OK` | `1ee3197e5` | Passed |

Task 2's single-observation bound also has a separate RED/GREEN pair: `252-05-task2-single-red-evidence.json` (`RED_EVIDENCE_OK`), `2ffb1610d` → `6807e6fe6`.

## Files Created/Modified

- `.github/workflows/ci.yml` — timing and metadata uploads on existing jobs; no job or required-check ownership changes.
- `scripts/ci/ci-measure-workflow.test.mjs` — offline CI structure and artifact contract checks.
- `scripts/ci/ci-run-metrics.sh` and `.test.sh` — source-checked replay rankings and bounded failure diagnostics.
- `scripts/ci/ci-run-metrics-replay.test.mjs` — empty-sample, unknown, and cancellation classification contracts.
- `252-05-task{1,2,3}-red-evidence.json` and `252-05-task2-single-red-evidence.json` — actual TAP RED runs accepted by the GSD classifier.
- `252-05-MIX-CI-DIAGNOSTIC.json` and `deferred-items.md` — durable record of the remaining full-suite failure.

## Decisions Made

- The job API does not expose dependency edges, so dependency-gap values are explicitly unknown; no elapsed time is assigned to an inferred stage.
- ExUnit formatter overhead is presented as a historical instrumentation baseline, separate from current run measurements.
- A cancelled run is called superseded only when a later attempt or superseding run identity is present; otherwise it stays `cancellation_unclassified`.
- Phase requirements remain Pending until phase-level verification. Hosted artifacts and the five browser selections are pending Plan 252-06; no hosted result is claimed here.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Existing workflow contract compatibility] Restored the documented `MIX_ENV=test mix ci` text while keeping the planned command semantics.**
- **Found during:** final `mix ci` verification.
- **Issue:** Existing ExUnit workflow checks require the historical literal command phrase, while Plan 252-05 keeps `run: mix ci` and sets `MIX_ENV=test` in the step environment.
- **Fix:** Added the local-equivalent comment and allowed the original command form in the new offline workflow test. The actual run command remains `run: mix ci`.
- **Files modified:** `.github/workflows/ci.yml`, `scripts/ci/ci-measure-workflow.test.mjs`.
- **Verification:** workflow Node test, actionlint, and the three existing workflow-contract ExUnit files passed (28 tests, 0 failures).
- **Committed in:** `085143ff0`.

**Total deviations:** 1 auto-fixed compatibility issue. The unrelated six-test Threadline failure is recorded as deferred work, not changed by this plan.

## Issues Encountered

- The full required `mix ci` command exits 2 after six `Sigra.Audit.Forwarders.ThreadlineTest` cases fail with `UndefinedFunctionError` for `Sigra.Audit.Forwarders.Threadline.attach/1`. The separate dependency-off group passes (65 tests, 0 failures). The changed workflow contract failures found on the first run were fixed and their focused tests now pass. Full output details and failing test names are in `252-05-MIX-CI-DIAGNOSTIC.json`.
- Hosted CI was not dispatched. Plan 252-06 owns acquisition of the producing draft PR, hosted browser selections, and proof that hosted artifacts carry the actual locked Playwright version.

## User Setup Required

None.

## Next Phase Readiness

Plan 252-05 implementation and offline contracts are committed. The SDK-generated state transition is recoverable at commit `428183e85`; the prior STATE, state.json, and ROADMAP bytes were verified before route reconciliation. Hosted artifact and browser proof remains pending Plan 252-06, and the six Threadline failures remain in `deferred-items.md`. Continue with `$gsd-execute-phase 252`; keep all Phase 252 requirements Pending until phase-level verification.

## Self-Check: PASSED

- Summary and evidence files exist at the paths listed above.
- All ten task commits and two plan-record commits measured from `plan_head_before` are ancestors of `plan_head_after`.
- The working tree was clean after task commits; the only failing full-suite cases are listed in the committed diagnostic.

---
*Phase: 252-measure-current-ci*
*Completed: 2026-10-12*
