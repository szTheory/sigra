---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "119"
subsystem: ci-reliability / scoped refs (R10)
tags: [ci-reliability, load-recovery, scoped-refs, r10, code-review]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-116 run-name identity and canary ledger binding; 253-117 real-shape fakes and the skipped-producer closed set; 253-118 response-shape audit class; 253-111 r9 pair (the precedent); 253-113 r9 refs on GitHub (b9720d8e / aa701489)"
provides:
  - "r10 scoped ref pair (gsd/253-replan-r10-candidate / gsd/253-replan-r10-fixture), selected by the freeze, in the publisher, the transport PR-head allowlist, ci-pr-proof.sh and the verifier"
  - "--seed-r9-refs and seeded_r9_refs_changed in the dry-run harness (combinable with --seed-r8-refs)"
  - "Final W2 review of every R10 product change (253-116..119): no accepted finding needed a code change"
  - "Early R10 publication projection: ready-local-proposal, 17 of 22 requests, 4 trees, largest body 2,083,078 of 2,097,152 bytes"
affects: ["253-120", "253-121", "253-122", "253-123", "253-124"]
tech-stack:
  added: []
  patterns:
    - "A new scoped pair is additive: legacy stays the default, earlier pairs keep byte-identical derivations, and the 'unknown pair' probes move to a name that is never pinned (now r11)"
key-files:
  created: []
  modified:
    - scripts/ci/ci-git-publication.py
    - scripts/ci/ci-git-publication.test.py
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-pr-proof.sh
    - scripts/ci/ci-pr-proof.test.sh
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R10.json
key-decisions:
  - "PR_HEAD_REFS stays one source line (now 165 characters, within the file's existing 187-character maximum) so no transport audit anchor moves."
  - "The only audit drift was publication-1497 (line 1497 -> 1498) from the added REF_PAIRS line; its id, anchor and coverage are unchanged."
  - "The r9 seed SHAs are FREEZE-R9's candidate_helper_commit and fixture_workflow_commit; a test binds R9_REFS to the committed freeze so they cannot drift."
requirements-completed: []
estimate: {tokens: 46000, tasks: 3}
actuals:
  tokens: 9022
  tasks: 3
  commits: 3
commits: 3
plan_head_before: e26431f1fbb8079ba283cf16fbbcc829d6aa9238
plan_head_after: b26d207ee0cf289d550d6dbb8a1d5c9b7a09aa4e
duration: "about 1h 46m (17:47Z to 19:34Z), 73 minutes of it the final verify (58.4 minutes the dry-run suite)"
completed: 2026-10-16
status: complete
---

# Phase 253 Plan 119: r10 scoped ref pair, final R10 review and early projection Summary

**R10 now publishes under its own create-only names, gsd/253-replan-r10-candidate and gsd/253-replan-r10-fixture. The freeze selects the pair, and the publisher, transport, ci-pr-proof.sh and the verifier all follow it. Each earlier freeze still derives its recorded digests exactly: FREEZE-R9 f4210ba5.../5f8b394a..., R8, R7 and 253-91. An r10 publication creates only the two r10 refs; r8 and r9 refs seeded beside it are never read or moved. An r9 publication still stops on its seeded refs. The dry-run harness can seed both earlier pairs at their real GitHub SHAs, and both gate modes pass on r10 with neither pair moved. The final review of every R10 product change found nothing that needed a fix. The R10 publication projects at 17 of 22 requests, with every tree body under 2 MiB. There were zero GitHub requests.**

## Performance

- **Started:** 2026-10-16T17:47:43Z
- **Completed:** 2026-10-16T19:34:05Z
- **Tasks:** 3/3
- **Files:** 11 modified. In the diff from e26431f1f to b26d207ee: +478 / -40 lines, 36,090 added characters (about 9,022 tokens at chars/4).

## Task commits

1. **Task 1 (tracer):** `9219283af` feat(253-119): r10 scoped ref pair in the publisher and transport
2. **Task 2:** `df8fb8c30` feat(253-119): r10 normal PR head in the PR consumers
3. **Task 3:** `b26d207ee` feat(253-119): seed both earlier scoped ref pairs in the dry-run gates

