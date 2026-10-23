---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "120"
subsystem: ci-reliability / R10 freeze
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, canary-freeze, publication-manifest, r10]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-116..119 R10 product changes (run-name identity, ledger binding, real-shape fakes, response-shape audit class, r10 ref pair) and the final R10 review; 253-111 freeze precedent"
provides:
  - "253-LOAD-RECOVERY-CANARY-PUBLICATION-R10.json: packed graph from the reviewed source 7e681e6a (17 of 22 projected requests, largest tree body 2,083,078 of 2,097,152 bytes)"
  - "253-LOAD-RECOVERY-CANARY-FREEZE-R10.json: plan 253-120, ref pair r10, new section digests; both offline gate modes pass on it with the r8 and r9 refs seeded and unchanged"
affects: ["253-121", "253-122", "253-123", "253-124"]
tech-stack:
  added: []
  patterns: []
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-R10.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-FREEZE-R10.json
  modified: []
key-decisions:
  - "The frozen source is 7e681e6a (HEAD at plan start). Only the 253-119 SUMMARY moved after the last product commit b26d207ee, so the product tree is the reviewed one."
  - "The server parent is the live-proven 84ebcea6, not the local origin/main 4ff6c50e, as in 253-111."
actuals:
  tokens: 4334
  tasks: 2
  commits: 2
commits: 2
plan_head_before: 7e681e6a9f4cbf10b1824f294a4fec54871da905
plan_head_after: c283b15a8993628c735779b2e17df0bd3bd4151d
duration: "about 9 minutes (19:36Z to 19:45Z), 5.5 minutes of it the Task 2 verify"
completed: 2026-10-16
---

# Phase 253 Plan 120: PUBLICATION-R10 and FREEZE-R10 Summary

**FREEZE-R10 is cut from the reviewed source 7e681e6a with the r10 ref pair. The manifest matches the 253-119 early projection exactly: 17 of 22 requests and four trees, the largest 2,083,078 of 2,097,152 bytes. Every identity is new. The candidate, fixture and both section digests differ from all R9, R8, R7 and 253-91 values. Jon's R9 approval is refused against FREEZE-R10 and still accepted against FREEZE-R9. Both offline gate modes pass on the committed freeze with the r8 and r9 refs seeded and unchanged, and response_shape matches. There were zero GitHub requests.**

## Performance

- **Started:** 2026-10-16T19:36:55Z
- **Completed:** 2026-10-16T19:45:02Z
- **Tasks:** 2/2
- **Files:** 2 created (17,335 bytes, about 4,334 tokens at chars/4) plus this SUMMARY.

## Task commits

1. `339d67528` docs(253-120): R10 publication manifest from the reviewed source 7e681e6a (the manifest alone)
2. `c283b15a8` docs(253-120): FREEZE-R10 on the reviewed source 7e681e6a with the r10 ref pair (the freeze alone)

Nothing was published between the two commits. Task 2 writes only this SUMMARY.

## Task 1: PUBLICATION-R10 and FREEZE-R10 (tracer)

**Preconditions:**
- The 253-119 SUMMARY is status complete. Its review is finished, every offline suite passed, and the early projection fits.
- The tree held only ` M .planning/config.json`.
- The disposition predicate (`--require-target-disposition`) exited 0.
- `git diff --name-only b26d207ee 7e681e6a9` lists only 253-119-SUMMARY.md.

**Frozen source:**
- Commit `7e681e6a9f4cbf10b1824f294a4fec54871da905`, repo tree 8f1ee62e.
- Product tree `0a1412c824aadbe469670a7df8684a3809490eb0`, 1,478 product files.
- `--validate-frozen-source 7e681e6a…` reports planning_only_movement true, with head c283b15a8 (after both commits).

