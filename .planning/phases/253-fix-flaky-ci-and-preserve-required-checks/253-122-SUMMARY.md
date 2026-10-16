---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "122"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-canary, github, operator-run, r10, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-116 run-name fix and receipt-to-ledger binding, 253-117 real-shape fakes, 253-118 R10 response-shape audit, 253-119 r10 refs, 253-120 FREEZE-R10/PUBLICATION-R10, 253-121 R10 contract"
provides:
  - "Committed fresh canary-section approval bound to the R10 outward_actions.canary sha256 (3ef4162b...)"
  - "Committed self-contained operator runner (253-R10-CANARY-OPERATOR.sh, sha256 da70cbba...)"
  - "Runner-committed live canary allocation (117 requests / 3600 s) bound to FREEZE-R10 (69eb3df7...)"
  - "Actual server publication: both r10 create-only refs exist at the frozen SHAs (live-origin receipt valid)"
  - "Live proof that the 253-116 run-name fix works: full-pass run 38962706886 and docs-only run 38963059240 accepted by the frozen verifier"
  - "First live run_logs response: 302 to results-receiver.actions.githubusercontent.com (ledger seq 47), refused by the trusted download policy"
  - "Halted partial evidence, five preflight copies, HTTP ledger (47 of 117 requests) and publication receipt"
