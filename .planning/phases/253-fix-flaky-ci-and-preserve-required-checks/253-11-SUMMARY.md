---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 11
subsystem: ci
tags: [bash, github-actions, python, hosted-canary, request-accounting]

requires:
  - phase: 253-07
    provides: Repaired hosted gate candidate checks retained by this recovery plan
provides:
  - Explicit charged 60-second hosted-run polling with bounded redirect handling and independent request reconciliation
  - Locally checked, distinct unpushed canary workflow and finite six-scenario freeze
affects: [253-12, 253-13, CIREL-02]

actuals:
  tokens: 17004
  tasks: 2
  commits: 6
  plan_head_before: f7dca19fec120f5fbb01eb30d256d18f88e2005e
  plan_head_after: b7b7020f95d79e9b2b04ffad22d447ca667aa29a

tech-stack:
  added: []
  patterns:
    - One charged API request per poll, with one poller per run and terminal run payload reused as the structured summary
    - No-follow artifact/log downloads with every redirect recorded as a separate transaction
    - Independent verifier compares actual transport entries, dispatch sizes, job receipts, and artifact limits
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-WORKFLOW.yml
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-11-TASK1-RED.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-11-TASK1-GREEN.json
  modified:
    - scripts/ci/ci-gate-canary.sh
    - scripts/ci/ci-gate-canary.test.sh
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py

key-decisions:
  - "Count every GitHub API call and every explicit download redirect from the transport ledger; remove reserved watcher calls."
  - "Keep the original failed run 38347679431 and its ref/blob historical; use a distinct local unpushed fixture identity."
  - "Leave CIREL-02 open until Plan 12 supplies hosted evidence."

patterns-established:
  - "A poller checks REST core remaining before watching, sleeps 60 seconds between polls, and stops on 403/429."
  - "The independent verifier requires exact transport totals, bounded inputs/artifacts, and terminal source receipts."

requirements-completed: []

coverage:
  - id: D1
    description: "Canary transport, dispatch inputs, artifacts, and freeze limits have deterministic local checks."
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "python3 scripts/ci/ci-hosted-gate-verify.test.py"
        status: pass
      - kind: integration
        ref: "bash scripts/ci/ci-gate-canary.test.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "A new six-scenario fixture identity is sealed locally before any dispatch."
    requirement: CIREL-02
    verification:
      - kind: other
        ref: "bash scripts/ci/ci-gate-canary.sh --check-only --recovery-freeze .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-10-13
status: complete
---

# Phase 253 Plan 11: Bounded Hosted Gate Canary Summary

**The canary runner now charges each poll and redirect, independently reconciles request totals, and freezes a distinct local fixture with six expected outcomes and hard input, artifact, job, and time limits.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-10-13T15:51:34Z
- **Completed:** 2026-10-13T16:09:13Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Replaced the unproved eight-call watcher reservation with one explicit gh api run poller per workflow run, polling every 60 seconds and using its terminal response as the structured run summary.
- Charged each API transaction and no-follow download redirect; the independent verifier computes totals from the ledger and rejects over-limit inputs, artifacts, hidden mock requests, rate limits, and incomplete receipts.
- Created a dispatch-only, read-only fixture with five tiny producers, a verdict, and an independent verifier. The freeze records six exact outcomes, the five existing required names, the actual candidate and fixture identities, and bounds of 120 requests, 45 executed jobs, 60 minutes, and one diagnosed infrastructure-only retry.
- Kept the old failed run and its 20 accounted/reserved requests historical; the exact old HTTP count remains unproved. No hosted request or dispatch occurred.

## Task Commits

1. **Task 1 RED tests** — 731ed5bfb (test)
2. **Task 1 transport and verifier** — 764d5a4d9 (fix)
3. **Task 1 RED evidence record** — e6b1ee6e6 (docs)
4. **Task 2 freeze validation candidate** — 307dd9591 (fix)
5. **Task 2 durable halt diagnostics** — b8a3b128d (fix)
6. **Task 2 workflow and freeze** — b7b7020f9 (docs)

## TDD Gate Compliance

- The RED test commit preceded the implementation commit. The captured RED run failed the intended verifier assertions: the runner-supplied request count was trusted and an oversized artifact was accepted. The record passed check tdd-red-evidence as RED_EVIDENCE_OK.
- The verifier suite passed after implementation: 16 tests, 0 failures. The complete mocked receipt path covers dispatch, run discovery/poll, jobs and artifact metadata, an explicit redirect, and independent verification; no network request runs in the test.
- The RED JSON report was committed after the GREEN implementation commit, although the failing test itself and actual RED command ran before GREEN. This timing is disclosed rather than represented as a pre-GREEN report commit.

## Files Created/Modified

- scripts/ci/ci-gate-canary.sh — charged transport, explicit polling, no-follow downloads, bounded inputs, and durable halt diagnostics.
- scripts/ci/ci-gate-canary.test.sh — freeze identity, trigger, budget, and fail-closed checks.
- scripts/ci/ci-hosted-gate-verify.py — independent ledger, input, job, and artifact validation.
- scripts/ci/ci-hosted-gate-verify.test.py — mocked transport and adversarial verifier cases.
- 253-RECOVERY-CANARY-WORKFLOW.yml and 253-RECOVERY-CANARY-FREEZE.json — distinct local fixture proposal and exact frozen identities.
- 253-11-TASK1-RED.json and 253-11-TASK1-GREEN.json — task evidence records.

## Decisions Made

- Each poll and redirect is a separate charged transaction. No watcher request is hidden inside a reserve.
- The fixture ref is create-only and unpushed. It differs from the old failed ref, commit, and blob.
- The 20 requests/reservations from the earlier failed attempt do not count as an exact HTTP total.
- CIREL-02 stays open pending Plan 12's hosted run and receipt.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical diagnostics] Persisted a terminal halt when a canary check fails**
- **Found during:** Task 2 (freeze validation)
- **Issue:** A deterministic failure could exit without marking execution evidence halted, allowing a later invocation to look like an unused scenario slot.
- **Fix:** The runner now writes a durable status: halted and diagnostic before exiting.
- **Files modified:** scripts/ci/ci-gate-canary.sh, scripts/ci/ci-gate-canary.test.sh
- **Verification:** The shell test forces an invalid scenario and checks the retained halted diagnostic; the full local suite passed.
- **Committed in:** b8a3b128d

The first local fixture candidate/ref was superseded by the durable-diagnostics repair before any dispatch. Both local identities are retained in the freeze; the active candidate is the later one. No hosted or remote call was made.

**Total deviations:** 1 auto-fixed (Rule 2 - missing critical diagnostics)  
**Impact on plan:** This makes failed or incomplete canary runs stop future scenarios with a durable reason. Scope remains within the plan.

## Issues Encountered

The TDD RED report was persisted after the GREEN code commit. The test and actual failing command were committed/run before implementation, and the unchanged report was later validated by the GSD RED evidence checker. The earlier Plan 07 missing RED chronology remains disclosed and is not repaired by this new test.

## User Setup Required

None for this local preparation. Plan 12 still needs its own pre-dispatch checks before making hosted requests.

## Next Phase Readiness

Plan 12 is the next dependency after this local freeze. This plan did not dispatch the fixture, prove hosted required checks, complete CIREL-02, or finish Phase 253. The original failed canary and registration attempt remain unchanged.

## Self-Check: PASSED

- Summary, workflow, freeze, RED report, and GREEN report exist.
- All six measured plan commits are ancestors of plan_head_after.
- Commit count from plan_head_before to plan_head_after is 6.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-13*

