---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "92"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-canary, github, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-91 canary freeze, publication manifest, native_target disposition"
provides:
  - "Committed canary-section approval bound to outward_actions sha256"
  - "Halted partial canary evidence, HTTP ledger (6 requests) and publication receipt"
affects: ["253-93", "253-94"]
actuals:
  tokens: 9000
  tasks: 1
  commits: 3
plan_head_before: b20f68cc8159cd6bcebe11705a84ff16391b3335
plan_head_after: 01240a3707c87fa0a9521e3174def478a23768a2
commits: 3
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ALLOCATION.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT.json
  modified: []
key-decisions:
  - "Halted honestly at publication on a publisher readback mismatch; no retry, no source edit, no rerun."
requirements-completed: []
duration: 3min
completed: 2026-10-15
status: halted
---

# Phase 253 Plan 92: Hosted canary Summary

**Halted: Jon approved the canary section, but counted publication stopped after 6 requests because the publisher's candidate commit readback compared a newline-terminated message against the server's stripped message; no ref, dispatch or run was created.**

## Task outcomes

- **Task 1 (decision):** Jon approved, verbatim "Approve exactly this list", no note. Pre-checks: freeze `--check-only` exit 0 (freeze sha256 726adae6...), `--verify-load-acceptance ... --require-target-disposition` exit 0 (route: disposition, human-approved not_reproduced; CIREL-01 partial).
- **Approval record:** committed alone (8e82569cb) before any request; section canary, section sha256 678e2576b2aec98434410aeb6b1ed9ab257fce850ade6737277c6287b902a071; docs_and_prs excluded.
- **Task 2 (tracer): HALTED.** `--publish-only` ran inside the approved list: 6 requests (1 get_commit of server parent, 3 git_create_tree, 1 git_create_commit for candidate 1351b066..., 1 get_commit readback). The readback check in `scripts/ci/ci-git-publication.py` (line ~813) failed with `server commit readback differs for candidate`. The server returned the commit with the expected sha, tree f509f042..., parent 84ebcea6..., but its `message` field lacks the trailing newline the publisher expects (`"Phase 253 frozen CI candidate\n"`). That is a publisher defect, not tampering (sha matches).
- **Task 3: not run.**

## GitHub actions actually performed

All inside outward_actions.canary (publication category, 6 of 24):
- GET git/commits/84ebcea6... (200)
- POST git/trees x3 (201)
- POST git/commits (201) creating unreferenced candidate commit 1351b066c087d04ba3bf3996394df0080ae9d818
- GET git/commits/1351b066... (200)

No ref created, no dispatch, no cancel, no verifier, no rerun, no push/PR/merge/main mutation. Server now holds unreferenced tree and commit objects (garbage-collectable). Fixture commit and both refs were never reached.

## Totals

- Requests: 6 of 117 (publication 6/24). Jobs: 0 of 45. Elapsed: about 77 s of 60 min (window_wall_start_epoch 1792026772).

## Deviations from Plan

**1. [Rule 3 - Blocking] Created 253-LOAD-RECOVERY-CANARY-ALLOCATION.json**
- **Found during:** Task 2. `--http-allocation` is mandatory for every live mode and the plan declares no allocation file.
- **Fix:** Built a live, canary-kind allocation bound to the freeze sha256 (117 requests, 3600 s, the freeze's canary category limits summing to 117, bound documents re-hashed, trusted download hosts only), validated with `ci-hosted-transport.py --check-only`, committed (acf541d3a) before any request. It authorizes nothing beyond the approved list.

**2. Runtime lock file** `...HTTP-LEDGER.json.lock` left by the halted transport was deleted, not committed.

## Remaining gap / needed decision

Per contract, no source edit, reseal or extra window after a halt, and halted evidence cannot be retried (`ci-gate-canary.sh` refuses halted evidence). Resuming CIREL-02 needs a separately authorized fix of the readback comparison (message newline normalization) and a new freeze, approval and window. 253-93 and 253-94 cannot complete on this evidence. Full Phase253 verification stays not_started.

## Self-Check: PASSED
Commits 8e82569cb, acf541d3a, 01240a370 exist; evidence, ledger, receipt, approval and allocation files exist; tree clean except config.json (sha256 8e312f6c...), state.json 70229 bytes.
