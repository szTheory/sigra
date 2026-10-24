---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "113"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-canary, github, r9, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-111 R9 freeze and publication manifest, 253-112 R9 reconciliation contract, 253-107 transport redirect fix, 253-108 live-policy gate, 253-110 hermetic-vs-live audit"
provides:
  - "Committed fresh canary-section approval bound to the R9 outward_actions.canary sha256 (f4210ba5...)"
  - "Committed declared live canary HTTP allocation (117 requests / 3600 s) bound to FREEZE-R9 (3ddde073...)"
  - "Actual server publication: both r9 create-only refs exist at the frozen SHAs (live-origin receipt valid)"
  - "First live proof of the 253-107 redirect fix: artifact_zip hop 0 api.github.com 302, hop 1 productionresultssa15.blob.core.windows.net 200"
  - "Halted partial evidence, five preflight copies and HTTP ledger (31 of 117 requests)"
affects: ["253-114", "253-115", "R10 gap-closure replan"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R9.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ALLOCATION-R9.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R9.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R9.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R9-PREFLIGHT-rate.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R9-PREFLIGHT-effective-rules.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R9-PREFLIGHT-registered-workflow.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R9-PREFLIGHT-legacy-protection.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R9-PREFLIGHT-check-runs.json
  modified: []
key-decisions:
  - "Halted honestly on a defect in the frozen verifier scripts/ci/ci-hosted-gate-verify.py lines 713-714: it requires the GitHub run `name` to equal the bare FIXTURE_NAME \"Phase 253 Gate Canary\", but the fixture workflow declares a run-name, and real GitHub returns run `name` equal to that run-name (\"Phase 253 Gate Canary / full-pass / 38906314106-1\"). Every offline fake writes the bare name, so no gate could see it. No source edit, reseal, retry or extra window."
requirements-completed: []
estimate: {tokens: 28000, tasks: 3}
actuals:
  tokens: 5500
  tasks: 1
  commits: 3
commits: 3
plan_head_before: c9f78a907df6546c01b2cd5bd655223edf6cba6c
plan_head_after: 7d9e3c303e006fa34e7cfba95e497fba229d6421
duration: 3min (hosted window, 169 s)
completed: 2026-10-16
status: halted
---

# Phase 253 Plan 113: Hosted canary (R9) Summary

**Halted. Under Jon's fresh R9 approval, publication worked: 17 requests created both r9 create-only refs. The once-per-window preflight passed. The full-pass fixture run 38906314106 completed with conclusion success. Its artifact ZIP was downloaded through the approved redirect, hop 0 to api.github.com (302) and hop 1 to productionresultssa15.blob.core.windows.net (200). That is the first live proof that the 253-107 fix works. The frozen verifier then rejected the run with `run workflow identity mismatch`. The reason: real GitHub reports a run's `name` as the workflow's run-name, while the verifier expects the bare workflow name. The window used 31 of 117 requests, and no further scenario ran.**

## Task 1: offline gates and decision

- **Gates (orchestrator, offline, before the prompt, GH_TOKEN/GITHUB_TOKEN/PYTHONPATH/SIGRA_LIVE_POLICY_SHIM unset; env-check count 0):**
  - `ci-gate-canary-dryrun.py --revision-freeze FREEZE-R9 --seed-r8-refs` (hermetic): RC 0.
  - The same with `--live-policy`: RC 0.
  - The plan's full Task 1 `<verify>` chain then ran. Its log shows `ci-hermetic-live-audit.test.py` at 14 tests OK and `ci-gate-canary: local fixture contract passed` from `--check-only`.
  - The gate JSON outputs were not retained in the scratchpad, so this SUMMARY can't restate their per-category counts or `live_hops` count. The proof that they passed is the scratch log plus the fact that the orchestrator went on to present the approval.
- **Decision:** Jon was asked fresh via AskUserQuestion, relayed by the orchestrator. Verbatim selection: "Approve (Recommended)". Note: empty.
- **Approval record:** `253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R9.json`, sha256 `043092132da2dcf43713236fae167767888af9ff71fe7d3bf623a8277dcf67ee`.
  - Bound to canary section `f4210ba50fbc1a3bc94e45f8c7091b4083c45d80076a890596e1fc269c708b4a` and FREEZE-R9 `3ddde073506474ab74092a093f85e8a6259372faa24fd17ec1d46db4ec9d432d`.
  - It authorizes the r9 refs for candidate `b9720d8e00e69e11c965ed7cf5029e3a0008783a` and fixture `aa7014893b716f279b60ceb545b8aee5ca15b10c`.
  - It excludes docs_and_prs, reruns, any r8-ref access, and any push, merge, deletion, force, rule, tag, release or main mutation.
  - recorded_at 2026-10-16T12:37:06Z. Committed alone in `3be0e3f38`, committer time 1792154252 (12:37:32Z), which is before window_wall_start_epoch 1792156377.

## Task 2 (tracer): HALTED at the full-pass verifier

**Who ran it.** The auto-mode permission classifier refused the allocation commit and the live runs, for both the executor and the orchestrator. Jon ran these steps himself via `!` using the orchestrator's script, `scratchpad/253-113-canary.sh`. The script runs the plan's Task 2 steps in order with the explicit R9 paths: `--revision-freeze`, `--action-approval`, `--http-allocation`, `--requests`, `--evidence` and `--publication-receipt`. Before the clock it unsets GH_TOKEN, GITHUB_TOKEN, PYTHONPATH, SIGRA_LIVE_POLICY_SHIM and every SIGRA_CANARY_TEST_* variable, and asserts none remain.

- **Allocation:** `253-LOAD-RECOVERY-CANARY-ALLOCATION-R9.json`, sha256 `bcc14d85bab79b38989f1cea1a44d7a07744d9fa3ad7729197b0b1cfc1c4d121`. The script checks this sha before committing.
  - Window `253-113-canary-window-1`, live canary, 117 requests / 3600 s, max_hops 2.
  - `source_sha256` = FREEZE-R9 `3ddde073…`. The category limits sum to 117.
  - Bound documents: FREEZE-R9 `3ddde073…`, PUBLICATION-R9 `1f820993…` and WORKFLOW.yml `3c31cb72…`.
  - Download hosts: pipelines.actions.githubusercontent.com plus productionresultssa0-40.
  - Committed alone in `a09e456cc`, committer time 1792156362 (13:12:42Z), before the first request.
- **Pre-clock checks (all passed):**
  - the disposition predicate (`--require-target-disposition`);
  - `--check-only --revision-freeze FREEZE-R9`;
  - `--validate-frozen-source 283b256265e30b0b452bb1478fa3db51d37edeb6` with `planning_only_movement` true;
  - `--check-approval` with APPROVAL-R9 / canary;
  - config.json sha256 `8e312f6ccd34…`.
- **Clock:** the script printed `CLOCK STARTS` at 2026-10-16T13:12:53Z. The first metered transaction set `started_epoch` = `window_wall_start_epoch` = 1792156377, which is 13:12:57Z. Elapsed at the halt was 169 s.
- **`--publish-only`:** exit 0, 17 publication requests (ledger seq 1-17).
  - get_ref returned 404 for both r9 refs, then create_ref returned 201 and a get_ref readback returned 200.
  - Refs created: `refs/heads/gsd/253-replan-r9-candidate` → `b9720d8e…` and `refs/heads/gsd/253-replan-r9-fixture` → `aa701489…`. The receipt fields match.
  - `--verify-publication --require-live-origin`: "publication receipt valid".
- **`--scenario full-pass`:** exit 1.
  - **Preflight:** ran once, 5 requests (seq 18-22, which brought the running transport count to 22): rate_limit, rules_main, branch_protection 404, check_runs on server parent `84ebcea6…`, and workflow. All five required check names were verified (`effective_checks_verified`).
  - **Dispatch:** one fixture ref read (seq 23), then dispatch returned 204 (seq 24).
  - **Discovery:** discovery (seq 25) and pre_watch_rate (seq 26) found run **38906314106**, attempt 1, head `aa701489…` on `gsd/253-replan-r9-fixture`, event workflow_dispatch, workflow_id 259268962, path `.github/workflows/ci.yml`.
  - **Polling:** the first poll (seq 27) found the run completed with conclusion success.
  - **Jobs:** run_jobs (seq 28) listed 7 jobs: 5 producers, Browser verdict and verifier. Six executed with success; the verifier was skipped. `budget.actual_jobs` = 6.
  - **Artifact:** run_artifacts (seq 29), then artifact_zip for artifact 12048052856 (`gate-canary-full-pass-38906314106-1`, 933 bytes):
    - hop 0 went to api.github.com and returned **302** (seq 30);
    - hop 1 went to **productionresultssa15.blob.core.windows.net** and returned **200** (seq 31).

    The retained `archive_sha256` `6ff02bc7…` equals the artifact API digest `sha256:6ff02bc7…`. This is the first live proof of the 253-107 redirect fix.
  - **Verifier:** the driver's verifier step (`ci-gate-canary.sh` line 941) then failed with `hosted-gate-verify: FAIL: run workflow identity mismatch`. The driver recorded the canary-stop diagnostic at line 941 and set the evidence to `status: halted`.
- **Halt handling:**
  - The window is terminal: no source edit, reseal, rerun or second window.
  - The ledger lock is absent.
  - The halted records (evidence, five preflight copies, ledger and receipt) were committed in `7d9e3c303`, committer time 13:15:47Z.

## Diagnosis (read-only, confirmed from committed bytes, each with a control)

1. **The failing check is `ci-hosted-gate-verify.py` lines 713-714.** It requires `run.get("name") == FIXTURE_NAME`, and FIXTURE_NAME is `"Phase 253 Gate Canary"` (line 27). The file was last changed in `283b25626`.
   - **Reproduction:** `python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario full-pass --evidence EVIDENCE-R9` (offline, tokens unset) exits 1 with exactly `FAIL: run workflow identity mismatch`.
   - **Positive control:** a scratch copy of the evidence was edited in one field only, `scenarios["full-pass"].run.name` = `"Phase 253 Gate Canary"`. The verifier exits 0 with `canary_scenario_verified`, `transport_verified` (31 requests, window 253-113-canary-window-1), `effective_checks_verified`, and the artifact digest `sha256:6ff02bc7…`.
   - So this is the only failing check. Everything else in full-pass would have accepted. The committed evidence sha256 `a3ca8cc0…` was unchanged before and after the run.
2. **The fixture workflow declares a run-name.** `253-LOAD-RECOVERY-CANARY-WORKFLOW.yml` lines 3-4 read `name: Phase 253 Gate Canary` and `run-name: Phase 253 Gate Canary / ${{ inputs.scenario }} / ${{ github.run_id }}-${{ github.run_attempt }}`.
   - **Control:** `git show aa701489:.github/workflows/ci.yml` carries the same two lines. Its blob is `f4c9e2f2…`, the published fixture blob, and its sha256 `3c31cb72…` equals the committed WORKFLOW.yml and the allocation's bound document.
3. **Real GitHub returns `name` equal to the run-name.** In the raw seq-27 ledger response body (decoded from `response_body_base64`), `name` and `display_title` are both `"Phase 253 Gate Canary / full-pass / 38906314106-1"`. The derived receipt `scenarios["full-pass"].run` carries the same value.
   - **Control:** the same raw-body decode on halted 253-104's R8 run poll gives `name` = `display_title` = `"Phase 253 Gate Canary / full-pass / 38791286863-1"`. GitHub behaved the same in two independent windows.
   - **Second control:** the registered-workflow preflight copy reports `name: "CI"` (main's ci.yml), not FIXTURE_NAME. That confirms `name` on the run object is not the registered workflow's name either.
4. **Every offline fake writes the bare workflow name.** `ci-gate-canary-dryrun.py:441` writes `"name": "Phase 253 Gate Canary"`, even though line 442 of the same fake writes the correct run-name shape into `display_title`. `ci-hosted-gate-verify.test.py:67` also writes the bare name.
   - **Control:** grepping `scripts/ci/` for a bare FIXTURE_NAME run `name` finds only these two fakes, plus the registered-workflow object at `ci-git-publication.py:1256`, which is correctly bare.
   - **Contrast:** the sibling `release-canary.test.sh` fakes write `name` equal to `display_title`, which is the real GitHub shape.
   - This is a hermetic-gate blind spot of the same class as 253-104. The 253-110 audit's "Still not covered offline" list names real GitHub latency, auth scopes and 403/429 responses. It doesn't name run metadata shape, so this gap fell outside even its listed residuals.
5. **No earlier window reached the verifier with real run metadata.** The committed canary evidence shows:
   - R9: 1 run poll, verifier reached here;
   - R8 (253-104): 1 run poll, but `scenarios` is empty because it halted at artifact_zip before line 941;
   - R7 and the unsuffixed record: 0 run transactions.

   The defect was therefore latent in 253-104 as well.
6. **The same check appears in two more places.**
   - Line 836 applies the identical `run.get("name") == FIXTURE_NAME` to the separate verifier run. That run's driver discovery (`ci-gate-canary.sh:963`) expects the display title `Phase 253 Gate Canary / verifier /…`, so it would fail the same way.
   - Line 705 checks the frozen `expected.workflow_name` and is correct as is.
   - The PR-mode run check (around line 1278) does not compare `name`, so 253-114's PR path is not affected by this defect.

**Likely fix shape (recorded for the R10 replan, not made here).** At lines 713-714 and 836, accept `run.name` equal to FIXTURE_NAME or equal to the expected run-name `f"{FIXTURE_NAME} / {scenario} / {run_id}-{run_attempt}"`, and require `display_title` to match that same run-name. Keep the existing `workflow_id == 259268962` and path `.github/workflows/ci.yml` requirements unchanged. Also fix both fakes so they emit the real shape (`name` = `display_title` = run-name), and add a verifier test with the real-shape receipt plus a negative for a wrong scenario or run id in the run-name.

**Additional observation for the replan (not verified further).** The positive control above was accepted even though its edited `run.name` no longer matched the raw seq-27 response body. That suggests canary-mode run identity is read from the derived receipt and not re-derived from the ledger's raw run response, unlike the PR path, which uses `tx_json(polls[-1])`. R10 should check whether canary run fields need binding to the raw transaction.

## Task 3: not run

No docs-only, actual-failure, missing-seam, unexpected-skip or cancelled dispatch; no cancellation; no separate verifier dispatch.

## GitHub actions actually performed (all inside the approved outward_actions.canary)

- **Publication (17):** git object reads and creates, plus the two create-only r9 refs (each with a 404 probe, a 201 create and a 200 readback), and one more fixture get_ref at full-pass.
- **Dispatch (1):** full-pass on `gsd/253-replan-r9-fixture`, workflow 259268962.
- **Reads:** preflight 5, run_discovery 1, pre_watch_rate 1, terminal_polls 1, attempt_jobs 1, artifact_metadata 1, artifact_downloads 2 (one api.github.com 302 and one blob 200).
- **Not performed:** no push, PR, merge, rerun, cancel, ref deletion, force update, rule change, tag, release or main mutation. No request names an r8 ref: 0 matches for `253-replan-r8` in the R9 evidence and ledger, against 1 match for `replan-r9` in the ledger as a control. The r8 refs are untouched.

## Totals

- **Requests:** 31 of 117 newly measured.

  | Category | Used / limit |
  |---|---|
  | publication | 18/24 |
  | preflight | 5/8 |
  | dispatch | 1/7 |
  | run_discovery | 1/7 |
  | pre_watch_rate | 1/7 |
  | terminal_polls | 1/18 |
  | attempt_jobs | 1/7 |
  | artifact_metadata | 1/7 |
  | artifact_downloads | 2/12 |
  | infrastructure_retry | 0 (expired) |

  The ledger has 31 transactions, equal to `budget.request_count`. The accounted cap stays 120, made up of the 117 new requests plus the 3 historical command allocations. The old wire count stays unknown.
- **Live redirect hops:** 1 group. Hop 0 went to api.github.com (302), hop 1 to productionresultssa15.blob.core.windows.net (200).
- **Jobs:** 6 executed, 1 skipped, within the cap of 45.
- **Elapsed:** 169 s of 3600.
- **Record hashes:**

  | Record | sha256 |
  |---|---|
  | approval | `043092132da2dcf43713236fae167767888af9ff71fe7d3bf623a8277dcf67ee` |
  | allocation | `bcc14d85bab79b38989f1cea1a44d7a07744d9fa3ad7729197b0b1cfc1c4d121` |
  | evidence | `a3ca8cc0b562b2a060540f6b55fc1c0d29907c7103f87db970e1f4f678043aba` |
  | ledger | `9c3d7659981a3be0e2592d09d670e4ab0dfc8084771a8ce51d8d1075a5f34e01` |
  | receipt | `183a873ff17aa3e223e7d6d59934f21f22c2df3af7b32bc600e0dc73e72ea670` |
  | PREFLIGHT-check-runs | `f685c02d…` |
  | PREFLIGHT-effective-rules | `be0842c4…` |
  | PREFLIGHT-legacy-protection | `d6020ee3…` |
  | PREFLIGHT-rate | `9c385a82…` |
  | PREFLIGHT-registered-workflow | `96395734…` |

- **Untouched records:** `shasum -a 256 -c --quiet 253-LOAD-RECOVERY-PRESERVATION-R9.sha256` returns rc 0, so the halted 253-104, 253-97 and 253-92 records and the other pins keep their bytes.

## Commits

- `3be0e3f38`: docs(253-113): record Jon's R9 canary action approval
- `a09e456cc`: docs(253-113): declare the R9 live canary HTTP allocation
- `7d9e3c303`: docs(253-113): halted R9 canary records (full-pass exit 1)

## Deviations from Plan

**1. Operator-run live steps.** The auto-mode classifier refused the allocation commit and the live modes for both agents. Jon ran the allocation commit and Task 2 himself via `!`, using the orchestrator's script, which follows Task 2's steps and explicit R9 paths in order. Nothing outside the plan's steps ran. Otherwise the plan executed as written, and the halt follows the plan's own rule: an unexpected failure permits no source edit, reseal or extra window.

## Remaining gaps / needs a decision

- **R10 gap-closure replan needed.** It must fix the canary run-identity check (lines 713-714 and 836) per the fix shape above, fix both offline fakes to emit GitHub's real run shape, and add a real-shape test plus negatives. It also needs a new freeze or reseal, a fresh approval and a new window.
- **Refs:** `gsd/253-replan-r9-candidate` → `b9720d8e` and `gsd/253-replan-r9-fixture` → `aa701489` now exist on GitHub, alongside the untouched r8 refs. The publisher is create-only, so R10 needs new ref names or an approved reuse path. All four scoped refs remain for Jon's optional manual cleanup.
- **CIREL-02 stays open.** Run 38906314106 is literally green on GitHub, and its artifact was retained with a matching digest, but the verifier did not accept it, so it is not accepted evidence. CIREL-01 stays partial under the 253-89 not_reproduced disposition. Full Phase 253 verification stays not_started.
- **Blocked:** 253-114 and 253-115 depend on this halted plan and stay blocked until R10.
- **Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints.

## Known Stubs

None.

## Self-Check: PASSED

- All ten R9 records exist and are committed.
- Commits `3be0e3f38`, `a09e456cc` and `7d9e3c303` are ancestors of HEAD. The approval precedes the allocation, which precedes the ledger commit.
- No ledger lock file is present.
- The tree is clean except config.json (sha256 `8e312f6ccd34…`). state.json is 70229 bytes, sha prefix `e45278c2cee0`. `scripts/ci/__pycache__` is absent.