**Server parent** `84ebcea60024c9e8caee405d55cad1c76b0e858a`, re-derived offline:
- Row 1 (sequence 1) of the committed R8 ledger is a live `GET git_get_commit` of this SHA on api.github.com: actual_status 200, state complete, window 253-104-canary-window-1. Row 1 of the R9 ledger is the same request (window 253-113-canary-window-1). Both rows share response sha256 06d45fe9…, and the decoded body names tree e9d63071.
- `git rev-parse 84ebcea6^{tree}` = `e9d63071f0ab4ac8edba8a60a2503cc882cb5556`, as required.
- **Discrepancy (expected):** local `refs/remotes/origin/main` is `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97`, the same value 253-111 recorded. The live-proven 84ebcea6 was used.

**PUBLICATION-R10** (`--prepare --candidate-source 7e681e6a… --server-parent 84ebcea6…`):
- sha256 `a14db1a817d2882e0d2ec4e4e36200fd132e93ef3d9aa6d7e2206c01b9f4abb3`. Status ready-local-proposal, no blockers. `--check-manifest` reports valid.
- **Projection: 17 of 22 requests.** 1 parent preflight, 4 tree requests, 12 fixed non-tree requests, 0 binary blobs. max_requests is 24; complete_product_delta_dropped is false.
- **Tree bodies:** 2,047,127; **2,083,078 (the largest; cap 2,097,152, 14,074 bytes headroom)**; 1,034,007; 17,686. These are identical to the 253-119 early projection.
- The fallback (halt with options) did not fire.

**FREEZE-R10** (`--build-freeze --manifest PUBLICATION-R10 --freeze-plan 253-120 --ref-pair r10`, default acceptance evidence, disposition and approval):
- sha256 `69eb3df785be88446ca44f6da9bc3ed572a8a7dea173f3fcfd224ab4d5515bd7`, plan `253-120`.
- Bound documents: publication_manifest a14db1a8… and fixture_workflow `3c31cb72c3168c4e86a1ea529f16bfdd40b4405551459ca27b9b989cb762df7b`. The fixture workflow is unchanged.
- **Section digests:**
  - canary `3ef4162bbff963b0613635729104476fd3d83c081de9c8b9ad8bf6bc531504fe`;
  - docs_and_prs `a3734ed5b1445ef41fa1d77afc37fe7f787f9e0cf6e3e32e83b2a5be9f1c3c7b`.
- **Identity:**
  - candidate_ref `refs/heads/gsd/253-replan-r10-candidate`; fixture_ref `refs/heads/gsd/253-replan-r10-fixture`;
  - candidate_helper_commit `d16617f77223ff136a0c9e04bc3cd067bc6370cf`, tree 161aeb56c432dab8621ed2f88651fb8c8bff2fb6;
  - fixture_workflow_commit `06bb7dfb7dad0221d49292b9342ad871685a673b`, tree 724c753ffbd55d456034cb154d136293016b0eb3, workflow blob f4c9e2f23be6af58af3ae257579ca6d935251b56 (unchanged);
  - docs base `a7585f0427a66cdde3f1c59a8e96adc3f8cec251`, docs head `44786dde37bbf7c2941899ef4c277deaf739bfec`;
  - server_parent_sha 84ebcea6…, workflow_path .github/workflows/ci.yml.
- **outward_actions:**
  - **canary** (max_requests 117, reruns 0):
    - publish_git_objects (candidate d16617f7, fixture 06bb7dfb, max 24);
    - create_ref r10-candidate and create_ref r10-fixture;
    - workflow_dispatch on `gsd/253-replan-r10-fixture` for full-pass, docs-only, actual-failure, missing-seam, unexpected-skip and cancelled;
    - cancel_run (cancelled);
    - workflow_dispatch verifier.
  - **docs_and_prs** (max_requests 120):
    - publish_docs_objects (docs-base a7585f04, docs-head 44786dde; max 14);
    - draft pr_create normal `gsd/253-replan-r10-candidate` → main;
    - draft pr_create docs-only `gsd/253-replan-docs-head` → `gsd/253-replan-docs-base`.
  - Both sections prohibit rerun, merge, auto_merge, push, force_update, delete_ref, rule_change, release and tag.