affects: ["253-123", "253-124", "R11 gap-closure replan"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R10.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R10-CANARY-OPERATOR.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ALLOCATION-R10.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R10.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R10.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R10.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R10-PREFLIGHT-rate.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R10-PREFLIGHT-effective-rules.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R10-PREFLIGHT-registered-workflow.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R10-PREFLIGHT-legacy-protection.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R10-PREFLIGHT-check-runs.json
  modified: []
key-decisions:
  - "Halted honestly at the first failure scenario. Real GitHub answered the actual-failure run's run_logs GET (ledger seq 47) with a 302 to results-receiver.actions.githubusercontent.com. That host is outside both the frozen allocation download_hosts and the hard-coded trusted policy in ci-hosted-transport.py (lines 512-513 and 802-803), so the transport refused the hop before its socket (redirect_rejected). This is the third hermetic-vs-live blind spot: every fake modeled the log redirect on an assumed host (dry-run: productionresultssa17 blob; transport test: pipelines.actions.githubusercontent.com). The 253-118 audit row shape-run_logs predicted this exact fail-closed halt. No source edit, reseal, retry or extra window."
requirements-completed: []
estimate: {tokens: 34000, tasks: 4}
actuals:
  tokens: 855181
  tasks: 4
  commits: 5
commits: 5
plan_head_before: 0c876fa8c277e7429c71761f295cebfc746e2c1f
plan_head_after: 3382083b8d36170d295495315edd39c079d6b6c3
duration: 18min (approval commit to halt commit; hosted window 421 s)
completed: 2026-10-16
status: halted
---

# Phase 253 Plan 122: Hosted canary (R10, operator-run) Summary

**Halted at the first failure scenario. Under Jon's fresh R10 approval, the two r10 create-only refs were published and the preflight passed. The full-pass run 38962706886 and the docs-only run 38963059240 both concluded success, and the frozen verifier accepted both. That is live proof that the 253-116 run-name fix works. The actual-failure run 38963239851 concluded `failure` as it should. The driver then asked for its failed logs. GitHub answered `GET /actions/runs/38963239851/logs` with a 302 to `results-receiver.actions.githubusercontent.com` (ledger seq 47). That host is not in the trusted download policy, so the transport refused the hop (`redirect_rejected`) and the driver stopped with `ci-gate-canary: FAIL: failed-log retrieval failed for run 38963239851`. The window used 47 of 117 requests, 12 recorded jobs and 421 s. Missing-seam, unexpected-skip, cancelled, the cancellation and the separate verifier dispatch were not run.**

## Task 1: offline gates and decision (orchestrator)

- **Gates:** the orchestrator ran these offline on FREEZE-R10 with the r8 and r9 refs seeded, before the prompt. This executor did not re-run them; the figures are as the orchestrator reported.
  - The hermetic gate and the live-policy gate each passed with 93 requests.
  - Per-category counts: publication 19, preflight 5, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6, cancellation 1.
  - 8 live hops; `response_shape` ok, including the verifier run; live-policy `verify_sources`.
  - Audit test: 30 OK. `--check-only`: rc 0. Disposition predicate: rc 0. The R9 approval was refused against R10, and as a control was accepted against R9.
- **Deviation found in Task 1 (orchestrator):** the Task 1 verify chain as written fails at `--check-only`. The audit python run just before it leaves an untracked `scripts/ci/__pycache__`, and `--check-freeze` counts that as product-tree dirt. This was reproduced both ways. The chain passed when the pycache was deleted between steps.
- **Decision:** Jon was asked fresh via AskUserQuestion, relayed by the orchestrator. His verbatim selection was "Approve (Recommended)", with an empty note. The approval record's `decision_text` is `Approve (Recommended)` and its `note` is `""`.
- **Approval record:** `253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R10.json`, sha256 `350809f4a7e49008f75b1e16ff3e55d9606fa7426d126cfe550c2a7ad9e569db`.
  - section_sha256 `3ef4162bbff963b0613635729104476fd3d83c081de9c8b9ad8bf6bc531504fe`; freeze_sha256 `69eb3df7…` (FREEZE-R10).
  - Committed alone in `94c845f01`, committer time 1792181917 (20:18:37Z). That is before window_wall_start_epoch 1792182543 (20:29:03Z).

## Task 2: runner (executor)

- `253-R10-CANARY-OPERATOR.sh`, sha256 `da70cbba3f7eb117a2aac4be49b5084a690a99ecececcb23e46f40197beb5978`, committed alone in `01718c289` (20:22:18Z).

## Task 3: live window (Jon ran the runner via `!`)

The CLOCK, WINDOW LEFT and STOP lines below are Jon's runner output as relayed. Each one that can be checked against committed bytes was checked.

- **Allocation:** `253-LOAD-RECOVERY-CANARY-ALLOCATION-R10.json`, sha256 `19f88204483b94e70f5e7d717dee94c285ba22e8b61eb0290c581b1d00e49edb`.
  - Window `253-122-canary-window-1`, mode live, kind canary, 117 requests / 3600 s, max_hops 2. `source_sha256` is FREEZE-R10.
  - The category limits equal the freeze's canary table and sum to 117.
  - It lists 42 download hosts: pipelines.actions.githubusercontent.com plus productionresultssa0 through 40. results-receiver.actions.githubusercontent.com is not among them (`index` returns null).
  - The runner committed it alone in `1697e8b46` at 20:28:48Z, before the first request.
- **Step 1:**
  - CLOCK 2026-10-16T20:29:03Z, which equals `budget.started_epoch` 1792182543.
  - publish-only (seq 1-17): get_ref 404, create_ref 201 and get_ref 200 for each r10 ref.
  - Preflight ran once (seq 18-22).
  - full-pass (seq 23-31): run **38962706886**, conclusion success, 6 executed jobs plus the verifier skipped. Its artifact 12073352181 came through hop 0 api.github.com 302 (seq 30) and hop 1 **productionresultssa16**.blob.core.windows.net 200 (seq 31). The handoff said sa15 for this hop; the ledger says sa16, and sa15 was docs-only's hop.
  - The runner committed the step-1 records in `8343b9f82` (20:31:45Z).
- **Step 2 (remaining-scenarios):**
  - docs-only (seq 32-40): run **38963059240**, conclusion success, 6 executed jobs plus the verifier skipped. Its artifact 12074150354 came through hop 0 302 (seq 39) and hop 1 **productionresultssa15**.blob.core.windows.net 200 (seq 40).
  - actual-failure (seq 41-47): run **38963239851**. Run, jobs and artifacts were read (seq 44-46). Then run_logs (seq 47) returned 302 and was refused.
  - The runner committed the halted records in `3382083b8` (20:36:05Z) and printed `STOP: remaining-scenarios exit 1`.
- **Halt literal:** the ledger's `terminal_stop` is `{code: "redirect_rejected", status: 302}`. The evidence has `status: halted` and `diagnostics: [{kind: "canary-stop", message: "failed-log retrieval failed for run 38963239851"}]`. The transport message, from `ci-hosted-transport.py:821`, is `redirect host is outside the frozen download-host list or trusted download policy`.

## Diagnosis (read-only, from committed bytes, each claim with a control)

1. **actual-failure behaved correctly as a negative.** The raw seq-44 run body (decoded from `response_body_base64`) has:
   - `conclusion: "failure"`, status completed, `name` equal to `display_title` = `"Phase 253 Gate Canary / actual-failure / 38963239851-1"`;
   - head `06bb7dfb…` on `gsd/253-replan-r10-fixture`, workflow_id 259268962, path `.github/workflows/ci.yml`.

   The seq-45 jobs body has `producer (admin_behavior)` failure, `Browser verdict` failure, verifier skipped, and the other four producers success. Seq 46 lists 6 artifacts, including `gate-canary-actual-failure-38963239851-1`.
   - **Control:** the same decode of seq 27 and seq 36 gives `conclusion: "success"` for full-pass and docs-only.
   - The driver fetches logs only `if [[ "$conclusion" == failure ]]` (`ci-gate-canary.sh:913-916`), which is why the failed-log route ran for the first time here.
2. **The real log redirect host is `results-receiver.actions.githubusercontent.com`.** Seq 47 (`run_logs`, category failure_logs, hop 0, api.github.com) has:
   - `actual_status` 302;
   - `scrubbed_headers.location` = `{host: "results-receiver.actions.githubusercontent.com", path: "/rest/runs/b972c96c-3f23-44de-883a-280b8f45a02c/logs", has_query: true, port: null}`;
   - content-type `text/html;charset=utf-8`, content-length 0, x-github-request-id `EAF0:9C08E:53D04F:111B77C:6AD28AB4`, date 20:36:04 GMT. That date equals started_epoch + 421 s.

   There is no hop-1 transaction for run_logs, so nothing was sent to the host and no token left api.github.com. Seq 47 is the last transaction.
   - **Control:** both artifact_zip hop-0 302s (seq 30 and 39) carry blob-host locations and have hop-1 200 rows.
3. **The transport's policy refuses that host, by design and in two places.** Reproduced offline by importing `ci-hosted-transport.py` against ALLOCATION-R10:
   - `_trusted_download_host("results-receiver.actions.githubusercontent.com")` returns False;
   - `_approved_redirect(<that location>)` raises `redirect_rejected` with the exact message above.
   - **Positive control:** productionresultssa16, productionresultssa15 and pipelines.actions.githubusercontent.com return True, and a blob location is approved.
   - **Second control:** a scratch allocation copy with results-receiver appended to `download_hosts` still returns False. The predicate at lines 802-803 only admits `pipelines.actions.githubusercontent.com` or `productionresultssa[0-9]+.blob.core.windows.net`, and `_validate_allocation` at lines 512-513 would refuse such an allocation anyway.
   - So admitting the host needs a source change, not just an allocation change.
4. **No earlier committed record ever observed a log redirect.** run_logs transactions per committed ledger:

   | Ledger | run_logs | artifact_zip |
   |---|---|---|
   | unsuffixed | 0 | 0 |
   | R7 | 0 | 0 |
   | R8 | 0 | 1 |
   | R9 | 0 | 2 |
   | R10 | 1 | 4 |

   The R10 row is the positive control for the same query.
   - `git grep results-receiver` matches only the two R10 records (evidence and ledger). As a control, `productionresultssa` matches many files.
   - The Phase 252 bundle only holds `logs_url` strings inside run payloads (12 in 252-BASELINE.json; 0 log URLs in `acquisition-attempts/`). Its only log-redirect host is a test fake inside a ci-run-metrics test patch: `pipelines.actions.githubusercontent.com/job-log/run?sig=SIGNED_LOG_SENTINEL`. That fake is where the trusted pipelines host came from, an assumed host that was never observed.
5. **Every offline model put the log redirect on the wrong host.**
   - `ci-gate-canary-dryrun.py:894-907` (`_redirect`) serves both `artifacts` and `logs` in live-policy mode as `https://{BLOB_HOST}/_downloads/{kind}/...`, with `BLOB_HOST = "productionresultssa17.blob.core.windows.net"` (line 79).
   - `ci-hosted-transport.test.py:1104-1119` (`test_run_logs_follow_to_pipelines_host_without_authorization`) models it on pipelines.actions.githubusercontent.com.
   - Neither matches GitHub. The orchestrator-reported 8 live gate hops (5 artifact_zip and 3 run_logs, all on productionresultssa17) agree with this code. This executor did not re-derive that hop list.
   - This is the third hermetic-vs-live blind spot. The first was the 253-104 redirect host; the second was the 253-113 run-name.
6. **It was a declared, fail-closed residual risk.**
   - The R10 audit row `shape-run_logs` (`253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R10.json`) is `justified` with `real_samples: []`. Its residual_risk reads: "If GitHub redirects run logs to a host outside the frozen download hosts, the transport refuses the hop before its socket and download_no_follow fails, halting the window at the first failure scenario (fail-closed)… First seen: 253-122."
   - 253-118-SUMMARY line 132 says the same thing.
   - 253-122-PLAN line 102 lists "real redirect hosts outside the trusted list, the real failed-log redirect" as honest halts not covered offline.
   - The halt happened exactly where it was predicted.
7. **The failing Task 4 verify check is this halt, not a new defect.**
   - Verbatim verify: rc 1. The first failing check is `hosted-gate-verify: FAIL: measured transport ledger has a terminal stop`, and the same holds for `--scenario sources` and `--scenario matrix`.
   - **Control:** `--scenario full-pass` on the step-1 evidence from `8343b9f82` (`git show` into the scratchpad, 31 transactions, no terminal_stop) exits 0, with scenario `verified`, run 38962706886, digest `sha256:1c1dfc27…`, `transport_verified` at 31 requests, and `effective_checks_verified`.
   - Running the checks one by one:
     - **Fail** (expected for this halt): `status != halted`; exactly 7 dispatches (actual 3); exactly one cancel_run 202 (actual 0); 6 scenario runs with `name == display_title` (actual 2: full-pass and docs-only, both of which match).
     - **Pass:** `--verify-publication --require-live-origin` ("publication receipt valid"); `--check-approval` canary; receipt refs; check_runs ≤ 1; no infrastructure_retry; ≤ 117 transactions; request_count == ledger length; jobs ≤ 45; seconds ≤ 3600; artifact_zip hop-1 blob 200; no r8/r9 URL; r10 URL present (9); ledger and origin window ids; ledger ≤ 117; approval → allocation → ledger ancestry (`94c845f01` → `1697e8b46` → `8343b9f82`); allocation committed alone; the node approval/allocation binding (rc 0, with a node exit-3 control); `PRESERVATION-R10.sha256` (62 lines, rc 0); config.json sha256.

## GitHub actions actually performed (all inside the approved outward_actions.canary)

- **Mutations (POST only, no PUT/PATCH/DELETE):** git_create_tree 4, git_create_commit 2, create_ref 2, dispatch 3.
- **Refs created:** the seq-13 and seq-16 response bodies, with readbacks at seq 14, 17, 23 and 32, show `refs/heads/gsd/253-replan-r10-candidate` → `d16617f77223ff136a0c9e04bc3cd067bc6370cf` and `refs/heads/gsd/253-replan-r10-fixture` → `06bb7dfb7dad0221d49292b9342ad871685a673b`. These match the receipt.
- **r8/r9 refs untouched:** 0 occurrences of `replan-r8` or `replan-r9` in the R10 ledger or evidence bytes, against 9 r10 URLs as a control.
- **Runs left on GitHub:** three completed runs: 38962706886 (full-pass, success), 38963059240 (docs-only, success) and 38963239851 (actual-failure, failure).
- **Not performed:** no missing-seam, unexpected-skip or cancelled dispatch; no cancel_run; no verifier dispatch; no push, PR, merge, rerun, ref deletion, force, rule change, tag, release or main mutation.

## Totals

- **Requests:** 47 of 117 (ledger length equals `budget.request_count`).

  | Category | Used / limit |
  |---|---|
  | publication | 19/24 |
  | preflight | 5/8 |
  | dispatch | 3/7 |
  | run_discovery | 3/7 |
  | pre_watch_rate | 3/7 |
  | terminal_polls | 3/18 |
  | attempt_jobs | 3/7 |
  | artifact_metadata | 3/7 |
  | artifact_downloads | 4/12 |
  | failure_logs | 1/6 |
  | cancellation | 0/1 |
  | infrastructure_retry | 0/13 (expired) |

- **Jobs:** `budget.actual_jobs` 12/45 (6 executed per accepted run).
  - actual-failure's 6 executed jobs were never added, because the halt came before the job accounting at `ci-gate-canary.sh:918-920`. Hosted executions were therefore 18, still ≤ 45.
- **Elapsed:** 421 s of 3600.
- **Live redirect hop groups:**
  - artifact_zip for full-pass: hop 0 api.github.com 302, then hop 1 productionresultssa16.blob.core.windows.net 200.
  - artifact_zip for docs-only: hop 0 api.github.com 302, then hop 1 productionresultssa15.blob.core.windows.net 200.
  - run_logs for actual-failure: hop 0 api.github.com 302 to results-receiver.actions.githubusercontent.com, hop 1 refused.
  - Signed queries are stored as `[REDACTED]` (`sig=` count 0).
- **Record sha256:**

  | Record | sha256 |
  |---|---|
  | approval | `350809f4a7e49008f75b1e16ff3e55d9606fa7426d126cfe550c2a7ad9e569db` |
  | runner | `da70cbba3f7eb117a2aac4be49b5084a690a99ecececcb23e46f40197beb5978` |
  | allocation | `19f88204483b94e70f5e7d717dee94c285ba22e8b61eb0290c581b1d00e49edb` |
  | evidence | `86f33b0ab98b47b19fa33952390f1fbd2f9e7b15a9cac60677c546ebe8c47551` |
  | ledger | `3b0dd91e85612a973012bbcdadcc925afa3b1dc5cbe4b95a1c5349c6ed226c33` |
  | receipt | `0d5c2e0865b021a1419c1778525d194e015e5dc0d85553e9c153a3728d7c4518` |
  | PREFLIGHT-rate | `85bd82ad…` |
  | PREFLIGHT-effective-rules | `be0842c4…` |
  | PREFLIGHT-registered-workflow | `96395734…` |
  | PREFLIGHT-legacy-protection | `d6020ee3…` |
  | PREFLIGHT-check-runs | `f685c02d…` |
  | FREEZE-R10 | `69eb3df7…` (unchanged) |
  | PUBLICATION-R10 | `a14db1a8…` (unchanged) |

- **Shapes never observed (still open):**
  - the cancelled run and cancel_run 202;
  - the separate verifier run and its skipped-producer job naming (the 253-117 closed set);
  - matrix_evidence dispatch inputs;
  - missing-seam and unexpected-skip runs;
  - what results-receiver returns on hop 1: a direct 200, or another redirect, which would count against max_hops 2.

  Their audited expectations could not be compared with reality.

## What R11 needs (options, not chosen here)

All of these need a new freeze or reseal, a fresh approval and a new window. They also need new create-only ref names, or an approved reuse path, because r10 now exists.

- **A. Admit the real log host, scoped to the run_logs route.**
  - Add `results-receiver.actions.githubusercontent.com` to the trusted policy for run_logs only. That means changing both `_validate_allocation` (512-513) and `_trusted_download_host` (802-803), keeping blob/pipelines for artifact_zip, and adding it to the allocation hosts.
  - Turn seq 47's committed headers (host, `/rest/runs/<uuid>/logs`, has_query, text/html, length 0) into a real-shape fixture.
  - Move both fakes (`dryrun._redirect` for logs and `transport.test:1104`) onto it, and change the audit row from justified to real-shape-test.
  - Pros: the window would complete as designed. Cons: a new token-free egress host; hop-1 behavior is still unobserved.
- **B. Accept the 302 from api.github.com as the failed-log proof, without following it.**
  - The audit row already states the driver "reads nothing from the bytes for acceptance". Change `download_no_follow`'s run_logs leg to require a 302 with a Location on a recognized GitHub host and no hop 1.
  - Pros: no new egress host, fewer requests. Cons: log bytes are never retrieved; this weakens the D-17 record.
- **C. Switch to per-job logs (`jobs/{id}/logs`, the job_logs route).**
  - Its redirect host is also never observed (justified row), so this repeats the same blind-spot risk unless it is probed first.
- **D. Drop failed-log retrieval from canary acceptance.** The failure is already proven by the run and jobs bodies. This needs a decision on the D-17/D-21 evidence contract.
- **Cross-cutting option:** a single approved read-only probe at the start of R11 that follows `runs/38963239851/logs` end to end, to capture the real hop-1 shape before the six scenarios. Run 38963239851 already exists and its logs are retained.
- **Carry forward the residual-risk list:** the cancelled run, cancel_run 202, the verifier run and job names, matrix_evidence, missing-seam/unexpected-skip, results-receiver hop 1, and the Task 1 verify-chain pycache ordering (delete `scripts/ci/__pycache__` between the audit python and `--check-only`).

## Commits

- `94c845f01`: docs(253-122): record Jon's R10 canary action approval
- `01718c289`: docs(253-122): R10 canary operator runner (Jon runs the live steps)
- `1697e8b46`: docs(253-122): declare the R10 live canary HTTP allocation (runner, Jon)
- `8343b9f82`: docs(253-122): R10 full-pass evidence, ledger and publication receipt (runner, Jon)
- `3382083b8`: docs(253-122): halted R10 canary records (remaining-scenarios exit 1) (runner, Jon)
- This SUMMARY: docs(253-122): halted SUMMARY (R10 failed-log redirect host outside trusted list)

## Deviations from Plan

1. **Task 1 verify-chain ordering (orchestrator; see Task 1).** The pycache left by the audit python step breaks `--check-only`. It was run with the pycache deleted between steps. Nothing was loosened.
2. **Executor mistake in Task 4, contained.** While extracting the Task 4 `<verify>` from the PLAN, the first sed range also captured the Task 1 and Task 3 verify blocks and the text between them, and ran them under bash.
   - The Task 1 offline dry-run gates started. Per the module docstring, they use a local HTTPS fake, gh/curl as failing recorders and tokens removed.
   - The executor killed the script and its orphaned dry-run processes, and removed the dry-run's own temp clone, `$TMPDIR/sigra-253-dryrun-aggk8ll8`.
   - No GitHub request was possible. Afterwards the repository tree was clean except config.json, no `.git` file changed, and config.json and state.json were unchanged.
   - The correct Task 4 verify, the last `<verify>` only, was then run verbatim (rc 1, as above).
3. **Otherwise as written.** The halt follows the plan's own rule: no source edit, reseal, rerun or extra window. STATE, ROADMAP and REQUIREMENTS writers were skipped per the orchestrator's hard constraints.

## Remaining gaps

- **CIREL-02 stays open.** Two positive scenarios were accepted live. No negative outcome, cancellation or separate verifier was accepted.
- **CIREL-01** stays under the 253-89 not_reproduced disposition.
- **Blocked:** 253-123 and 253-124 stay blocked until R11. Full Phase 253 verification stays not_started.
- **Refs for Jon's optional manual cleanup:** six scoped refs remain on GitHub: r8 (untouched), r9 (`b9720d8e` / `aa701489`) and r10 (`d16617f7` / `06bb7dfb`). Three R10 runs remain as well.

## Known Stubs

None.

## Self-Check: PASSED

- All eleven 253-122 records exist and are committed.
- `94c845f01`, `01718c289`, `1697e8b46`, `8343b9f82` and `3382083b8` are ancestors of HEAD. Approval precedes allocation, which precedes ledger.
- `git rev-list --count 0c876fa8c..3382083b8` = 5.
- The tree is clean except config.json (sha256 `8e312f6ccd34…`). state.json is 70229 bytes, prefix `e45278c2cee0`. `scripts/ci/__pycache__` is absent.
