---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "131"
subsystem: ci-reliability / R11 freeze
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, canary-freeze, publication-manifest, r11]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-125..130 R11 product changes (scoped results-receiver admission, probe driver and records, probe-driven fakes, observed-route audit rule, r11 ref pair, --seed-r10-refs) and the final R11 review; 253-120 freeze precedent"
provides:
  - "253-LOAD-RECOVERY-CANARY-PUBLICATION-R11.json: packed graph from the reviewed source 8d648821 (17 of 22 projected requests, largest tree body 2,094,030 of 2,097,152 bytes, binary_blob_requests 0)"
  - "253-LOAD-RECOVERY-CANARY-FREEZE-R11.json: plan 253-131, ref pair r11, new section digests; both offline gate modes pass on it with the r8, r9 and r10 refs seeded and unchanged"
affects: ["253-132", "253-133", "253-134", "253-135"]
tech-stack:
  added: []
  patterns: []
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-FREEZE-R11.json
  modified: []
key-decisions:
  - "The frozen source is 8d648821 (HEAD at plan start). Only the 253-130 SUMMARY moved after the last product commit 5b66685c9, so the product tree is the reviewed one."
  - "The server parent is the live-proven 84ebcea6, not the local origin/main 4ff6c50e, as in 253-111 and 253-120."
actuals:
  tokens: 4334
  tasks: 2
  commits: 2
commits: 2
plan_head_before: 8d648821fac5414774b173f579a847a27a122b73
plan_head_after: 130c28acf8c607373928f824735a2610d20d07a0
duration: "about 7 minutes (07:37Z to 07:44Z on 2026-10-17), 4.3 minutes of it the Task 2 verify"
completed: 2026-10-17
---

# Phase 253 Plan 131: PUBLICATION-R11 and FREEZE-R11 Summary

**FREEZE-R11 is cut from the reviewed source 8d648821 with the r11 ref pair. The manifest matches the 253-130 early projection exactly: 17 of 22 requests, four trees, the largest 2,094,030 of 2,097,152 bytes, and binary_blob_requests 0. Every identity is new. The candidate, fixture and both section digests differ from all R10, R9, R8, R7 and 253-91 values. Jon's R10 approval is refused against FREEZE-R11 and still accepted against FREEZE-R10. Both offline gate modes pass on the committed freeze with the r8, r9 and r10 refs seeded and unchanged. response_shape matches, including the three probe-recorded run_logs chains on results-receiver. There were zero GitHub requests.**

CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Performance

- **Started:** 2026-10-17T07:37:12Z
- **Completed:** 2026-10-17T07:44Z
- **Tasks:** 2/2
- **Files:** 2 created (17,336 bytes, about 4,334 tokens at chars/4) plus this SUMMARY.

## Task commits

1. `78ade0d55` docs(253-131): R11 publication manifest from the reviewed source 8d648821 (the manifest alone)
2. `130c28acf` docs(253-131): FREEZE-R11 on the reviewed source 8d648821 with the r11 ref pair (the freeze alone)

Nothing was published between the two commits. Task 2 writes only this SUMMARY.

## Task 1: PUBLICATION-R11 and FREEZE-R11 (tracer)

**Preconditions:**
- The 253-130 and 253-127 SUMMARYs are status complete. The 253-130 review is finished, every offline suite passed, and the early projection fits.
- The tree held only ` M .planning/config.json`, and scripts/ci/__pycache__ was absent.
- The disposition predicate (`--require-target-disposition`) exited 0.
- `git diff --name-only 5b66685c9 8d648821f` lists only 253-130-SUMMARY.md.

**Frozen source:**
- Commit `8d648821fac5414774b173f579a847a27a122b73`, repo tree fad2216f.
- Product tree `e58d2f75f9cf3603f077904a47e4f76c61942c2a`, 1,480 product files.
- `--validate-frozen-source 8d648821…` reports planning_only_movement true, with head 130c28acf (after both commits).