**Checks** (all offline):
- `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R10` exits 0 ("local fixture contract passed"). `--check-freeze` reports freeze_valid with network_requests 0.
- **New identities:**
  - The candidate d16617f7 is not b9720d8e, 7a1ba235, ce89eb73 or 1351b066.
  - The fixture 06bb7dfb is not aa701489, ad015ec1 or 12cc2ded.
  - The canary and docs_and_prs digests differ from every R9, R8, R7 and 253-91 value in the verify.
- **Approval replay control:**
  - Jon's R9 approval (04309213…, commit 3be0e3f38) against FREEZE-R9, section canary, exits 0 and returns section_sha256 f4210ba5… (positive control).
  - Against FREEZE-R10 it exits 1 with "approval record digest is not the canary section digest".
- **Ledgers:** no r10 name appears in any of the 87 URLs across the 253-92, R7, R8 and R9 ledgers. `git grep 253-replan-r10` over the ledgers also returns rc 1. Positive control: the same jq query finds 6 URLs containing `253-replan-r9-` in the R9 ledger.
- The manifest and freeze were added in different commits (339d67528 and c283b15a8).
- `shasum -c PRESERVATION-R10.sha256` passes.
- **Tracer gate:** the verbatim Task 1 `<verify>` ran on the clean tree after both commits and exited 0. Expansion followed.

## Task 2: both offline gates on the committed FREEZE-R10

The verbatim Task 2 `<verify>` ran under `caffeinate -i -s` from 19:39:06Z to 19:44:38Z and exited 0 (VERIFY_RC=0). FREEZE-R10 was read only.

| Field | Hermetic `--revision-freeze FREEZE-R10 --seed-r8-refs --seed-r9-refs` | `--live-policy` (same flags) |
|---|---|---|
| status / mode / synthetic | passed / hermetic / true | passed / live-policy / true |
| freeze_plan / stop | 253-120 / null | 253-120 / null |
| seeded_r8_refs_changed / seeded_r9_refs_changed | false / false | false / false |
| scenarios | full-pass, docs-only, actual-failure, missing-seam, unexpected-skip, cancelled | the same |
| verifier | passed | passed |
| verifier_job_model / result | scenario-set / scenario_set_complete (matrix 15,676 of 64,511 chars) | verify_sources / sources_verified, 35 executed jobs (matrix 15,752 of 64,511 chars) |
| requests_total | 93 | 93 |
| publication | published-local-fixture, origin hermetic, fixture ref hermetic-unverified | published-actual-github on window 253-dryrun-live-policy-66785, verifier_dryrun_window true, fixture ref verified |
| authorization | api_with 0, api_without 0, blob_with 0 | api_with 85, api_without 0, blob_with 0 |
| live_hops | 8 (5 artifact_zip hop 1, 3 run_logs) | 8, all at hop 1 on productionresultssa17.blob.core.windows.net (5 artifact_zip, 3 run_logs) |
| shim refusals / violations | none / none | none / none |
| response_shape | ok; 46 runs, 45 jobs, 177 steps, 33 artifacts; 7 scenarios incl. verifier; verifier_run_checked true; 0 mismatches | the same |

The requests by category were identical in both modes: publication 19, preflight 5, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6, cancellation 1. These match the 253-119 synthetic-r10 gates.

The same verify also confirmed:

| Check | Result |
|---|---|
| `--validate-frozen-source 7e681e6a…` | frozen_source matches, planning_only_movement true, product tree 0a1412c8 |
| ci-hermetic-live-audit.test.py | 30 OK (17.9 s) |
| `--require-target-disposition` / `--require-target-accepted` | exit 0 / exit 3 (unchanged) |
| v1 and r2–r9 reconcile `--prepare-contract --check-only` | all exit 0 |
| `shasum -c PRESERVATION-R10.sha256` | rc 0 |
| config.json sha256, state.json size, clean tree | 8e312f6c…, 70229 bytes, only ` M .planning/config.json` |

