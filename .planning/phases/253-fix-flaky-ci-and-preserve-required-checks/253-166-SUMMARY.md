---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "166"
subsystem: ci-reliability / scoped refs (R13)
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, scoped-refs, main-freshness, canary-table, r13, r14, r15, red-first]
requirements: [CIREL-02]
requirements-completed: []
requires: ["253-165 (complete)", "253-164 (complete)", "253-137 r12 pair (the precedent)", "253-138 main-freshness guard", "253-136 MAIN-FETCH-R12"]
provides:
  - "r13 scoped ref pair (gsd/253-replan-r13-candidate / gsd/253-replan-r13-fixture) in publisher REF_PAIRS, transport PR_HEAD_REFS, ci-pr-proof.sh NORMAL_HEADS and verifier PR_NORMAL_HEADS"
  - "MAIN_FRESHNESS_PAIRS = (r12, r13): one main-freshness guard for build_freeze and check_revision_freeze"
  - "CANARY_CATEGORIES_R13 (preflight 16, infrastructure_retry 5, sum 117), carried only by r13 freezes; static_freeze_sections(pair)"
  - "ci-pr-proof.sh MAIN_RECORD_HEADS {r12, r13}: the r13 normal head requires --main-record"
  - "dry-run --seed-r12-refs, R12_REFS, seeded_r12_refs_changed; the derived r13 freeze passes the guard with the clone-local synthetic record"
affects: ["253-167", "253-168", "253-169", "253-170", "253-171", "253-172"]
tech-stack:
  added: []
  patterns:
    - "Per-pair canary table: pairs not named in PAIR_CANARY_CATEGORIES keep CANARY_CATEGORIES, so every earlier freeze's static sections are byte-identical"
    - "Main-freshness guard keyed on a pair set, not a per-pair copy"
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-166-SUMMARY.md
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
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R13.json
key-decisions:
  - "R13 reuses MAIN-FETCH-R12 (fetched_main_sha 09df342a) as its main record, with no new fetch. Local origin/main still equals it, the R12 candidate sits on it, its first check-runs page is committed real bytes, and the PR window re-checks mergeability at step 0 (253-171)."
  - "R13 canary table (an explicit R13 decision that changes the R12 table; Jon approves at 253-170): preflight 8 -> 16 and infrastructure_retry 13 -> 5. The retry category is expired and can never be spent. The total stays 117 and every other category is unchanged. Evidence: R12 ledger seq 21 (253-143's page 1) holds 209 check runs, and its only complete day (2026-10-18) added 55. Preflight 16 fits the request arithmetic; the binding ceiling is the verifier's MAX_CHECK_RUN_PAGES = 10 (1000 runs, about 14 days at 55/day from 209). The expired-retry record for r13 says requests 5."
  - "The legacy CANARY_CATEGORIES block is byte-unchanged since the FREEZE-R12 commit; the verify checks this. CANARY_CATEGORIES_R13 = {**CANARY_CATEGORIES, preflight: 16, infrastructure_retry: 5}, and both sums are asserted at import."
  - "require_r12_main_freshness was renamed require_main_freshness(repo, manifest, pair_name). The refusal message names the pair ('an r13 freeze needs ...'); the r12 text is unchanged."
  - "MAIN_RECORD_HEADS maps head -> pair name, so the refusal reads 'the r13 normal head requires --main-record'. The r12 text is unchanged and the edit adds no lines (no audit anchor moved in ci-pr-proof.sh or the verifier)."
estimate: {tokens: 46000, tasks: 3}
actuals:
  tokens: 29000
  tasks: 3
  commits: 6
commits: 6
plan_head_before: a6faf5f4ed123825a09593a46549c298682e6385
plan_head_after: d5f83ba01bc33cc4a763dda995dc711cd5f3515f
duration: "06:55Z to 08:14Z on 2026-10-20 (about 80 min, mostly test runs)"
completed: 2026-10-20
---

# Phase 253 Plan 166: r13 scoped ref pair under the main-freshness guard Summary

**R13 now publishes under its own create-only names, gsd/253-replan-r13-candidate and gsd/253-replan-r13-fixture. They are code-pinned in the publisher, the transport PR-head allowlist, ci-pr-proof.sh and the verifier.**

