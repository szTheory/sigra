---
phase: 233-library-suite-economics
plan: 02
subsystem: ci-evidence
tags: [github-actions, pull-request, exunit, timing, evidence-ledger]
requires:
  - phase: 233-library-suite-economics
    plan: 01
    provides: same-run deterministic timing artifacts for both ordinary library shards
provides:
  - Retry-free pull-request timing-probe receipt with immutable run and artifact provenance
  - Deterministically sorted repository-relative per-file cost input for D-04 balancing
affects: [233-03, 233-04, 233-05, TEST-01, TEST-02]
tech-stack:
  added: []
  patterns: [exact PR run matching, fail-closed receipt validation, stable per-file cost aggregation]
key-files:
  created: []
  modified:
    - .planning/phases/233-library-suite-economics/233-EVIDENCE.json
    - .planning/phases/233-library-suite-economics/233-EVIDENCE.md
decisions:
  - "Use PR #175 run 30666977944 as the timing probe because its CI workflow, pull_request event, PR number, and head SHA match exactly and run_attempt is 1."
  - "Store artifact identities and SHA-256 digests plus analyzed per-file aggregates, rather than volatile raw receipt downloads."
metrics:
  duration: 18m
  tasks_completed: 2
  files_modified: 2
  measured_files: 217
  measured_total_time_us: 506537530
  observed_shard_durations_seconds: {"1": 476, "2": 304}
completed: 2026-07-31
status: complete
---

# Phase 233 Plan 02: PR Timing-Probe Evidence Summary

**A retry-free PR run now proves both ordinary library shards executed in parallel and supplies 217 deterministic per-file costs for later D-04 balancing.**

## Accomplishments

- Created PR #175 and captured exact matching CI run `30666977944` (`pull_request`, head `5803ef3d03f9a224143a70a3ffe55aefdf0aa621`, attempt 1, success).
- Recorded the inherited `470s`/`278s` baseline and observed timing-probe shard durations of `476s`/`304s`.
- Downloaded and validated both same-run timing receipts, preserving their artifact names and SHA-256 digests.
- Aggregated 217 unique repository-relative test-file costs with non-negative-integer validation, duplicate identity rejection, and descending-cost/lexical-path ordering.
- Marked TEST-01 observed; TEST-02 remains measured-input-ready until extraction, manifest, and after-run comparison are complete.

## Verification

- `gh run view 30666977944 --json event,headSha,conclusion,jobs` confirmed a successful `pull_request` run on the exact PR head.
- `gh pr checks 175` reported both library shards and the `Library tests` aggregate as passing; shard 1 took 476s and shard 2 took 304s.
- JSON structural/ordering checks passed for the before baseline, retry-free probe, two artifacts, and all per-file costs.
- `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs test/support/ci/ex_unit_timing_formatter_test.exs` passed: 8 tests, 0 failures. Local PostgreSQL connection messages are expected test-helper noise and did not skip or fail assertions.

## Task Commits

1. Task 1 — `78d7b18a` docs(233-02): capture retry-free library timing probe
2. Task 2 — `256283b5` docs(233-02): aggregate library timing costs

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 3 - Blocking branch history] Created a clean Phase 233 evidence branch from current `main`.
- **Found during:** Task 1
- **Issue:** The supplied Phase 232 branch was merge-conflicted after Phase 232 had already landed as a squash merge, so PR #174 did not schedule the required CI run.
- **Fix:** Created `gsd/phase-233-library-suite-economics` from current `main` and replayed only the Phase 233 commits; PR #175 produced the required retry-free run.
- **Files modified:** None directly; branch history only.
- **Verification:** PR #175 CI run `30666977944` completed successfully with both ordinary shards and both timing artifacts.

**Total deviations:** 1 auto-fixed (Rule 3). **Impact:** None on scope; the clean branch enabled the plan's required real-PR observation while preserving the user's uncommitted `.planning/config.json` change and leaving the original branch untouched.

## Known Stubs

None.

## Next Phase Readiness

Plans 03 and 04 can use `timing_probe.per_file_costs` as the empirical input for extraction and partition balancing. TEST-02 is intentionally not complete until the final topology has its own retry-free after-run comparison.

## Self-Check: PASSED

- Confirmed both evidence files exist and both task commits are present.
- Confirmed the cited run still resolves as successful `pull_request` CI and its two artifact identities/digests are recorded.
