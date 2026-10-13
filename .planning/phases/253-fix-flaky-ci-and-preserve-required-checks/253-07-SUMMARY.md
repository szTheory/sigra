---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 07
subsystem: ci
tags: [github-actions, playwright, hosted-canary, artifacts, ci-gate]
requires:
  - phase: 253-06
    provides: shared browser execution records and gate validation
provides:
  - scoped dispatch-only canary workflow and bounded runner
  - independent hosted receipt verifier and durable first-run diagnostics
  - fail-closed docs-only classification for unit, install, and HTTP heavy steps
affects: [phase-253, ci-gate, hosted-canary]
actuals:
  tokens: 26126
  tasks: 0
  commits: 6
plan_head_before: 1842dfe16b5bf90f9077ea0d12c118f6bddf0463
plan_head_after: 8459c10df54623d6f69f68076556dd0f144ec58f
tech-stack:
  added: []
  patterns: [synthetic dispatch-only fixture, independent run and archive digest binding]
key-files:
  created:
    - scripts/ci/ci-gate-canary.sh
    - scripts/ci/ci-gate-canary.test.sh
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CANARY-WORKFLOW.yml
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CANARY-EVIDENCE.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CANARY-FAILED-RUN-38347679431.json
  modified:
    - .github/workflows/ci.yml
    - .github/ci-skip-manifest.tsv
    - MAINTAINING.md
    - scripts/ci/honest-skip-verdict.sh
    - scripts/ci/honest-skip-verdict.test.sh
key-decisions:
  - "A docs-only claim is trusted only when the pull-request classifier result is success."
  - "Synthetic canary receipts remain explicitly labeled and do not count as real Playwright coverage."
patterns-established:
  - "A hosted canary receipt is bound to the exact run, attempt, fixture workflow commit/blob, candidate commit, jobs, and digest-checked artifact bytes."
requirements-completed: []
coverage:
  - id: D1
    description: "Scoped hosted canary runner and independent receipt verifier."
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-gate-canary.test.sh; scripts/ci/ci-hosted-gate-verify.test.py"
        status: pass
      - kind: other
        ref: "https://github.com/szTheory/sigra/actions/runs/38347679431"
        status: fail
    human_judgment: false
  - id: D2
    description: "Failed classifier output cannot authorize docs-only omission of unit, install, or HTTP work."
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/honest-skip-verdict.test.sh (21 checks); p10/p21 (16 checks); actionlint"
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-10-13
status: halted
---

# Phase 253 Plan 07 Summary

The bounded canary workflow, shared-helper invocation, verifier, and classifier fail-closed fix are committed; hosted proof halted after the first full-pass scenario failed its source identity check.

## Performance

- **Hosted window:** 4m 28s used of the 60-minute limit when terminal evidence was recorded.
- **Tasks:** 0/2 acceptance tasks completed; the full-pass source was not independently verified and the remaining scenarios were not dispatched.
- **Hosted requests:** 20/120, including the three parent preflight calls, the eight-call watcher reservation, and the two-call failed-log reservation.
- **Hosted job records:** 7/45, counting the skipped verifier job returned by GitHub.
- **Local changes:** 11 source/configuration files plus scoped evidence artifacts.

## Accomplishments

- Added a scoped `workflow_dispatch` fixture named **Phase 253 Gate Canary** at the registered `.github/workflows/ci.yml` path. Its five producer jobs run only tiny synthetic commands. The fixture workflow commit and blob are recorded separately from the candidate helper commit.
- Added a bounded runner and an independent verifier that binds the hosted run, attempt, source commits, job steps, artifact API digest, and exact archived result bytes. Local tests cover malformed identities, event mismatches, and archive/result tampering.
- Closed a classifier gap found during pre-host review: unit, install, and HTTP bodies now run when the changes classifier did not succeed, even if a stale output says `docs_only=true`. The shared verdict helper and three manifest rows apply the same condition.
- Ran local checks successfully: honest-skip verdict 21/21, browser-record integration 26/26, hosted verifier 8/8, p10/p21 16/16, canary contract tests, and actionlint on both workflow files.

## Hosted Result

The scoped fixture ref is `gsd/253-gate-canary-fixture-20261013T044113Z-67104`. Candidate commit `8459c10df54623d6f69f68076556dd0f144ec58f` was checked out separately from fixture workflow commit `19e66df3c7869cc52b4662ae8d0e3b0ee2ec3c6f`, whose `.github/workflows/ci.yml` blob is `077a89e438d5e054ee48799fe741cf1a49d2f85c`.

