---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "111"
subsystem: ci-reliability / scoped refs and R9 freeze
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, scoped-refs, canary-freeze, r9]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-107..110 live transport policy, live-policy canary and PR gates, hermetic-vs-live audit checker"
provides:
  - "r9 scoped ref pair (gsd/253-replan-r9-candidate / gsd/253-replan-r9-fixture), selected by the freeze, in the publisher, the transport PR-head allowlist, ci-pr-proof.sh and the verifier"
  - "253-LOAD-RECOVERY-CANARY-PUBLICATION-R9.json: packed graph from the reviewed source 283b2562 (17 projected requests, largest tree body 2,083,078 bytes)"
  - "253-LOAD-RECOVERY-CANARY-FREEZE-R9.json: plan 253-111, ref pair r9, new section digests, both offline gate modes pass on it"
affects: ["253-112", "253-113", "253-114"]
tech-stack:
  added: []
  patterns:
    - "Probe for an unknown ref pair with a name that can never be pinned (r10) instead of the next planned name"
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-R9.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-FREEZE-R9.json
  modified:
    - scripts/ci/ci-git-publication.py
    - scripts/ci/ci-git-publication.test.py
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-pr-proof.sh
    - scripts/ci/ci-pr-proof.test.sh
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
key-decisions:
  - "R9 publishes under new create-only names chosen by the freeze. The r8 refs that 253-104 left on GitHub are never read for reuse, moved or deleted."
  - "CANARY_BRANCH was removed. A repo-wide git grep found it only at its own definition (positive control) and in planning prose."
  - "The verifier's weaker PR-transport host rule (253-110 observation) was not changed in R9. It is pre-existing, not a widening, and the transport refuses that shape before the socket. Fixing it adds matched audit lines whose rows live in an undeclared file. Deferred to a replan."
actuals:
  tokens: 11526
  tasks: 3
  commits: 5
commits: 5
plan_head_before: 313676055e81a822f690f23a4f1ac0cc31528cae
plan_head_after: 3185c3fa9c0097d4ae16e16879d3bc0025a8015a
duration: "about 7h 17m wall clock (02:55Z to 10:12Z). Most of it was two runs of the 42-test dry-run suite (44 and 34 min), slowed further by Mac idle sleep until caffeinate was started."
completed: 2026-10-16
---

# Phase 253 Plan 111: R9 scoped ref pair and the R9 freeze Summary

**The r9 pair (gsd/253-replan-r9-candidate / -fixture) is now the third and last code-pinned pair. The publisher, the transport, ci-pr-proof.sh and the verifier all take it from the freeze identity, and FREEZE-R8 still replays e272c040.../083a4ce3... exactly. After the final review of every R9 product change, PUBLICATION-R9 and FREEZE-R9 were derived from the clean reviewed source 283b2562: 17 of 22 requests, largest tree body 2,083,078 of 2,097,152 bytes. Both offline gate modes pass on the committed freeze with the r8 refs seeded and unchanged, and Jon's R8 approval is refused against it. There were zero GitHub requests.**

## Performance

- **Started:** 2026-10-16T02:55:22Z
- **Completed:** 2026-10-16T10:12:39Z
- **Tasks:** 3/3
- **Files:** 2 created, 8 modified. In the diff from 313676055 to 3185c3fa9: +868 / -35 lines.

## Task 1: r9 through the publisher and transport (tracer)

- **RED** (tests written first, run against the old code):
  - ci-git-publication.test.py: 76 ran, 6 failed (5 failures, 1 error).
    - Failed: exactly_three_ref_pairs, an_r9_identity_moves_every_ref, build_freeze_accepts_r9, check_freeze_refuses_r9_mixed, r9_publication_creates_only_the_r9_refs, unused_canary_branch_alias_is_gone.
    - Passed already, kept as guards: freeze_r8_replays_its_recorded_section_digests_exactly and r8_freeze_publication_stops_on_seeded_r8_refs.
  - ci-hosted-transport.test.py: 59 ran, 2 failed (the PR-head membership test and the new r9 pr_create test). The new create_ref r9-names test passed already, because the regex is unchanged.
- **GREEN:**
  - REF_PAIRS gains `"r9": {"candidate": "gsd/253-replan-r9-candidate", "fixture": "gsd/253-replan-r9-fixture"}`. Legacy and r8 are byte-identical, legacy stays the default, and HELPER_PATHS is unchanged.
  - `PR_HEAD_REFS` gains the r9 candidate. PR_BASE_REFS and the create_ref regex are unchanged.
  - The `ref_pair_name` error and the `--ref-pair` help now say "legacy, r8 or r9".