**Server parent** `84ebcea60024c9e8caee405d55cad1c76b0e858a`, re-derived offline:
- Row 1 (sequence 1) of the committed R8 ledger is a live `GET` of `/git/commits/84ebcea6…` on api.github.com: actual_status 200, state complete, window 253-104-canary-window-1. Row 1 of the R9 ledger is the same request (window 253-113-canary-window-1). Both rows share response sha256 06d45fe9….
- `git rev-parse 84ebcea6^{tree}` = `e9d63071f0ab4ac8edba8a60a2503cc882cb5556`, as required.
- **Discrepancy (expected):** local `refs/remotes/origin/main` is still `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97`. The live-proven 84ebcea6 was used.

**PUBLICATION-R11** (`--prepare --candidate-source 8d648821… --server-parent 84ebcea6… --fixture-file 253-LOAD-RECOVERY-CANARY-WORKFLOW.yml --workflow-path .github/workflows/ci.yml`):
- sha256 `fd2e9004bb3e15998b5cd01f87595ed0d3cebcc7abad6e6335917e1213301db8`. Status ready-local-proposal, no blockers. `--check-manifest` reports valid.
- **Projection: 17 of 22 requests.** 1 parent preflight, 4 tree requests, 12 fixed non-tree requests. max_requests is 24; complete_product_delta_dropped is false.
- **binary_blob_requests: 0.** 253-129's git_create_blob audit claim still holds.
- **Tree bodies:** 2,001,252; **2,094,030 (the largest; cap 2,097,152, 3,122 bytes headroom)**; 1,278,302; 17,686. These are identical to the 253-130 early projection.
- The fallback (halt with options) did not fire. Budgets, the category table and the server parent were not changed.

**FREEZE-R11** (`--build-freeze --manifest PUBLICATION-R11 --freeze-plan 253-131 --ref-pair r11`, default acceptance evidence, disposition and approval):
- sha256 `e6eb4cd07dccf75804202dedafe323adcddceaf45ef71a3c8c4faf0caa129c90`, plan `253-131`.
- Bound documents: publication_manifest fd2e9004… and fixture_workflow `3c31cb72c3168c4e86a1ea529f16bfdd40b4405551459ca27b9b989cb762df7b`. The fixture workflow is unchanged.
- **Section digests:**
  - canary `898ffa480dc8b56dc72945feba35af326f12b9e291230ead17e76f7751ca410f`;
  - docs_and_prs `f0e47f00c63f2ac3b9e8ed3a560ba9d5d2148c31aa00234329e18e2d65646ee2`.
- **Identity:**
  - candidate_ref `refs/heads/gsd/253-replan-r11-candidate`; fixture_ref `refs/heads/gsd/253-replan-r11-fixture`;
  - candidate_helper_commit `2b239a98df72b8d47e8c4e03edf193905b3239da`, tree 05fc6801a8cf2533d816b38d874d652b16c1341f;
  - fixture_workflow_commit `65c402f966602dfc4a609af724457808cd8528eb`, tree 83a35c1119f2e2bb29945ac74a091a1e9228a645, workflow blob f4c9e2f23be6af58af3ae257579ca6d935251b56 (unchanged);
  - docs base `99b33f903038d523865889bcc8a97b7a73c042e9`, docs head `40adc7e54b7c1353e2ae155067566ecaed2f656c`;
  - server_parent_sha 84ebcea6…, workflow_path .github/workflows/ci.yml.
- **Canary category table:** identical to FREEZE-R10's (publication 24, preflight 8, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 7, artifact_downloads 12, failure_logs 6, cancellation 1, infrastructure_retry 13; sum 117).
- **outward_actions:**
  - **canary** (max_requests 117, reruns 0):
    - publish_git_objects (candidate 2b239a98, fixture 65c402f9, max 24);
    - create_ref r11-candidate → 2b239a98 and create_ref r11-fixture → 65c402f9;
    - workflow_dispatch (workflow 259268962) on `gsd/253-replan-r11-fixture` for full-pass, docs-only, actual-failure, missing-seam, unexpected-skip and cancelled;
    - cancel_run (cancelled, max 1, run identity bound to head_sha 65c402f9 on the r11 fixture branch);
    - workflow_dispatch verifier.
  - **docs_and_prs** (max_requests 120):
    - publish_docs_objects (docs-base 99b33f90, docs-head 40adc7e5; max 14);
    - draft pr_create normal `gsd/253-replan-r11-candidate` → main;
    - draft pr_create docs-only `gsd/253-replan-docs-head` → `gsd/253-replan-docs-base`.
  - Both sections prohibit rerun, merge, auto_merge, push, force_update, delete_ref, rule_change, release and tag.

