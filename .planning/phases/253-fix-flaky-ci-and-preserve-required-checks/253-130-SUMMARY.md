---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "130"
subsystem: ci-reliability / scoped refs (R11)
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, scoped-refs, r11, code-review, publication-budget]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-125 scoped results-receiver admission; 253-126/127 read-only probe driver and committed probe records; 253-128 probe-driven fakes; 253-129 observed-route audit rule; 253-119 r10 pair (the precedent); 253-122 r10 refs on GitHub (d16617f7 / 06bb7dfb)"
provides:
  - "r11 scoped ref pair (gsd/253-replan-r11-candidate / gsd/253-replan-r11-fixture), selected by the freeze, in the publisher, the transport PR-head allowlist, ci-pr-proof.sh and the verifier"
  - "--seed-r10-refs and seeded_r10_refs_changed in the dry-run harness (combinable with --seed-r8-refs and --seed-r9-refs)"
  - "Final W2 review of every R11 product change (253-125..130): no finding needed a code change"
  - "Early R11 publication projection: ready-local-proposal, 17 of 22 requests, 4 trees, largest body 2,094,030 of 2,097,152 bytes, binary_blob_requests 0"
affects: ["253-131", "253-133", "253-134"]
tech-stack:
  added: []
  patterns:
    - "A new scoped pair is additive: legacy stays the default, earlier pairs keep byte-identical derivations, and the unknown-pair probes move to a name that is never pinned (now r12)"
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-130-SUMMARY.md
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
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R11.json
key-decisions:
  - "PR_HEAD_REFS, NORMAL_HEADS and PR_NORMAL_HEADS each stay on one source line, as in 253-119, so no audit anchor moves in the transport, ci-pr-proof.sh or the verifier. The transport line is now 197 characters (the file's earlier maximum was 187) and the ci-pr-proof.sh line is 169 (earlier maximum 149). No line-length lint exists."
  - "The only audit drift was publication-1497 (line 1498 -> 1499), caused by the added REF_PAIRS line. Its id, anchor and coverage are unchanged."
  - "R10_REFS are FREEZE-R10's candidate_helper_commit and fixture_workflow_commit. A test binds them both to the committed freeze and to PUBLICATION-RECEIPT-R10's created refs."
  - "The pr-proof World now keeps publication_journal before clearing the journal. Without it, a no-earlier-ref-path check covers only the PR window. The r11 tests check both windows, with an r11 ref-path positive control."
estimate: {tokens: 46000, tasks: 3}
actuals:
  tokens: 10253
  tasks: 3
  commits: 3
commits: 3
plan_head_before: bb332c096923c6740b78a3baedcfc567aaca00a2
plan_head_after: 5b66685c91243bfcaf2d99c0004a1e0d734ce1e1
duration: "02:56Z to 05:11Z on 2026-10-17 (work). The final verify took 67 minutes (53 of them the dry-run suite). The Mac slept twice before this SUMMARY was written."
completed: 2026-10-17
---

# Phase 253 Plan 130: r11 scoped ref pair, final R11 review and early projection Summary

**R11 now publishes under its own create-only names, gsd/253-replan-r11-candidate and gsd/253-replan-r11-fixture. The freeze selects the pair, and the publisher, transport, ci-pr-proof.sh and the verifier all follow it. Each earlier freeze still derives its recorded digests exactly: FREEZE-R10 3ef4162b.../a3734ed5..., R9, R8, R7 and 253-91. An r11 publication creates only the two r11 refs. The r8, r9 and r10 refs seeded beside it are never read or moved, and an r10 publication stops on its seeded refs. The dry-run harness seeds all three earlier pairs at their real GitHub SHAs, and both gate modes pass on r11 with none of them moved. The final review of every R11 product change found nothing that needed a fix. The R11 publication projects at 17 of 22 requests with binary_blob_requests 0, and every tree body is under 2 MiB. There were zero GitHub requests.**

CIREL-02 stays open. Full Phase 253 verification stays not_started. FREEZE-R11 is not cut; that is 253-131.

## Task commits