- **Results after GREEN:** publication 76 OK, transport 59 OK, audit checker 14 OK.
  - Audit lines did not move: one REF_PAIRS line was added and the CANARY_BRANCH line was removed, so the net shift is zero. The audit record needed no refresh.
- **Tracer gate:** the verbatim Task 1 `<verify>` first failed on a transport flake (see Deviations, item 1). After the flake fix (28ac9636a) it re-ran end to end and exited 0.
- **CANARY_BRANCH:** `git grep -n CANARY_BRANCH` found the definition at ci-git-publication.py:1163 (positive control) and otherwise only planning prose (253-102-PLAN, 253-102-SUMMARY, 253-108-PLAN, 253-111-PLAN). It was removed, and a test now asserts it is absent.

## Task 2: PR consumers, both gates on r9, and the final R9 review

- **RED:**
  - ci-hosted-gate-verify.test.py: 94 ran, 1 failed (the normal-head membership test).
  - ci-pr-proof.test.sh: 54 ran, 1 failed, plus 2 setUpClass errors. The errors blocked the 4 R9RefPairTests and the 1 LivePolicyR9PRTests test with "the publication receipt's candidate_ref is not one of the two known candidate refs". The failure was check_only accepting r9.
- **GREEN:**
  - `NORMAL_HEADS` (ci-pr-proof.sh) and `PR_NORMAL_HEADS` (verifier) each gain `gsd/253-replan-r9-candidate`.
  - The stale "two known candidate" wording in one ci-pr-proof.sh message and one docstring now reads "known".
- **New tests:**
  - an r9 world with seeded r8 refs: the normal family verifies, the r8 refs are unchanged, the PR window never touches an r8 path, and r10, r9-fixture, r8 and legacy heads are refused by the verifier;
  - an r8 freeze still yields the r8 head;
  - --prepare refuses an r9 receipt naming r10, the fixture as candidate, or a mixed r9/r8 pair;
  - an r9/r8 head disagreeing with the revision freeze is refused before any request;
  - the 253-109 live-policy universe under r9 (LivePolicyR9PRTests) verifies as synthetic with the r9 head and r8 refs untouched;
  - the verifier's dry-run marker never matches a real window id (with a positive control).
- **Gate commands** (both run on a synthetic r9 freeze):
  - `ci-gate-canary-dryrun.py --ref-pair r9 --seed-r8-refs`: passed, synthetic, seeded_r8_refs_changed false.
  - `--live-policy --ref-pair r9 --seed-r8-refs`: passed, mode live-policy, synthetic, seeded_r8_refs_changed false.
  - Positive control that the pair selection is real: `--ref-pair r8 --seed-r8-refs` FAILS with "scoped ref gsd/253-replan-r8-candidate already points to a different commit" and seeded_r8_refs_changed false.
- **Task 2 `<verify>` (verbatim, after 283b25626): exit 0.**

  | Suite | Result |
  |---|---|
  | ci-git-publication.test.py | 76 OK |
  | ci-hosted-transport.test.py | 59 OK |
  | ci-pr-proof.test.sh | 59 OK |
  | ci-hosted-gate-verify.test.py | 95 OK |
  | ci-gate-canary-flow.test.py | 22 OK |
  | ci-gate-canary-dryrun.test.py | 42 OK (2039 s) |
  | ci-gate-canary.test.sh | passed |
  | ci-gate-canary-recovery.test.py | 5 OK |
  | ci-hermetic-live-audit.test.py | 14 OK |

### Review findings (W2: every R9 product change, 253-107..111)

The review covered the diff from ad1964168 to HEAD in ci-hosted-transport.py, ci-live-policy-shim.py, ci-gate-canary-dryrun.py, ci-gate-canary.sh (unchanged in R9), ci-git-publication.py, ci-pr-proof.sh, ci-hosted-gate-verify.py, ci-hermetic-live-audit.test.py and their tests.

