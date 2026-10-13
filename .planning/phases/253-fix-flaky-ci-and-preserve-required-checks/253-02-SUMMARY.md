---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 02
subsystem: testing
tags: [playwright, phoenix, registration, ci]
requires:
  - phase: 252-measure-current-ci
    provides: archived CI source and registration failure leads
provides:
  - Frozen registration reproduction selection and bounded execution limits
  - Durable record of setup failures and the unresolved CIREL-01 gap
affects: [253-08, CIREL-01]
actuals:
  tokens: 6803
  tasks: 0
  commits: 1
commits: 1
plan_head_before: de53d1c80f4a67b73a5e5078959c2c88ad75abe8
plan_head_after: 810b6c3be2470b549fa65d1a6d082670ca2678fe
tech-stack:
  added: []
  patterns: [isolated lockfile restore, bounded browser diagnostics]
key-files:
  created:
    - scripts/ci/ci-registration-repro.sh
    - scripts/ci/ci-registration-repro.test.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPRO-FREEZE.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REGISTRATION-EVIDENCE.json
  modified: []
key-decisions:
  - "Keep CIREL-01 unsatisfied because no Playwright browser invocation ran."
  - "Do not infer a preceding test order that the retained archive does not identify."
requirements-covered: [CIREL-01]
requirements-completed: []
coverage:
  - id: D1
    description: Frozen selection, tool versions, and bounded runner diagnostics for the registration lead
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: bash scripts/ci/ci-registration-repro.test.sh
        status: pass
      - kind: integration
        ref: .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REGISTRATION-EVIDENCE.json
        status: unknown
    human_judgment: true
    rationale: The isolated example app never became HTTP ready, so no browser result proves the registration behavior.
duration: 14min
completed: 2026-10-13
status: halted
---

# Phase 253 Plan 02: Registration Reproduction Summary

**The selected registration failure remains unexplained; the pinned browser run did not start.**

## Performance

- **Duration:** Approximately 14 minutes
- **Started:** 2026-10-13T03:14:00Z (approximate tool session start)
- **Completed:** 2026-10-13T03:28:54Z
- **Tasks:** 0/3 completed; Task 1 diagnostic artifacts are partial
- **Files modified:** 5, including this summary

## Accomplishments

- Froze the exact `board-mg-9/populated` selection across `admin-eval`, `admin-eval-mobile`, and `admin-eval-dark`, with retries set to zero and the 10-invocation, 20-minute-per-signature, and 60-minute-total limits recorded before results.
- Confirmed the current helper blob matches the historical blob `6540493e78121f134867445dffc7010afcd85815`. The retained records name three failed admin-eval jobs and the latest failed test, but leave the cause unknown.
- Restored Playwright 1.59.1 from the existing lockfile in a temporary clean checkout. Observed Ecto SQL 3.13.5 and Phoenix LiveView 1.1.28. The shell freeze checks and acceptance-record check pass.

## Task Commits

1. **Task 1 partial diagnostics:** `810b6c3be` (`chore(253-02): preserve bounded registration diagnostics`). This commit preserves the freeze and setup evidence; Task 1 acceptance criteria were not met.

No Task 2 or Task 3 commit was made. There is no RED evidence or RED commit for the planned TDD controls.

## Files Created/Modified

- `scripts/ci/ci-registration-repro.sh` - bounded isolated runner and evidence checks. Its real-app launch path remains unverified and requires repair before reuse.
- `scripts/ci/ci-registration-repro.test.sh` - freeze and runner-mode contract checks.
- `253-REPRO-FREEZE.json` - source identities, selected test, project order, and budgets fixed before any browser results.
- `253-REGISTRATION-EVIDENCE.json` - Playwright 1.59.1 and locked Mix dependency versions, historical failures, attempted setup diagnoses, zero browser invocations, and the open requirement.

## Decisions Made

- The previous failure order was not present in the retained record, so no preceding-order selection was invented.
- No timeout, authentication behavior, application helper, or retry policy was changed without a reproduced cause.
- `CIREL-01` remains unsatisfied; the evidence status is `diagnosis_incomplete`, not `not_reproduced`.

## Deviations from Plan

The frozen browser run could not reach Playwright. The initial setup hit a write denial in the global Hex cache; using a scoped temporary `HEX_HOME` resolved that. The next setup exposed an output-pipe error in version extraction; consuming the full Mix output resolved that. The first app launch then failed HTTP readiness because the runner did not retain its launcher process. One independently diagnosed infrastructure retry was used, but its per-project Mix build path failed to compile a JOSE include. The frozen retry allowance is exhausted, so further browser-runner retries stopped here.

No actual registration test, readiness control, state-collision control, or trace assertion ran. The evidence records these as unrun, retains CIREL-01 as unsatisfied, and leaves the plan halted. Tasks 2 and 3 remain unfinished; no speculative fix or no-flake claim is made.

**Total deviations:** 4 setup/runner corrections attempted; the final runner blocker remains unresolved.
**Impact on plan:** Pinned tool versions and failure leads are recorded, but the planned reproduction, controls, conditional fix, and acceptance evidence are incomplete.

## Verification

- `bash -n scripts/ci/ci-registration-repro.sh scripts/ci/ci-registration-repro.test.sh` — passed.
- `bash scripts/ci/ci-registration-repro.test.sh` — passed.
- `bash scripts/ci/ci-registration-repro.sh --verify-acceptance .../253-REGISTRATION-EVIDENCE.json` — returned `diagnosis_incomplete` and preserved CIREL-01 as unsatisfied.
- Frozen real-app diagnostic command — did not reach a Playwright invocation. The recorded failures are in `253-REGISTRATION-EVIDENCE.json`.
- `--verify-controls` and the retry-wrapper prohibition test were not run because the browser controls were not implemented or exercised.

## Issues Encountered

The temporary checkout could restore the pinned Node and Mix dependencies, but the Phoenix server did not become HTTP-ready under the one allowed infrastructure retry. The retained evidence identifies the setup failures and distinguishes them from the historical registration failure, whose cause is still unknown.

## Next Phase Readiness

This plan is halted and CIREL-01 remains open. The next executor must repair the isolated Mix/app launch, then rerun the already-frozen selection within the original limits or create a new freeze after the limits are explicitly re-established. Tasks 2 and 3 need to be completed before this plan can be summarized as complete. Independent Phase 253 plans may continue where their dependency graph permits.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-13 (halted)*

## Self-Check: PASSED

The four diagnostic artifacts and this summary exist, and task artifact commit `810b6c3be` is an ancestor of HEAD. The plan remains halted because the browser reproduction and two control tasks did not run.
