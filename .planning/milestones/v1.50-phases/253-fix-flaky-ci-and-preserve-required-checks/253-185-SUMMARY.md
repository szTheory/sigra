---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "185"
subsystem: testing
tags: [github-actions, registration, bounded-rest, main-ci]
requires: []
provides:
  - Truthful halted outcome for the approved PR372 preflight attempt; no merge was attempted.
affects: [CIREL-01, Phase253 verification]
actuals:
  tokens: 0
  tasks: 0
  commits: 0
  plan_head_before: b11bcca1db7c0186b4610ab4f10aeb7f84567540
  plan_head_after: b11bcca1db7c0186b4610ab4f10aeb7f84567540
tech-stack:
  added: []
  patterns: [one-request curl receipts with retries and redirects disabled]
key-files:
  created:
    - .planning/execution/253/phase253-plan185-auth-20261110/RESULT.json
    - .planning/execution/253/phase253-plan185-auth-20261110/diagnostics/PREFLIGHT-01-LOCAL-ABORT.json
  modified:
    - .planning/execution/253/phase253-plan185-auth-20261110/BOUNDS.json
key-decisions:
  - "Stopped before mutation after the fresh PR-files endpoint returned HTTP 500; the approved scope permits no retry."
  - "Kept CIREL-01 open because preflight, merge and main CI did not complete."
requirements-completed: []
duration: 55min
completed: 2026-11-10
status: halted
---

# Phase 253 Plan 185: Pinned registration fix main CI proof Summary

**The approved attempt stopped during fresh preflight after GitHub returned HTTP 500 for the PR files list. No merge or main CI run was started.**

## Outcome

- The verifier self-test passed before network activity, and the verifier source bytes are archived and hash-bound.
- The first wrapper invocation stopped in local route bookkeeping before starting `curl`. Its exact ledger revision and route files were preserved; receipt `PREFLIGHT-01-LOCAL-ABORT.json` records zero HTTP spend. The request slot remained available.
- Fresh request `preflight-01` returned HTTP 200. Request `preflight-02` returned HTTP 500 with GitHub’s message that the diff was temporarily unavailable because of heavy server load. The raw headers, body and request IDs are retained.
- The preflight gate did not pass, so `PREMERGE.json` was not written. There was no merge intent, merge attempt, resulting main push run, retry, rerun or D-20 invocation.
- Two new GitHub API attempts are charged, for 12 aggregate attempts including the ten predecessor charges. The fixed window ended at 2026-11-10T16:35:40Z; this attempt halted with 274 seconds left. The exact approval permits zero retries and renewals.
- CIREL-01 and Phase253 remain open. This plan does not complete the milestone.

## Evidence

- Machine-readable halted result: [RESULT.json](../../execution/253/phase253-plan185-auth-20261110/RESULT.json)
- Request and spend ledger: [BOUNDS.json](../../execution/253/phase253-plan185-auth-20261110/BOUNDS.json)
- Raw preflight response headers and bodies: [requests](../../execution/253/phase253-plan185-auth-20261110/requests/)
- Zero-HTTP wrapper abort receipt: [PREFLIGHT-01-LOCAL-ABORT.json](../../execution/253/phase253-plan185-auth-20261110/diagnostics/PREFLIGHT-01-LOCAL-ABORT.json)
- Frozen verifier source: [VERIFIER-SOURCE.json](../../recovery/opengsd-health-20261106/phase253-plan185-approval-01/write-ahead/runtime-source-reconciled-01/VERIFIER-SOURCE.json)

## Next Action

No further hosted request or merge is authorized by this expired, zero-retry window. The next actor is the user to approve a fresh source-bound recovery proposal if they want another attempt. No GSD execute command is active until that authority exists.

## Self-Check

The halted result and bounds parse, all listed evidence hashes match current bytes, both HTTP responses reconcile to unique request IDs, outstanding attempts are zero, and PREMERGE/MERGE/MAIN-CI files were not created.