| # | Finding | Disposition |
|---|---|---|
| R1 | **Live origin rule (transport).** Hop 0, or no destination, must be api.github.com:443. Hop >= 1 needs all of: a download route, an int hop_ordinal (not a bool) in 1..max_hops, and `_trusted_download_host` (port 443, host in download_hosts and matching the trusted pattern). `download_hosts` is itself validated against the policy. api.github.com can never pass at hop >= 1. `_connect` is always HTTPS. Authorization is attached only when host == api.github.com, so redirect hops carry none. | Conforms. Nothing widened. No change. |
| R2 | **Verifier live canary host rule** (`verify_live_transaction_host`). It requires https:443 with no credentials and a host that agrees with the URL. Hop 0 must be api.github.com. Any other hop must match the trusted pattern, so api.github.com is refused there. | Matches the transport rule at the pattern level. Membership in download_hosts cannot be checked from canary evidence (recorded by 253-110). No change. |
| R3 | **verify_pr_transport is weaker** (253-110 observation): it accepts api.github.com or any frozen download host at any hop. | Pre-existing, not an R9 widening. The transport refuses that shape before the socket, so a real ledger cannot contain it. Mirroring the canary rule adds matched audit lines whose rows live in the audit record, which Task 2 does not declare. **Not accepted for R9; deferred to a replan** (see handoff). |
| R4 | **Shim isolation.** `git grep` for `ci-live-policy-shim`, `live_policy_shim` or `SIGRA_LIVE_POLICY_SHIM` outside .planning finds exactly the shim, ci-gate-canary-dryrun.py, ci-pr-proof.test.sh and ci-hosted-transport.test.py (positive control). Excluding the shim, the two harnesses and test files leaves nothing (rc 1). | Product code never imports the shim. No change. |
| R5 | **Dry-run window marker** `253-dryrun-`. The committed real windows are 253-92/97/104-canary-window-1. Plan-named windows put a digit after `253-`; the marker puts a letter there. Nothing forces the real-window form, but a collision fails closed: evidence on a marked window is labelled synthetic and never accepted. | Cannot match a plan-named window. Test added (`test_253_111_the_dryrun_window_marker_never_matches_a_real_window_id`, with a positive control). |
| R6 | Test-only flake: `small_zip()` stamped the wall clock. | Fixed in 28ac9636a (Deviations, item 1). |
| R7 | Stale "two known candidate" wording in ci-pr-proof.sh. | Fixed in the Task 2 commit. |

## Task 3: PUBLICATION-R9 and FREEZE-R9

- **Frozen source commit:** `283b256265e30b0b452bb1478fa3db51d37edeb6` (reviewed and clean; repo tree a74e4517). `--validate-frozen-source` reports product tree `fda6ba927a619b613975bb81d4d5ff3a35074f55`, with only planning movement up to HEAD 3185c3fa9.
- **Server parent:** `84ebcea60024c9e8caee405d55cad1c76b0e858a`, tree `e9d63071f0ab4ac8edba8a60a2503cc882cb5556`, re-derived offline.
  - Row 1 of the committed R8 ledger is a live `GET git_get_commit` of this SHA on api.github.com: status 200, state complete.
  - **Discrepancy:** local `refs/remotes/origin/main` is `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97`, not 84ebcea6. 84ebcea6 is its ancestor. As the plan directs, the live-proven 84ebcea6 was used.
- **PUBLICATION-R9:**
  - sha256 `1f8209932cabea9ddcebb690ec2fe198664af9e84eacc8e8a0f9367cc9093228`, status ready-local-proposal; `--check-manifest` is valid.
  - Projection: **17 of 22 requests** (1 parent preflight, 4 trees, 12 fixed non-tree, 0 binary blobs). Tree bodies: 1,876,071; **2,083,078 (largest; cap 2,097,152, 14,074 bytes headroom)**; 1,034,007; 17,686.
- **FREEZE-R9:** sha256 `3ddde073506474ab74092a093f85e8a6259372faa24fd17ec1d46db4ec9d432d`, plan `253-111`, ref pair r9.
  - bound publication_manifest: 1f820993...;
  - bound fixture_workflow: 3c31cb72... (unchanged).
- **Section digests:** canary `f4210ba50fbc1a3bc94e45f8c7091b4083c45d80076a890596e1fc269c708b4a`; docs_and_prs `5f8b394a8ce66929839f4344a5617f0ff1c28a86028156b97ecbf47fb8ad9e0e`. Both differ from the R8, R7 and 253-91 values.
- **Commits:**
  - candidate `b9720d8e00e69e11c965ed7cf5029e3a0008783a`, tree 9fb0fcf2... (not 7a1ba235, ce89eb73 or 1351b066);
  - fixture `aa7014893b716f279b60ceb545b8aee5ca15b10c`, tree ef2956c0..., workflow blob f4c9e2f2... (not ad015ec1 or 12cc2ded);
  - docs base `186d2a7ba85df7b4250fb053360469c4b36fdfd4`; docs head `5e8981ed55a559632d3dc78a3248829922648346`.
