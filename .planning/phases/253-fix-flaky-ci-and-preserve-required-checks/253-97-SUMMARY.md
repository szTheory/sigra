---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "97"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-canary, github, r7, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-95 R7 freeze and publication manifest, 253-96 reconciliation contract"
provides:
  - "Committed fresh canary-section approval bound to the R7 outward_actions.canary sha256"
  - "Committed declared live canary HTTP allocation (117 requests / 3600 s) bound to FREEZE-R7"
  - "Actual server publication: both create-only refs exist at the frozen SHAs (live-origin verified)"
  - "Halted partial evidence and HTTP ledger (20 requests)"
affects: ["253-98", "253-99"]
actuals:
  tokens: 9000
  tasks: 1
  commits: 3
plan_head_before: 032f6415e4edb33d2aaa4d7ca5a349f55078e212
plan_head_after: f6e0a300d07b8a544799b910d75597ad8cda6ef2
commits: 3
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R7.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ALLOCATION-R7.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R7.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R7.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R7.json
  modified: []
key-decisions:
  - "Halted honestly on a defect in the frozen helper scripts/ci/ci-gate-canary.sh; no source edit, reseal, retry or extra window."
requirements-completed: []
duration: 3min
completed: 2026-10-15
status: halted
---

# Phase 253 Plan 97: Hosted canary (R7) Summary

**Halted: publication succeeded under Jon's fresh R7 approval (17 requests, both create-only refs created), but the full-pass scenario stopped locally at the check_runs preflight route because the frozen ci-gate-canary.sh expands `$BASH_REMATCH[1]` without braces; 20 of 117 requests used, no workflow was dispatched.**

## Task outcomes

- **Task 1 (decision):** Jon approved, decision_text "Approve exactly this list", note empty, relayed by the orchestrator. Section canary sha256 9059971bd427cf05cd49a26a8b06bb4176f4b65c266b8fa4e555399aeaf1c67d, freeze sha256 f608a445dcdd00fc0d3d2a529e50d445f9f831813c32f41140af00544736110c. docs_and_prs excluded (253-98).
- **Task 2 (tracer): HALTED after publication.**
  - Approval committed alone (1cbfbfaa3) before any request; `--check-approval` against FREEZE-R7 exited 0.
  - Allocation (sha256 72284acc8ee62cbd4f286ab9d47f6a75be42392be391534904a0501422fdbe12) committed alone (aa2d8eece) after `ci-hosted-transport.py --check-only` exited 0. Both are ancestors of the ledger commit; the approval commit precedes window_wall_start_epoch 1792032298.
  - Pre-clock assertions: disposition predicate exit 0; `--validate-frozen-source 97665bd2...` ok (planning-only movement); config.json sha256 unchanged; state.json 70229 bytes.
  - `--publish-only` (explicit R7 paths): 17 publication requests, get_ref 404 before each create, create_ref 201 for both refs, readback accepted (the 253-95 fix worked). `--verify-publication --require-live-origin` accepted.
  - `--scenario full-pass`: 3 preflight requests (rate_limit 200, rules_main 200, branch_protection 404), then the script died before the next request with `invalid_route_parameter: commit_sha must be a full lowercase Git SHA`. Cause: `scripts/ci/ci-gate-canary.sh` `api_get` (line ~550 and nine other routes) uses `"$BASH_REMATCH[1]"` instead of `"${BASH_REMATCH[1]}"`, so the route parameter is the whole match plus a literal `[1]`. The transport rejected it locally; no request was sent for it.
- **Task 3: not run.** No docs-only, actual-failure, missing-seam, unexpected-skip or cancelled dispatch, no cancellation, no verifier dispatch, no workflow run exists.

## GitHub actions actually performed (all inside outward_actions.canary)

- Publication category, 17 requests: git object reads/creates and two create-only refs `refs/heads/gsd/253-replan-candidate` -> ce89eb7319c20596850a0c8a0b6e5661e197c86a and `refs/heads/gsd/253-replan-fixture` -> 12cc2ded39301724b7234a4ee9a7a0d79609cc45, each with a get_ref readback.
- Preflight category, 3 read requests.
- No dispatch, cancel, rerun, push, PR, merge, rule change, tag, release or main mutation.

## Totals

- Requests: 20 of 117 (publication 17/24, preflight 3/8). Jobs: 0 of 45. Elapsed: about 110 s of 60 min.
- The halted 253-92 records are unchanged. The window 253-97-canary-window-1 is terminal; the evidence guard refuses a retry.

## Deviations from Plan

None in execution. The halt is the plan's own rule: an unexpected failure with no source edit, reseal or extra window permitted.

## Remaining gaps / needs a decision

- A successor plan needs a fixed `ci-gate-canary.sh` (brace all `BASH_REMATCH` expansions), a new freeze/reseal, a fresh approval and a new window. The two scoped refs already exist at the frozen SHAs; the successor must treat them as existing (publisher expects get_ref 404 and create-only), so it needs either new ref names or an approved reuse path. This is a human/orchestrator decision.
- CIREL-02 hosted proof is not obtained. Full Phase 253 verification stays not_started.

## Known Stubs

None.

## Self-Check: PASSED

Five R7 records present; commits 1cbfbfaa3, aa2d8eece and f6e0a300d are ancestors of HEAD; the lock file was deleted; tree clean except config.json.