| Task | Commit | Subject |
|---|---|---|
| 1 (tracer) | `c8643a441` | feat(253-130): r11 scoped ref pair in the publisher and transport |
| 2 | `5da56e959` | feat(253-130): r11 normal PR head in the PR consumers |
| 3 | `5b66685c9` | feat(253-130): seed all three earlier scoped ref pairs in the dry-run gates |

`commits: 3` is measured with `git rev-list --count bb332c096..5b66685c9`. This SUMMARY's commit adds a fourth. In that diff: 11 files, +522 / -54 lines, 41,013 added characters (about 10,253 tokens at chars/4).

## Task 1: r11 through the publisher and transport (tracer)

- **RED:**
  - ci-git-publication.test.py: 92 ran, 6 failed (5 failures, 1 error). The failures were exactly_five_ref_pairs, the r10 build_freeze test (its help and message now name five), build_freeze_accepts_r11, check_freeze_refuses_r11_mixed and r11_publication_creates_only_the_r11_refs. The error was an_r11_identity_moves_every_ref ("not one known ref pair").
    - These guards already passed: freeze_r10_replays, every_earlier_freeze_still_replays_with_the_fifth_pair_present and r10_freeze_publication_stops_on_seeded_r10_refs.
  - ci-hosted-transport.test.py: 76 ran, 4 failed (3 failures, 1 error). They were the 253-102 membership test, the 253-119 PR_HEAD_REFS count, the new r11 create_ref test and the new r11 pr_create test.
- **GREEN:**
  - REF_PAIRS gains `"r11": {"candidate": "gsd/253-replan-r11-candidate", "fixture": "gsd/253-replan-r11-fixture"}`.
  - The `ref_pair_name` error and the `--ref-pair` help now say "legacy, r8, r9, r10 or r11".
  - PR_HEAD_REFS gains the r11 candidate.
  - These are unchanged: legacy, r8, r9, r10, HELPER_PATHS, PR_BASE_REFS, the create_ref pattern (asserted to appear once), and RESULTS_RECEIVER_HOST and the 253-125 host predicate (asserted).
- **After GREEN:** publication 92 OK, transport 76 OK, audit 36 OK after the one line refresh.
- **Tracer gate:** the verbatim Task 1 `<verify>` was re-run after the commit on the clean tree and exited 0.

New publisher tests (R11RefPairTests):
- FREEZE-R10 replays its canary and docs_and_prs digests and equals its recorded outward_actions. All five earlier freezes (R10, R9, R8, R7, 253-91) replay in one loop.
- An r11 identity moves create_ref, workflow_dispatch, cancel head_branch and the normal PR head to the r11 names. No r8, r9 or r10 name appears anywhere in the sections.
- These mixed identities are refused: r11/r10, r10/r11, r11/r9, r9/r11, r11/r8, half-pairs and r12.
- build_freeze accepts r11 and refuses r12, R11, "r11 ", "r10,r11", r1 and r110. The CLI refusal names all five pairs.
- check_freeze refuses r11/r10, r10/r11, r11/r9, r9/r11, r11/r8 and r11/legacy. It also refuses the r10 pair under an r11 freeze, fixture-as-candidate and r12.
- **End to end over local HTTPS:**
  - An r11 freeze, with all six r8, r9 and r10 refs seeded at the parent SHA, creates exactly the two r11 refs. server.refs equals the seeded set plus the two r11 refs, and no ref path names r8, r9 or r10 (positive control: r11 ref paths are present). There are exactly two create_ref POSTs and no DELETE or PATCH.
  - verify_publication refuses the receipt when it is tampered to r11/r10, r10/r11, r11/r9 or r12.
  - An r10 freeze with the r10 refs seeded at another SHA stops with "scoped ref gsd/253-replan-r10-candidate already points to a different commit". No POST /git/refs is made and no ref changes.

New transport tests:
- `test_253_130_pr_create_accepts_the_r11_candidate_...` accepts the r11 head and all four earlier candidates.
  - As head it refuses: r11-fixture, r12, r11-candidate-x, r1, r110, the refs/heads/ form, the owner: form, R11 and r10-fixture.
  - As base it refuses: the r11 candidate, the r11 fixture and the r10 candidate.
