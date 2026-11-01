---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "141"
subsystem: ci-reliability / R12 freeze
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, canary-freeze, publication-manifest, r12]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-136 MAIN-FETCH-R12 (fetched main 09df342a); 253-137 r12 ref pair and --seed-r11-refs; 253-138 --main-record guards and the main_freshness binding; 253-139/140 R12 product changes, review and early projection; 253-131 freeze precedent"
provides:
  - "253-LOAD-RECOVERY-CANARY-PUBLICATION-R12.json: packed graph from the reviewed source ded90ae9c on the fetched main 09df342a (17 of 22 projected requests, largest tree body 2,082,931 of 2,097,152 bytes, binary_blob_requests 0, main_freshness clean)"
  - "253-LOAD-RECOVERY-CANARY-FREEZE-R12.json: plan 253-141, ref pair r12, server parent 09df342a, MAIN-FETCH-R12 bound, new section digests; both offline gate modes pass on it with the r8, r9, r10 and r11 refs seeded and unchanged"
affects: ["253-142", "253-143", "253-144", "253-145"]
tech-stack:
  added: []
  patterns: []
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-FREEZE-R12.json
  modified: []
key-decisions:
  - "The frozen source is ded90ae9c (HEAD at plan start). Only planning files (the 253-140 SUMMARY and the R12 audit record) moved after the last product commit e2f7054a4, so the product tree is the reviewed one."
  - "The server parent is MAIN-FETCH-R12's fetched_main_sha 09df342a, which equals local refs/remotes/origin/main. It is not 84ebcea60."
estimate: {tokens: 26000, tasks: 2}
actuals:
  tokens: 4545
  tasks: 2
  commits: 2
commits: 2
plan_head_before: ded90ae9c5455d6dc69a68a34a99eb900006c0f5
plan_head_after: 74857cfe02933da01cd2d689ac6065c08dfb8387
duration: "about 8 minutes (08:37Z to 08:45Z on 2026-10-19), 4.5 minutes of it the Task 2 verify"
completed: 2026-10-19
---

# Phase 253 Plan 141: PUBLICATION-R12 and FREEZE-R12 Summary

**FREEZE-R12 is cut from the reviewed source ded90ae9c on the fetched main 09df342a with the r12 ref pair. The candidate 6e4f8765 is a direct single-parent child of 09df342a, and it merges into it cleanly. The manifest matches the 253-140 projection: 17 of 22 requests, four trees, the largest 2,082,931 of 2,097,152 bytes, and binary_blob_requests 0. Every identity is new. The candidate, fixture and both section digests differ from every R11 and earlier value. Both R11 approvals are refused against FREEZE-R12, and the R11 canary approval is still accepted against FREEZE-R11. Both offline gate modes pass on the committed freeze with the r8, r9, r10 and r11 refs seeded and unchanged. There were zero GitHub requests.**

CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Performance

- **Started:** 2026-10-19T08:37:18Z
- **Completed:** 2026-10-19T08:45Z
- **Tasks:** 2/2
- **Files:** 2 created (18,181 bytes, about 4,545 tokens at chars/4) plus this SUMMARY.

## Task commits

1. `447dde352` docs(253-141): R12 publication manifest on the fetched main (the manifest alone)
2. `74857cfe0` docs(253-141): R12 canary freeze (the freeze alone)

Nothing was published between the two commits. Task 2 writes only this SUMMARY.

## Task 1: PUBLICATION-R12 and FREEZE-R12 (tracer)

**Preconditions (all met):**
- The 253-136 and 253-140 SUMMARYs are status complete. The 253-140 review is finished and its projection fits.
- Local `refs/remotes/origin/main` = MAIN-FETCH-R12 `fetched_main_sha` = `09df342a82e03c3d5d40173c912b70e827f7eadc`. Nobody re-fetched.
- The tree held only ` M .planning/config.json`, and scripts/ci/__pycache__ was absent.
- The disposition predicate (`--require-target-disposition`) exited 0.
- `git diff --name-only e2f7054a4 ded90ae9c` lists only 253-140-SUMMARY.md and 253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json.

**Frozen source:**
- Commit `ded90ae9c5455d6dc69a68a34a99eb900006c0f5`, repo tree 432cbd2d.
- Product tree `62058134606110982f003deaa80c8bb571b4e2fe`, 1,480 product files.
- `--validate-frozen-source ded90ae9c…` reports frozen_source equal to it, planning_only_movement true, head 74857cfe0 (after both commits).