## Task 1: r10 through the publisher and transport (tracer)

- **RED** (tests written first, run against the old code):
  - ci-git-publication.test.py: 85 ran, 5 failed (4 failures, 1 error). Failed: exactly_four_ref_pairs, an_r10_identity_moves_every_ref (error: "not one known ref pair (legacy, r8 or r9)"), build_freeze_accepts_r10_..., check_freeze_refuses_r10_mixed_..., r10_publication_creates_only_the_r10_refs_....
    - These passed already, as intended guards: freeze_r9_replays_its_recorded_section_digests_exactly, every_earlier_freeze_still_replays_with_the_fourth_pair_present, r9_freeze_publication_stops_on_seeded_r9_refs_at_another_sha_with_no_ref_changed.
  - ci-hosted-transport.test.py: 61 ran, 3 failed (2 failures, 1 error): the 253-102 membership test, the new r10 pr_create test and the new r10 create_ref test (which asserts five PR heads).
- **GREEN:**
  - REF_PAIRS gains `"r10": {"candidate": "gsd/253-replan-r10-candidate", "fixture": "gsd/253-replan-r10-fixture"}`. Legacy, r8 and r9 are byte-identical, legacy stays the default, and HELPER_PATHS is unchanged.
  - The `ref_pair_name` error and the `--ref-pair` help now say "legacy, r8, r9 or r10". `--ref-pair` refuses anything else with "choose one of ['legacy', 'r10', 'r8', 'r9']".
  - PR_HEAD_REFS gains the r10 candidate on its existing single line. PR_BASE_REFS and the create_ref pattern are unchanged; the pattern already accepts both r10 names.
- **Results after GREEN:** publication 85 OK, transport 61 OK, audit checker 30 OK after the one line refresh (publication-1497: 1497 -> 1498).
- **Tracer gate:** the verbatim Task 1 `<verify>` was re-run after the commit on the clean tree: rc 0. Expansion followed.

New publisher tests (R10RefPairTests):
- FREEZE-R9 replays f4210ba50fbc1a3bc94e45f8c7091b4083c45d80076a890596e1fc269c708b4a / 5f8b394a8ce66929839f4344a5617f0ff1c28a86028156b97ecbf47fb8ad9e0e, and its derived sections equal its recorded outward_actions.
- All four earlier freezes (R9, R8, R7, 253-91) replay their digests in one loop.
- An r10 identity moves every create_ref, dispatch ref, cancel head_branch and normal PR head to the r10 names, with no r8 or r9 name anywhere in the sections. Mixed identities are refused: r10/r9, r9/r10, r10/r8, half-pairs and r11.
- build_freeze accepts r10 and refuses r11, R10, "r10 ", "r9,r10" and r1. The CLI refusal names all four pairs, and `--help` says "r9 or r10".
- check_freeze refuses r10/r9, r9/r10, r10/r8, r10/legacy, the r9 pair under an r10 freeze, fixture-as-candidate and r11.
- **End to end over local HTTPS:** an r10 freeze, with all four r8 and r9 refs pre-seeded at the parent SHA, creates exactly the two r10 refs. The seeded refs are unchanged, and no ref path or create body names r8 or r9 (positive control: r10 ref paths are present). verify_publication refuses the receipt tampered to r10/r9, r9/r10, r10/r8 or r11.
- An r9 freeze with the r9 refs seeded at another SHA stops with "scoped ref gsd/253-replan-r9-candidate already points to a different commit". No POST /git/refs is made and no ref changes.

New transport tests:
- `test_253_119_pr_create_accepts_the_r10_candidate_and_refuses_the_r10_fixture_and_a_fifth_name` accepts the r10 candidate. It refuses as head the r10 fixture, r11, an r10 suffix, r1, the refs/heads/ form, the owner: form and R10. It refuses as base the r10 candidate, the r10 fixture and the r9 candidate. The three earlier candidates are still accepted.
- `test_253_119_create_ref_accepts_both_r10_names_under_the_unchanged_namespace_rule` checks both r10 names, the unchanged PR_BASE_REFS, exactly 5 PR heads, and that the create_ref pattern appears exactly once.