- `test_253_130_create_ref_accepts_both_r11_names_...` checks both r11 names, the exact six-member PR_HEAD_REFS and the unchanged PR_BASE_REFS. It also asserts that the create_ref pattern and the RESULTS_RECEIVER_HOST line each appear once.

## Task 2: PR consumers

- **RED:**
  - ci-pr-proof.test.sh: 64 ran, 1 failure (check_only refusing the r11 head) plus 2 setUpClass errors (R11RefPairTests and LivePolicyR11PRTests: "the publication receipt's candidate_ref is not one of the known candidate refs").
  - ci-hosted-gate-verify.test.py: 124 ran, 3 failed: the membership test, the 253-119 count and the new r11 test.
- **GREEN:** `NORMAL_HEADS` (ci-pr-proof.sh) and `PR_NORMAL_HEADS` (the verifier) each gain `gsd/253-replan-r11-candidate`, on their existing single lines. No audit anchor moved.
- **Results:** pr-proof 69 OK (5 new), verifier 124 OK, audit 36 OK. The verbatim Task 2 `<verify>` exited 0 (see Deferred issues for its first attempt).

New tests:
- **R11RefPairTests** (an r11 World seeding r8, r9 and r10, plus an r10 World):
  - An r11 freeze yields normal head gsd/253-replan-r11-candidate, and the normal family verifies.
  - The six seeded refs are unchanged after publication and after the PR window. No publication-window or PR-window path names r8, r9 or r10. Positive controls: r11 ref paths in the publication journal and /pulls requests in the PR window.
  - The verifier refuses r12, r11-fixture, r10, r9, r8 and legacy as the head.
  - An r10 freeze still yields the r10 head. The r9, r8 and legacy heads are still covered by the unchanged R10RefPairTests, R9RefPairTests and RefPairTests worlds.
  - `--prepare` refuses an r11 receipt with r12, the fixture as candidate, r11/r10, r10/r11 or r11/r9.
  - An r11 world given the r10 head, and an r10 world given the r11 head, are both refused before any request, for both families.
- **LivePolicyR11PRTests:** the 253-109 live-policy universe under r11, beside six seeded refs. It verifies as synthetic through the verifier CLI with accepted_live false and origin actual-github. The seeded refs are unchanged and no earlier ref path was requested (positive control: r11 ref paths are present).
- **Verifier** `test_253_130_the_r11_candidate_is_a_normal_head_and_nothing_else_r11_is_accepted`: exactly five normal heads, and the docs refs are unchanged. It refuses r12, r11-fixture, r11 on the docs base, r11 as the docs-only head, r11 as the docs-only base, the refs/heads/ form, a trailing space, R11, r110 and r11 with an r10 base.

**The PR driver never uses run_logs (offline, recorded):** `test -z "$(grep -n run_logs scripts/ci/ci-pr-proof.sh)"` is true. Positive control: `artifact_zip` appears once (ci-pr-proof.sh:447, `self.call("download", "artifact_zip", "artifact_downloads", ...)`). job_logs appears 0 times. The R11 PR allocation (253-134) therefore need not list results-receiver.

## Task 3: seeding all three earlier pairs, the review and the projection

- **RED:** `ci-gate-canary-dryrun.test.py SeededR10RefsTests`: 4 ran, 4 failed. The 2 failures were the r11 gate test and the r10 control, both on "unrecognized arguments: --seed-r10-refs". The 2 errors were the two tests that read `R10_REFS`, which did not exist yet.
- **GREEN:**
  - `R10_REFS = {gsd/253-replan-r10-candidate: d16617f77223ff136a0c9e04bc3cd067bc6370cf, gsd/253-replan-r10-fixture: 06bb7dfb7dad0221d49292b9342ad871685a673b}`.
  - `seeded_scoped_refs` merges any combination of the three pairs.
  - `--seed-r10-refs` sets `seeded_r10_refs_changed`, and only when the flag is given. The r8 and r9 behaviour and keys are unchanged.
  - SeededR10RefsTests, SeededR9RefsTests and RefPairHelpTests: 8 OK.
