---
phase: 256-repair-ci-diagnostics-and-complete-bounded-speed-comparison
plan: "03"
subsystem: ci
tags: [ci, source-readiness, bounded-comparison]
requires:
  - phase: 256 Plan06
    provides: contract-bound candidate/control source and preparation proposal
provides:
  - Terminal record for the single Phase256 candidate-preparation attempt
  - Corrected local pre-update readiness checks and focused regressions
  - Exact blocker and next-scope transport diagnosis
affects: [Phase256, CISPEED-01, CISPEED-02]
actuals:
  tokens: null
  tasks: 1
  commits: 0
tech-stack:
  added: []
  patterns:
    - Validate the existing PR's exact pre-update identity before a single branch update
key-files:
  created:
    - .planning/execution/256/CANDIDATE-DIAGNOSTIC.json
    - .planning/debug/phase256-prep-readiness-local-20261105/LOCAL-RESULT.json
  modified:
    - scripts/ci/ci-repaired-comparison.py
    - scripts/ci/ci-repaired-comparison.test.py
key-decisions:
  - "A terminal one-shot claim stays consumed when readiness fails; no preparation replay is allowed."
  - "The current ref-only PATCH route cannot publish objects that the remote commit lookup cannot retrieve; remote availability is unproven because the exact HTTP cause was not retained."
  - "The next attempt requires a distinct source-bound scope using one exact leased Git push, with no retry or force fallback."
requirements-completed: []
duration: "not recorded"
completed: 2026-11-05
status: halted
---

# Phase 256 Plan 03: Candidate preparation halted

**The only candidate-preparation invocation stopped at readiness before the PR branch update or CI workload. The speed comparison has zero samples.**

## Outcome

The invocation consumed its one-use claim and returned exit code 2 after about 26 seconds; it did not time out. Its ledger contains 11 GET requests, including the rate-limit check, and zero mutations, workloads, runner minutes, retries, reruns, renewals, or acceptance samples. `preparation/EXECUTION.json` was not produced. The independent verifier recorded a blocked result. Evidence and exact hashes are in [`CANDIDATE-DIAGNOSTIC.json`](../../execution/256/CANDIDATE-DIAGNOSTIC.json).

The saved readiness receipt exposed two local logic errors. It compared the revalidated `main` SHA to an absent source-identity field instead of the contract's base SHA, although the first and last `main` reads were identical. It also applied a new-PR/post-update readiness rule before this plan's update of existing PR368, incorrectly rejecting the expected open PR and old branch head. These defects are fixed locally. Six focused production-path regressions pass, including changed-identity and unavailable-source no-mutation cases; an independent review found no issues. The pre-fix code reproduces the blockers.

A separate readiness check for target commit `5effabe...` failed. The commit is present in the bound local bare object store and is a direct child of PR368's recorded old head. The saved remote request has return code 1 but no retained HTTP cause, so whether the commit is absent remotely is unproved. The current SHA-only ref update does not upload Git object contents; that is an inference from GitHub's separate reference-update and commit-object endpoints ([references](https://docs.github.com/en/rest/git/refs), [commits](https://docs.github.com/en/rest/git/commits)).

## Task status

| Task | Result |
| --- | --- |
| Bind the frozen proposal to the existing Phase256 authorization | Completed; the source-bound one-use claim was created and consumed by the only invocation. |
| Run one candidate preparation and retain its independent result | Halted before branch update; exact spend and blockers are preserved. |

Local diagnosis corrected the readiness defects without altering the consumed claim, proposal, contract, ledger, or verification record. No hosted action was repeated.

## Next phase readiness

Plans 04 and 05 remain blocked; CISPEED-01 and CISPEED-02 remain open. Do not rerun Phase256 Plan03 or route back to Phase255.1. A new, separately source-bound scope will use one expected-old-SHA leased Git push from the verified object store to the exact existing PR368 branch, then verify the remote commit/tree/ref/PR before allowing the bounded comparison. It permits no retry, force fallback, merge, or release. The project handoff records the new route.

---
*Phase: 256*
*Completed: 2026-11-05*