## Task 2: PR consumers

- **RED:**
  - ci-hosted-gate-verify.test.py: 118 ran, 2 failed: the membership test (its REF_PAIRS cross-check already saw r10 after Task 1) and the new r10 test.
  - ci-pr-proof.test.sh: 59 ran, 1 failed plus 2 setUpClass errors. The errors (R10RefPairTests, LivePolicyR10PRTests) were "the publication receipt's candidate_ref is not one of the known candidate refs". The failure was check_only refusing the r10 head.
- **GREEN:** `NORMAL_HEADS` (ci-pr-proof.sh) and `PR_NORMAL_HEADS` (verifier) each gain `gsd/253-replan-r10-candidate`. Each lives on its existing single line, and both comments now say "four". No audit anchor moved; the checker stays at 30 OK.
- **Results:** verifier 118 OK, ci-pr-proof.test.sh 64 OK (5 new), audit 30 OK. The verbatim Task 2 `<verify>` exited 0 after the commit.

New tests:
- **R10RefPairTests** (a World with `seed_r8_refs=True, seed_r9_refs=True`, plus an r9 World):
  - An r10 freeze yields normal head gsd/253-replan-r10-candidate. The normal family verifies (synthetic_pr_family_verified), and the four seeded r8/r9 refs are unchanged after both publication and the PR window. No journal path names r8 or r9 (positive control: /pulls requests are present). The verifier refuses r11, r10-fixture, r9, r8 and legacy as the head.
  - An r9 freeze still yields the r9 head.
  - --prepare refuses an r10 receipt with r11, the fixture as candidate, r10/r9, r9/r10 or r10/r8.
  - An r10 world given the r9 head, and an r9 world given the r10 head, are both refused before any request ("revision freeze candidate_ref"), for both families.
- **LivePolicyR10PRTests:** the 253-109 live-policy universe under r10, beside four seeded refs. The normal family verifies through the verifier CLI as synthetic, accepted_live false, origin actual-github. The seeded refs are unchanged and no r8 or r9 path was requested.
- **Verifier** `test_253_119_the_r10_candidate_is_a_normal_head_and_nothing_else_r10_is_accepted`: exactly 4 unique normal heads, docs refs unchanged. It refuses r11, r10-fixture, r10 on the docs base, r10 as the docs-only head, r10 as the docs-only base, the refs/heads/ form, a trailing space, R10 and r1.

## Task 3: seeding both earlier pairs, the review and the projection

- **RED:** `ci-gate-canary-dryrun.test.py SeededR9RefsTests`: 3 ran, 3 failed (2 failures, 1 error). The causes were no `R9_REFS` attribute, and "unrecognized arguments: --seed-r9-refs" with no JSON summary.
- **GREEN:**
  - `R9_REFS = {gsd/253-replan-r9-candidate: b9720d8e00e69e11c965ed7cf5029e3a0008783a, gsd/253-replan-r9-fixture: aa7014893b716f279b60ceb545b8aee5ca15b10c}`.
  - `seeded_scoped_refs(args)` merges R8_REFS and/or R9_REFS into the fake's seed.
  - `--seed-r9-refs`, and `seeded_r9_refs_changed`, which is set only when the flag is given (as for r8).
  - `--seed-r8-refs`, `seeded_r8_refs_changed` and R8_REFS are unchanged.
  - SeededR9RefsTests and RefPairHelpTests: 4 OK.
- New tests:
  - R9_REFS equals FREEZE-R9's candidate and fixture commits, and R8_REFS is unchanged.
  - An r10 quick gate with both pairs seeded passes in both modes: response_shape ok, two create_ref requests, neither pair moved.
  - The r9 positive control stops on the first get_ref and moves nothing. seeded_r8_refs_changed is absent there, because r8 was not seeded.

### Gate summaries (full sequence, synthetic r10 freeze, both pairs seeded)