- New tests:
  - R10_REFS equals FREEZE-R10's commits and PUBLICATION-RECEIPT-R10's created refs. R8_REFS and R9_REFS are unchanged.
  - seeded_scoped_refs merges exactly the requested pairs.
  - An r11 quick gate with all three pairs seeded passes in both modes with two create_ref requests and no pair moved.
  - The r10 positive control stops on the first get_ref and moves nothing. seeded_r8_refs_changed and seeded_r9_refs_changed are absent there, because those pairs were not seeded.

### Gate summaries (full sequence, synthetic r11 freeze, all three pairs seeded; from the verbatim Task 3 verify)

| Field | Hermetic `--ref-pair r11 --seed-r8-refs --seed-r9-refs --seed-r10-refs` | `--live-policy` (same flags) |
|---|---|---|
| status / synthetic | passed / true | passed / true |
| scenarios | all six | all six |
| verifier | passed | passed |
| requests_total | 93 | 93 |
| create_ref | 2 | 2 |
| seeded_r8 / r9 / r10 _refs_changed | false / false / false | false / false / false |
| verifier_job_model | scenario-set | verify_sources |
| response_shape | ok, run_logs_checked true, 0 mismatches | the same |
| Authorization to results-receiver | 0 | 0 |
| shim refusals / violations | none / none | none / none |

The requests by category were identical in both modes: publication 19, preflight 5, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6, cancellation 1. failure_logs was not changed.

### r10 positive control (`--ref-pair r10 --seed-r10-refs --stop-after full-pass`)

```
status failed; evidence_status halted; invocations [publish-only, exit 1, 12 publication requests]
stop: ci-git-publication: PublicationError: scoped ref gsd/253-replan-r10-candidate already points to a different commit
seeded_r10_refs_changed false; requests_total 12 (git_get_commit 3, git_create_tree 4, git_get_blob 2, git_create_commit 2, get_ref 1); no create_ref
```

### Final review (W2) of every R11 product change, 253-125..130

The review covered the diff from 1058a9236 (the R11 plan commit) to HEAD. The files with changes were ci-hosted-transport.py, ci-hosted-gate-verify.py, ci-shape-probe.py, ci-gate-canary-dryrun.py, ci-git-publication.py, ci-pr-proof.sh, ci-hermetic-live-audit.test.py and their tests. ci-gate-canary.sh and ci-live-policy-shim.py have no R11 diff.

