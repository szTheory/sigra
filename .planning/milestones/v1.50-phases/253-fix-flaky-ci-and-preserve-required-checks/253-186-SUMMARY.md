---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "186"
subsystem: testing
tags: [github-actions, registration, bounded-rest, main-ci]
requires: []
provides:
  - Frozen, locally verified Plan186 proposal and executable source bindings.
  - Truthful halted result for the approved one-shot attempt; no GitHub request was started.
affects: [CIREL-01, Phase253 verification]
actuals:
  tokens: 47527
  tasks: 2
  commits: 0
  plan_head_before: b11bcca1db7c0186b4610ab4f10aeb7f84567540
  plan_head_after: b11bcca1db7c0186b4610ab4f10aeb7f84567540
tech-stack:
  added: []
  patterns: [one-request curl receipts with retries and redirects disabled]
key-files:
  created:
    - .planning/execution/253/phase253-plan186-auth-20261110/verify.py
    - .planning/execution/253/phase253-plan186-auth-20261110/EXECUTABLE-SOURCE.tar
    - .planning/execution/253/phase253-plan186-auth-20261110/SOURCE-MANIFEST.json
    - .planning/execution/253/phase253-plan186-auth-20261110/AUTHORIZATION-PROPOSAL.json
    - .planning/execution/253/phase253-plan186-auth-20261110/READY.json
    - .planning/execution/253/phase253-plan186-auth-20261110/APPROVAL.json
    - .planning/execution/253/phase253-plan186-auth-20261110/BOUNDS.json
    - .planning/execution/253/phase253-plan186-auth-20261110/RESULT.json
  modified:
    - .planning/HANDOFF.json
    - .planning/STATE.md
    - .planning/state.json
key-decisions:
  - "The one approved execute invocation is terminal: the readiness self-test recursively re-entered transport setup and stopped before writing an invocation marker or starting curl."
  - "No retry, source edit, renewal, or second execution is authorized by this proposal; all requirements remain open."
requirements-completed: []
duration: 7min
completed: 2026-11-10
status: halted
---

# Phase 253 Plan 186: Pinned registration fix main CI proof Summary

**The approved execution stopped in local verification before its first GitHub request. No merge or main CI run was started.**

## Outcome

- Offline preparation completed. The proposal and READY receipt bind the exact plan, twelve charged predecessor HTTP attempts, the bounded request map, source archive, and local verification checks.
- The user approved the exact proposal at 2026-11-10T17:42:05Z. Its fixed one-hour window ended at 18:42:05Z; the approved execution command was invoked once under a hard timeout.
- The invocation created the one-use BOUNDS claim, then failed when `load_bounds` re-ran `verify_ready`, whose self-test called `run_one_request` while execution mode was active. That re-entered `load_bounds` until Python raised `RecursionError`.
- The write-ahead ledger records 0 new attempts, 0 completed, 0 outstanding, and 12 aggregate predecessor attempts. There is no invocation marker, request directory, or raw HTTP response. `network_io_started` is false. Merge attempts and resulting main push runs are both zero.
- The offline `--verify` command is blocked because the fresh PREMERGE proof does not exist. It cannot validate a merge or main CI result.
- Plan186 is halted. CIREL-01 and Phase253 remain open; this partial main-CI slice did not complete the phase or milestone. No retry, rerun, renewal, D-20 invocation, release change, or additional external action was made.

## Evidence

- Machine-readable halted result: [RESULT.json](../../execution/253/phase253-plan186-auth-20261110/RESULT.json)
- One-use spend ledger: [BOUNDS.json](../../execution/253/phase253-plan186-auth-20261110/BOUNDS.json)
- Exact approval: [APPROVAL.json](../../execution/253/phase253-plan186-auth-20261110/APPROVAL.json)
- Frozen source and local readiness: [READY.json](../../execution/253/phase253-plan186-auth-20261110/READY.json), [SOURCE-MANIFEST.json](../../execution/253/phase253-plan186-auth-20261110/SOURCE-MANIFEST.json)
- Route bytes preserved before the halted-route refresh: [PRESERVATION.json](../../recovery/opengsd-health-20261106/phase253-plan186-approval-01/write-ahead/plan186-halted/PRESERVATION.json)

## Next Action

No Plan186 execute or resume command is active. The user is the next actor to decide whether to prepare a distinct recovery scope for the local recursion defect. Phase253 and CIREL-01 remain incomplete.

## Self-Check

The BOUNDS, APPROVAL and RESULT receipts parse and their recorded hashes match current bytes. BOUNDS contains zero new attempts and no request intents; no invocation marker, PREMERGE, MERGE or MAIN-CI receipt exists. The RESULT is `halted` and lists no completed requirements.