**Checks** (all offline):
- `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R11` exits 0 ("local fixture contract passed"). `--check-freeze` reports freeze_valid with network_requests 0.
- **New identities:**
  - The candidate 2b239a98 is not d16617f7, b9720d8e, 7a1ba235, ce89eb73 or 1351b066.
  - The fixture 65c402f9 is not 06bb7dfb, aa701489, ad015ec1 or 12cc2ded.
  - The canary and docs_and_prs digests differ from every R10, R9, R8, R7 and 253-91 value in the verify.
- **Approval replay control:**
  - Jon's R10 approval (350809f4…, commit 94c845f0) against FREEZE-R10, section canary, exits 0 and returns section_sha256 3ef4162b… (positive control).
  - Against FREEZE-R11 it exits 1 with "approval record digest is not the canary section digest".
- **Ledgers:** no r11 name appears in any of the 140 URLs across the 253-92, R7, R8, R9, R10 and R11-PROBE ledgers. `git grep 253-replan-r11` over the ledgers also returns rc 1. Positive controls: the jq query finds 9 URLs containing `253-replan-r10-` in the R10 ledger, and `git grep 253-replan-r10-` finds the R10 ledger (rc 0).
- The manifest and freeze were added in different commits (78ade0d55 and 130c28acf). Neither commit deletes a file.
- `shasum -c PRESERVATION-R11.sha256` passes.
- **Tracer gate:** the verbatim Task 1 `<verify>` ran on the clean tree after both commits and exited 0 (VERIFY_RC=0). Expansion followed.

## Task 2: both offline gates on the committed FREEZE-R11

The verbatim Task 2 `<verify>` ran under `caffeinate -i -s` from 07:39:08Z to 07:43:23Z and exited 0 (VERIFY_RC=0). FREEZE-R11 was read only.

| Field | Hermetic `--revision-freeze FREEZE-R11 --seed-r8-refs --seed-r9-refs --seed-r10-refs` | `--live-policy` (same flags) |
|---|---|---|
| status / mode / synthetic | passed / hermetic / true | passed / live-policy / true |
| freeze_plan / stop | 253-131 / null | 253-131 / null |
| seeded_r8 / r9 / r10 _refs_changed | false / false / false | false / false / false |
| verifier / verifier_job_model | passed / scenario-set | passed / verify_sources |
| requests_total | 93 | 93 |
| authorization | api_with 0, api_without 0, blob_with 0, results_receiver_with 0 | api_with 85, api_without 0, blob_with 0, results_receiver_with 0 |
| live_hops | 8, all hop 1 on localhost (5 artifact_zip, 3 run_logs) | 8, all hop 1: 5 artifact_zip on productionresultssa17.blob.core.windows.net, 3 run_logs on results-receiver.actions.githubusercontent.com (none elsewhere) |
| shim refusals | 0 | 0 |
| response_shape | ok; 46 runs, 45 jobs, 177 steps, 33 artifacts; 3 run_logs chains; run_logs_checked, verifier_run_checked and cancelled_run_checked true; 0 mismatches | the same |

The requests by category were identical in both modes: publication 19, preflight 5, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6 (of 6), cancellation 1.

The same verify also confirmed:

| Check | Result |
|---|---|
| `--validate-frozen-source 8d648821…` | frozen_source matches, head 130c28acf, planning_only_movement true, product tree e58d2f75 |
| ci-hermetic-live-audit.test.py | 36 OK (20.5 s) |
| `--require-target-disposition` / `--require-target-accepted` | exit 0 / exit 3 (unchanged) |
| v1 and r2–r10 reconcile `--prepare-contract --check-only` | all exit 0 |
| `shasum -c PRESERVATION-R11.sha256` | rc 0 |
| config.json sha256, state.json size, clean tree | 8e312f6c…, 70229 bytes, only ` M .planning/config.json` |

