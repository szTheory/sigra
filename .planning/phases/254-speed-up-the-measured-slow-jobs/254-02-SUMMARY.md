---
phase: 254-speed-up-the-measured-slow-jobs
plan: "02"
subsystem: testing
tags: [ci, playwright, workload-parity, native-reports]
requires:
  - phase: 252-measure-current-ci
    provides: Frozen source bundle, native reports, and comparison contract
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: Existing native report normalization and hosted-origin verifier
  - phase: 254-speed-up-the-measured-slow-jobs
    plan: "01"
    provides: Source readiness and pinned preparation source identities
provides:
  - Source-bound browser product identity, expected-status, actual-result, and owner comparison in ci-browser-records
  - Exact five-owner inventory mapping from frozen Phase 252 reports to the pinned pre-optimization selection
  - Adversarial fixtures for substitutions, skips, exclusions, setup rows, ownership, source binding, and unsafe paths
affects: [254-03, 254-07, ci, playwright]
tech-stack:
  added: []
  patterns: [source-bound native coverage descriptors, exact one-to-one workload identity mapping]
key-files:
  created:
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-WORKLOAD-MAP.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-02-01-red-evidence.json
  modified:
    - scripts/ci/ci-browser-records.mjs
    - scripts/ci/ci-browser-records.test.mjs
key-decisions:
  - "Use the full project, spec, suite-title path, native spec ID, and test title as the mapped identity; counts alone cannot establish parity."
  - "Keep Playwright --list selection distinct from executed results and keep setup dependencies separate from product coverage."
  - "Require intentional skips to cite a source-bound policy and exact native identity."
  - "Keep CISPEED-01 and CISPEED-02 supported but incomplete until hosted comparison evidence passes."
actuals:
  tokens: 32325
  tasks: 2
  commits: 4
plan_head_before: 499f758eda7bc59b1d57d636a8f5eda610209f9f
plan_head_after: 2a57d3a10fd350b2f033899536d3a5fc57bc7ff6
patterns-established:
  - "Coverage descriptors bind each native report digest to one source revision and the workflow/configuration/lock digests."
  - "A complete candidate selection can be reported while candidate execution outcomes remain explicitly unproven."
requirements-completed: []
requirements-supported: [CISPEED-01, CISPEED-02]
coverage:
  - id: D1
    description: "The record CLI compares exact native product identities, expected and actual status, owner mapping, source binding, and report digests."
    verification:
      - kind: unit
        ref: scripts/ci/ci-browser-records.test.mjs
        status: pass
      - kind: integration
        ref: "node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "The workload map matches all 108 frozen baseline case identities to the pinned candidate selection across five owners; candidate execution outcomes are not available."
    requirement: CISPEED-01
    verification:
      - kind: other
        ref: .planning/phases/254-speed-up-the-measured-slow-jobs/254-WORKLOAD-MAP.json
        status: unknown
    human_judgment: true
    rationale: "The missing full-lane Phase 253 native reports and execution-record wrapper for source 588497a4db5a5ab09ebb7e150f059f09f838943e prevent checking candidate actual results."
metrics:
  duration: 16m
  completed: 2026-10-23
  status: complete
---

# Phase 254 Plan 02: Exact Browser Workload Map Summary

**The browser record tool now checks exact case and project parity; the pinned candidate selection matches all 108 baseline identities, while candidate execution results remain unproven.**

## Performance

- **Duration:** 16 minutes
- **Started:** 2026-10-23T17:01:00Z
- **Completed:** 2026-10-23T17:17:32Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `--compare-coverage`, `--before-directory`, `--after-directory`, and `--mapping` to `ci-browser-records.mjs`, along with `normalizedProductRows` and `compareProductCoverage`. Comparisons preserve project, spec path, complete suite-title path, native spec ID, case title, expected status, actual result, and explicit owner.
- Bound native reports to source revisions and workflow/configuration/lock digests. The tool checks report digests, rejects duplicate or missing mappings and source mismatches, compares exclusions, keeps setup rows separate, and accepts intentional skips only when their exact identities are tied to a source-bound policy. Existing same-run native failure and provenance checks remain intact.
- Created a five-owner map from the retained Phase 252 source bundle and Playwright 1.59.1 `--list` output from source `588497a4db5a5ab09ebb7e150f059f09f838943e`. All 108 baseline identities have a matching candidate selection: 43 admin_behavior, 3 admin_checkpoints, 42 design_gallery, 16 non_admin_smoke, and 4 demo_showcase. Three gallery setup rows are labeled as setup work.
- Captured the RED evidence and verified it with `gsd-tools check tdd-red-evidence`; it returned `RED_EVIDENCE_OK`. The final focused Node suite passed 41/41 tests, and the independent hosted-gate verifier passed 151/151 tests.