**PUBLICATION-R12** (`--prepare --candidate-source ded90ae9c… --server-parent 09df342a… --main-record 253-LOAD-RECOVERY-MAIN-FETCH-R12.json --fixture-file 253-LOAD-RECOVERY-CANARY-WORKFLOW.yml --workflow-path .github/workflows/ci.yml`):
- sha256 `151765e54c4c24a8fa3f36dec6e6f58a8fd32dbd35a8ccbd9b3abce44c290ad1`. Status ready-local-proposal, no blockers. `--check-manifest` reports valid.
- **main_freshness:** candidate_parent_is_fetched_main true, fetched_main_sha 09df342a, record_sha256 35fd1543… (MAIN-FETCH-R12), merge_preflight clean (exit 0, no conflicts, head 6e4f8765, base 09df342a).
- **Projection: 17 of 22 requests.** 1 parent preflight, 4 tree requests, 12 fixed non-tree requests. max_requests is 24; complete_product_delta_dropped is false.
- **binary_blob_requests: 0.**
- **Tree bodies, R12 against R11:**

| Tree | R12 bytes | R11 bytes |
|---|---|---|
| 1 | 2,070,800 | 2,001,252 |
| 2 | **2,082,931** (largest; 14,221 bytes headroom) | 2,094,030 |
| 3 | 1,404,652 | 1,278,302 |
| 4 | 17,686 | 17,686 |

  These match the 253-140 projection. The fallback (halt with options) did not fire. Budgets, the category table and the server parent were not changed.
- product_tree_parity: same_paths_modes_blobs true; source and candidate product tree 62058134; parent product tree 817de244.

**FREEZE-R12** (`--build-freeze --manifest PUBLICATION-R12 --freeze-plan 253-141 --ref-pair r12`, default acceptance evidence, disposition and approval):
- sha256 `fd1a27cb2c3e40e1f598b51576083ddb2fc89527e5a3933cfa81cd56cf2bf309`, plan `253-141`.
- **Bound documents:**
  - publication_manifest 151765e5…;
  - main_freshness_record `35fd1543a87d7abfe50949b1d1b616c3afd18f868e7382de871028681515b90e` (MAIN-FETCH-R12, re-hashes);
  - fixture_workflow `3c31cb72c3168c4e86a1ea529f16bfdd40b4405551459ca27b9b989cb762df7b` (unchanged).
- **Section digests:**
  - canary `e506857812ea12e17e0ccd06e640a3ffd2582b6b90e3d3df6dba395a0456bd29`;
  - docs_and_prs `cbe72208c1939edfd2462da025547f693b257be9ef26f910432af6fc2fa9d9c6`.
- **Identity:**
  - candidate_ref `refs/heads/gsd/253-replan-r12-candidate`; fixture_ref `refs/heads/gsd/253-replan-r12-fixture`;
  - candidate_helper_commit `6e4f87657254ed9d4a3c8b661d5e707751bc5214`, tree 766812efa6e286bae069b06361d1c475cc016fde, single parent 09df342a;
  - fixture_workflow_commit `b37f05424b2b497b3c786fc604caa4dab4dbcdf0`, tree f28833d2482403e971548420c33d6d3a2f9f9b87, parent 6e4f8765, workflow blob f4c9e2f23be6af58af3ae257579ca6d935251b56 (unchanged);
  - docs base `a090f9117503c543aacc5f5b38be1aaac1339b98`, docs head `53cef261c9455ae2f6701f7b8d271e999eac77f6`;
  - server_parent_sha `09df342a82e03c3d5d40173c912b70e827f7eadc`, workflow_path .github/workflows/ci.yml.
- **Canary category table:** identical to FREEZE-R11's (publication 24, preflight 8, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 7, artifact_downloads 12, failure_logs 6, cancellation 1, infrastructure_retry 13; sum 117).
- **outward_actions:**
  - **canary** (max_requests 117, reruns 0):
    - publish_git_objects (candidate 6e4f8765, fixture b37f0542, max 24);
    - create_ref r12-candidate → 6e4f8765 and create_ref r12-fixture → b37f0542;
    - workflow_dispatch (workflow 259268962) on `gsd/253-replan-r12-fixture` for full-pass, docs-only, actual-failure, missing-seam, unexpected-skip and cancelled;
    - cancel_run (cancelled, max 1, run identity bound to head_sha b37f0542 on the r12 fixture branch);
    - workflow_dispatch verifier.
  - **docs_and_prs** (max_requests 120):
    - publish_docs_objects (docs-base a090f911, docs-head 53cef261; max 14; refs gsd/253-replan-docs-base and gsd/253-replan-docs-head);
    - draft pr_create normal `gsd/253-replan-r12-candidate` → main;
    - draft pr_create docs-only `gsd/253-replan-docs-head` → `gsd/253-replan-docs-base`.
  - Both sections prohibit rerun, merge, auto_merge, push, force_update, delete_ref, rule_change, release and tag.