## Deviations from Plan

None. The process notes:
1. **Verbatim verifies ran from bash script files in the session scratchpad,** because zsh does not word-split (the 253-111/119/120 precedent). The Task 2 script copies the two gate summaries and the validate-frozen-source output to the scratchpad before the block's own `rm`, so they could be recorded here. The chain is otherwise unchanged.
2. **`--candidate-source`** took the full SHA from `git rev-parse HEAD`, because a bare `HEAD` is refused.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. WINDOWS.md was not appended: there are no stubs, skipped tests or unrun verifies.

## Known Stubs

None.

## Threat Flags

None.
- T-253-278 is mitigated: the R11 canary section has new SHAs and r11 ref names, so its digest is 898ffa48…. The R10 approval is refused against FREEZE-R11, and the positive control against FREEZE-R10 passes.
- T-253-279 is mitigated: 17 of 22 requests, largest body 2,094,030 bytes, binary_blob_requests 0. The manifest and freeze are separate commits from a clean reviewed tree with pycache removed. `--validate-frozen-source` guards against later product movement, and both offline gates pass on the committed freeze.
- T-253-SC: no new dependency, and the workflow pins are unchanged.

## Follow-ups and remaining gaps

- **The r8 refs (7a1ba235 / ad015ec1), the r9 refs (b9720d8e / aa701489) and the r10 refs (d16617f7 / 06bb7dfb) remain on GitHub** for Jon's optional manual cleanup. Automation never reads them for reuse, moves them or deletes them.
- **FREEZE-R11 binds the product tree e58d2f75.** Any product byte change after 8d648821 invalidates it, so 253-132..135 may touch .planning files only.
- Projection headroom on tree 2 is 3,122 bytes. This only matters if a later replan changes product bytes, which would need a new freeze anyway.
- The driver accepts a 202 or 204 dispatch status, while the binding requires 204. This is still open and was not loosened.
- CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Notes for 253-132 and later

- **What to approve (253-133):** Jon's fresh approval must name FREEZE-R11 sha256 `e6eb4cd07dccf75804202dedafe323adcddceaf45ef71a3c8c4faf0caa129c90`, canary `898ffa480dc8b56dc72945feba35af326f12b9e291230ead17e76f7751ca410f` and docs_and_prs `f0e47f00c63f2ac3b9e8ed3a560ba9d5d2148c31aa00234329e18e2d65646ee2`. The R10 approval is provably refused.
- **Refs the live canary creates:** exactly refs/heads/gsd/253-replan-r11-candidate → 2b239a98df72b8d47e8c4e03edf193905b3239da and refs/heads/gsd/253-replan-r11-fixture → 65c402f966602dfc4a609af724457808cd8528eb. get_ref must 404 first.
- **Pre-clock gates:** `ci-gate-canary-dryrun.py --revision-freeze FREEZE-R11 --seed-r8-refs --seed-r9-refs --seed-r10-refs`, hermetic and again with `--live-policy`, then `ci-hermetic-live-audit.test.py`. All three passed at 130c28acf in about 4.3 minutes together.
- **origin/main:** local origin/main is still 4ff6c50e. If the live parent preflight finds 84ebcea6 unreachable, that is a stop, not a re-freeze.
- Dispatch stays explicit; blocked_by is inherited from the halted plans R11 supersedes.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is 8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d.
- state.json is 70229 bytes, sha256 prefix e45278c2cee0.
- STATE.md, ROADMAP.md, REQUIREMENTS.md, state.json and HANDOFF.json were not touched, and no gsd-tools writer verb was run.
- `shasum -c PRESERVATION-R11.sha256` rc 0.
- scripts/ci/__pycache__ was removed after every python run.
- Zero GitHub requests: no push, fetch, gh, curl or ls-remote.

## Self-Check: PASSED

- Both created files exist. Both task commits (78ade0d55, 130c28acf) are ancestors of HEAD, and neither deletes a file.
- `git rev-list --count 8d648821f..HEAD` = 2, before this SUMMARY's commit.