| Field | Hermetic `--ref-pair r10 --seed-r8-refs --seed-r9-refs` | `--live-policy` (same flags) |
|---|---|---|
| status / synthetic | passed / true | passed / true |
| scenarios | all six | all six |
| verifier | passed | passed |
| requests_total | 93 | 93 |
| create_ref | 2 | 2 |
| seeded_r8_refs_changed / seeded_r9_refs_changed | false / false | false / false |
| verifier_job_model / result | scenario-set / scenario_set_complete | verify_sources / sources_verified (35 executed jobs) |
| matrix payload chars (limit 64511) | 15652 | 15732 |
| response_shape | ok; 46 runs, 45 jobs, 177 steps, 33 artifacts; verifier run checked; 0 mismatches | the same |
| publication origin / fixture ref state | hermetic / hermetic-unverified | actual-github / verified |
| shim refusals / violations | none / none | none / none |

The requests by category were identical in both modes: publication 19, preflight 5, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6, cancellation 1.

### r9 positive control (`--ref-pair r9 --seed-r9-refs --stop-after full-pass`)

```
status failed; evidence_status halted; invocations [publish-only]
stop: ci-git-publication: PublicationError: scoped ref gsd/253-replan-r9-candidate already points to a different commit
seeded_r9_refs_changed false; requests_total 12 (git_get_commit 3, git_create_tree 4, git_get_blob 2, git_create_commit 2, get_ref 1); no create_ref
```

### Final review (W2) of every R10 product change, 253-116..119

The review covered the diff from cefbe6cee (the R10 plan commit) to HEAD in ci-hosted-gate-verify.py, ci-gate-canary-dryrun.py, ci-git-publication.py, ci-hosted-transport.py, ci-pr-proof.sh and their tests. ci-gate-canary.sh and ci-live-policy-shim.py have no R10 diff.

| # | Check | Finding | Disposition |
|---|---|---|---|
| W1 | **Identity rule** (`require_run_title`) | display_title must equal `expected_run_title(scenario, run)`, which is the run-name for the run's own scenario, id and run_attempt, with no normalization. name must be the bare fixture name or that exact title, and a non-bare name must equal display_title. verify_scenario independently binds run id and attempt to the receipt. The separate verifier is held to the "verifier" title. The rule's last clause is redundant given the first two (it is implied), which is harmless. | Conforms. No change. |
| W2 | **Binding coverage** (`verify_canary_bindings`) | There are three call sites: replan_result for a single scenario, replan_result for sources/matrix (matrix adds the verifier receipt), and completion's verify_canary_matrix. It is not called from legacy mode or from the hosted verifier job, which runs `verify_sources` on the decoded compact matrix (fixture YAML :297-301). The compact matrix carries no ledger. The binding requires dispatch 204, while the driver still accepts 202/204. | Conforms. The 202/204 asymmetry is the known open item and was not loosened. |
| W3 | **Skipped-producer closed set** | There are exactly four forms: the five expanded names, `producers`, `producer (${{ matrix.seam }})` and `producer ()`. The following check still requires every non-verifier job to conclude skipped, each with the run's id and attempt. | Conforms. No change. |
| W4 | **Live origin and redirect hop rule** | ci-hosted-transport.py's whole R10 diff is the PR_HEAD_REFS line. The verifier diff touches no host-rule code (verify_live_transaction_host, download_hosts). The create_ref pattern and PR_BASE_REFS are unchanged and test-pinned. | Nothing widened. No change. |
| W5 | **Shim isolation** | `git grep` for `ci-live-policy-shim\|live_policy_shim\|SIGRA_LIVE_POLICY_SHIM` outside .planning finds the shim, ci-gate-canary-dryrun.py, ci-hosted-transport.test.py and ci-pr-proof.test.sh (positive control). Excluding the shim, the harness and test files leaves nothing (`test -z` true). | Product code never imports the shim. No change. |
| W6 | **Real-shape reference** | `load_reference` reads the committed R9 ledger at run time (seq 25/27/28/29) and records its sha256 in `response_shape.reference`. build_run, build_job and build_artifact order their keys like the real objects and deep-copy only the real actor and repository objects. No hand-written copy of a real body exists. VERIFIER_STEPS and SKIPPED_PRODUCER_NAME are modeled from the fixture, because no real sample exists; they are justified rows in the 253-118 audit. | Conforms. No change. |
| W7 | **r10 pair (this plan)** | REF_PAIRS, PR_HEAD_REFS, NORMAL_HEADS and PR_NORMAL_HEADS each have exactly four candidates, cross-checked by the verifier's REF_PAIRS test. HELPER_PATHS is unchanged. Earlier digests replay. | Conforms. |