- **The guard covers r13 through one pair set.** `MAIN_FRESHNESS_PAIRS = ("r12", "r13")` replaces the literal r12 comparisons, so r13 sits under the same 253-138 main-freshness guard as r12.
- **r13 has its own canary table.** An r13 freeze carries preflight 16 and infrastructure_retry 5; r12 and every earlier pair keep 8 and 13.
- **Nothing earlier moved.** An r13 publication creates only the r13 pair beside the r8-r12 refs, which are seeded at their real GitHub SHAs and left untouched. Publishing r12 over the seeded r12 refs stops with "already points to a different commit".
- **Both dry-run gate modes pass on r13** with all five earlier pairs seeded and unmoved, preflight 7, and a 3-page check_runs read (the repositories-id form in live-policy).
- **No network.** There were zero GitHub requests, fetches or pushes.

CIREL-02 stays open. Full Phase 253 verification stays not_started. FREEZE-R12 can no longer validate the tree, as planned.

## Precondition (Task 1)

- 253-165 and 253-164 are status complete. PRESERVATION-R13 checks clean. refs/remotes/origin/main = 09df342a82e03c3d5d40173c912b70e827f7eadc = MAIN-FETCH-R12 fetched_main_sha. The tree was clean except config.json.
- R15 deadline guard, margin 1 (exit 0): `R13 canary deadline guard: margin 1 d, projected check_runs pages 4 of 10, canary deadline 2026-11-02T19:18:40.000Z`
- Positive control, margin 20 (exit 1): `projected check_runs pages 14 of 10`.

## Task commits

| Task | Commit | Subject |
|---|---|---|
| 1 RED | `64c075d4b` | test(253-166): r13 scoped ref pair and its main-freshness guard (RED) |
| 1 GREEN (tracer) | `a3df31cfa` | feat(253-166): r13 scoped ref pair under the main-freshness guard |
| 2 RED | `40e13c178` | test(253-166): r13 normal PR head (RED) |
| 2 GREEN | `3e3111f52` | feat(253-166): r13 normal PR head in the PR consumers |
| 3 RED | `3c42b57fa` | test(253-166): seed the r12 refs and the r13 derived freeze (RED) |
| 3 GREEN | `d5f83ba01` | feat(253-166): seed the r12 refs and derive the r13 freeze through the guard |

`commits: 6` is measured with `git rev-list --count a6faf5f4e..d5f83ba01`. The range touches 11 files, +778 / -107. This SUMMARY's commit adds a seventh.

## RED -> GREEN

| Suite | RED (exit, result) | GREEN (exit, result) |
|---|---|---|
| ci-git-publication.test.py | exit 1: 118 tests, failures=10 errors=4. These are the 11 new R13RefPairTests plus the r13-including membership/help assertions (RefPairTests seven pairs; the R10/R11/R12 help strings; R12 `len == 7`) | exit 0: 118 OK |
| ci-hosted-transport.test.py | exit 1: 85 tests, failures=5 errors=1 (the two new 253-166 tests and four PR_HEAD_REFS set/length assertions) | exit 0: 85 OK |
| ci-pr-proof.test.sh | exit 1: 103 tests, failures=1 errors=2. The R13RefPairTests and LivePolicyR13PRTests setUpClass failed with "the publication receipt's candidate_ref is not one of the known candidate refs"; check-only refused the r13 head | exit 0: 110 OK (in the Task 2 verify) |
| ci-hosted-gate-verify.test.py | exit 1: 151 tests, failures=5 (253-102/119/130/137 head-set assertions and the new 253-166 test) | exit 0: 151 OK |
| ci-gate-canary-dryrun.test.py SeededR12RefsTests + DryRunR13MainRecordTests (new names only) | exit 1: 4 tests ran, failures=2 errors=3. No R12_REFS; `--seed-r12-refs` unrecognized; DryRunR13MainRecordTests setUpClass: "an r13 freeze needs a publication manifest with main_freshness" | exit 0: with DryRunR12MainRecordTests and RefPairHelpTests, 13 OK (339 s) |
| ci-hermetic-live-audit.test.py | after the Task 1 code: exit 1, 10 failures, all "anchor moved" (see below) | exit 0: 54 OK |

## Verify blocks (verbatim, long-run protocol)

Each block was copied verbatim from the plan into `${TMPDIR}/253-166-task<N>-verify.sh`, behind a single added `cd /Users/jon/projects/sigra`. Each ran with run_in_background under `caffeinate -i -s`. Power was `Now drawing from 'AC Power'` for every run. All three logs ended in exactly `VERIFY-EXIT 0` on their first run; none was re-run. The scripts and logs were deleted afterwards.