| # | Check | Finding | Disposition |
|---|---|---|---|
| W1 | **Scoped results-receiver admission** (transport) | `_trusted_download_host` admits results-receiver only when all of these hold: exact string `RESULTS_RECEIVER_HOST`, route_id run_logs, `type(hop_ordinal) is int and hop_ordinal == 1`, the host is in `download_hosts`, and port is None or 443. follow_download passes `hop + 1`, so a hop 2 after results-receiver passes only `_pre_r11_download_host` (pipelines or productionresultssa*), which is byte-equal to the old predicate. The token is attached in one place (:679), and the R11 diff does not touch it. Neither the artifact_zip nor the job_logs route definition changed. `_validate_allocation` lets results-receiver appear in a live download_hosts list. That only lists it; the predicate still scopes its use. | Conforms. No change. |
| W2 | **Verifier mirror** | `verify_live_transaction_host` accepts results-receiver only on a run_logs transaction at hop 1 (an exact int), and otherwise the unchanged TRUSTED_DOWNLOAD_HOST regex. Like the pre-R11 rule, it does not itself check download_hosts. `verify_pr_transport` (the PR host check against download_hosts) has no R11 diff. The verifier has 3 R11 hunks in all: two from 253-125 and the PR_NORMAL_HEADS line. | Mirrors the transport scope exactly. No change. |
| W3 | **Probe driver** (ci-shape-probe.py) | It imports no HTTP client and opens no socket. Every request goes through `transport.request_one` / `transport.follow_download`, and its only subprocess is `git`. `_check_request_item` refuses any item naming a gsd/253-replan ref, any route outside rate_limit/run/run_jobs/run_logs/job_logs, any non-GET method, and any follow mode except on run_logs. It refuses a driver or transport that differs from HEAD. A bash grep of the product files (transport, verifier, publisher, ci-gate-canary.sh, ci-pr-proof.sh, ci.yml) finds no reference to it (rc 1). Positive control: the dry-run harness (:134) and the two test files reference it. | Conforms. No change. |
| W4 | **Probe-driven fakes** | `load_log_reference` and `load_cancelled_reference` read the committed -R11-PROBE evidence, bodies and ledger (plus R10 seq 47) at run time and cross-check every hop against the ledger rows. There is no hand-written copy. The two new faults, run-logs-legacy-blob-redirect and cancelled-shape-drift, fail the gate in their tests, which are in the 62-test dry-run suite that passed. | Conforms. No change. |
| W5 | **Nothing widened** | PRODUCTION_CATEGORY_LIMITS and the category tables have no R11 diff. Hop 0 is still api.github.com:443 only. The hop rule widened only as in W1. | Conforms. |
| W6 | **Shim isolation** | Searched under bash for `live-policy-shim\|live_policy_shim\|SIGRA_LIVE_POLICY_SHIM` in the product files: no match (rc 1). Positive control: 3 hits each in ci-gate-canary-dryrun.py and ci-pr-proof.test.sh. | Product code never imports the shim. |
| W7 | **r11 pair (this plan)** | REF_PAIRS, PR_HEAD_REFS, NORMAL_HEADS and PR_NORMAL_HEADS each have exactly five candidates, cross-checked by the verifier's REF_PAIRS test. HELPER_PATHS is unchanged, and the earlier digests replay. | Conforms. |
| W8 | **Inherited vacuous negatives** (tests only) | Two negatives in the 253-119 R10 tests are vacuous. (a) The publisher's "no r8/r9 name in POST /git/refs bodies" check can never fire, because the fake journal stores body digests, not bodies. (b) The pr-proof "no r8/r9 path" check covers only the PR window, because World clears the journal after publication. The binding proof in both is the server.refs equality, which does hold. The new r11 tests use binding checks: exact server.refs set, exact create_ref count, and publication_journal path checks with an r11 positive control. | The earlier tests were left as they are; editing them beyond probes and membership sets is not permitted. No product change. |
| W9 | **My own search** | A zsh `$P` file list did not word-split and gave a false "none". It was re-run under bash, with a positive control. | Process note; the result in W3 and W6 is from the bash run. |

No finding needed a fix, so no file outside the declared set was touched and the plan did not halt.

### Early R11 publication projection (no commit; output deleted)

This ran at HEAD 5b66685c9: `--prepare --candidate-source 5b66685c9... --server-parent 84ebcea60024c9e8caee405d55cad1c76b0e858a`. A first attempt before the Task 3 commit was refused ("source working tree is dirty"), as designed.

| Field | R11 (this plan) | R10 (PUBLICATION-R10) |
|---|---|---|
| status | ready-local-proposal | ready-local-proposal |
| projected_total_requests | **17** (limit 22) | 17 |
| parent preflight / fixed non-tree / **binary_blob_requests** | 1 / 12 / **0** | 1 / 12 / 0 |
| tree_request_count | 4 | 4 |
| tree body bytes | 2,001,252; **2,094,030**; 1,278,302; 17,686 | 2,047,127; 2,083,078; 1,034,007; 17,686 |
| largest body / cap | 2,094,030 / 2,097,152 (**3,122 bytes headroom**) | 2,083,078 / 2,097,152 (14,074) |
| complete_product_delta_dropped | false | false |

**Budget analysis.**
- The packer splits trees greedily at the 2,097,152-byte cap, so growth adds a tree request instead of causing a refusal. The only body-size refusal is a single entry larger than the cap.
- R11's delta (the new probe driver and its test, the longer fakes and tests) repacked the first three trees. The third tree grew by 244,295 bytes, and the second now sits 3,122 bytes under the cap.
- The binding limit is 22 projected requests: the 24-request publication category minus the full-pass and remaining fixture ref reads. That allows up to 9 tree requests.
- R11 uses 4 trees and 17 requests, 5 under the limit. Any further product growth that overflows the second tree adds one request (18), still within the limit.
- binary_blob_requests is 0, so 253-129's condition holds for this projection: git_create_blob is not called by any R11 hosted window.
- The fallback (halt with options for Jon) did not fire.

