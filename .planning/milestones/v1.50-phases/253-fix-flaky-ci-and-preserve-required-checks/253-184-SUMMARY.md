---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "184"
subsystem: testing
tags: [github-actions, registration, bounded-rest, main-ci]
requires: []
provides:
  - Exact-source PR372 preflight evidence; merge and main CI were not attempted.
affects: [CIREL-01, Phase253 verification]
actuals:
  tokens: 166784 # chars/4 over retained text artifacts
  tasks: 0
  commits: 0
  plan_head_before: b11bcca1db7c0186b4610ab4f10aeb7f84567540
  plan_head_after: b11bcca1db7c0186b4610ab4f10aeb7f84567540
tech-stack:
  added: []
  patterns: [one-request curl receipts with retries and redirects disabled]
key-files:
  created:
    - .planning/diagnostics/phase253-pr372-main-proof/PREMERGE.json
    - .planning/diagnostics/phase253-pr372-main-proof/RESULT.json
  modified:
    - .planning/diagnostics/phase253-pr372-main-proof/BOUNDS.json
key-decisions:
  - "Stopped before the one-way merge because the remaining fixed window was shorter than the comparable CI run duration."
  - "Kept CIREL-01 open; preflight evidence does not prove the main render or missing behavior repeats."
requirements-completed: []
duration: 56min
completed: 2026-11-10
status: halted
---

# Phase 253 Plan 184: Pinned registration fix main CI proof Summary

**The exact PR372 source and required checks passed preflight, but the merge and main workflow were not attempted because too little of the fixed window remained to prove the resulting run.**

## Performance

- **Duration:** 56 minutes from the fixed BOUNDS start
- **Started:** 2026-11-10T02:14:34Z
- **Stopped:** 2026-11-10T03:10:36Z
- **Tasks completed:** 0/2; Task 1 preflight passed, but its merge/run work did not start; Task 2 was not started
- **GitHub API attempts:** 9; one auxiliary source fetch was also charged
- **Merge attempts / main runs:** 0 / 0

## Outcome

- The read-only preflight confirmed PR372 is open, clean and mergeable at the pinned base/head, with exactly the two approved file blobs.
- The repository ruleset contains the five required contexts, and their current Check Runs are successful. The classic branch-protection endpoint returned `404 Branch not protected`; the separate ruleset response supplies the effective checks.
- Prior PR run 42731566718 succeeded, including `ci-gate`; its Admin eval render job was skipped, as expected for a pull request event.
- Only 3m58s remained before the fixed 03:14:34Z deadline. The comparable PR workflow took 6m47s end-to-end, and the required main push run also needs to execute the skipped render. The merge was therefore not attempted.

## Evidence

- Raw preflight response objects, headers, request IDs and hashes: [PREMERGE.json](../../diagnostics/phase253-pr372-main-proof/PREMERGE.json)
- Request, deadline and spend ledger: [BOUNDS.json](../../diagnostics/phase253-pr372-main-proof/BOUNDS.json)
- Machine-readable blocked outcome: [RESULT.json](../../diagnostics/phase253-pr372-main-proof/RESULT.json)
- Exact GitHub CLI source used to identify and replace unbounded watcher/check pagination: [v2.101.0 source archive](../../diagnostics/phase253-pr372-main-proof/gh-v2.101.0-source.tar.gz)

## Deviations from Plan

The plan halted before mutation because the remaining fixed deadline could not contain the required main workflow observation and independent receipt validation. No merge intent was written, no source or workflow files were changed, and no retry, rerun, D-20 invocation or second attempt was made. The unused 60 API reservations were released; 9 API attempts and the one auxiliary source request remain charged.

## Requirements and Phase Status

- **CIREL-01:** Open. The merge commit’s main render, current-source behavior regression and fresh D-20 repeats remain unproved; no D-20 authority remains.
- **CIREL-02:** Prior independent evidence is preserved and was not rerun.
- **Phase verification:** Pending. Preflight did not complete the feature or phase verification.

## Next Action

The phase owner must reconcile active route copies with live Phase253 readiness before advertising a next command. Any new merge/run window requires new, explicit authorization; the expired deadline and unused merge slot are not renewed by this halted attempt.

## Self-Check: PASSED

The preflight, bounds, blocked result and summary files exist and parse. BOUNDS records nine API attempts, one auxiliary request, zero merge intent, and zero outstanding reservations. PREMERGE records the pinned-source and check results. No task commit exists because execution halted before task completion; HEAD remains `b11bcca1db7c0186b4610ab4f10aeb7f84567540`.