| Task | UTC start -> end | Result |
|---|---|---|
| 1 (tracer gate) | 07:07:15 -> ~07:11:45 | VERIFY-EXIT 0. Publication 118 OK, transport 85 OK, audit 54 OK. The greps, the CANARY_CATEGORIES/_R13 python check, the legacy-block-unchanged check against the FREEZE-R12 commit and the RED-before-fix ancestry all passed, as did PRESERVATION-R13, config.json, state.json and the clean tree. The tracer feedback gate (interactive, end-of-phase, automated-only verify) passed on this run, so the plan expanded. |
| 2 | 07:28:44 -> ~07:34:25 | VERIFY-EXIT 0. pr-proof 110 OK, verifier 151 OK, audit 54 OK. |
| 3 | 07:49:20 -> ~08:13:25 | VERIFY-EXIT 0. MainRecord/Seed classes (SeededR9/R10/R11/R12RefsTests, DryRunR12/R13MainRecordTests) 23 OK in 1046 s. Both r13 gates and the r12 control met their jq/grep checks. Audit 54 OK. The real origin/main and main did not move. |

## Gate summaries (Task 3 action runs, committed HEAD d5f83ba01, 07:42:40 -> 07:49:07)

| Run | status | seeded_r8..r12_refs_changed | create_ref | paginated_reads | response_shape | authorization |
|---|---|---|---|---|---|---|
| `--ref-pair r13` + five seed flags (hermetic) | passed, synthetic | false x5 | 2 | check_runs 3 pages, form `repos` | ok, run_logs_checked true, mismatch 0 | api_with 0, blob_with 0, results_receiver_with 0; verifier_job_model scenario-set |
| same with `--live-policy` | passed, live-policy | false x5 | 2 | check_runs 3 pages, form `repositories-id` | ok, run_logs_checked true, mismatch 0 | api_with 87, api_without 0, blob_with 0, results_receiver_with 0; verifier_job_model verify_sources |
| control `--ref-pair r12 --seed-r12-refs` | failed (exit 1), evidence_status halted | r12 false (others absent) | 0 | none | not reached | none |

- **requests_by_category** was identical in both passing modes: artifact_downloads 10, artifact_metadata 6, attempt_jobs 7, cancellation 1, dispatch 7, failure_logs 6, pre_watch_rate 7, **preflight 7**, publication 19, run_discovery 7, terminal_polls 18. The control spent publication 12 and nothing else.
- **live_hops:** each passing mode has 8 hop-1 rows, all status 200: 5 artifact_zip and 3 run_logs. Hermetic hosts were all localhost. Live-policy hosts were productionresultssa17.blob.core.windows.net for artifact_zip and results-receiver.actions.githubusercontent.com for run_logs.
- **Control stop:** `ci-git-publication: PublicationError: scoped ref gsd/253-replan-r12-candidate already points to a different commit`.

## Audit rows changed (253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R13.json)

Only `line` values in scripts/ci/ci-git-publication.py rows changed. Ids, anchors and coverage are unchanged:
- publication-628: 753 -> 754
- publication-629: 754 -> 755
- publication-731: 856 -> 857
- publication-879: 1004 -> 1005
- publication-909: 1034 -> 1035
- publication-912: 1037 -> 1038
- publication-982: 1107 -> 1108
- publication-1497: 1644 -> 1663

The first seven moved one line because the guard docstring gained a line; publication-1497 moved because of the added constants. Nothing moved in the transport, ci-pr-proof.sh or the verifier: each edited line stayed one line. ci-gate-canary-dryrun.py is not in the matcher's file list. Final sha256 is 46669f60679f2c101f2c515db5953597058d2f07dd67a89a150aa50eab6d0470.

## Earlier-test edits (the permitted classes only)

- **Unknown-pair probes, r13 -> r14:**
  - publication: UNKNOWN_PAIR, the bad-pair loops and the `--ref-pair` CLI probes;
  - transport: the 253-102/111/119/130/137 pr_create probes;
  - pr-proof: every r13 probe, including the R12RefPairTests check-only test, now named `..._refuses_an_r14_normal_head_...`;
  - verifier: the 253-102/119/130/137 refused lists.
- **Membership assertions:**
  - REF_PAIRS equality (`..._six_...` -> `..._seven_...`) and R12 `len(REF_PAIRS)` 6 -> 7;
  - transport PR_HEAD_REFS set equality (3 sites) and length 7 -> 8;
  - verifier PR_NORMAL_HEADS set (3 sites), its accepted-head loop and lengths 6 -> 7;
  - the pr-proof check-only accepted/refused head lists (`six` -> `seven`).