**Checks** (all offline):

| Check | Result |
|---|---|
| `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R12` (pycache removed first) | exit 0, "local fixture contract passed" |
| `--check-manifest PUBLICATION-R12` | valid, no blockers |
| `git rev-list --parents -n 1 6e4f8765` | `6e4f8765… 09df342a…` (single parent, the fetched main) |
| `git merge-tree --write-tree --name-only --no-messages 6e4f8765 09df342a` | exit 0, tree 766812ef (clean) |
| Identity and digests against every R11 and earlier value in the verify | all new |
| `.categories.canary` against FREEZE-R11 | equal |
| `bound_documents.main_freshness_record.sha256` against `shasum MAIN-FETCH-R12` | equal (35fd1543…) |
| r12 ref names in the eight committed HTTP ledgers | 0 |
| Positive control: r11 ref names in CANARY-HTTP-LEDGER-R11 | 13 |
| R11 canary approval against FREEZE-R11, section canary (positive control) | exit 0, section_sha256 898ffa48… |
| R11 canary approval against FREEZE-R12, section canary | exit 1: `approval record digest is not the canary section digest` |
| R11 PR approval against FREEZE-R12, section docs_and_prs | exit 1: `approval record digest is not the docs_and_prs section digest` |
| `--validate-frozen-source ded90ae9c…` | frozen_source matches, planning_only_movement true |
| Manifest and freeze commits | separate (447dde352, then 74857cfe0), manifest an ancestor of the freeze |
| `shasum -c PRESERVATION-R12.sha256` | rc 0 |

**Task 1 verify block:** exit 0 (`VERIFY_RC=0`).

## Task 2: offline gates on the committed FREEZE-R12

Both gates ran on the committed FREEZE-R12 at 74857cfe0 with GH_TOKEN, GITHUB_TOKEN, PYTHONPATH and SIGRA_LIVE_POLICY_SHIM unset, under caffeinate, with `--seed-r8-refs --seed-r9-refs --seed-r10-refs --seed-r11-refs`.

| Field | Hermetic | Live-policy |
|---|---|---|
| status / synthetic / freeze_plan / stop | passed / true / 253-141 / null | passed / true / 253-141 / null |
| seeded r8 / r9 / r10 / r11 refs changed | false / false / false / false | false / false / false / false |
| requests_total | 93 | 93 |
| verifier / verifier_job_model | passed / scenario-set | passed / verify_sources |
| authorization | api_with 0, api_without 0, blob_with 0, results_receiver_with 0 | api_with 85, api_without 0, blob_with 0, results_receiver_with 0 |
| live_hops | n/a | 5 artifact_zip hop 1 on productionresultssa17.blob.core.windows.net; 3 run_logs hop 1 on results-receiver.actions.githubusercontent.com; no run_logs hop 1 elsewhere |
| shim_refusals | 0 | 0 |
| response_shape | ok; 46 runs, 45 jobs, 177 steps, 33 artifacts; 3 run_logs chains; run_logs_checked, verifier_run_checked and cancelled_run_checked true; 0 mismatches | the same |

The requests by category were identical in both modes: publication 19, preflight 5, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6 (of 6), cancellation 1.

The same verify also confirmed:

| Check | Result |
|---|---|
| `--validate-frozen-source ded90ae9c…` | frozen_source matches, head 74857cfe0, planning_only_movement true, product tree 62058134 |
| ci-hermetic-live-audit.test.py | 54 OK (33.9 s) |
| `--require-target-disposition` / `--require-target-accepted` | exit 0 / exit 3 (unchanged) |
| v1 and r2–r11 reconcile `--prepare-contract --check-only` | all exit 0 |
| `shasum -c PRESERVATION-R12.sha256` | rc 0 |
| config.json sha256, state.json size, clean tree | 8e312f6c…, 70229 bytes, only ` M .planning/config.json` |

**Task 2 verify block:** exit 0 (`VERIFY_RC=0`), 08:39:32Z to 08:44:01Z. The KNOWN FLAKE in ci-pr-proof.test.sh is not part of this block and did not run.

## Deviations from Plan