## Deviations from Plan

None. The process notes:
1. **Verbatim verifies ran from bash script files in the session scratchpad,** because zsh does not word-split (the 253-111/119 precedent). The Task 2 script copies the two gate summaries and the validate-frozen-source output to the scratchpad before the block's own `rm`, so they could be recorded here. The chain is otherwise unchanged.
2. **`--candidate-source`** took the full SHA from `git rev-parse HEAD`, because a bare `HEAD` is refused.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. WINDOWS.md was not appended: there are no stubs, skipped tests or unrun verifies.

## Known Stubs

None.

## Threat Flags

None.
- T-253-251 is mitigated: the R10 canary section has new SHAs and r10 ref names, so its digest is 3ef4162b…. The R9 approval is refused against FREEZE-R10, and the positive control against FREEZE-R9 passes.
- T-253-252 is mitigated: 17 of 22 requests, largest body 2,083,078 bytes. The manifest and freeze are separate commits from a clean reviewed tree, `--validate-frozen-source` guards against later product movement, and both offline gates pass on the committed freeze.
- T-253-SC: no new dependency, and the workflow pins are unchanged.

## Follow-ups and remaining gaps

- **The r8 refs (7a1ba235 / ad015ec1) and the r9 refs (b9720d8e / aa701489) remain on GitHub** for Jon's optional manual cleanup. Automation never reads them for reuse, moves them or deletes them.
- **FREEZE-R10 binds the product tree 0a1412c8.** Any product byte change after 7e681e6a invalidates it, so 253-121..124 may touch .planning files only.
- The driver accepts a 202 or 204 dispatch status, while the binding requires 204. This is still open and was not loosened.
- The 9 justified response-shape rows from 253-118 remain the residual risks for the live canary.
- CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Notes for 253-121 and later

- **What to approve (253-122):** Jon's fresh approval must name FREEZE-R10 sha256 `69eb3df785be88446ca44f6da9bc3ed572a8a7dea173f3fcfd224ab4d5515bd7`, canary `3ef4162bbff963b0613635729104476fd3d83c081de9c8b9ad8bf6bc531504fe` and docs_and_prs `a3734ed5b1445ef41fa1d77afc37fe7f787f9e0cf6e3e32e83b2a5be9f1c3c7b`. The R9 approval is provably refused.
- **Refs the live canary creates:** exactly refs/heads/gsd/253-replan-r10-candidate → d16617f7… and refs/heads/gsd/253-replan-r10-fixture → 06bb7dfb…. get_ref must 404 first.
- **Pre-clock gates:** `ci-gate-canary-dryrun.py --revision-freeze FREEZE-R10 --seed-r8-refs --seed-r9-refs` in hermetic mode and again with `--live-policy`, then `ci-hermetic-live-audit.test.py`. All three passed at c283b15a8, in about 5.5 minutes together.
- **origin/main:** local origin/main is still 4ff6c50e. If the live parent preflight finds 84ebcea6 unreachable, that is a stop, not a re-freeze.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is 8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d.
- state.json is 70229 bytes, sha256 prefix e45278c2cee0.
- STATE.md, ROADMAP.md, REQUIREMENTS.md, state.json and HANDOFF.json were not touched, and no gsd-tools writer verb was run.
- `shasum -c PRESERVATION-R10.sha256` rc 0.
- scripts/ci/__pycache__ was removed after every python run.
- Zero GitHub requests: no push, fetch, gh or curl.

## Self-Check: PASSED

- Both created files exist. Both task commits (339d67528, c283b15a8) are ancestors of HEAD, and neither deletes a file.
- `git rev-list --count 7e681e6a9..HEAD` = 2, before this SUMMARY's commit.