### Task 3 `<verify>` (verbatim, on HEAD 5b66685c9): rc 0, under `caffeinate -i -s`, 04:04:38Z to 05:11:22Z

| Check | Result |
|---|---|
| projection jq (ready, <= 22, every body <= 2097152) | true |
| hermetic r11 gate jq | true |
| live-policy r11 gate jq | true |
| r10 positive control jq | true |
| ci-hermetic-live-audit.test.py | 36 OK |
| ci-git-publication.test.py | 92 OK (was 85 at 253-119) |
| ci-hosted-transport.test.py | 76 OK |
| ci-shape-probe.test.py | 19 OK |
| ci-pr-proof.test.sh | 69 OK (5 new) |
| ci-hosted-gate-verify.test.py | 124 OK (1 new) |
| ci-gate-canary-flow.test.py | 22 OK |
| ci-gate-canary-dryrun.test.py | 62 OK (4 new; 3,188 s) |
| ci-gate-canary.test.sh | OK |
| ci-gate-canary-recovery.test.py | 5 OK |
| `--require-target-disposition` / `--require-target-accepted` | exit 0 / exit 3 (unchanged) |
| v1 and r2-r10 reconcile `--check-only` | all exit 0 |
| PRESERVATION-R11 checklist | `shasum -c` rc 0 |
| config.json sha256, state.json size, clean tree | 8e312f6c..., 70229 bytes, only ` M .planning/config.json` |

HEAD has not moved since this run. The Mac slept twice after it, before the SUMMARY was written, and the run's rc, start and end files were re-checked on resume.

## Recorded edits to earlier tests

Every place an earlier test used r11 as the never-pinned "unknown" name now uses r12. r11 joins the accepted sets.

- **ci-git-publication.test.py:**
  - `UNKNOWN_PAIR` is now the r12 pair (its comment was updated). `R11_PAIR` and `FREEZE_R10_DIGESTS` were added.
  - `test_exactly_four_ref_pairs_...` is now `test_exactly_five_...`. r11 was added to the expected REF_PAIRS and the accepted names. The mixed cases gained r11/r10, r10/r11, r11/r9, r9/r11, r11/r8, r11/legacy and the reversed r11 pair.
  - The `build_freeze` bad-pair list: "r11" became "r12".
  - The R9 test's fourth-pair probe (ref_pair, output name, CLI argument): r11 became r12.
  - In the R10 test `test_build_freeze_accepts_r10_...`, the bad list and CLI probe moved from r11 to r12. Its help assertion "r9 or r10" became "r9, r10 or r11", and its message assertion became "legacy, r8, r9, r10 or r11", because the plan requires the help and messages to name the five. See Deviations.
- **ci-hosted-transport.test.py:**
  - The 253-102 membership test adds r11 to the expected set. Its reject probe moved from r11-candidate to r12-candidate.
  - The 253-111 and 253-119 pr_create reject probes moved from r11-candidate to r12-candidate.
  - In the 253-119 create_ref test, `len(PR_HEAD_REFS)` went from 5 to 6.
- **ci-pr-proof.test.sh:**
  - World and LiveWorld gain `seed_r10_refs` (default False). World keeps `publication_journal` before clearing the journal. Existing worlds are unchanged.
  - Seven probes moved from r11 to r12: the RefPairTests verifier-head probe and --prepare "fourth candidate" probe, the R9RefPairTests verifier-head and --prepare probes, and the R10RefPairTests verifier-head and --prepare "fifth candidate" probes. (Some of those are two-ref entries.)
  - `test_check_only_accepts_only_the_four_candidate_names_...` is now `..._five_...`. It accepts r11, its unknown probe became r12, and it also refuses r11-fixture.
- **ci-hosted-gate-verify.test.py:**
  - `test_253_102_normal_head_is_one_of_the_four_...` is now `..._five_...`. r11 was added to the expected set and the accepted heads, and its unknown probe became r12.
  - The 253-119 r10 test: its counts went from 4 to 5, and its unknown probe became r12.