No finding needed a fix, so no file outside the declared set was touched and the plan did not halt.

### Early R10 publication projection (no commit; output deleted)

`--prepare --candidate-source b26d207ee0cf289d550d6dbb8a1d5c9b7a09aa4e --server-parent 84ebcea60024c9e8caee405d55cad1c76b0e858a`:

| Field | R10 (this plan) | R9 (PUBLICATION-R9) |
|---|---|---|
| status | ready-local-proposal | ready-local-proposal |
| projected_total_requests | **17** (limit 22) | 17 |
| parent preflight / fixed non-tree / binary blobs | 1 / 12 / 0 | 1 / 12 / 0 |
| tree_request_count | 4 | 4 |
| tree body bytes | 2,047,127; **2,083,078**; 1,034,007; 17,686 | 1,876,071; 2,083,078; 1,034,007; 17,686 |
| largest body / cap | 2,083,078 / 2,097,152 (14,074 headroom) | the same |

**Budget analysis.**
- The packer splits trees greedily at the 2,097,152-byte cap, so growth adds a tree request rather than causing a refusal. The only body-size refusal is a single entry larger than the cap.
- The R10 product delta grew the first tree by 171,056 bytes, to 50,025 bytes under the cap. Every other tree is byte-identical to R9.
- The binding limit is 22 projected requests: the 24-request publication category minus the full-pass and remaining fixture ref reads. That allows up to 9 tree requests.
- R10 uses 4 trees and 17 requests, 5 under the limit. A future delta that overflows the first tree adds one request (18), still within the limit.
- The fallback (halt with options for Jon) did not fire.

### Task 3 `<verify>` (verbatim, after b26d207ee): rc 0, under `caffeinate -i -s`, 18:20:54Z to 19:33:35Z

| Check | Result |
|---|---|
| projection jq (ready, <= 22, every body <= 2097152) | true |
| hermetic r10 gate jq | true |
| live-policy r10 gate jq | true |
| r9 positive control jq | true |
| ci-hermetic-live-audit.test.py | 30 OK |
| ci-git-publication.test.py | 85 OK (was 78) |
| ci-hosted-transport.test.py | 61 OK (was 59) |
| ci-pr-proof.test.sh | 64 OK (was 59) |
| ci-hosted-gate-verify.test.py | 118 OK (was 117) |
| ci-gate-canary-flow.test.py | 22 OK |
| ci-gate-canary-dryrun.test.py | 54 OK in 3501.8 s (was 51) |
| ci-gate-canary.test.sh | passed |
| ci-gate-canary-recovery.test.py | 5 OK |
| `--require-target-disposition` / `--require-target-accepted` | exit 0 / exit 3 (unchanged) |
| v1 and r2-r9 reconcile `--check-only` | all exit 0 |
| PRESERVATION-R10 checklist | `shasum -c` rc 0 |
| config.json sha256, state.json size, clean tree | 8e312f6c..., 70229 bytes, only ` M .planning/config.json` |

## Recorded edits to earlier tests

Every place an earlier test used r10 as the never-pinned "unknown" name now uses r11. r10 joins the accepted sets.
- **ci-git-publication.test.py:**
  - `UNKNOWN_PAIR` is now the r11 pair (its comment was updated).
  - `test_exactly_three_ref_pairs_exist_and_legacy_is_the_default` is now `test_exactly_four_...`. r10 was added to the expected REF_PAIRS and the accepted names, and the mixed cases gained r10/r9, r9/r10, r10/r8, r8/r10, r10/legacy and the reversed r10 pair.
  - The `build_freeze` bad-pair probe list: "r10" became "r11".
  - `test_build_freeze_accepts_r9_and_the_cli_refuses_a_fourth_pair`: the r10 probe (ref_pair, output name, CLI argument) became r11. The test name is kept.
