---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "172"
status: complete
requirements-completed: []
subsystem: ci
key-files:
  - .planning/execution/253-pr343-remaining-evidence/attempt-result.json
  - .planning/execution/253-pr344-closeout/result.json
metrics:
  requests_this_continuation: 56
  permitted_requests: 70
  seconds_this_continuation: 341
  draft_prs_created: 1
  automatic_ci_runs_created: 1
---

# Plan 172: approved collection completed; phase verification remains open

The user approved the exact prepared proposal with **i approve**. Approval was committed before the one live invocation. The continuation downloaded the five pinned PR343 archives, matched their saved sizes and SHA-256 digests, and passed all five browser groups through the existing policy owner. It then published only the frozen docs base/head refs and opened draft PR344. Its run39837182521 attempt1 completed successfully, and the independent docs-family verifier returned accepted_live=true.

Actual collection: **56/70 HTTP requests, 341/3600 seconds, one draft PR, one automatic CI run**. All20 artifact-download requests, including redirects, were charged. No retry, rerun, workflow dispatch, merge, old-window reopening or Plan179 replay occurred. The window is closed and its approval is consumed.

| Commit | Result |
| --- | --- |
| f75e6a88b | Offline continuation,20 tests, strict request and source limits |
| 9d7a450d9 | Exact action checkpoint and shared-state preservation |
| c67cbeac7 | Literal approval for proposal88645f424b4913c9a8c7609def7f5d4890065c5b0deaa7f3e1b334b053699c6d |
| bc989be0f | Actual closed ledger, five original archives, docs PR evidence and independent verifier outputs |

The offline closeout rechecks the original seven-GET normal snapshot, all five required native checks and ci-gate against the actual successful attempt jobs, all five downloaded browser records, identical repaired-source freezes, and the exact normal/docs workflow relation. Three negative development copies reject a missing job, skipped required check and wrong source. Candidate publication verifies independently. The original six hosted canary outcomes and separate verifier remain under their original identities; a fresh offline source comparison confirms unchanged gate inputs and canary code. These read-only checks made zero GitHub requests.

## Deviations

Recovery used the separately approved bounded snapshot and artifact/docs continuation after the original paired attempt closed. Their ledgers remain separate. The original verify_pr_pair single-ledger acceptance is not claimed, and no historical attempt or budget was rewritten. This summary completes the current approved Plan172 execution tasks; it does not mark CIREL-02 or the phase passed.

## What remains

CIREL-01 remains partial_not_reproduced: the original selected registration failure has not been reproduced within its existing closed limits. CIREL-02 now has the collected normal/docs and retained canary evidence, pending whole-phase review. Both requirement checkboxes remain unchanged. The29 historical halts stay halted; no new numbered repair plan was created.

## Self-Check: PASSED

Actual normal run39815188159 and docs run39837182521 both succeeded on attempt1. Offline closeout result: `.planning/execution/253-pr344-closeout/result.json`; closed live attempt: `.planning/execution/253-pr343-remaining-evidence/attempt-result.json`. Implementation work is complete for Plan172; Phase253 verification remains not_started. Next command: `$gsd-progress` to review the original remaining requirement and stopped-plan dependencies without restarting any spent collection.