- **Refs:** `identity.candidate_ref` is `refs/heads/gsd/253-replan-r9-candidate`; `identity.fixture_ref` is `refs/heads/gsd/253-replan-r9-fixture`.
- **outward_actions:**
  - **canary:**
    - publish_git_objects (max 24);
    - create_ref r9-candidate and create_ref r9-fixture;
    - workflow_dispatch on `gsd/253-replan-r9-fixture` for full-pass, docs-only, actual-failure, missing-seam, unexpected-skip and cancelled;
    - cancel_run (cancelled);
    - workflow_dispatch verifier.
  - **docs_and_prs:**
    - publish_docs_objects (docs-base 186d2a7b, docs-head 5e8981ed; max 14);
    - draft pr_create normal `gsd/253-replan-r9-candidate` → main;
    - draft pr_create docs-only `gsd/253-replan-docs-head` → `gsd/253-replan-docs-base`.
- **Checks.** All are offline and part of the verbatim Task 3 `<verify>`, which exited 0.
  - `ci-gate-canary.sh --check-only --revision-freeze FREEZE-R9` exits 0, and `--check-manifest PUBLICATION-R9` reports valid.
  - **Approval replay control:** Jon's R8 approval against FREEZE-R8, section canary, exits 0 (positive control). Against FREEZE-R9 it exits 1 with "approval record digest is not the canary section digest".
  - **No r9 name in any committed ledger:** 0 of 56 URLs across 253-92, R7 and R8. Positive control: the same query finds 6 URLs containing `253-replan-r8` in the R8 ledger.
  - **Pre-clock gate rehearsal on the committed freeze, hermetic** (`--revision-freeze FREEZE-R9 --seed-r8-refs`):
    - status passed, synthetic, freeze_plan 253-111, seeded_r8_refs_changed false, verifier passed;
    - 93 requests;
    - scenarios full-pass, docs-only, actual-failure, missing-seam, unexpected-skip, cancelled;
    - origin hermetic.
  - **Same, live-policy** (`--live-policy`):
    - status passed, mode live-policy, synthetic, seeded_r8_refs_changed false, verifier passed;
    - 93 requests;
    - publication published-actual-github on window `253-dryrun-live-policy-91900`, with verifier_dryrun_window true;
    - Authorization went only to api.github.com (85 with, 0 without, 0 to blob);
    - 8 live hops, each hop 1 to productionresultssa17.blob.core.windows.net;
    - no shim refusals, no violations.
  - The audit checker passes (14 OK) and `shasum -c PRESERVATION-R9.sha256` passes.
  - v1 and r2–r8 reconcile `--check-only` exit 0. `--require-target-disposition` exits 0 and `--require-target-accepted` exits 3, so CIREL-01 stays partial.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, test-only] small_zip() flake in ci-hosted-transport.test.py**
- **Found during:** the Task 1 tracer `<verify>`, where test_run_logs_follow_to_pipelines_host_without_authorization failed once.
- **Issue:** `writestr(name)` stamps the local time. Two calls on either side of a 2-second DOS-time boundary give different bytes.
- **Fix:** a fixed `ZipInfo(date_time=(2026,1,1,0,0,0))`.
  - Proof: with the new helper, two calls 2.1 s apart are equal.
  - Positive control: the old helper's two calls are unequal.
- **Files modified:** scripts/ci/ci-hosted-transport.test.py (a declared file).
- **Commit:** 28ac9636a, an extra test(253-111) commit.

**2. [Rule 3 - Blocking] `--candidate-source HEAD` is refused**
- **Issue:** --prepare requires a full lowercase SHA.
- **Fix:** passed `git rev-parse HEAD` = 283b2562..., the same commit.

### Recorded edits to earlier (253-102) tests
Every place an earlier test used r9 as the "unknown third name" now uses r10. r9 joins the accepted sets.
- **ci-git-publication.test.py:**
  - `test_exactly_two_ref_pairs...` is now `test_exactly_three_ref_pairs...`, with r9 added and more mixed combinations;
  - the r10 probe in the r8 outward-action, build-freeze bad-pair, check-freeze and r8 receipt-tamper tests.