- **ci-hosted-transport.test.py:**
  - `test_253_102_pr_heads_are_exactly_the_two_candidates_and_the_docs_head` adds the r10 name to the expected set, and its reject list swaps r10-candidate for r11-candidate. The test name is kept.
  - `test_253_111_pr_create_...` swaps its r10-candidate reject probe for r11-candidate.
- **ci-pr-proof.test.sh:**
  - World and LiveWorld gain a `seed_r9_refs` option (default False; existing worlds are unchanged).
  - The RefPairTests verifier-head probe and --prepare "fourth candidate" probe, and the R9RefPairTests verifier-head probe and --prepare "fourth candidate" probe, all moved from r10 to r11.
  - `test_check_only_accepts_only_the_three_candidate_names_as_the_normal_head` is now `..._four_...`: it accepts r10, its r10 refusal became r11, and it also refuses r10-fixture.
- **ci-hosted-gate-verify.test.py:** `test_253_102_normal_head_is_one_of_the_three_...` is now `..._four_...`. r10 was added to the expected set and the accepted heads, and its r10 refusal became r11.
- **ci-gate-canary-dryrun.test.py:** no existing test was edited.

## Deviations from Plan

None that changed behaviour or scope. The process notes:
1. **Test renames.** Four earlier membership tests were renamed from "three" to "four" so their names stay true, following the 253-111 precedent. Their bodies changed only in the membership sets and the r10 -> r11 probes listed above.
2. **Verbatim verifies ran from bash script files in the scratchpad.** zsh does not word-split. The Task 3 script copied the four outputs to the scratchpad before its own `rm` so they could be recorded here; the chain is otherwise unchanged. It ran under `bash -x` to locate any failure; none occurred.
3. **Intermediate red between commits.** After the Task 1 commit (9219283af), the verifier's existing `PR_NORMAL_HEADS == REF_PAIRS candidates` cross-check was red until Task 2 (df8fb8c30). That is expected: the plan splits the producer and consumer sides. Task 1's verify does not run that suite.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. config.json and state.json are untouched (state.json 70229 bytes, sha256 prefix e45278c2cee0). WINDOWS.md was not appended: there are no stubs, skipped tests or unrun verifies.

## Follow-ups and remaining gaps

- **The r8 refs (7a1ba235 / ad015ec1) and the r9 refs (b9720d8e / aa701489) remain on GitHub.** Automation never reads them for reuse, moves them or deletes them. They are left for Jon's optional manual cleanup.
- **253-120** cuts FREEZE-R10 with `--ref-pair r10` from a clean reviewed source. FREEZE-R9 still does not validate the tree (expected). Pre-clock gates: `--revision-freeze FREEZE-R10 --seed-r8-refs --seed-r9-refs`, hermetic and `--live-policy`.
- The driver accepts a 202 or 204 dispatch status, while the binding requires 204. This is still open and was not loosened.
- The 9 justified response-shape rows from 253-118 remain the residual risks for 253-122 and 253-123.
- CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Known Stubs

None.

## Threat Flags

None. T-253-249 is mitigated: there are exactly four code-pinned pairs, chosen by the freeze and consistent everywhere, and refs are create-only (get_ref must 404 first). Seeded r8 and r9 refs are proven untouched in the publisher, the PR consumers and both gate modes, and the FREEZE-R9, R8, R7 and 253-91 digests replay. T-253-250 is mitigated: 17 of 22 requests, largest body 2,083,078 bytes. T-253-SC: no new dependency and no workflow change.

## Self-Check: PASSED

- All 11 modified files exist, and the plan's commits are ancestors of HEAD: 9219283af, df8fb8c30, b26d207ee.
- `git rev-list --count e26431f1f..HEAD` = 3, before this SUMMARY's commit.
- Each RED preceded its GREEN.
- No `scripts/ci/__pycache__` remains, and `git status` showed only ` M .planning/config.json` after the regression.
