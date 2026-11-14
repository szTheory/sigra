---
phase: 254-speed-up-the-measured-slow-jobs
plan: "08"
subsystem: infra/testing
tags: [ci, performance, github-actions, comparison]
requires:
  - phase: 254-07
    provides: Reviewed candidate workload map and passing native parity receipt
provides:
  - Authenticated read-only proof that the current required pull_request path cannot execute the exact frozen baseline tree
  - Durable blocked readiness records with preparation and comparison explicitly unstarted
affects: [254-hosted-comparison, CISPEED-01, CISPEED-02]
tech-stack:
  added: []
  patterns: [read-only GitHub ruleset and merge-tree feasibility proof]
key-files:
  created:
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-HOSTED-PR-PATH-PROOF.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-RUN-CONTRACT.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-HOSTED-READINESS.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-CACHE-PREPARATION.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-REGISTRATIONS.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-RESULT.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-COMPARISON-EVIDENCE.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-08-SUMMARY.md
  modified: []
key-decisions:
  - "Stop before cache preparation and comparison collection because current-main PR merge trees cannot reproduce the exact frozen baseline tree and workflow."
  - "Keep both CISPEED requirements open; zero comparison families were started."
patterns-established:
  - "Treat current PR merge/source/workflow tree identities as the baseline feasibility proof; an old PR head SHA or dispatch is insufficient."
requirements-completed: []
actuals:
  tokens: 5864
  tasks: 1
  commits: 1
  plan_head_before: 0daf97f53067a046b0945e56565cd632c9f3d2ef
  plan_head_after: 7bfee2017fc68ccc54d5745018c6c7b8760d9ece
  halted: true
  phase_verification_status: pending
duration: "~15min"
completed: 2026-10-23
status: halted
---

# Phase 254 Plan 08: Hosted Comparison Readiness Summary

**The exact frozen baseline cannot currently run through the required real pull request path, so hosted preparation and measurement remain unstarted.**

## Progress

- **Tasks:** Task 1 produced its designed blocked outcome; Tasks 2 and 3 were not run.
- **Started:** Exact start time was not captured.
- **Completed:** 2026-10-23 (UTC)
- **Commits counted at summary write:** 1 task commit.
- **Files created:** 8, including this summary.

## Findings

- The active default-branch ruleset is #14941512 and requires five contexts: Library tests, Example unit smoke, Install smoke, Example HTTP smoke, and Example Playwright smoke.
- Current `main` is `09df342a82e03c3d5d40173c912b70e827f7eadc`. The open frozen-baseline PR #331 has head `d4dcc1939bd1f1590f6ca01d55b861e31acc745f`, but GitHub's current PR merge preview has tree `cc2038166f1847e2e2f5ce2428d9a53ba0ae8cae`, not the frozen baseline tree `bcda2b1eb386bdbaaf1bde2b6f034e0c7ee74452`. Its CI workflow blob also differs from the frozen baseline workflow.
- Current `main` CI accepts pull requests targeting `main`; therefore the historical head SHA and its earlier passing run do not establish that today's required PR run executes the frozen baseline sources.
- The reviewed candidate SHA `da6401170e4295cba8099fd6f3ec348c6867de47` is currently unavailable through GitHub's commit API and has no current open PR head match. This is recorded as a separate availability fact, not the primary baseline blocker.
- Frozen-source preflight passed in check-only mode. No main/protection/workflow edits, dispatch substitutions, cache/image preparations, comparison families, requests for additional warm-up budget, or acceptance runs were made.
- The blocked contract retains the exact method, thresholds, and reviewed native-map/receipt digests, but has no reservations or future window. Its exact SHA-256 is `77d89fbaebe9478a62659a2eea1fbacffec0579c7139c5f461bcb2d95b259ea4`.
- The existing plan validator was invoked on that blocked contract and raised `AttributeError: 'NoneType' object has no attribute 'replace'` while reading the intentionally unset window. The complete command, traceback, and contract hash are retained in `254-HOSTED-PR-PATH-PROOF.json`; no validator or source repair was made.

## Durable Evidence

- [254-HOSTED-PR-PATH-PROOF.json](./254-HOSTED-PR-PATH-PROOF.json) records the effective ruleset, current baseline PR merge SHA/tree, file-level tree evidence, candidate availability, and exact validator traceback.
- [254-HOSTED-READINESS.json](./254-HOSTED-READINESS.json) records implementation complete, hosted comparison blocked, whole-phase verification pending, and both requirements open.
- [254-CACHE-PREPARATION.json](./254-CACHE-PREPARATION.json) records that cache/image feasibility was not evaluated because baseline feasibility failed first; no warm-up recipe or budget request was started.
- [254-COMPARISON-RUN-CONTRACT.json](./254-COMPARISON-RUN-CONTRACT.json) is blocked, has no reservation schedule or window, and preserves the source and native parity identities.
- [254-COMPARISON-REGISTRATIONS.json](./254-COMPARISON-REGISTRATIONS.json), [254-COMPARISON-RESULT.json](./254-COMPARISON-RESULT.json), and [254-COMPARISON-EVIDENCE.json](./254-COMPARISON-EVIDENCE.json) record not started, zero families, and no raw comparison data. This is not a sample-based pass, miss, or insufficient-data result.

## Requirements and Verification Status

- **CISPEED-01:** open. No hosted median was measured.
- **CISPEED-02:** open. No hosted p95 or all-attempt runner cost was measured.
- **Implementation:** complete through the locally reviewed Plan 07 candidate.
- **Hosted comparison:** blocked before preparation and collection.
- **Whole-phase verification:** pending and not run.
- The two unresolved assumptions and the two flagged reporting prohibitions from the plan remain unresolved; none was cleared by this blocker proof.

## Next Step

Establish a lawful current `pull_request` path whose actual merge/source/workflow trees prove the exact frozen baseline application, producer, and workflow. Then resume `$gsd-execute-phase 254`. Task 2 is only relevant if that proof passes and genuinely new warm-up executions need their own explicit budget. Phase verification remains pending.

## Task Commit

- Task 1 blocked-readiness evidence: `7bfee2017` (`docs(254-08): record blocked real-PR baseline feasibility`).

## Deviations from Plan

None. The plan's explicit stop condition was met; cache/image preparation and all forty comparison families were not attempted.

## Self-Check: PASSED

- All seven execution/proof JSON files and this summary exist and parse as valid JSON where applicable.
- Task commit `7bfee2017fc68ccc54d5745018c6c7b8760d9ece` is an ancestor of the current `HEAD`.
- The exact blocked contract bytes match SHA-256 `77d89fbaebe9478a62659a2eea1fbacffec0579c7139c5f461bcb2d95b259ea4`.
- The hosted comparison remains blocked, no families or prep runs were started, both requirements remain open, and whole-phase verification remains pending.
