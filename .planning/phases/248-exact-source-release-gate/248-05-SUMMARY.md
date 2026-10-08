---
phase: 248-exact-source-release-gate
plan: 05
subsystem: release-automation
tags: [github-actions, workflow-run, receipts, bash, exunit, actionlint]
requires:
  - phase: 248-04
    provides: shared terminal release receipt schema and writer
provides:
  - Trusted read-only observer for cancelled Release Please runs
  - Hermetic source-run correlation and cross-workflow contracts
affects: [phase-249-publish-and-prove-sigra-1-6-0, release-automation]
actuals:
  tokens: 6801
  tasks: 2
  commits: 5
  plan_head_before: 43f7842b6e9f4b316a512a172fa09d330cb6e96d
  plan_head_after: 823af8e4d3c25e674040b3d75f16091374a200d5
tech-stack:
  added: []
  patterns: ["workflow_run payload identifies a source run; authoritative API data gates receipt creation"]
key-files:
  created:
    - .github/workflows/release-run-observer.yml
    - scripts/ci/release-observer.sh
    - scripts/ci/release-observer.test.sh
    - test/sigra/planning/phase_248_release_observer_contract_test.exs
  modified: []
key-decisions:
  - "Use only the workflow_run payload to identify the source run, then validate its identity and cancellation against the Actions API before recording evidence."
  - "Record missing or mismatched release tags as cancellation diagnostics; cancellation evidence never represents publication success."
patterns-established:
  - "Trusted cancellation observer: default-branch code, read-only permissions, no source checkout or artifact download."
requirements-completed: [AUTO-01, AUTO-02]
coverage:
  - id: D1
    description: Correlate cancelled Release Please runs on main and retain source-linked cancellation receipts.
    requirement: AUTO-02
    verification:
      - kind: unit
        ref: scripts/ci/release-observer.test.sh
        status: pass
      - kind: unit
        ref: scripts/ci/release-receipt.test.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Preserve source, merge, permissions, credentials, timeout, and receipt contracts across the release lane.
    requirement: AUTO-01
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_248_release_gate_contract_test.exs
        status: pass
      - kind: unit
        ref: test/sigra/planning/phase_248_release_observer_contract_test.exs
        status: pass
      - kind: other
        ref: six Phase 248 hermetic shell fixture suites
        status: pass
    human_judgment: false
duration: 32min
completed: 2026-10-08
status: complete
plan_head_before: 43f7842b6e9f4b316a512a172fa09d330cb6e96d
plan_head_after: 823af8e4d3c25e674040b3d75f16091374a200d5
commits: 5
---

# Phase 248 Plan 05: Trusted cancellation observer Summary

**A trusted default-branch observer records source-linked cancellation receipts and adds deterministic contracts for the complete release lane.**

## Performance

- **Duration:** 32 min
- **Started:** 2026-10-08
- **Completed:** 2026-10-08
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a `workflow_run` observer with read-only permissions, a unique non-cancelling run group, default-branch helper checkout, and 90-day receipt artifact retention.
- Added authoritative correlation for repository, workflow, run ID, supported event, main branch, cancellation conclusion, and source SHA before a receipt can be written.
- Added hermetic cancellation fixtures and cross-workflow ExUnit contracts covering release-source identity, security boundaries, and receipt wiring.

## Task Commits

1. **Task 1: Correlate cancelled source runs and create cancellation receipts** - `46885298c` (`feat(248-05): correlate cancelled release runs`)
2. **Task 2: Install the trusted completion workflow and cross-workflow security contracts** - `925466011` (`feat(248-05): add trusted cancellation observer`)
3. **Task 2 follow-up: Require workflow identity in the source event** - `823af8e4d` (`fix(248-05): require source workflow id in event`)

The measured plan range also includes two earlier metadata-only closeout commits: `74679b468` (initial summary/roadmap update) and `8a0ae42de` (state status correction). The final metadata commit below is outside `plan_head_after`.

## Files Created/Modified

- `.github/workflows/release-run-observer.yml` - Trusted completion observer and retained cancellation artifact.
- `scripts/ci/release-observer.sh` - Fail-closed source-run correlation and cancellation receipt generation.
- `scripts/ci/release-observer.test.sh` - Hermetic API/event fixtures for supported, malformed, unrelated, tag, and duplicate cases.
- `test/sigra/planning/phase_248_release_observer_contract_test.exs` - Observer trust-boundary and cross-workflow contracts.

## Decisions Made

- The webhook payload is used only to locate the source run; the helper re-queries GitHub and validates authoritative source identity before recording evidence.
- Missing or mismatched tag resolution remains diagnostic cancellation evidence and cannot be represented as release success.

## Deviations from Plan

None - the implementation stayed within the plan's four files. The required default `actionlint` command reports six pre-existing embedded ShellCheck warnings in inherited `.github/workflows/ci.yml` (SC2209, SC2010, SC2034); the same findings were reproduced against the committed baseline. Actionlint passed for all five workflows with embedded ShellCheck disabled, and passed normally for the other four workflows. The inherited workflow was left untouched.

## Verification

- `bash scripts/ci/release-observer.test.sh` - 22 passed, 0 failed.
- `bash scripts/ci/release-receipt.test.sh` - 13 passed, 0 failed.
- `bash scripts/ci/release-candidate-preflight.test.sh` - 26 passed, 0 failed.
- `bash scripts/ci/release-environment-preflight.test.sh` - 9 passed, 0 failed.
- `bash scripts/ci/release-exact-source.test.sh` - passed.
- `bash scripts/ci/wait-for-ci-gate.test.sh` - 13 passed, 0 failed.
- `mix test test/sigra/planning/phase_248_release_gate_contract_test.exs test/sigra/planning/phase_248_release_observer_contract_test.exs` - 11 tests, 0 failures.
- `shellcheck scripts/ci/release-observer.sh scripts/ci/release-observer.test.sh` - passed.
- Actionlint passed on all five required workflows with embedded ShellCheck disabled; the other four workflows passed with default ShellCheck enabled. The default five-workflow command remains red only on the inherited baseline warnings listed above.
- Scoped `git diff --check` for Plan05 Task 2 files - passed.

## Issues Encountered

The default actionlint invocation includes embedded ShellCheck and therefore surfaces existing CI workflow warnings outside this plan's scope. Baseline comparison confirmed the warnings predate Plan05; no inherited file was changed.

## Next Phase Readiness

Phase 249, “Publish and Prove Sigra 1.6.0,” is pending with no plans, context, or research yet. `init.plan-phase 249` reports no prerequisite blocker and no existing context; the forward route is `$gsd-discuss-phase 249`, followed by planning. Plan 248's edge-probe assumptions AUTO-01 and AUTO-02 remain unresolved until actual GitHub workflow runs and retained success, failure, and cancellation artifacts are verified. This plan provides deterministic offline contracts only; no remote workflow was dispatched and no release was merged, tagged, or published.

## Self-Check: PASSED

- Task commits `46885298c` and `925466011` exist and are ancestors of `plan_head_after`.
- All four planned artifacts exist; task 2's commit contains only the observer workflow and its contract test.
- Measured plan commit count is 5 from `plan_head_before` through `plan_head_after`, including the three implementation commits and two earlier metadata-only closeout updates.

---
*Phase: 248-exact-source-release-gate*
*Completed: 2026-10-08*
