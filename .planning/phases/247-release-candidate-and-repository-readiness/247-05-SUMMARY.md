---
phase: 247-release-candidate-and-repository-readiness
plan: 05
subsystem: release-readiness
tags: [github-actions, hex, provenance, release-readiness]
requires:
  - phase: 247-04
    provides: Initial candidate ledger and blocked local dry-run evidence.
provides:
  - Operational completion of Plan 05's fixed-source evidence workflow, baseline, authenticated dry run, and final ledger through the current-source successors in Plans 06–08.
  - Historical Plan 05 checkpoint preserved without reusing its superseded source pins.
affects: [247-04, 247-06, 247-07, 247-08, release-readiness]
actuals:
  tokens: 1542
  tasks: 4
  commits: 0
tech-stack:
  added: []
  patterns: [exact-SHA release evidence, protected evidence-only merge, boolean-only secret receipt, independent final readiness validation]
key-files:
  created:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-05-SUMMARY.md
  referenced:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-05-CHECKPOINT.md
    - .planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-HEX-DRY-RUN-RECEIPT.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-08-DRY-RUN-RECOVERY.md
decisions:
  - "Treat the 563f411/e3883b historical workflow and baseline as superseded; use only the final reviewed source and its re-bound evidence."
  - "Close Plan 05 operationally through Plans 06–08, while retaining independent Phase 247 verification as the next gate."
requirements-completed: [READY-01]
duration: 10min
completed: 2026-10-08
status: complete
plan_head_before: 21c6e070ad6badedf8bf415b026596a4bbec2fa3
plan_head_after: 21c6e070ad6badedf8bf415b026596a4bbec2fa3
commits: 0
---

# Phase 247 Plan 05: Current-source evidence completion

**Plan 05's release-evidence objective is operationally complete through Plans 06–08, which rebound the workflow to the final reviewed candidate, passed an authenticated non-publishing dry run, and produced a ready final ledger. Independent Phase 247 verification remains pending.**

## Disposition

Plan 05's original pinned candidate (`563f411bc2659bb9ac1652d552ce58ffb0c876b1`, reviewed base `590eb4ed3323db11dd74326cbee00c9c7973e529`) was superseded after Release Please advanced PR #224 and source review found raw internal changelog history and a missing adopter-guide path. Its earlier workflow and baseline results are historical. Plans 06–08 repaired and re-reviewed the candidate, rebound the evidence workflow and baseline, completed the protected authenticated dry run, and refreshed the final readiness validator. This summary reconciles Plan 05's unfinished tasks to those current-source results; it does not assert that the independent phase verifier passed.

The original checkpoint remains unchanged at [247-05-CHECKPOINT.md](./247-05-CHECKPOINT.md). Its old candidate pins, blocked run notes, and resume route describe the state at that checkpoint only. Do not resume its credential step or reuse its old baseline.

## Current-source evidence

| Plan 05 objective | Current evidence | Result |
|---|---|---|
| Trusted exact-source workflow, helper, and deterministic fixtures | Key-presence workflow merge `cd978dad3504bf4ff775ea89e98d063d2a189d56`; path-only diagnostics merge `7b907abcf15785b7396da5d1fe5f5115ccd9af64`; final evidence PR #296 contains the four approved evidence paths. | Complete on protected main |
| Frozen candidate diff and main-only evidence route | PR #296 pre-merge head `76f6c6aced57a71020573bbd477d3624fd2c2f73`; main merge `a494f3ee3878da93aab4f70712ffddeefd77a802`; manifest blob `c87eeb19e79b4e19d34ff522c487894c8cb3c558`; reviewed base `d135cbce343947499a0810736c500ef5f1cb5c32`; candidate `d76d7f2306f6099063a80a420d2d8a4e04c7785f`; raw diff SHA-256 `d7cbfeddd55bc0528738f89b82377379e55a73464f2c174217af31410625ac5e`, 8,372 bytes. | Independently reverified after merge |
| Exact-head candidate CI and adopter source | PR #224 remains open at `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, based on `d135cbce343947499a0810736c500ef5f1cb5c32`; required CI run `37800067568` passed. | Current source reviewed and green |
| Authenticated, non-publishing Hex dry run | Initial pre-auth run `37803560621` stopped because the merged evidence PR's pre-merge tree was unreachable after branch deletion. Recovery restored only the verified ref; retry `37803817504` passed on trusted main and produced the safe receipt. | Complete; both runs are documented in [247-08-DRY-RUN-RECOVERY.md](./247-08-DRY-RUN-RECOVERY.md) |
| Final ledger and inherited inventory | Validator run at `2026-10-08T16:05:38.855Z` returned `valid: true`, `status: ready`, zero diagnostics; it verified 400 inherited commits, 1,301 paths, and 14 open PRs. Focused validator tests passed 25/25. | Complete as readiness evidence |

Plan 08 implementation commits include `897db1e9b` (receipt/baseline/recovery), `fe40065a4` (validator and ledger), and `7cacda13e` (require the clean trusted checkout to match observed live main). The safe receipt records `mix hex.publish --dry-run --yes`, boolean-only credential presence, and HTTP 404 before and after for Hex 1.6.0. No key value or environment secret metadata was inspected.

## Remaining GSD gate

The independent Phase 247 verification has **not** passed and `247-VERIFICATION.md` was not changed. The immediate next command is `$gsd-execute-phase 247`; with all plan summaries now present, its `verify_phase_goal` step must dispatch the independent `gsd-verifier` to assess READY-01 and READY-02. PR #224 remains open; no tag or Hex publication was created.

## Self-Check: PASSED

- This summary and the original historical checkpoint both exist.
- The cited final candidate, evidence merge, CI run, dry-run run, and validator evidence are recorded in the current Plan 06–08 artifacts.
- The summary makes no claim that independent Phase 247 verification has passed.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Plan: 05*
*Completed: 2026-10-08 (operationally superseded by Plans 06–08)*