The only dispatch was [run 38347679431](https://github.com/szTheory/sigra/actions/runs/38347679431). Its five tiny producer commands and uploads succeeded. The shared browser-record validator failed with `record identity mismatch: source_sha`; therefore the source verdict is **unverified**, and this run does not count as a passing full-pass case. The returned jobs response contained seven records: five producers, the browser verdict, and a skipped separate-verifier job. The verifier currently expects only the first six names, so the job-set contract also needs correction. Both issues are deterministic; no retry or additional dispatch was made. Exact run metadata, the one structured jobs response, and failed logs are retained in `253-CANARY-FAILED-RUN-38347679431.json`.

No docs-only, actual-failure, missing-seam, unexpected-skip, cancellation, or separate-verifier run was dispatched. The hosted fixture uses synthetic tiny-command receipts; no real Playwright coverage was produced. `CIREL-02` remains open.

## Task Commits

The following six commits were measured between the plan ledger base and candidate source HEAD:

1. `56170a130` — initial hosted verifier contracts.
2. `5fbf4babb` — classifier failure regression and RED record.
3. `258eb98a1` — verifier contract tests and the then-current event-binding report.
4. `4bc7c4249` — fail-closed classifier wiring and canary implementation.
5. `4cc96210a` — negative-control classification and report correction.
6. `8459c10df` — request-ledger jq fix discovered before the fixture push.

The plan metadata commit is separate.


Canonical task commit rows for scope checking (no acceptance status change):

1. **Task 1: partial canary implementation, hosted acceptance not met** — `56170a130`, `5fbf4babb`, `4bc7c4249`, `8459c10df`.
2. **Task 2: later verifier tests, no accepted RED chronology** — `258eb98a1`, `4cc96210a`.
3. **Task 1: review repairs only, hosted acceptance remains halted** — RED `a7685bcfb`, repairs `b0bed87cf`, `7da6766eb`.

## Files Created/Modified

- `scripts/ci/ci-gate-canary.sh` and its shell test — bounded fixture creation, dispatch, cancellation identity checks, request/job/time accounting, and evidence preservation.
- `scripts/ci/ci-hosted-gate-verify.py` and its tests — independent hosted run and artifact origin verification.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CANARY-WORKFLOW.yml` — dispatch-only synthetic fixture at the registered workflow path on a scoped ref.
- `.github/workflows/ci.yml`, `.github/ci-skip-manifest.tsv`, `MAINTAINING.md`, and the honest-skip helper/tests — require successful classification before trusting a docs-only exemption.
- `253-CANARY-EVIDENCE.json`, `253-CANARY-REQUESTS.json`, frozen preflight responses, and `253-CANARY-FAILED-RUN-38347679431.json` — request ledger, identities, source result, and failure diagnostics.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Require a successful classifier before allowing docs-only heavy-step skips**
- **Found during:** Task 1 pre-host candidate review.
- **Issue:** The unit, install, and HTTP guards trusted `docs_only=true` without checking `needs.changes.result`; the shared verdict helper also lacked the classifier result.
- **Fix:** Pass classifier status to the verdict helper, fail closed on an unverified true claim, and update only the affected 20 CI conditions, three manifest cells, and matching maintenance prose.
- **Verification:** The focused classifier tests, all 21 honest-skip checks, p10/p21, and actionlint passed.
- **Committed in:** `4bc7c4249`.

**2. [Rule 3 - Blocking issue] Correct request-ledger jq expression before any hosted mutation**
- **Found during:** Task 1 setup.
- **Issue:** jq rejected the request-sequence expression before the scoped fixture push.
- **Fix:** Parenthesized the arithmetic expression and committed the runner correction.
- **Verification:** `bash -n`, `bash scripts/ci/ci-gate-canary.test.sh`, and a later authorized fixture push passed this setup step.
- **Committed in:** `8459c10df`.

### TDD and Evidence Sequencing

Task 2's original untracked RED report was overwritten before its exact bytes had a durable preservation ref. Its visible prior content was reconstructed from earlier tool output, but exact original-byte recovery cannot be proven. This loss is disclosed rather than presented as an exact backup. The verifier protections already existed before the new Task 2 tests were added. A later test run deliberately removed and restored those protections; `253-07-TASK2-BROKEN-SOURCE-NEGATIVE-CONTROL.json` labels its two failures as a broken-source negative control, not as TDD RED evidence. No Task 2 RED-before-GREEN chronology is claimed.

## Issues Encountered

- The runner's `watch_run` function restores shell `errexit` before returning `gh run watch --exit-status`'s expected failure. That stopped the executor before it saved the run/job/artifact summary. The subsequent one-time forensic fetch recorded the run and jobs, and the failed logs were retained. This runner exit-status handling remains to be corrected.
- The run's deterministic `source_sha` mismatch and the extra skipped verifier job prevent the full-pass acceptance proof. No source scenario was marked passed, no infrastructure retry was used, and remaining hosted evidence was not attempted.
- The pre-host report also identifies a separate blocker in the halted registration runner. That path remains unaccepted and outside this plan's canary proof.

## Decisions Made

- Preserve the scoped fixture ref and failed run for review; do not delete or reuse it.
- Keep `CIREL-02` open until the full hosted matrix and separate verifier are independently proven.
- Do not update shared state, roadmap, requirements, or handoff files from this scoped executor.

## TDD Gate Compliance

- Classifier guard: the targeted classifier test failed before its implementation commit and passed afterward.
- Hosted verifier: no valid Task 2 RED-before-GREEN sequence is claimed. The separate negative-control artifact records the two failures produced only after existing protections were deliberately removed.

## Self-Check: PASSED

All seven planned source/evidence files exist, and all six listed plan commits are ancestors of the recorded candidate source HEAD.