- **Help and message strings** now read "..., r11, r12 or r13" (the 253-137 precedent).
- **Additive harness change:** the pr-proof World and LiveWorld gained `seed_r12_refs`, and the publication tests gained `real_earlier_refs_r13()`. The r12 values come from FREEZE-R12's identity, never retyped.

## Deviations from Plan

1. **[Rule 1 - test bug in a new test] The r14 collector test asserted the wrong gate.**
   - Found during: Task 2 GREEN.
   - Issue: the new `R13RefPairTests` collection test expected frozen_refs' message ("normal refs are not the exact proof refs"). The collector actually stops first at its revision-freeze NORMAL_HEADS gate ("the PR freeze normal head ref differs from the revision freeze candidate_ref ('gsd/253-replan-r14-candidate' ...)"), still with 0 requests and no evidence written.
   - Fix: the test now asserts the real message and was renamed `..._refused_by_the_collector_before_any_request`. frozen_refs' own refusal of r14 is proven by `test_check_only_refuses_an_r14_normal_head_and_accepts_the_r13_head`, with the r13 positive control, and the verifier refusal by `test_253_166_...`.
   - The fix went into the GREEN commit 3e3111f52. It is a test of this plan's own, not an earlier test.
2. **[Rule 3] require_r12_main_freshness was renamed require_main_freshness and gained a pair-name argument,** so that the refusal names the pair. It has no external callers (grep across scripts/ci).
3. **The verify scripts carry one added `cd` line** before the verbatim block. It does not affect pass or fail.
4. **I peeked once at the Task 1 verify log tail while it was still running.** It was a read, not a re-run and not a wait loop. The result was taken only from the final VERIFY-EXIT line.

**Not done by design:**
- Per the orchestrator's hard constraints, the gsd-tools state/roadmap/requirements writers were not run, STATE.md, ROADMAP.md and REQUIREMENTS.md were not edited, and WINDOWS.md was not written.
- The full dry-run suite was not run; 253-167 runs it before anything is frozen (R15-FULL-SUITE does not bind here, per the plan).

## Carry-forward findings (from 253-165; not acted on, outside this plan's scope)

1. **A PR head with more than 100 check runs.** The verifier refuses it fail-closed (`check_run_page_set`), but the collector still finishes "collected" with exit 0. 253-167 should list this as an R13 unobserved shape.
2. **The pre-existing flake `LivePolicyPRTests.test_live_policy_token_and_host_rules_hold_across_both_families`.**
   - What happened: it recurred once in a non-verify development run of ci-pr-proof.test.sh (Task 2, the run after the test fix). The sleep recorder caught a `0.001` s sleep: `[60, 60, 60, 60, 60, 60, 0.001] != [60, 60, 60, 60, 60, 60]`, which matches CPython subprocess `_wait` retry sleeps.
   - It did not occur in the Task 2 verify block (110 OK), and neither did any other failure.
   - Why it was not fixed: this plan only permits the r14 probe move and the head-tuple edits to earlier tests, so editing that earlier test is out of scope. It should be handled by a later plan.

## Known Stubs

None.

## Threat Flags

None. No new network surface; every change is an allowlist entry, a pair-set condition or an offline harness flag.

- **T-253-384 is mitigated.** There are exactly seven code-pinned pairs, and refs are create-only (get_ref precedes create_ref for each r13 ref). The r8-r12 refs, at their real SHAs, are proven untouched in the publisher and both gate modes. The r12-over-r12 control fails, and r14 is refused.
- **T-253-385 is mitigated.** One pair set covers r13. r13 freezes, PR prepare and the dry-run derived freeze all need the recorded fresh main. The stripped-manifest control is refused for r13.
- **T-253-386 is mitigated.** The r13 head was added to exactly three allowlists. r14 is refused by the transport, by ci-pr-proof.sh (check-only/frozen_refs, prepare and the collector) and by the verifier, each with an r13 positive control.
- **T-253-387 is mitigated.** Preflight comes only from the expired retry. The total is 117 and the other categories are equal. The legacy block is unchanged since the FREEZE-R12 commit. An r13 freeze edited back to the R12 table, or to a retry of 13, is refused, and so is an r12 freeze carrying the r13 table.
- **T-253-SC:** no new dependency.

## Self-Check: PASSED

- All 11 modified files and this SUMMARY exist.
- Commits 64c075d4b, a3df31cfa, 40e13c178, 3e3111f52, 3c42b57fa and d5f83ba01 are ancestors of HEAD.
- config.json sha256 is 8e312f6c...0b8d (unstaged, uncommitted). state.json is 70229 bytes, prefix e45278c2cee0.
- The tree is clean except config.json.
