---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "104"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-canary, github, r8, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-102 R8 freeze and publication manifest, 253-103 R8 reconciliation contract, 253-100/101 driver fixes"
provides:
  - "Committed fresh canary-section approval bound to the R8 outward_actions.canary sha256 (e272c040...)"
  - "Committed declared live canary HTTP allocation (117 requests / 3600 s) bound to FREEZE-R8"
  - "Actual server publication: both r8 create-only refs exist at the frozen SHAs (live-origin receipt valid)"
  - "Halted partial evidence, five preflight copies and HTTP ledger (30 of 117 requests)"
affects: ["253-105", "253-106"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R8.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ALLOCATION-R8.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R8.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R8.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R8.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R8-PREFLIGHT-rate.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R8-PREFLIGHT-effective-rules.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R8-PREFLIGHT-registered-workflow.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R8-PREFLIGHT-legacy-protection.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R8-PREFLIGHT-check-runs.json
  modified: []
key-decisions:
  - "Halted honestly on a defect in the frozen transport scripts/ci/ci-hosted-transport.py: request_one refuses every non-api.github.com host in live mode, including a redirect destination _approved_redirect has just accepted from the trusted download_hosts list, so no live artifact ZIP can ever be downloaded. No source edit, reseal, retry or extra window."
requirements-completed: []
estimate: {tokens: 28000, tasks: 3}
actuals:
  tokens: 9000
  tasks: 1
  commits: 3
commits: 3
plan_head_before: 54b248e7a9e3db5ca7f2ea34f1b4d9b052a75ad7
plan_head_after: 8d7e161cc6af7035eee53dfae6b0db2a86b71e1c
duration: 4min (hosted window)
completed: 2026-10-15
status: halted
---

# Phase 253 Plan 104: Hosted canary (R8) Summary

**Halted. Publication under Jon's fresh R8 approval worked: 17 requests, and both r8 create-only refs were created. The once-per-window preflight passed (5 requests). The full-pass fixture run 38791286863 was dispatched and completed with conclusion success. Then the frozen transport refused to follow the artifact ZIP's 302 redirect to the trusted host productionresultssa17.blob.core.windows.net, because live mode is hard-restricted to api.github.com. That came to 30 of 117 requests; no further scenario ran.**

## Dry-run gate (Task 1, offline, before any request)

- **Command:** `unset GH_TOKEN GITHUB_TOKEN; python3 scripts/ci/ci-gate-canary-dryrun.py --revision-freeze FREEZE-R8 --seed-legacy-refs`
- **Result:** exit 0, status `passed`, synthetic `true`, stop `null`, problems `[]`, verifier passed, seeded_refs_changed `false`.
- **Requests:** 93 total, equal to the journal.
  - By invocation: publish-only 17, full-pass 16, remaining 60. The remaining invocation made 0 preflight requests, because it reused the retained preflight.
  - By category: publication 19/24, preflight 5/8, dispatch 7/7, run_discovery 7/7, pre_watch_rate 7/7, terminal_polls 18/18, attempt_jobs 7/7, artifact_metadata 6/7, artifact_downloads 10/12, failure_logs 6/6, cancellation 1/1, infrastructure_retry 0/13 (expired).
- **Other offline checks:**
  - `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R8`: exit 0.
  - `--verify-load-acceptance ... --require-target-disposition`: exit 0.
  - `--check-approval` with the 253-97 approval:
    - against FREEZE-R8: exit 1 ("approval record digest is not the canary section digest");
    - against FREEZE-R7 (positive control): exit 0.
  - The string `replan-r8` occurs 0 times in either committed ledger. Positive control: the R7 ledger's get_ref/create_ref rows for the R7 names are found.
- **Gap the dry-run could not show:** its fake GitHub runs under a `hermetic-test` allocation. The transport exempts that mode from the origin check that halted the live run, so the gate could not reveal this defect.

## Decision (Task 1)

- **Decision:** Jon approved via an AskUserQuestion prompt relayed by the orchestrator. Verbatim selection: "Approve (Recommended)". Note: empty.
- **Approval record:** `253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R8.json`, sha256 `85f94d1e0d195a25fce3b5be1d69a938f1ba76ecab224bf36f0a7828a88e9a6f`.
  - Bound to canary section `e272c040ecb6533f775340885bfac68a917f3da8866ab1312947aba32af54cc7` and FREEZE-R8 `3c07f4e35c3eea8b347f7019178cc2a71595eb2b2a26708382074eea8172cb25`.
  - It does not carry the docs_and_prs digest, which belongs to 253-105.
  - Committed alone in `cd1622e90`, committer time 1792091044. `--check-approval` against FREEZE-R8 / canary: exit 0.

## Task 2 (tracer): HALTED during full-pass

- **Allocation:** `253-LOAD-RECOVERY-CANARY-ALLOCATION-R8.json`, sha256 `bafe77e5fd9e3991b91187617739a966c6862385c0e40c80bb8e90023c0733f3`.
  - Window `253-104-canary-window-1`, live canary, 117 requests / 3600 s.
  - `source_sha256` = FREEZE-R8. Category limits equal the freeze's canary table (sum 117).
  - Bound documents: FREEZE-R8 `3c07f4e3…`, PUBLICATION-R8 `6ad1c2ee…`, WORKFLOW.yml `3c31cb72…`.
  - Download hosts are the 253-97 trusted list.
  - `ci-hosted-transport.py --check-only` exited 0. Two negative controls were refused with exit 1: max_requests 118, and an untrusted host added.
  - Committed alone in `09742f572`.
- **Pre-clock checks:**
  - `--validate-frozen-source 9c2db232…`: ok, planning_only_movement true, product tree `d97f3025…`.
  - Disposition predicate: exit 0.
  - `--check-only` native_target re-open: exit 0.
  - config.json sha256 `8e312f6ccd34…`; state.json 70229 bytes; no `SIGRA_CANARY_TEST_*` set.
- **Window:**
  - Start epoch 1792091119 (2026-10-15T19:05:19Z). The approval and allocation commits both precede it and are ancestors of the ledger commit `8d7e161cc`.
  - Elapsed at halt: 210 s.
- **`--publish-only`** (explicit R8 paths): exit 0, 17 publication requests.
  - get_ref returned 404 for both r8 refs, then create_ref returned 201 and a get_ref readback returned 200.
  - Refs created: `refs/heads/gsd/253-replan-r8-candidate` → `7a1ba235a502c1f7b379a6109698fa59b65b6c8a` and `refs/heads/gsd/253-replan-r8-fixture` → `ad015ec1005b7f19d8722ce3650aa1eb777b8f44`.
  - `--verify-publication --require-live-origin`: "publication receipt valid", exit 0.
- **`--scenario full-pass`** (explicit R8 paths): exit 1.
  - Preflight ran once (5 requests: rate_limit, rules_main, branch_protection 404, check_runs on server parent `84ebcea6…`, workflow). The five required check names were verified (`preflight_verified`).
  - Fixture ref read: 1. Dispatch: 1 (204).
  - Discovery listed the run after the request-free wait: run **38791286863**, attempt 1, head `ad015ec1…` on `gsd/253-replan-r8-fixture`.
  - The first poll found the run completed with conclusion success.
  - Jobs: the 5 producers succeeded, Browser verdict succeeded, and the fixture verifier job was skipped.
  - Artifact metadata listed 6 artifacts, including `gate-canary-full-pass-38791286863-1` (id 11999138572, `sha256:665c6559…`).
  - Then `artifact_zip` returned 302 with Location host `productionresultssa17.blob.core.windows.net` (in the trusted list). Hop 1 was refused locally: `origin_rejected: live transport is restricted to api.github.com`. No request was sent for hop 1, and none was charged.
  - The driver marked the evidence `status: halted` with the diagnostic "artifact download failed for full-pass".
- **Diagnosis (read-only, confirmed offline):**
  - In `scripts/ci/ci-hosted-transport.py`, `follow_download` calls `_approved_redirect`, which accepts trusted download hosts, and passes the destination to `request_one`.
  - `request_one` (line 594, unchanged since 253-18 `156d59883`) then overrides `host` with the destination and raises `origin_rejected` for any host other than `api.github.com` unless the mode is `hermetic-test`.
  - So a live artifact download can never get past hop 0. Every earlier window halted before reaching an artifact, and the dry-run and transport tests use hermetic-test mode, so this was never exercised.
  - An offline reproduction (scratch script, no network, no ledger written) confirmed it:
    - `_approved_redirect` accepts `productionresultssa17.blob.core.windows.net:443` (control);
    - `request_one` with that destination raises `origin_rejected`.
- **Halt handling:** no source edit, reseal, retry or second window. The window is terminal. The ledger lock file was deleted. The halted records were committed in `8d7e161cc`.

## Task 3: not run

No docs-only, actual-failure, missing-seam, unexpected-skip or cancelled dispatch; no cancellation; no verifier dispatch.

## GitHub actions actually performed (all inside the approved outward_actions.canary)

- **Publication (17):** git object reads and creates, plus the two create-only r8 refs listed above, each with a 404 probe and a 200 readback. One more fixture get_ref was made at full-pass.
- **Dispatch (1):** full-pass on `gsd/253-replan-r8-fixture`, workflow 259268962.
- **Reads:** preflight 5, run_discovery 1, pre_watch_rate 1, terminal_polls 1, attempt_jobs 1, artifact_metadata 1, artifact_downloads 1 (302 only).
- **Not performed:** no push, PR, merge, rerun, cancel, ref deletion, force update, rule change, tag, release or main mutation, and no access to the former R7 ref names.

## Totals

- **Requests:** 30 of 117 new measured requests: publication 18/24, preflight 5/8, dispatch 1/7, run_discovery 1/7, pre_watch_rate 1/7, terminal_polls 1/18, attempt_jobs 1/7, artifact_metadata 1/7, artifact_downloads 1/12, infrastructure_retry 0. The 3 historical command allocations are unchanged; the old wire count stays unknown.
- **Jobs:** the hosted run executed 6 jobs (5 producers and Browser verdict) and skipped 1 (the verifier), within 45. The evidence `budget.actual_jobs` reads 0 because the driver stopped before its job accounting step. Read the run_jobs transaction (ledger sequence 28) for the literal job list.
- **Elapsed:** 210 s of 3600.
- **Record hashes:**

  | Record | sha256 |
  |---|---|
  | evidence | `4e2532455d7966a6781e25c94601cf478c881fa8572c911dc0cdbb3e1077db7e` |
  | ledger | `b0341dd567f840baad429ae4a683fa9b20ea6cc9aeb0c09e629413db2cc806e8` |
  | receipt | `fa6c2d74616c91bd62fbd191b0ef00bbf41da9fb13c67674ee598af68c8b073e` |
  | PREFLIGHT-check-runs | `f685c02d…` |
  | PREFLIGHT-effective-rules | `be0842c4…` |
  | PREFLIGHT-legacy-protection | `d6020ee3…` |
  | PREFLIGHT-rate | `9379c286…` |
  | PREFLIGHT-registered-workflow | `96395734…` |

- **Untouched records:** the halted 253-97 and 253-92 records and the earlier approval and ledger pins all re-hash to their pinned values (`shasum -c`, rc 0).

## Operator actions outside this plan (recorded for accuracy)

- **R7 ref deletion:** before this plan started, Jon asked the orchestrator to delete the two R7 refs as his optional manual cleanup. The orchestrator verified they pointed at `ce89eb7319c20596850a0c8a0b6e5661e197c86a` and `12cc2ded39301724b7234a4ee9a7a0d79609cc45`, then deleted `refs/heads/gsd/253-replan-candidate` and `refs/heads/gsd/253-replan-fixture` via `gh api`. Both now return 404.
  - This was an operator action outside every plan window and ledger. No automation did it, and this plan neither read nor recreated those refs.
  - The plan text's statement that "the R7 refs stay on GitHub untouched" is therefore out of date. The pinned plan is left unedited.
- **Orchestrator read:** while preparing the approval prompt, the orchestrator made one read-only GitHub request, `GET actions/workflows/259268962/runs?per_page=30`, to estimate fixture run duration (the prior canary fixture run took 29 s). It was outside this window and ledger and involved no mutation.

## Deviations from Plan

None in execution. The halt follows the plan's own rule: an unexpected failure permits no source edit, reseal or extra window.

## Remaining gaps / needs a decision

- **Successor plan needed.** It must fix `ci-hosted-transport.py` `request_one` so a live hop to a destination accepted by `_approved_redirect` (trusted `download_hosts`, port 443) is allowed, while the api.github.com-only rule stays for hop 0.
- **Live-mode test.** The successor should add a transport test that exercises the live-mode redirect path rather than only hermetic-test. Today the hermetic exemption hides this class of defect from the dry-run gate.
- **Also needed:** a new freeze or reseal, a fresh approval and a new window.
- **The r8 refs now exist** at the frozen SHAs. Because the publisher is create-only (it expects a 404), a successor needs either new ref names or an approved reuse path. This is a human/orchestrator decision.
- **CIREL-02 hosted proof was not obtained.** The full-pass run itself is literally green on GitHub, but its artifact was never retained, so it is not accepted evidence. Full Phase 253 verification stays not_started. CIREL-01 stays partial.
- **Not done by design:** STATE/ROADMAP/REQUIREMENTS writer steps were skipped per the orchestrator's hard constraints.

## Known Stubs

None.

## Self-Check: PASSED

- All ten R8 records exist and are committed.
- Commits `cd1622e90`, `09742f572` and `8d7e161cc` are ancestors of HEAD.
- The ledger lock file is deleted; the tree is clean except config.json (sha256 `8e312f6ccd34…`); state.json is 70229 bytes; `scripts/ci/__pycache__` is absent.