None. Process notes:
1. **Verbatim verifies ran from bash script files in the session scratchpad,** because zsh does not word-split (the 253-111/119/120/131 precedent). The Task 2 script copies the two gate summaries and the validate-frozen-source output to the scratchpad before the block's own `rm`, so they could be recorded here. The chain is otherwise unchanged.
2. **`--candidate-source`** took the full SHA from `git rev-parse HEAD`, because a bare `HEAD` is refused.
3. A first ad-hoc run of the three approval checks (for recording the messages, outside the verify) was invoked from zsh with unsplit arguments and failed at argparse. It was re-run with explicit arguments and the results above come from that run. The verify block itself ran under bash and was unaffected.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. WINDOWS.md was not appended: there are no stubs, skipped tests or unrun verifies.

## Known Stubs

None.

## Threat Flags

None.
- T-253-304 is mitigated: the R12 sections have new SHAs and r12 ref names, so the digests are canary e5068578… and docs_and_prs cbe72208…. Both R11 approvals are refused against FREEZE-R12, and the R11 canary positive control against FREEZE-R11 passes.
- T-253-305 is mitigated: the parent is the fetched main 09df342a (guarded by the 253-138 code and re-checked here with the direct-child and merge-tree tests). 17 of 22 requests, largest body 2,082,931 bytes, binary_blob_requests 0. The manifest and freeze are separate commits from a clean reviewed tree with pycache removed. `--validate-frozen-source` guards later product movement, and both offline gates pass on the committed freeze.
- T-253-SC: no new dependency, and the workflow pins are unchanged.

## Follow-ups and remaining gaps

- **The r8 refs (7a1ba235 / ad015ec1), the r9 refs (b9720d8e / aa701489), the r10 refs (d16617f7 / 06bb7dfb) and the r11 refs (2b239a98 / 65c402f9) remain on GitHub, and draft PR #337 stays open,** for Jon's optional manual cleanup. Automation never reads them for reuse, moves them or deletes them.
- **FREEZE-R12 binds the product tree 62058134.** Any product byte change after ded90ae9c invalidates it, so 253-142..145 may touch .planning files only.
- **The design keeps main's newer changes out of the candidate.** The candidate is the branch's product tree as a direct child of 09df342a, so the draft PR diff will show main's newer changes as reverted. That is accepted, as in R11.
- Projection headroom on the largest tree (tree 2) is 14,221 bytes.
- The driver accepts a 202 or 204 dispatch status, while the binding requires 204. This is still open and was not loosened.
- CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Notes for 253-142 and later

- **What to approve (253-143):** Jon's fresh approval must name FREEZE-R12 sha256 `fd1a27cb2c3e40e1f598b51576083ddb2fc89527e5a3933cfa81cd56cf2bf309`, canary `e506857812ea12e17e0ccd06e640a3ffd2582b6b90e3d3df6dba395a0456bd29` and docs_and_prs `cbe72208c1939edfd2462da025547f693b257be9ef26f910432af6fc2fa9d9c6`. Both R11 approvals are provably refused.
- **Refs the live canary creates:** exactly refs/heads/gsd/253-replan-r12-candidate → 6e4f87657254ed9d4a3c8b661d5e707751bc5214 and refs/heads/gsd/253-replan-r12-fixture → b37f05424b2b497b3c786fc604caa4dab4dbcdf0. get_ref must 404 first.
- **Pre-clock gates:** `python3 scripts/ci/ci-gate-canary-dryrun.py --revision-freeze FREEZE-R12 --seed-r8-refs --seed-r9-refs --seed-r10-refs --seed-r11-refs`, hermetic and again with `--live-policy`, then `ci-hermetic-live-audit.test.py`. All passed at 74857cfe0 in about 4.5 minutes together.
- **origin/main:** local origin/main is still 09df342a. If the live parent preflight finds main moved, that is a stop, not a re-freeze.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is 8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d.
- state.json is 70229 bytes, sha256 prefix e45278c2cee0.
- STATE.md, ROADMAP.md, REQUIREMENTS.md, state.json and HANDOFF.json were not touched, and no gsd-tools writer verb was run.
- `shasum -c PRESERVATION-R12.sha256` rc 0.
- scripts/ci/__pycache__ was removed after every python run.
- Zero GitHub requests: no push, fetch, gh, curl or ls-remote.

## Self-Check: PASSED

- Both created files exist. Both task commits (447dde352, 74857cfe0) are ancestors of HEAD, and neither deletes a file.
- `git rev-list --count ded90ae9c..HEAD` = 2, before this SUMMARY's commit.