- **ci-hosted-transport.test.py:** `test_253_102_pr_heads_are_exactly_the_two_candidates_and_the_docs_head` only adds the r9 name to the expected set, and its reject list swaps r9-candidate for r10-candidate. The test name is kept.
- **ci-pr-proof.test.sh:**
  - verifier-head and receipt probes now use r10;
  - `test_check_only_accepts_only_the_two_...` is now `..._three_...`, which accepts r9 and also refuses r9-fixture;
  - World and LiveWorld gain a `seed_r8_refs` option.
- **ci-hosted-gate-verify.test.py:** `test_253_102_normal_head_is_one_of_the_two_...` is now `..._three_...`, with r9 accepted and r10, r9-fixture, r9-on-docs-base and r9-as-docs-only refused.

### Process
- The verbatim `<verify>` blocks ran from bash script files in the session scratchpad, because zsh does not word-split, so an inline loop failed with rc 127. The commands are unchanged.
- The Task 3 script copied the two dry-run summaries to the scratchpad before the block's own `rm`, so they could be recorded here.
- `caffeinate -i -s` was started after Mac idle sleep stretched the first Task 2 verify. No result was affected, and every run passed.

### Not done (out of scope, recorded)
- R3 (verify_pr_transport host rule): deferred, see the handoff notes.
- WINDOWS.md: nothing appended, to keep the tree limited to declared files. There are no stubs or skipped tests.

## Known Stubs

None.

## Threat Flags

None. T-253-229 is mitigated: three pinned pairs, create-only, with seeded-r8 tests in the publisher, the PR consumers and both gate modes. T-253-230 is mitigated: the R8 approval is refused against FREEZE-R9, with a passing positive control. T-253-231 is mitigated: 17 of 22 requests, largest body 2,083,078 bytes. T-253-SC: no new dependency and no workflow change.

## Follow-ups

- The r8 refs (`gsd/253-replan-r8-candidate` → 7a1ba235..., `gsd/253-replan-r8-fixture` → ad015ec1...) and the R8/253-92 git objects remain on GitHub for Jon's optional manual cleanup. The R7 refs were already deleted by Jon. Automation never touches them.

## Notes for 253-112 and 253-113

- **What to approve:** Jon's fresh approval must name FREEZE-R9 sha256 3ddde073... and section digests canary f4210ba5... and docs_and_prs 5f8b394a.... The R8 approval is provably refused.
- **Pre-clock gate:** run `ci-gate-canary-dryrun.py --revision-freeze FREEZE-R9 --seed-r8-refs`, the same with `--live-policy`, and `ci-hermetic-live-audit.test.py`. All three passed at 3185c3fa9.
- **Publication:** 17 requests against the canary publication limit of 24 (the plan budget is 22), with 14,074 bytes of headroom under the 2 MiB tree body cap. Any product byte change after 283b2562 invalidates FREEZE-R9 (validate-frozen-source checks that only planning files moved).
- **Refs created on GitHub in 253-113:** exactly refs/heads/gsd/253-replan-r9-candidate → b9720d8e and refs/heads/gsd/253-replan-r9-fixture → aa701489. get_ref must 404 first.
- **origin/main:** local origin/main is 4ff6c50e, not 84ebcea6. The freeze uses the live-proven 84ebcea6. If 253-113's parent preflight finds the server parent no longer reachable, that is a stop, not a re-freeze inside 253-113.
- **Deferred R3:** if the verifier should be independent of the transport for PR evidence, mirror `verify_live_transaction_host` in verify_pr_transport in a replan that also declares the audit record. Today the transport refuses the weaker shape.
- **Runtime:** the dry-run suite takes 34–44 minutes. Keep the machine awake (caffeinate) during long gates.
- **Verification status:** full Phase 253 verification remains not_started.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is 8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d.
- state.json is 70229 bytes with sha256 prefix e45278c2cee0.
- STATE.md, ROADMAP.md, REQUIREMENTS.md, state.json and HANDOFF.json were not touched, and no gsd-tools state, roadmap, config or requirements writers were run.
- No pinned PLAN, SUMMARY, R7/R8 record or PRESERVATION-R9 file changed (`shasum -c` rc 0). The audit record is unchanged.
- scripts/ci/__pycache__ was removed after every python run.
- Zero GitHub requests, no push, no fetch, no gh or curl.

## Self-Check: PASSED

- Both created files exist, and all five task commits (d4c57ebd9, 28ac9636a, 283b25626, 8e0393fd0, 3185c3fa9) are ancestors of HEAD. No commit deleted a file.
- The commit count measured from the plan ledger is 5 (313676055..3185c3fa9).
