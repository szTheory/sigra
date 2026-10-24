---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "137"
subsystem: ci-reliability / scoped refs (R12)
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, scoped-refs, r12]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-136 MAIN-FETCH-R12 (fetched main 09df342a) and PRESERVATION-R12; 253-130 r11 pair (the precedent); 253-133 r11 refs on GitHub (2b239a98 / 65c402f9)"
provides:
  - "r12 scoped ref pair (gsd/253-replan-r12-candidate / gsd/253-replan-r12-fixture), selected by the freeze, in the publisher REF_PAIRS, the transport PR_HEAD_REFS, ci-pr-proof.sh NORMAL_HEADS and the verifier PR_NORMAL_HEADS"
  - "--seed-r11-refs, R11_REFS and seeded_r11_refs_changed in the dry-run harness (combinable with --seed-r8/r9/r10-refs)"
  - "R12 hermetic-vs-live audit record (schema sigra.phase253.hermetic-live-audit/r12); the checker points at it"
affects: ["253-138", "253-139", "253-140", "253-141", "253-144"]
tech-stack:
  added: []
  patterns:
    - "A new scoped pair is additive: legacy stays the default, earlier pairs keep byte-identical derivations, and the unknown-pair probes move to a name that is never pinned (now r13)"
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-137-SUMMARY.md
  modified:
    - scripts/ci/ci-hermetic-live-audit.test.py
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
key-decisions:
  - "The checker's SCHEMA constant also moved to r12, beside AUDIT_REL. The plan asked for only AUDIT_REL to change, but it also requires the record's schema to be r12, and the checker refuses any record whose schema is not SCHEMA. Both are in the same declared file; 253-126 made the same r10 -> r11 move."
  - "R12 audit_head stays a8213226f (the HEAD before this plan's code edits). The checker only requires audit_head to be an ancestor of HEAD, so it did not need advancing after the commits."
  - "The only audit drift was publication-1497 (line 1499 -> 1500), caused by the added REF_PAIRS line. Its id, anchor and coverage are unchanged. NORMAL_HEADS, PR_NORMAL_HEADS and PR_HEAD_REFS each stayed on one line (as in 253-119/253-130), so no anchor moved in ci-pr-proof.sh, the verifier or the transport. ci-gate-canary-dryrun.py is not in the audit matcher's file list."
  - "The publication test seeds the r8-r10 refs from the dry-run harness's existing R8_REFS/R9_REFS/R10_REFS tables and the r11 refs from FREEZE-R11's identity, never retyped. The dry-run R11_REFS constant is a literal (as the verify requires), and a test binds it to FREEZE-R11 and PUBLICATION-RECEIPT-R11."
  - "The pr-proof World seeds the r11 refs at a foreign SHA (self.parent), matching how it seeds r8-r10. The real-SHA seeding is proven in the publisher and dry-run gates."
estimate: {tokens: 44000, tasks: 3}
actuals:
  tokens: 48298
  tasks: 3
  commits: 4
commits: 4
plan_head_before: a8213226fb5640a3c875429c9cf49431535377eb
plan_head_after: 0488703520d32a800551649d05a8e253f5531974
duration: "03:50:40Z to about 04:43Z on 2026-10-19 (about 53 min, most of it test runs)"
completed: 2026-10-19
---

# Phase 253 Plan 137: r12 scoped ref pair and the R12 audit record Summary

**R12 now publishes under its own create-only names, gsd/253-replan-r12-candidate and gsd/253-replan-r12-fixture. These are code-pinned in the publisher, the transport PR-head allowlist, ci-pr-proof.sh and the verifier. An r12 publication creates only the two r12 refs. The r8, r9, r10 and r11 refs, seeded beside it at their real GitHub SHAs, are never read or moved. Publishing r11 over the seeded r11 refs stops with "already points to a different commit". FREEZE-R11 (898ffa48... / f0e47f00...) and every earlier freeze still replay their recorded digests. Both dry-run gate modes pass on r12 with all four earlier pairs seeded and none of them moved. From this plan on, the audit checker runs on the new R12 record. There were zero GitHub requests.**

CIREL-02 stays open. Full Phase 253 verification stays not_started. As planned, FREEZE-R11 can no longer validate the tree, so no R12 plan runs `ci-gate-canary.sh --check-only` against it.

## Task commits

| Task | Commit | Subject |
|---|---|---|
| 1, step 1 | `c7cb40a6a` | docs(253-137): R12 hermetic-vs-live audit record |
| 1 (tracer), steps 2-3 | `5928b35d7` | feat(253-137): r12 scoped ref pair |
| 2 | `69fcbbc18` | feat(253-137): r12 normal PR head in the PR consumers |
| 3 | `048870352` | feat(253-137): seed the r11 refs in the dry-run gates |

