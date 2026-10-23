---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "133"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-canary, github, operator-run, r11]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-125 scoped results-receiver admission, 253-127 probe-recorded log chain, 253-128 fakes on the recorded chain, 253-130 r11 refs, 253-131 FREEZE-R11/PUBLICATION-R11, 253-132 R11 reconciliation contract"
provides:
  - "Committed fresh canary-section approval bound to the FREEZE-R11 outward_actions.canary sha256 (898ffa48...a410f)"
  - "Committed self-contained operator runner 253-R11-CANARY-OPERATOR.sh (sha256 5f5cc0c7...8787), run by Jon"
  - "Runner-committed live canary allocation (117 requests / 3600 s, 43 download hosts) bound to FREEZE-R11"
  - "Actual server publication: both r11 create-only refs at the frozen SHAs (live-origin receipt valid)"
  - "Six actual hosted canary outcomes plus a separate hosted verifier, all accepted by the frozen verifier (canary_verified, transport_verified)"
  - "First live fresh-run results-receiver log retrieval: three run_logs 302 -> results-receiver hop 1 200 application/zip, no hop 2"
  - "Sealed accounting: 82/117 requests, 37/45 executed jobs, 845/3600 s"
affects: ["253-134", "253-135"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-CANARY-OPERATOR.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ALLOCATION-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-rate.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-effective-rules.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-registered-workflow.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-legacy-protection.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-check-runs.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-133-SUMMARY.md
  modified: []
key-decisions:
  - "Complete, not halted: the Task 4 verify exited 0, the frozen verifier accepts all six scenarios plus sources and matrix, and every ledger proof below holds with a positive control."
  - "The 45-job cap counts executed (non-skipped) jobs, per ci-gate-canary.sh:939/978 and ci-hosted-gate-verify.py:521/889: 37/45. The API listed 45 job records including skipped ones (6 runs x 7 + 3), which is also within 45."
  - "requirements-completed stays [] as in 253-112/121/127/131/132: CIREL-02 acceptance is applied by 253-135 after the PR evidence of 253-134; whole-phase verification stays not_started."
requirements-completed: []
estimate: {tokens: 34000, tasks: 4}
actuals:
  tokens: 1677756
  tasks: 4
  commits: 5
commits: 5
plan_head_before: b1d5d292b3c6a94793571130e4311f7acca98ed8
plan_head_after: effa0243873ed0deb7da84c8fa2e4e873a426b35
duration: 22min (approval 23:36:15Z to sealed records 23:58:11Z; hosted window 845 s)
completed: 2026-10-18
status: complete
---

# Phase 253 Plan 133: Hosted canary (R11, operator-run) Summary

**The canary that 253-122 could not finish is now complete. Under Jon's fresh R11 approval, the two r11 create-only refs were published and the preflight passed. All six scenarios then produced actual hosted outcomes. Full-pass (39177854780) and docs-only (39178068636) concluded success. Actual-failure (39178172412), missing-seam (39178277698) and unexpected-skip (39178379571) concluded failure, and cancelled (39178485107) concluded cancelled. The frozen verifier accepted all four negatives as `verified_non_green`. Each failure run's logs came back through the scoped results-receiver hop (302, then hop 1 200 application/zip, no hop 2), about one minute after the run completed. The separate verifier run 39178583761 succeeded. Sealed totals: 82 of 117 requests, 37 of 45 executed jobs and 845 of 3600 s, with no infrastructure retry.**

## Performance

- **Started:** 2026-10-18T23:36:15Z (Jon's decision); first plan commit 23:38:18Z.
- **Hosted window:** CLOCK STARTS 23:43:59Z (publish-only); window started 23:44:05Z (`budget.started_epoch` 1792367045); WINDOW DEADLINE 2026-10-19T00:44:05Z; the last request ended 774.9 s after the first (ledger monotonic span); sealed `elapsed_seconds` 845.
- **Completed:** records sealed 23:58:11Z ("DONE step 2"); offline Task 4 verification finished 2026-10-19T00:07Z.
- **Tasks:** 4 of 4. **Files:** 10 records and the runner, plus this SUMMARY.

## Task 1: offline gates and decision (orchestrator)

- The orchestrator ran the Task 1 verify (both dry-run gate modes on FREEZE-R11 with the r8, r9 and r10 refs seeded, the audit checker, `--check-only`, the disposition predicate, the refusal of the R10 approval, and the absence of any R11 ledger or approval). It exited 0. This executor did not re-run those gates; the per-category figures were not relayed to it.
- **Decision:** Jon's own answer via AskUserQuestion at 2026-10-18T23:36:15Z was **"Approve (Recommended)"**, with an empty note. The approval record carries `decision: approve`, `decision_text: "Approve (Recommended)"`, `note: ""`, section `canary`, `section_sha256` 898ffa480dc8b56dc72945feba35af326f12b9e291230ead17e76f7751ca410f and `freeze_sha256` e6eb4cd07dccf75804202dedafe323adcddceaf45ef71a3c8c4faf0caa129c90.

## Task 2: approval, allocation, runner (executor)

- Approval commit `8c9eda093` (one path, exact subject). Runner commit `ab70ba2f4`, runner sha256 5f5cc0c7a6246d63e864e300dc660ed9230061a9ab033a693bf2c7aede188787.
- Self-check receipt: `SELF-CHECK OK head=ab70ba2f4a951b20a2dd4139296f2d8b1751fcca runner_sha256=5f5cc0c7…8787`.
- Embedded allocation sha256: 6b8b1e299798c50373552bf399ba9dcb10d3e82aec4963b5bdf19dfd5a093b79.
- Step-2 reservation constants, taken from the code: DISCOVERY_WAIT=20 (ci-gate-canary.sh:27, asserted by the runner at :131), watch reserve 240 s, and 300 s for other requests. That gives 6 x (20 + 240) + 300 = 1860 s. Step 2's first request (seq 32) started 217 s after the first window request, leaving about 3380 s, far above 1860.

## Task 3: Jon ran both live steps

- **Step 1** (`! bash …/253-R11-CANARY-OPERATOR.sh`):
  - the allocation was committed alone (`102cc5381`);
  - publish-only ran, and the receipt verified with `--require-live-origin`;
  - full-pass ran: `preflight_verified`, 22 transport requests;
  - records commit `dd9308c9c`; "DONE step 1 2026-10-18T23:47:11Z".
- **Step 2** (`… remaining`):
  - the five remaining scenarios and the separate verifier ran;
  - every scenario verified, and the overall result was `canary_verified` / `transport_verified`;
  - records commit `effa02438`; "DONE step 2 2026-10-18T23:58:11Z", exit 0.
- No agent made a GitHub request at any point. This Task 4 also made zero GitHub requests: no gh, curl, fetch, push or ls-remote, and the runner was not re-run.

## Task 4: offline verification (this executor)

- **The Task 4 verify ran verbatim** from a bash script extracted from the Task 4 block only (one `<verify>`; it contains no `ci-gate-canary.sh` call). Result: exit 0 (`VERIFY_RC=0`); it printed "publication receipt valid".
- **Frozen verifier, per scenario** (`ci-hosted-gate-verify.py --mode canary`), each rc 0, with transport `transport_verified`, 82 requests, window 253-133-canary-window-1, and checks `effective_checks_verified` (the five required names):

| Scenario | Run ID | Conclusion | Verifier status | Scenario artifact |
|---|---|---|---|---|
| full-pass | 39177854780 | success | verified | 12154902724 |
| docs-only | 39178068636 | success | verified | 12155645231 |
| actual-failure | 39178172412 | failure | verified_non_green | 12155441173 |
| missing-seam | 39178277698 | failure | verified_non_green | 12154852476 |
| unexpected-skip | 39178379571 | failure | verified_non_green | 12155655195 |
| cancelled | 39178485107 | cancelled | verified_non_green | none (artifacts 0) |
| separate verifier | 39178583761 | success | separate_verifier.status passed | n/a |

  - `--scenario sources`: `sources_verified`, executed_jobs 36. `--scenario matrix`: `canary_verified`.
  - Every run is attempt 1, and each run's `name` equals its `display_title` ("Phase 253 Gate Canary / <scenario> / <run_id>-1"). The verifier run's name is "… / verifier / 39178583761-1".
  - **Artifact binding check.** The artifact IDs are not monotonic in run order, so the raw bodies were decoded (seq 29, 38, 46, 56, 66, 77). Every artifact's `workflow_run.id` equals its own run, its name embeds that run ID, and its head is gsd/253-replan-r11-fixture at 65c402f9…. Non-monotonic IDs also occur inside a single run (full-pass's scenario artifact is that run's newest, yet has a lower ID than its producers). This is GitHub's ID assignment, not cross-run reuse.
- **Negative controls** (each must fail, and each did):
  - the Task 4 evidence predicate with `actual_jobs` 46: rc 1;
  - with the cancel status set to 200: rc 1;
  - with results-receiver put on an artifact_zip hop: rc 1;
  - the verifier `--scenario matrix` on the halted R10 evidence: rc 1;
  - the verifier with missing-seam forced to success: rc 1;
  - `--validate-frozen-source` with a bogus SHA: rc 1.
  - Positive control: the same predicate on the real evidence: rc 0.

## Sealed accounting

Requests per category against the FREEZE-R11 canary table (= allocation `category_limits`, sum 117):

| Category | Used / limit |
|---|---|
| publication | 19 / 24 (17 publish-only + one fixture ref read per live scenario invocation, seq 23 and 32) |
| preflight | 5 / 8 (check_runs 1) |
| dispatch | 7 / 7 |
| run_discovery | 7 / 7 |
| pre_watch_rate | 7 / 7 |
| terminal_polls | 7 / 18 (each run was terminal at its first poll) |
| attempt_jobs | 7 / 7 |
| artifact_metadata | 6 / 7 |
| artifact_downloads | 10 / 12 |
| failure_logs | 6 / 6 (3 failure runs x hop 0 + hop 1) |
| cancellation | 1 / 1 |
| infrastructure_retry | 0 / 13 (expired, unused) |
| **Total** | **82 / 117** |

- `budget.request_count` 82 equals the ledger's 82 transactions (sequences 1..82, all `state: complete`, `terminal_stop` null). The evidence's `transport_ledger.transactions` is byte-identical to the ledger's (sorted-JSON compare).
- **Jobs:** 37 / 45 executed (6 scenarios x 6 executed jobs, plus 1 verifier job). The API listed 45 job records including skipped ones.
- **Time:** 845 / 3600 s sealed (ledger span 774.9 s).

## Ledger proofs (each with a positive control)

- **Authorization only to api.github.com.** The frozen transport fetches a token only when `host == API_HOST` (ci-hosted-transport.py:665-679); every other host gets no Authorization header. The transport bytes are the frozen ones: `--validate-frozen-source 8d648821…` reports frozen_source matches, `planning_only_movement: true`, product tree e58d2f75…. In the ledger, all 8 non-API transactions are hop 1 on download hosts: 5 blob hosts and 3 results-receiver. The other 74 are on api.github.com (positive control). The ledger does not record request headers, so this proof combines the code rule with the host set; the pre-window live-policy gate also asserted `blob_with 0` and `results_receiver_with 0`.
- **results-receiver only on run_logs hop 1.** It appears at seq 48, 58 and 68 (route run_logs, hop 1) and nowhere else; the positive control is those 3 rows. No transaction has hop >= 2 (positive control: 8 hop-1 rows exist).
- **Live redirect hop groups:**
  - artifact_zip hop 1: seq 31 productionresultssa17, 40 sa3, 50 sa11, 60 sa18 and 70 sa0 (`.blob.core.windows.net`), each 200 with a zip body (PK\x03\x04);
  - run_logs hop 1: seq 48, 58 and 68 on results-receiver.actions.githubusercontent.com, each 200.
- **No rerun, push, merge, deletion or force.**
  - Methods are only GET (66) and POST (16). There is no PATCH, PUT or DELETE (count 0).
  - The POST routes are git_create_tree 4, git_create_commit 2, create_ref 2, dispatch 7 and cancel_run 1.
  - No URL matches rerun, merges, pulls, releases or tags. The positive control is the one `/cancel` URL.
  - The create_ref request bodies are not stored, but both reconstruct exactly from their recorded sha256 and length: `{"ref":"refs/heads/gsd/253-replan-r11-candidate","sha":"2b239a98df72b8d47e8c4e03edf193905b3239da"}` (98 B, ff0abbf9…) and `{"ref":"refs/heads/gsd/253-replan-r11-fixture","sha":"65c402f966602dfc4a609af724457808cd8528eb"}` (96 B, fbe2d8b1…). No `force` field.
- **Exactly the two r11 refs were created**, at those SHAs: each had a pre-read 404 (seq 12 and 15), a create 201 (seq 13 and 16) and a read-back 200 (seq 14 and 17). The response bodies name the same ref and SHA, and the receipt's candidate and fixture ref and SHA agree.
- **r8, r9 and r10 untouched.** 0 URLs and 0 decoded request bodies mention `253-replan-r(8|9|10)-`, including the gunzipped matrix_evidence. Positive controls: r11 appears in 13 URLs and all 7 dispatch bodies.
- **cancel_run observed:** seq 73, `POST /actions/runs/39178485107/cancel` returned 202 `application/json; charset=utf-8`, content-length 2, body `{}`. The run concluded cancelled (seq 75), with producer (admin_behavior) cancelled and Browser verdict cancelled (seq 76).
- **failure_logs 6 / 6**, used only by the three failure-concluded runs. The cancelled run fetched no logs.
- **Ordering:** approval `8c9eda093` → allocation `102cc5381` (one path) → first ledger commit `dd9308c9c`, each an ancestor of the next. The approval committer time (1792366698) is 347 s before `window_wall_start_epoch` (1792367045).

## unobserved_live_shapes: first live observation vs audited expectation

**Now observed live (6):**

- **shape-run_logs-fresh-run** (stated first because it was the most likely new halt). Observed at seq 47→48, 57→58 and 67→68:
  - hop 0 (api.github.com): 302, `text/html;charset=utf-8`, content-length 0, Location host results-receiver.actions.githubusercontent.com (`/rest/runs/<uuid>/logs`, with a query);
  - hop 1 (results-receiver): **200**, `application/zip`, no content-length header, bodies of 56089, 54254 and 56026 B, each starting PK\x03\x04;
  - **no hop 2**;
  - timing: fetched 67, 62 and 64 s after each run's `updated_at`.

  The feared not-ready, 404 or other content-type answer did not occur. The shape matches the 253-127 probe's recorded chain (probe seq 5/6: 302 text/html, then 200 application/zip, 24644 B) and the fakes moved onto it in 253-128.
- **shape-cancel_run:** seq 73 returned 202 with body `{}` (2 B), as audited. The cancellation was then observed on a hosted job (seq 76), so neither stop path fired.
- **workflow-source:canary-fixture (separate verifier):**
  - seq 81 (run) and 82 (jobs), 3 jobs: `verifier` success, `producer (${{ matrix.seam }})` skipped with no steps, and `Browser verdict` skipped;
  - the skipped producer job's name is the literal unexpanded matrix expression;
  - the verifier's two checked steps, "Verify immutable candidate verifier checkout" and "Verify retained source matrix independently", both succeeded;
  - the verifier accepted it: no "job set is unexpected" stop.
- **shape-dispatch-matrix_evidence:** seq 78, the verifier dispatch, returned 204. Its request body is 29916 B and matrix_evidence is 29652 characters, under the 64511 MATRIX_PAYLOAD_LIMIT. No 202 halt.
- **scenario-missing-seam-run:** seq 51-60, run 39178277698 concluded failure. Its 7 jobs: five producers success, verifier skipped, Browser verdict failure. It has 5 artifacts, with no admin_checkpoints producer artifact (the missing seam). Verified non-green.
- **scenario-unexpected-skip-run:** seq 61-70, run 39178379571 concluded failure. Its 7 jobs: five producers success, verifier skipped, Browser verdict failure. It has 6 artifacts. Verified non-green.

**Still unobserved (8):**

- **shape-branch_protection-200:** seq 20 was again the 404 "Branch not protected" (149 B). main still has no classic protection.
- **shape-pr_create, shape-pr_read, shape-compare, shape-repo_contents:** first window is 253-134. No pulls, compare or contents route appears in this ledger.
- **shape-git_create_blob:** not called. PUBLICATION-R11 records `binary_blob_requests: 0`, and there is no git_create_blob route.
- **shape-git_get_tree:** not called (no route).
- **shape-job_logs-hop-1:** not called (no job_logs route).

Positive control for the "not called" claims: the ledger's route set is non-empty (git_create_tree and git_get_blob both appear).

## Record sha256 values

| Record | sha256 |
|---|---|
| ACTION-APPROVAL-R11 | 0b2d87a232c79e5eec62eeb4c55b9646d34e9c020247a1571a7ec0a87f856c00 |
| ALLOCATION-R11 | 6b8b1e299798c50373552bf399ba9dcb10d3e82aec4963b5bdf19dfd5a093b79 (= ledger allocation_sha256) |
| EVIDENCE-R11 | 34881588149d10b49cf28374055288d14b2f50d251e3df00e924647f06805fae |
| HTTP-LEDGER-R11 | 78b01fe33e7a6000111497c727feb2fca8b8d148783a1cebde14c374b3e94278 |
| PUBLICATION-RECEIPT-R11 | 49461fb3de0bbd3f8ba35f27ad6badf55f8e8366d06dfc7f980d7b83f5b3c06f |
| PREFLIGHT-rate | 6a24f8f7a14dd1c3f89d483ccbec14b1563e26b85160794bd26807b37c7de364 |
| PREFLIGHT-effective-rules | be0842c45869a3874be18438b085374418aae5b7abd442bb8df946dd9b202051 |
| PREFLIGHT-registered-workflow | 963957343ba110ce175bd31d6551e7a8ce3f11d2fbfec453a7922d268c9726cd |
| PREFLIGHT-legacy-protection | d6020ee3b0852c3deb66c66d159cc80caabeaa66ee301778307a2a18d486450d |
| PREFLIGHT-check-runs | f685c02d168b8dc7fe73e530e710e26e45201550eafae62a44bef036c4c89cff |
| FREEZE-R11 (unchanged) | e6eb4cd07dccf75804202dedafe323adcddceaf45ef71a3c8c4faf0caa129c90 |
| PUBLICATION-R11 (unchanged) | fd2e9004bb3e15998b5cd01f87595ed0d3cebcc7abad6e6335917e1213301db8 |
| Runner | 5f5cc0c7a6246d63e864e300dc660ed9230061a9ab033a693bf2c7aede188787 |

## Reconciliation ownership (R11 contract)

- **Canary rows owned by 253-133:** 253-23, 253-33, 253-45, 253-54, 253-66, 253-76 and 253-86. Each has `owners: ["253-133"]` and `required_links: ["canary"]`. Their shared objective is six actual hosted outcomes plus a separate verifier inside one sealed window, and this SUMMARY's `status: complete` with the evidence above discharges it. The helper refuses an owner SUMMARY whose status is halted or blocked (reconcile.mjs:2088-2092).
- **Halted proof.** 253-133 appears in the contract's `halted_proof_map` for 253-07, 253-12, 253-92, 253-97, 253-104, 253-113 and 253-122. (The 253-132 SUMMARY's prose lists six and omits 97; the committed contract lists seven.)
- **The halted-122 proof** is `[125, 126, 127, 128, 129, 130, 131, 133]`. 253-122 halted at its ledger seq 47 because the then-frozen transport refused the results-receiver redirect (`redirect_rejected`). The same route now completes three times (seq 47→48, 57→58, 67→68, all 200). The scenarios 253-122 never reached (missing-seam, unexpected-skip, cancelled, the cancellation and the separate verifier) were all run and accepted here.
- **Pins intact:**
  - plan_pins 135/135, summary_pins 62/62, fixture_only_records (the six -R11-PROBE records) 6/6, halted summaries 16/16 and halted receipts 66/66 all match their current bytes;
  - `shasum -c PRESERVATION-R11.sha256` (87 entries) passes.
- **Not evidence here:** the R10 runs 38962706886, 38963059240 and 38963239851 and the probe records serve only as historical context and fixtures.

## Deviations from Plan

None in the plan's actions. Execution notes:
- **zsh word-splitting:** zsh does not split `set -- $p`, so one read-only decode loop failed with jq argument errors. A bash re-run via `bash -c` was then blocked by the harness's removal safety check (a false positive: the script contained no removal). The same read-only queries ran from a scratch script file instead, as the brief suggested. No record was affected.
- **Ownership list correction:** see the 253-97 note above. The contract is the source of truth.

## Remaining gaps / next

- **CIREL-02:** hosted canary proof is in place. PR evidence (253-134) and the dispositioned completion (253-135) remain; whole-phase verification stays `not_started`. CIREL-01 stays partial under the 253-89 not_reproduced disposition (D-24).
- **Scoped refs left on GitHub:** the r8, r9, r10 and r11 refs (gsd/253-replan-r11-candidate → 2b239a98…, gsd/253-replan-r11-fixture → 65c402f9…) remain on GitHub for Jon's optional manual cleanup. No agent deletes them.
- **For 253-134:**
  - Jon's fresh approval must name FREEZE-R11's `outward_actions.docs_and_prs` section with sha256 **f0e47f00c63f2ac3b9e8ed3a560ba9d5d2148c31aa00234329e18e2d65646ee2**. Its contents:
    - publish_docs_objects with the create-only refs gsd/253-replan-docs-base → 99b33f903038d523865889bcc8a97b7a73c042e9 and gsd/253-replan-docs-head → 40adc7e54b7c1353e2ae155067566ecaed2f656c (<=14 requests);
    - draft PR gsd/253-replan-r11-candidate → main (normal);
    - draft PR gsd/253-replan-docs-head → gsd/253-replan-docs-base (docs-only);
    - max_requests 120, reruns 0, and prohibited rerun/merge/auto_merge/push/force_update/delete_ref/rule_change/release/tag.
  - The canary approval (APPROVAL-R11, section canary) does not cover this.
  - The record is `253-LOAD-RECOVERY-PR-ACTION-APPROVAL-R11.json`. The runner Jon runs is `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-PR-OPERATOR.sh` (normal family first, then a separate remaining step).

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d (never staged).
- state.json is 70229 bytes, sha256 e45278c2cee0….
- STATE.md, state.json, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json are untouched. No gsd-tools writer verb was run.
- `scripts/ci/__pycache__` is absent; it was removed after every python run. Positive control: a created directory was detected by the same check.
- FREEZE-R11 `--validate-frozen-source`: `planning_only_movement: true`, head effa02438, product tree e58d2f75f9cf3603f077904a47e4f76c61942c2a.
- No record, PLAN, earlier SUMMARY, runner, probe record, freeze, publication, contract or product source was edited.
- Zero GitHub requests by this executor.

## Self-Check: PASSED

- All 10 records and the runner exist and are committed. Commits 8c9eda093, ab70ba2f4, 102cc5381, dd9308c9c and effa02438 are ancestors of HEAD, and none deleted a file.
- `commits` was measured as 5 (`git rev-list --count b1d5d292b..HEAD`) before this SUMMARY's own commit.