## Task Commits

1. **Task 1: Compare native product selection and preserve source identities** - `4edda7061` (test), `daa63cd68` (feat)
2. **Task 2: Cover all owners, setup rows, exclusions, and skip policies** - `886298414` (feat), `2a57d3a10` (fix)

The measured task-commit count is 4 from `plan_head_before` through `plan_head_after`. The metadata summary commit is separate.

## Files Created/Modified

- [ci-browser-records.mjs](/Users/jon/projects/sigra/scripts/ci/ci-browser-records.mjs) - validates source-bound report descriptors and compares exact product coverage.
- [ci-browser-records.test.mjs](/Users/jon/projects/sigra/scripts/ci/ci-browser-records.test.mjs) - adds CLI and negative coverage fixtures.
- [254-WORKLOAD-MAP.json](/Users/jon/projects/sigra/.planning/phases/254-speed-up-the-measured-slow-jobs/254-WORKLOAD-MAP.json) - records all five owner inventories, native IDs, digests, and the missing candidate result source.
- [254-02-01-red-evidence.json](/Users/jon/projects/sigra/.planning/phases/254-speed-up-the-measured-slow-jobs/254-02-01-red-evidence.json) - retains the target test's verified RED output.

## Decisions Made

- The full native identity is the comparison key. A matching case count does not establish that the same project or test ran.
- `--list` output establishes selection only. Its skipped status is not an executed skip or pass.
- The map retains baseline actual results and candidate expected statuses separately; it does not fill unavailable candidate outcomes with inferred values.
- Requirements CISPEED-01 and CISPEED-02 are supported by the tooling and inventory, but are not marked complete because hosted comparison evidence has not passed.

## Deviations from Plan

None. The plan explicitly requires unknown native reports to remain unproven and to block collection.

## Issues Encountered

The retained Phase 252 bundle contains native reports for all five owners. The pinned current-source `--list` selection has matching identity rows for all 108 baseline cases. The repository does not contain full-lane Phase 253 native reports or an execution-record wrapper bound to candidate source `588497a4db5a5ab09ebb7e150f059f09f838943e`; the available Phase 253 reports are scoped recovery attempts on other commits. Therefore the map records every candidate actual result as `not_run`, and workload outcome parity is **unproven**. The missing item is the full-lane native result report set and its source-bound execution record for that candidate revision. Until those are available, this plan provides no hosted parity pass and no permission to collect hosted speed comparisons.

## Known Stubs

None. `not_run` is an explicit missing-evidence status in the map, not a placeholder result.

## Next Phase Readiness

Plan 254-03 may proceed: its plan depends on 254-01, which is complete. Plan 254-02 supplies the exact identity map for later comparison. Hosted collection remains blocked until candidate actual outcomes can be checked against these identities and the frozen reports.

## TDD Gate Compliance

- **RED:** `4edda7061`; target assertion failed because the comparison CLI did not yet exist. The unchanged TAP record passed `gsd-tools check tdd-red-evidence`.
- **GREEN:** `daa63cd68`; comparison implementation added.
- **REFACTOR:** not needed.
- **Verification:** 41/41 focused Node tests passed; 151/151 independent hosted-gate tests passed.

## Self-Check: PASSED

- All created and modified deliverables exist, and the workload map parses with five owners, 108 rows, and no unmatched selections.
- All four measured task commits are ancestors of the current `HEAD`.
- `plan_head_before` and `plan_head_after` match the persisted ledger and the committed task range.

---
*Phase: 254-speed-up-the-measured-slow-jobs*
*Completed: 2026-10-23*
