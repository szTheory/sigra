---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "102"
subsystem: ci-reliability / hosted canary scoped refs and R8 freeze
status: complete
tags: [ci-reliability, load-recovery, scoped-refs, canary-freeze, r8]
requirements: ["CIREL-02"]
dependency_graph:
  requires: ["253-101"]
  provides: ["freeze-selected scoped ref pair (legacy default, r8)", "253-LOAD-RECOVERY-CANARY-PUBLICATION-R8.json", "253-LOAD-RECOVERY-CANARY-FREEZE-R8.json (plan 253-102, ref pair r8)"]
  affects: ["253-103", "253-104", "253-105"]
tech-stack:
  added: []
  patterns: ["exactly two code-pinned ref pairs selected by the freeze identity", "pair-consistency check at every consumer (publisher, freeze checker, receipt verifier, PR collector, PR verifier)"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-R8.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-FREEZE-R8.json
  modified:
    - scripts/ci/ci-git-publication.py
    - scripts/ci/ci-git-publication.test.py
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-pr-proof.sh
    - scripts/ci/ci-pr-proof.test.sh
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
decisions:
  - "Ref decision (a): R8 publishes create-only refs under new names gsd/253-replan-r8-candidate and gsd/253-replan-r8-fixture, chosen by the freeze. The two R7 refs are never read for reuse, moved or deleted."
  - "--freeze-plan accepts 253-NN or 253-NNN with no leading zero on the three-digit form (253-095 stays refused, so the existing refusal test is unchanged)."
  - "Every live ci-pr-proof.sh --family run (normal and docs-only) requires the PR freeze's normal.head_ref to equal the revision freeze's identity.candidate_ref, refused before any request."
  - "CANARY_BRANCH stays in the publisher as an alias for the legacy fixture branch; nothing reads it now."
metrics:
  started: 2026-10-15T17:11:23Z
  completed: 2026-10-15T18:20:08Z
  tasks: 3
  files: 10
estimate: {tokens: 36000, tasks: 3}
actuals:
  tokens: 19497
  tasks: 3
  commits: 5
plan_head_before: aefb94a30989c6b7f7575e1d28438e6fe5e12ec5
plan_head_after: 22f96f8ea109fb6b09aabcc086e11982c540a790
---

# Phase 253 Plan 102: R8 scoped refs and canary freeze Summary

**R8 now publishes under its own new branch names, gsd/253-replan-r8-candidate and gsd/253-replan-r8-fixture, which the freeze selects. The two branches 253-97 left on GitHub are never touched. The reviewed source is frozen as FREEZE-R8, and that freeze passes the offline dry-run with the R7 branches pre-seeded. No GitHub requests were made.**

## Commits

| Commit | Message |
|---|---|
| `753fb81cf` | feat(253-102): freeze-selected scoped ref pair through the publisher and transport |
| `55c03eca1` | feat(253-102): PR collector and verifier take the normal head from the freeze |
| `9c2db2329` | style(253-102): separate require_pr_refs from the following constants (final R8 review) |
| `ae42a9fb9` | docs(253-102): R8 publication manifest from the reviewed post-fix tree |
| `22f96f8ea` | docs(253-102): R8 canary freeze on the r8 scoped ref pair |

There are 5 commits from `aefb94a30` up to the freeze commit, measured with `git rev-list --count`. This SUMMARY's commit comes after them.

## Ref decision and blast radius

- **Choice (a): new names, selected by the freeze.**
  - `REF_PAIRS` in `ci-git-publication.py` has exactly two entries:
    - legacy (the default): `gsd/253-replan-candidate` and `gsd/253-replan-fixture`;
    - r8: `gsd/253-replan-r8-candidate` and `gsd/253-replan-r8-fixture`.
  - These consumers all take the pair from the freeze identity and refuse a mixed pair or a third name: `build_freeze`/`--build-freeze --ref-pair`, `check_revision_freeze`, `build_outward_actions`, `publish()` with its receipt, and `verify_publication`.
  - The docs refs (`gsd/253-replan-docs-base` and `gsd/253-replan-docs-head`) keep their names.
- **Transport:** `PR_HEAD_REFS` is now exactly {`gsd/253-replan-candidate`, `gsd/253-replan-r8-candidate`, `gsd/253-replan-docs-head`}. `PR_BASE_REFS` and the `create_ref` name rule are unchanged (tested). `HELPER_PATHS` is unchanged.
- **No change to `ci-gate-canary.sh`.** It reads `fixture_ref` from the freeze, and its namespace check only looks at the prefix.
- **Earlier freezes are unchanged.** `build_outward_actions` still reproduces their recorded section digests exactly (test-asserted):
  - FREEZE-R7: `9059971b…`, `c2f66af0…`;
  - the 253-91 freeze: `678e2576…`, `5d15af53…`.
- **Leftovers on GitHub (optional manual cleanup for Jon; nothing automated touches them):**
  - `refs/heads/gsd/253-replan-candidate` → `ce89eb7319c20596850a0c8a0b6e5661e197c86a`;
  - `refs/heads/gsd/253-replan-fixture` → `12cc2ded39301724b7234a4ee9a7a0d79609cc45`;
  - the R7 git objects and the unreferenced 253-92 objects (commit `1351b066…`).

  They are harmless. 253-104 creates two new refs beside them.

## RED → GREEN record

- **Task 1, publication (`RefPairTests`, 7 new tests):**
  - RED: 5 failed (1 error, `REF_PAIRS` missing; 4 failures). The other 2 are guards that also pass on the old code: the digest replay of both earlier freezes, and the legacy-named publication stopping on seeded refs.
  - GREEN: 66/66 (was 59).
- **Task 1, transport (2 new tests):**
  - RED: 1 failed (the `PR_HEAD_REFS` membership test). The `create_ref` regex test is a guard.
  - GREEN: 35/35.
- **Task 2, verifier (1 new test):**
  - RED: 1 error (`PR_NORMAL_HEADS` missing).
  - GREEN: 78/78.
- **Task 2, collector (`ci-pr-proof.test.sh RefPairTests`, 5 new tests):**
  - RED: 3 tests failed (6 subtests):
    - the r8 freeze still produced head `gsd/253-replan-candidate`;
    - check-only refused the known r8 head;
    - all four "PR head differs from the revision freeze" cases failed with the old message instead of the new check.
  - Two tests passed on the old code and are guards: receipt-tamper refusal at `--prepare` (already caught by the Task 1 `verify_publication`), and the legacy head.
  - GREEN: 39/39 (was 34).
- **Task 2 test-harness change:** the `World` in `ci-pr-proof.test.sh` can now publish under a canary freeze (`ref_pair=`) with the legacy refs pre-seeded. `build_canary_freeze` is split out of `build_approval`. All 34 existing contracts still pass.

## Dry-runs (offline, synthetic)

- **`ci-gate-canary-dryrun.py --ref-pair r8 --seed-legacy-refs`** (synthetic r8 freeze in the clone): passed.
  - 93 requests, journal 93, all six scenarios and the matrix accepted.
  - `create_ref` 2, `seeded_refs_changed` false.
- **Legacy-pair positive control** (`--seed-legacy-refs` with the default legacy pair): exit 1 at publish-only after 12 requests, with `scoped ref gsd/253-replan-candidate already points to a different commit`. Seeded refs unchanged and no `create_ref`. So the seeded refs really would stop a legacy-named publication.
- **Task 3 gate on the committed FREEZE-R8** (`--revision-freeze FREEZE-R8 --seed-legacy-refs`): passed.
  - freeze_plan `253-102`, synthetic true, verifier matrix passed.
  - Scenarios: full-pass, docs-only, actual-failure, missing-seam, unexpected-skip, cancelled.
  - Requests: requests_total 93 = journal 93; per invocation publish-only 17, full-pass 16, remaining 60.
  - By category: preflight 5, publication 19, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6, cancellation 1. All are within the frozen table, and infrastructure_retry is 0.
  - Refs: `create_ref` 2, `get_ref` 6, `seeded_refs_changed` false.
  - Modeled elapsed time 132.9 s.

## Final R8 code review (W2)

Scope: every R8 product change from `9db1b5dd1` (the 253-100 base) to `9c2db2329`. That covers `ci-gate-canary.sh`, `ci-hosted-transport.py`, `ci-git-publication.py`, `ci-hosted-gate-verify.py`, `ci-pr-proof.sh`, `ci-gate-canary-dryrun.py` and their tests.

| # | Finding | Disposition |
|---|---|---|
| R1 | `ci-hosted-gate-verify.py`: the new `require_pr_refs` was followed by a constant with no blank-line separation (style). | Fixed in `9c2db2329` (a file this task declares). |
| R2 | `ci-gate-canary.sh`: the ERR trap now uses errtrace. A failing command substitution outside a condition would halt the window. | Checked: no `$(…grep…)`-style substitution that may legitimately fail exists; the only one is inside `[[ … ]] \|\| fail`. No change. |
| R3 | `ci-gate-canary.sh`: the inline Python in publish-only writes `EVIDENCE.tmp` without an explicit close. | Not a defect: CPython flushes when the interpreter exits, before the following `mv`. No change. |
| R4 | `ci-hosted-gate-verify.py`: the hermetic channel is chosen by the evidence's own `origin.channel`. | By design (T-253-204): hermetic evidence verifies only as synthetic and records a completion gap. Labelling live evidence hermetic can only downgrade it. No change. |
| R5 | `ci-hosted-gate-verify.py`: the page-ordinal rule is now sequential (page N>1 must directly follow page N-1); the old gap pass was removed. | Equivalent or stricter for the transport, which pages one request at a time. No change. |
| R6 | `ci-git-publication.py`: `CANARY_BRANCH` is no longer read. | Kept as a harmless legacy alias. Removing it would need a file outside Task 2's declared files for no behaviour change. Not accepted. |
| R7 | `ci-gate-canary-dryrun.py:939`: the `--ref-pair` help text still says "(253-102 adds the option; never passed here)". The option now works, and this plan passes it. | Cosmetic help text in a file outside this plan's declared files, with no behaviour effect. Not accepted for this plan; deferred, to fix the next time the runner is edited. |

Two findings, R6 and R7, would need a file outside the declared set, but neither is a correctness defect, so neither halts the plan.

## R8 freeze (Task 3)

- **Frozen source commit:** `9c2db232938c832bdfec765616a5aa0454c8fd88` (reviewed and clean). Product tree `d97f3025d12b788ea1437c385899988a4e44115e`, 1476 product files.
- **Server parent:** `84ebcea60024c9e8caee405d55cad1c76b0e858a`, re-derived offline with no fetch.
  - Local `refs/remotes/origin/main` equals it, and its tree is `e9d63071f0ab4ac8edba8a60a2503cc882cb5556`.
  - Row 1 of both committed ledgers (253-92 and 253-97) is a live 200 `git_get_commit` of this sha.
  - No discrepancy.
- **`253-LOAD-RECOVERY-CANARY-PUBLICATION-R8.json`:**
  - sha256 `6ad1c2ee42160c1500f70430ce9d6b3709ba2471f98d15f3a67ca205ff80d893`;
  - status ready-local-proposal;
  - projected requests 17 (≤24);
  - largest tree body 2083078 bytes (≤2097152, about 14 KB of headroom);
  - 4 tree requests, 0 binary blobs.
- **`253-LOAD-RECOVERY-CANARY-FREEZE-R8.json`:** sha256 `3c07f4e35c3eea8b347f7019178cc2a71595eb2b2a26708382074eea8172cb25`, plan `253-102`, ref pair r8.
- **Section digests:** canary `e272c040ecb6533f775340885bfac68a917f3da8866ab1312947aba32af54cc7`; docs_and_prs `083a4ce31dd0c036319a0cd3a54b95fbba0d2d71e2fb360b75c9f3ec247ba183`. Both differ from the R7 and 253-91 values.
- **Commits:**
  - candidate `7a1ba235a502c1f7b379a6109698fa59b65b6c8a` (not ce89eb73 or 1351b066);
  - fixture `ad015ec1005b7f19d8722ce3650aa1eb777b8f44` (not 12cc2ded), workflow blob `f4c9e2f23be6af58af3ae257579ca6d935251b56`;
  - docs base `1658789dddfac1da3d6796c93e5210f67b4bfa7b`; docs head `226db56537b3e95cdbf21acc4d04ca8d5479aca8`.
- **Refs:** `identity.candidate_ref` = `refs/heads/gsd/253-replan-r8-candidate`; `identity.fixture_ref` = `refs/heads/gsd/253-replan-r8-fixture`.
- **outward_actions:**
  - canary: publish_git_objects (max 24), create_ref r8-candidate, create_ref r8-fixture, workflow_dispatch on `gsd/253-replan-r8-fixture` for full-pass / docs-only / actual-failure / missing-seam / unexpected-skip / cancelled, cancel_run (cancelled), workflow_dispatch verifier;
  - docs_and_prs: publish_docs_objects (docs-base and docs-head refs), draft pr_create normal `gsd/253-replan-r8-candidate` → main, draft pr_create docs-only `gsd/253-replan-docs-head` → `gsd/253-replan-docs-base`.
- **Checks (all offline, and all part of the verbatim Task 3 `<verify>` block, which exited 0):**
  - `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R8` exits 0; `--check-manifest PUBLICATION-R8` exits 0.
  - Approval replay control: Jon's R7 approval passes `--check-approval` against FREEZE-R7 (positive control) and is refused against FREEZE-R8.
  - Neither r8 name appears in either committed HTTP ledger: 0 of 26 URLs. Positive control: the same query finds 2 URLs containing `253-replan-candidate`.
  - Dry-run on the committed freeze passed (see above).
  - Pinned records match: approval fb6c554c, allocation 72284acc, evidence e5be2150, ledger 48587280, receipt 3aa75308, FREEZE-R7 f608a445, PUBLICATION-R7 6813630f, workflow 3c31cb72, 253-97-SUMMARY de6b8ee0, R7 contract 8b077547.
  - v1 and r2–r7 reconcile `--check-only` exit 0. `--require-target-disposition` exits 0 and `--require-target-accepted` exits 3, so CIREL-01 stays partial.

## Verification

- Task 1 `<verify>` (verbatim, after `753fb81cf`): exit 0.
- Task 2 `<verify>` (verbatim, after `9c2db2329`): exit 0. Suite results:

  | Suite | Result |
  |---|---|
  | publication | 66 OK |
  | transport | 35 OK |
  | `ci-pr-proof.test.sh` | 39 OK |
  | verifier | 78 OK |
  | flow | 22 OK |
  | dryrun | 21 OK (2032 s) |
  | `ci-gate-canary.test.sh` | passed |
  | recovery | 5 OK |
  | r8 dry-run | passed |

- Task 3 `<verify>` (verbatim, after `22f96f8ea`): exit 0.
- Contract:
  - config.json sha256 `8e312f6ccd34…`, never staged;
  - state.json 70229 bytes;
  - tree clean apart from config.json;
  - `scripts/ci/__pycache__` deleted after every Python run;
  - zero GitHub requests, no push, no fetch;
  - no state, roadmap, requirements or config writer run.

## Deviations from Plan

- **[Rule 1, own test bug] RefPairTests ordering.** The test first built the explicit-legacy freeze while the r8 freeze file was still uncommitted, and `build_freeze` correctly refused the dirty tree. Fixed by committing the r8 freeze in the test before the second build. Done before the Task 1 commit.
- `--freeze-plan` takes three digits only without a leading zero (`253-[1-9][0-9]{2}`), so the existing refusal of `253-095` stays valid.

## Known Stubs

None.

## Threat Flags

None beyond the plan's register:
- **T-253-205 mitigated:** two pinned pairs, pair-consistent everywhere, create-only with get_ref 404 first, and no delete or force route. The seeded-legacy-ref tests and dry-runs show the R7 refs untouched.
- **T-253-206 mitigated:** the R7 approval is refused against FREEZE-R8, and the positive control passes.
- **T-253-SC:** no new dependency.

## Remaining gaps / handoff to 253-103

- 253-102 makes no GitHub request and no hosted proof. Full Phase 253 verification stays not_started; CIREL-01 is partial and CIREL-02 is open.
- The next live window must use FREEZE-R8 (sha256 `3c07f4e3…`, canary section `e272c040…`) and needs Jon's fresh canary-section approval bound to `e272c040…`; the R7 approval cannot carry over. The docs_and_prs approval must bind to `083a4ce3…`.
- PUBLICATION-R8 has about 14 KB of headroom under the 2 MiB tree-body cap (2083078 bytes). A further product-tree change before a new freeze could cross the cap.
- Deferred: the stale `--ref-pair` help text in `ci-gate-canary-dryrun.py` (R7 above).
- Optional for Jon: delete the two R7 refs on GitHub manually if wanted. No automation will.

## Self-Check: PASSED

- FOUND: 253-LOAD-RECOVERY-CANARY-PUBLICATION-R8.json, 253-LOAD-RECOVERY-CANARY-FREEZE-R8.json, all eight modified scripts/ci files
- FOUND on HEAD: 753fb81cf, 55c03eca1, 9c2db2329, ae42a9fb9, 22f96f8ea
