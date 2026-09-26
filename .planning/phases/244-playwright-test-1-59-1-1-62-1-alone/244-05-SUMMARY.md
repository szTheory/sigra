---
phase: 244-playwright-test-1-59-1-1-62-1-alone
plan: 05
subsystem: testing
tags: [playwright, github-actions, ci-evidence, jq]
requires:
  - phase: 244-04
    provides: measured defer disposition for PR #213 and final-main dispatch route
provides:
  - Fail-closed exact-main Playwright consumer collector and fake-GitHub contract suite
  - Exact-SHA final-main consumer receipt in 244-PLAYWRIGHT-EVIDENCE.json
affects: [QUEUE-02, Playwright CI evidence]
actuals:
  tokens: 8537.50
  tasks: 2
  commits: 12
tech-stack:
  added: []
  patterns: [paginated GitHub job and step validation, atomic evidence receipt]
key-files:
  created:
    - scripts/ci/capture-phase-244-final-main.sh
    - scripts/ci/capture-phase-244-final-main.test.sh
  modified:
    - .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json
key-decisions:
  - "A successful receipt requires each named browser or aggregate step individually completed and successful, independently of job and ci-gate conclusions."
  - "GitHub's run endpoint omits dispatch inputs; retain the exact authorized dispatch invocation as a route attestation while validating the returned event, ref, workflow, SHA, and all required consumers."
patterns-established:
  - "Collect every API job page and reject pagination inconsistencies before atomically writing evidence."
requirements-completed: [QUEUE-02]
coverage:
  - id: D1
    description: Fail-closed exact-main job and browser-step collector, including offline receipt verification.
    requirement: QUEUE-02
    verification:
      - kind: unit
        ref: bash scripts/ci/capture-phase-244-final-main.test.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Post-disposition main run proves all required browser consumers and ci-gate at the unchanged main SHA.
    requirement: QUEUE-02
    verification:
      - kind: integration
        ref: gh run 36266022766; capture and verify scripts/ci/capture-phase-244-final-main.sh
        status: pass
    human_judgment: false
metrics:
  duration: 45min
  completed: 2026-09-26
  status: complete
  plan_head_before: c006fd9cebc17b91693649713863ddf0cd30600d
  commits: 12
---

# Phase 244 Plan 05: Exact-Main Consumer Receipt Summary

**A fail-closed collector binds every named Playwright consumer and `ci-gate` to one successful post-disposition CI run on the exact unchanged main SHA.**

## Performance

- **Duration:** approximately 45 minutes
- **Started:** 2026-09-26T19:10:00Z
- **Completed:** 2026-09-26T19:55:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Implemented paginated structured GitHub job collection with exact job/step uniqueness and success checks, main SHA before/after checks, dispatch route validation, pagination integrity checks, atomic output, and offline verification.
- Added fake-`gh` cases for success, wrong SHA, missing and duplicate shard, duplicate step, missing `steps[]`, skipped smoke, failed gate, malformed response, changed main, total mismatch, and docs-only skipped browser bodies.
- Captured final-main run [36266022766](https://github.com/szTheory/sigra/actions/runs/36266022766), event `workflow_dispatch`, ref `main`, SHA `5a00b90d2314bc93f27aec4090b5928018743d1b`; all five shard browser steps, the example smoke aggregator, generated-admin harness, and `ci-gate` completed successfully. The complete run, including admin-eval, concluded success.
- Added a distinct machine-readable receipt to `244-PLAYWRIGHT-EVIDENCE.json`; verified the recorded measurement, PR disposition, and eligibility sections remain unchanged. QUEUE-02's descriptor-less edge probe remains explicitly unclassified and unresolved (applicable 1, resolved 0, unresolved 1).

## Task Commits

1. **Task 1: Reject stale, skipped or incomplete final-main CI receipts** - `37dbd974`, `f676dde3`, `7a23cf55`, `b05a5b35`, `62607bc8`, `d06ad5a6`, `090fd897`
2. **Task 2: Run final main CI and commit exact-SHA receipt** - `b9688271`

**Plan metadata:** GSD summary/state/roadmap bookkeeping commits are included in `actuals.commits`.

## Files Created/Modified

- `scripts/ci/capture-phase-244-final-main.sh` - exact-main GitHub job/step collector and offline validator.
- `scripts/ci/capture-phase-244-final-main.test.sh` - success fixture and ten fail-closed fixture cases.
- `.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json` - final-main run receipt plus QUEUE-02 probe status.

## Decisions Made

- GitHub's Actions run endpoint omits workflow-dispatch inputs. The receipt records the authorized dispatch route and its exact requested inputs alongside API-verified event, branch, workflow, SHA, and consumer executions.
- Unrelated CI jobs may be skipped on a successful run; the collector allows those jobs while requiring each of the eight named jobs and their required steps to pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Adapted dispatch proof to GitHub's structured run response**
- **Found during:** Task 2
- **Issue:** GitHub omits manual workflow inputs from the run endpoint, and unrelated CI jobs can be legitimately skipped, so the initial collector rejected valid main evidence.
- **Fix:** Record the exact authorized dispatch route as an attestation; validate API event/ref/workflow/SHA and the required consumers; permit skipped unrelated jobs.
- **Files modified:** `scripts/ci/capture-phase-244-final-main.sh`
- **Verification:** all local fixtures pass; live collector and offline receipt verification pass for run 36266022766.
- **Committed in:** `7a23cf55`, `b05a5b35`, `62607bc8`

## Issues Encountered

- The initial live collector attempt found the GitHub API metadata differences above. The collector was corrected, the fake-`gh` suite rerun, and live capture then passed.

## User Setup Required

None.

## Next Phase Readiness

Plan 05 has the exact-main consumer receipt. Push the scoped evidence branch only after exact-current-HEAD `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci` succeeds. Plan 05 leaves the QUEUE-02 edge-probe item unclassified and unresolved as required.

## Self-Check: PASSED

- Collector, test fixture, and updated evidence JSON are present.
- All listed task commits exist.
- Live run and offline receipt verification pass.

---
*Phase: 244-playwright-test-1-59-1-1-62-1-alone*
*Completed: 2026-09-26*