`commits: 4` is measured with `git rev-list --count a8213226f..048870352`. This SUMMARY's commit adds a fifth. That range touches 12 files, +3418 / -66. 2836 of those lines are the new R12 audit record, a two-line-different copy of R11.

## RED -> GREEN

| Suite | RED (exit, result) | GREEN (exit, result) |
|---|---|---|
| ci-git-publication.test.py | exit 1: 100 tests, failures=3 errors=2 (5 new R12RefPairTests) | exit 0: 100 OK |
| ci-hosted-transport.test.py | exit 1: 78 tests, failures=1 errors=1 (2 new 253-137 tests) | exit 0: 78 OK |
| ci-pr-proof.test.sh | exit 1: 69 tests, failures=1 errors=2 (R12RefPairTests and LivePolicyR12PRTests setUpClass: "candidate_ref is not one of the known candidate refs"; the check-only six-name test on the r12 subtest) | exit 0: 75 OK |
| ci-hosted-gate-verify.test.py | exit 1: 125 tests, failures=4 (253-102 six-name, 253-119 and 253-130 count 6, new 253-137) | exit 0: 125 OK |
| ci-gate-canary-dryrun.test.py SeededR11RefsTests (new names only) | exit 1: 4 tests, failures=2 errors=2 | exit 0: SeededR11/R10/R9RefsTests + RefPairHelpTests, 12 OK (752 s) |
| ci-hermetic-live-audit.test.py | after the Task 1 code: exit 1, 10 failures (the one drift, publication-1497 1499 -> 1500, which also trips every positive control's unmutated-copy precondition) | exit 0: 36 OK |

Three tests in R12RefPairTests passed on the RED run, as expected: the eight-ref seed-table check, the earlier-freeze replay and the r11-over-r11 positive control. They pin existing behaviour that r12 must not change.

## Verify blocks (verbatim, run under bash from scratchpad script files)

- **Task 1:** exit 0. Publication 100 OK, transport 78 OK, audit 36 OK, and the greps, jq schema check, git-log-added check and PRESERVATION-R12 `shasum -c` all passed. config.json, state.json and the tree were clean.
- **Task 2:** exit 0 after the commit. pr-proof 75 OK, verifier 125 OK, audit 36 OK. The pre-commit run exited 1 only on the clean-tree check, which works as a positive control for that check.
- **Task 3:** exit 0. The only change to the verbatim chain was a `cp` of the three gate outputs into the scratchpad just before the block's own `rm`, so they could be recorded below.

## Gate summaries (Task 3)

| Run | status | seeded_r8/r9/r10/r11_refs_changed | create_ref | response_shape | authorization |
|---|---|---|---|---|---|
| `--ref-pair r12 --seed-r8-refs --seed-r9-refs --seed-r10-refs --seed-r11-refs` (hermetic) | passed, synthetic | false/false/false/false | 2 | ok, run_logs_checked true, 3 run_logs chains, mismatch_count 0 | api_with 0, blob_with 0, results_receiver_with 0; verifier_job_model scenario-set |
| same with `--live-policy` | passed, mode live-policy | false/false/false/false | 2 | ok, run_logs_checked true, 3 chains, mismatch_count 0 | api_with 85, api_without 0, blob_with 0, results_receiver_with 0; verifier_job_model verify_sources |
| control `--ref-pair r11 --seed-r11-refs --stop-after full-pass` | failed, evidence_status halted | r11 false; r8-r10 keys absent | 0 | not reached (run_logs_checked false) | 0 |

- **requests_by_category** was identical in both passing modes: artifact_downloads 10, artifact_metadata 6, attempt_jobs 7, cancellation 1, dispatch 7, failure_logs 6, pre_watch_rate 7, preflight 5, publication 19, run_discovery 7, terminal_polls 18. The control made publication 12 and nothing else.
- **live_hops:** each passing mode has 8 hop-1 rows, all status 200: 5 artifact_zip and 3 run_logs. Hermetic hosts were all localhost. Live-policy hosts were productionresultssa17.blob.core.windows.net for artifact_zip and results-receiver.actions.githubusercontent.com for run_logs. The control had none.
- **Control stop:** `ci-git-publication: PublicationError: scoped ref gsd/253-replan-r11-candidate already points to a different commit`.

## Audit rows changed

- **253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json** was created from the R11 record. Three things differ from R11:
  - schema is `sigra.phase253.hermetic-live-audit/r12`;
  - audit_head is `a8213226fb5640a3c875429c9cf49431535377eb`;
  - row publication-1497 has `line` 1500. It was 1499; the line moved because REF_PAIRS gained a line.
- **No other row changed.** Final sha256 718e0e6a1b4753f0d606540c51641a73c947dfcf9c858ed511a859baf6d4693d.
- **The R11 record is byte-identical.** sha256 098da815..., and it is covered by PRESERVATION-R12, which still checks clean.

## Earlier-test edits (the permitted classes only)

- **Unknown-pair probes, r12 -> r13:**
  - publication: UNKNOWN_PAIR, the RefPairTests bad-pair loop, the R9 and R10 `--ref-pair` CLI probes and the R11 bad-pair loop and CLI probe;
  - transport: the 253-102, 253-111, 253-119 and 253-130 pr_create head probes;
  - pr-proof: 9 probe lines across RefPairTests, R9, R10 and R11RefPairTests;
  - verifier: the 253-102, 253-119 and 253-130 refused lists.
- **Head and pair membership assertions:**
  - REF_PAIRS equality (`test_exactly_five_...` renamed `..._six_...`);
  - the transport PR_HEAD_REFS set equality (2 sites) and length 6 -> 7;
  - the verifier PR_NORMAL_HEADS set (2 sites) and length 5 -> 6 (2 sites), and its accepted-head loop;
  - the pr-proof check-only accepted and refused head lists (`..._five_...` renamed `..._six_...`, r12 accepted, r12-fixture refused).
- **The help and message strings** in the R10 and R11 publication tests now read "..., r10, r11 or r12". This follows the 253-130 deviation-1 precedent.
- ci-gate-canary-dryrun.test.py: no existing test was edited.

## Deviations from Plan

1. **[Rule 3 - Blocking] The checker's SCHEMA constant moved to r12** along with AUDIT_REL, in the same declared file. Without it, the r12 schema the plan requires fails the checker (see key-decisions).
2. **Help and message assertions updated.** This is the membership-string edit 253-130 also made.
3. **Additive test-harness change.** pr-proof World and LiveWorld gained `seed_r11_refs`, and the publication tests gained a `real_earlier_refs()` helper.

**Not done by design:**
- Per the orchestrator's hard constraints, the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, and WINDOWS.md and deferred-items.md were not written.
- The full dry-run test suite was not run; that is 253-140, as planned.

## Known Stubs

None.

## Threat Flags

None.
- **T-253-295 is mitigated.** There are exactly six code-pinned pairs, and refs are create-only (get_ref must 404 first). The r8-r11 refs, at their real SHAs, are proven untouched in the publisher and in both gate modes, and at a foreign SHA in the PR consumers. The r11-over-r11 positive control fails, and r13 is refused.
- **T-253-296 is mitigated.** The r12 head was added to exactly three allowlists. An r13 head is refused by the transport (pr_create), by ci-pr-proof.sh (--check-only and frozen_refs) and by the verifier (require_pr_refs). Each refusal has an accepted-r12 positive control.
- **T-253-SC:** no new dependency.

## Handoff for 253-138

- **The pair and seeds:** `--ref-pair r12` is the R12 pair. The pre-clock gates are `python3 scripts/ci/ci-gate-canary-dryrun.py [--live-policy] --ref-pair r12 --seed-r8-refs --seed-r9-refs --seed-r10-refs --seed-r11-refs` (later with `--revision-freeze FREEZE-R12`).
- **The audit record is current at HEAD 048870352:** R12 audit sha256 718e0e6a1b4753f0d606540c51641a73c947dfcf9c858ed511a859baf6d4693d, audit_head a8213226f, publication-1497 at line 1500.
- **Refs on GitHub are left alone.** The r8 refs (7a1ba235 / ad015ec1), r9 (b9720d8e / aa701489), r10 (d16617f7 / 06bb7dfb) and r11 (2b239a98 / 65c402f9) remain on GitHub, and automation never reads them for reuse, moves them or deletes them.
- **Unchanged:**
  - PRESERVATION-R12 sha256 72ea87c5... still checks clean;
  - MAIN-FETCH-R12 sha256 35fd1543... (fetched main 09df342a);
  - draft PR #337 was not touched.

## Self-Check: PASSED

- All 12 files in the range exist. c7cb40a6a, 5928b35d7, 69fcbbc18 and 048870352 are ancestors of HEAD, and `git rev-list --count a8213226f..HEAD` = 4 before this SUMMARY's commit.
- Each RED preceded its GREEN.
- **Invariants:**
  - no `scripts/ci/__pycache__`;
  - `git status` shows only ` M .planning/config.json`;
  - config.json sha256 8e312f6c...0b8d;
  - state.json is 70229 bytes, sha256 prefix e45278c2cee0;
  - STATE.md, ROADMAP.md, REQUIREMENTS.md and state.json are unchanged in the range.
