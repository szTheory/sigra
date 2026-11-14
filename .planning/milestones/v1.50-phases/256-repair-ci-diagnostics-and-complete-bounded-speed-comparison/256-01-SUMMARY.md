---
phase: 256-repair-ci-diagnostics-and-complete-bounded-speed-comparison
plan: "01"
subsystem: ci
tags: [github-actions, diagnostics, authorization, budgets, measurement]
requires:
  - phase: 255
    provides: "The completed baseline needed by the bounded comparison."
  - phase: 255.1
    provides: "Historical stop, retained control evidence, and unchanged prior spend."
provides:
  - "Safe capture and metadata binding for report-only browser setup failures."
  - "Offline Phase256 authorization, route, shared-budget, clock-anchor, and process-timeout boundaries."
affects: [256-02, 256-03, 256-04, 256-05, CISPEED-01, CISPEED-02]
actuals:
  tokens: 200274
  tasks: 2
  commits: 0
plan_head_before: 302a7f3b6a9edb435f4917429b16cbe6befc6f8f
plan_head_after: 302a7f3b6a9edb435f4917429b16cbe6befc6f8f
tech-stack:
  added: []
  patterns:
    - "Distinct successor policy in the existing fail-closed authorizer."
    - "Shared append-only reservations and process-group timeouts before external collection."
key-files:
  created:
    - .planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-01-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - scripts/ci/ci-diagnostics-canary.test.py
    - scripts/ci/ci-repaired-comparison.py
    - scripts/ci/ci-repaired-comparison.test.py
    - scripts/ci/ci_metrics_security.py
    - scripts/ci/ci_repaired_driver.py
    - scripts/ci/ci-repaired-driver.test.py
    - scripts/ci/ci-prep-proposal.test.py
decisions:
  - "Keep CISPEED-01/02 open until the bounded hosted comparison and independent verification prove their measured outcomes."
  - "Resolve captured artifact members by exact ZIP-relative identity or exact artifact-qualified path; reject ambiguous matches."
  - "Defer the positive new object-store readback to Plan02 Task3, proposal closure to Plan02 Task2, and preparation/measurement outcome gates to Plans03–04."
metrics:
  duration: "not recorded"
  completed: 2026-11-04
status: complete
requirements-completed: []
---

# Phase 256 Plan 01: Diagnostics and local policy boundaries

**Report-only browser setup failures are retained safely, and the Phase256 local policy guards reject unsafe I/O and budget drift before transport.**

## Performance

- **Duration:** Not recorded; this executor continued an existing run without its start timestamp.
- **Completed:** 2026-11-04
- **Tasks:** 2/2
- **Files modified:** 8 source and test paths.

## Accomplishments

- The diagnostics path retains structured browser setup reports and phase logs, supports both report locations, binds metadata to the captured report, and rejects unsafe paths.
- The existing production authorizer has a distinct Phase256 policy. Offline tests cover claim and route rejection, shared request/mutation/workload/runner limits, immutable clock anchors, source-proof mutations through the verifier interface, and collection timeout behavior.
- Collection runs in a bounded process group and records attempted/spent counts on timeout or failure. No hosted action or performance workload ran in this plan.
- The local source-proof tests do not prove the positive readback from the new `objects.git` store. Plan02 Task3 owns that check; Plan02 Task2 owns proposal closure; Plans03–04 own preparation outcomes and the dependency-gated measurement handoff.
- CISPEED-01/02 remain open. Local checks and preparation do not establish measured performance results.

## Verification

- `python3 -B scripts/ci/ci-diagnostics-canary.test.py` — 19 passed.
- `python3 -B scripts/ci/ci-repaired-comparison.test.py Phase256ScopeTests` — 21 passed.
- `python3 -B scripts/ci/ci-repaired-comparison.test.py Plan10CandidateOnlyBoundaryTests` — 9 passed.
- Process-group termination and Phase256 pre-spawn reservation regressions — 1 passed each.
- Three targeted real-driver regressions passed: four-family preparation, forty-family comparison assembly, and measurement-ledger promotion. The forty-family case completed in 476.315 seconds; promotion completed in 95.505 seconds.
- Python byte-compilation and the scoped `git diff --check` passed.
- An independent plan review confirmed the Plan01/Plan02–04 boundary, unchanged limits and authorization, and that Plan01 is the sole ready plan.

## Files Created or Modified

- `.github/workflows/ci.yml` — retains the browser helper's structured report and logs in the diagnostics artifact.
- `scripts/ci/ci-diagnostics-canary.test.py` — exercises report capture, metadata binding, missing output, and unsafe paths.
- `scripts/ci/ci-repaired-comparison.py` — implements the Phase256 authorization, claim, route, source-proof, and shared-budget boundaries.
- `scripts/ci/ci-repaired-comparison.test.py` — covers Phase256 local guards and exact artifact-member matching.
- `scripts/ci/ci_metrics_security.py` — validates the distinct Phase256 policy while preserving historical policy branches.
- `scripts/ci/ci_repaired_driver.py` — bounds external collection with process-group termination and immutable receipts.
- `scripts/ci/ci-repaired-driver.test.py` — covers timeout receipts and bounded preparation/measurement driver paths.
- `scripts/ci/ci-prep-proposal.test.py` — covers proposal and source-proof rejection cases.

## Decisions Made

- Phase255.1 remains historical input only. Its spent allowances were neither reset nor reused.
- Source-derived limits and the original comparison plan remain fixed. Requirements close only after measured results and independent Phase256 verification.
- Artifact metadata accepts an exact ZIP-relative member path or the exact artifact-qualified path. It rejects basename suffixes and duplicate matches.
- Plan01 does not claim positive object-store readback, successful proposal closure, preparation outcome, or measurement continuation; those checks remain with their dependency-owning plans.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored exact ZIP-relative artifact member matching**
- **Found during:** Task 2 focused driver verification.
- **Issue:** The new artifact resolver accepted only `artifacts/<id>/<member>` paths, while existing production-shaped API evidence and fixtures record members relative to the ZIP root.
- **Fix:** Added exact ZIP-relative member matching while retaining the artifact-qualified match and rejecting ambiguous or basename-only matches.
- **Files modified:** `scripts/ci/ci-repaired-comparison.py`, `scripts/ci/ci-repaired-comparison.test.py`.
- **Verification:** Resolver tests and all three previously failing real-driver selectors passed.

**Total deviations:** 1 auto-fixed bug.

## Issues Encountered

The workspace `.git` metadata is read-only under the execution instruction. No Git write operation, permission change, or escalation was attempted. Implementation and evidence remain uncommitted; the recorded HEAD before and after is `302a7f3b6a9edb435f4917429b16cbe6befc6f8f` (0 commits).

## User Setup Required

None. No hosted or account access occurred.

## Next Plan Readiness

Plan 256-02 is the next dependency-ready plan after this terminal summary is registered and live readiness is refreshed. It creates the exact source store and proposal closure. No user action or additional approval is needed for the already authorized local scope. CISPEED-01/02 stay open pending the later bounded measurement and independent verification.

## Task Commits

No task or summary commit was created because Git writes were prohibited by the read-only workspace constraint.

## Self-Check: PASSED

- All eight declared source/test paths exist.
- The terminal summary records no completed requirements and no commit hash.
- Plan01 remains local-only; Phase255.1 allowances and Phase256 caps were unchanged.