- **ci-gate-canary-dryrun.test.py:** no existing test was edited.

## Deviations from Plan

None changed product behaviour or scope. The process notes:
1. **R10 help/message assertions updated.** The 253-119 R10 test asserted the four-name help and error strings. The plan requires them to name five, so they were updated to the five-name strings. This is the membership-set edit for those strings, beyond the bare r11 -> r12 probes. The renames from "four" to "five" follow the 253-119 precedent.
2. **Additive test-harness strengthening.** `World.publication_journal` was added so the r11 tests can check the publication window. The 253-119 negative only saw the PR window (W8).
3. **Long single lines.** These were kept to avoid audit-anchor churn (key-decisions).
4. **Verbatim verifies ran from bash script files in the scratchpad.** zsh does not word-split. The Task 3 script copied the three gate outputs to the scratchpad before its own `rm`, so they could be recorded here. The chain is otherwise unchanged.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. config.json and state.json are untouched (state.json 70229 bytes, sha256 prefix e45278c2cee0). WINDOWS.md and deferred-items.md were not written, because they are outside files_modified. The deferred issue is recorded here instead.

## Deferred Issues

- **A load-dependent flake in the existing `LivePolicyPRTests` (not in this plan's changes).** The first verbatim Task 2 verify failed two tests, because the requested-sleep log was `[60, 60, 60, 0.001]` instead of `[60, 60, 60]`.
  - Root cause: ci-pr-proof.sh:295 runs the transport with `subprocess.run(..., timeout=900)`. When the child has not been reaped at the first WNOHANG poll, CPython's `Popen._wait` busy-loop calls `time.sleep(0.001)`. The test's sleep recorder patches `time.sleep` process-wide, so it logs that call as a requested wait.
  - The same code passed the run before and the re-run after (69 OK). The verbatim Task 2 verify then exited 0.
  - Suggested fix for a future plan: have the recorder ignore sub-second requests, or record only `ci-pr-proof.sh`'s own `sleep()` call site. Not fixed here, because it is out of scope.

## Follow-ups and handoff for 253-131

- **The r8 refs (7a1ba235 / ad015ec1), r9 refs (b9720d8e / aa701489) and r10 refs (d16617f7 / 06bb7dfb) remain on GitHub.** Automation never reads them for reuse, moves them or deletes them. They are left for Jon's optional manual cleanup.
- **253-131** cuts FREEZE-R11 with `--ref-pair r11` from a clean reviewed source. The pre-clock gates are `--revision-freeze FREEZE-R11 --seed-r8-refs --seed-r9-refs --seed-r10-refs`, hermetic and `--live-policy`.
- **Projection headroom is thin.** Tree 2 is 3,122 bytes under the cap. Any product growth before the freeze adds a fifth tree (18 requests), which is still within the 22-request limit. PUBLICATION-R11 should report binary_blob_requests explicitly; it must stay 0 for 253-129's git_create_blob claim to hold.
- failure_logs stays 6/6 with zero slack; no budget was changed. The driver's 202/204 dispatch acceptance (the binding requires 204) is still open and was not loosened.
- CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Known Stubs

None.

## Threat Flags

None.
- T-253-275 is mitigated: exactly five code-pinned pairs, chosen by the freeze and consistent everywhere. Refs are create-only (get_ref must 404 first). Seeded r8, r9 and r10 refs are proven untouched in the publisher, the PR consumers and both gate modes, and the FREEZE-R10, R9, R8, R7 and 253-91 digests replay.
- T-253-276 is mitigated: 17 of 22 requests, largest body 2,094,030 bytes.
- T-253-277 is mitigated: the W2 review is complete, with no finding outside the declared files.
- T-253-SC: no new dependency and no workflow change.

## Self-Check: PASSED

- All 11 modified files exist, and c8643a441, 5da56e959 and 5b66685c9 are ancestors of HEAD.
- `git rev-list --count bb332c096..HEAD` = 3, before this SUMMARY's commit.
- Each RED preceded its GREEN.
- No `scripts/ci/__pycache__` remains, and `git status` shows only ` M .planning/config.json`.
