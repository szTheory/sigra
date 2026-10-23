---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "138"
subsystem: ci-reliability / main freshness and mergeability (R12)
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, mergeability, main-freshness, red-first, r12]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-136 MAIN-FETCH-R12 (fetched main 09df342a, record sha256 35fd1543...); 253-137 r12 scoped ref pair, the r12 publication/PR universes and the R12 audit record"
provides:
  - "merge_preflight(repo, head_sha, base_sha) in ci-git-publication.py: the one git merge-tree --write-tree merge test ({head, base, exit, clean, conflicts})"
  - "ci-git-publication.py --prepare --main-record: the record must be a fetched r12 record, its main must be local and must be the server parent, and local origin/main must equal it; the candidate must merge cleanly; the manifest gets a main_freshness block"
  - "--build-freeze --ref-pair r12 requires a clean main_freshness on the server parent and binds bound_documents.main_freshness_record; check_revision_freeze re-hashes it and never reads origin/main"
  - "ci-pr-proof.sh --prepare --main-record: the r12 head requires it; the PR freeze carries source.fetched_main_sha, source.main_record_sha256 and mergeability_preflight, and binds the record"
  - "ci-gate-canary-dryrun.py prepare_clone (derived-freeze branch, r12 only): a synthetic main-fetch record committed in the temporary clone and bound to its synthetic server parent"
  - "253-LOAD-RECOVERY-MAIN-FRESHNESS-RED-R12.json: RED receipts (four entries, copied from real runs)"
affects: ["253-139", "253-140", "253-141", "253-144"]
tech-stack:
  added: []
  patterns:
    - "The freshness guard is fail-closed on the real publication path. The dry-run harness satisfies it with a clone-local record bound to its own parent; it never skips it and has no override flag."
    - "The freeze binds the main-fetch record by sha256. It never binds the moving ref refs/remotes/origin/main."
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-MAIN-FRESHNESS-RED-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-138-SUMMARY.md
  modified:
    - scripts/ci/ci-git-publication.py
    - scripts/ci/ci-git-publication.test.py
    - scripts/ci/ci-pr-proof.sh
    - scripts/ci/ci-pr-proof.test.sh
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json
key-decisions:
  - "RED for the stale-parent and stale-record tests is shown on the unfixed logic with only the new option parsed (entries 2 and 4). The unfixed CLIs reject --main-record at argparse (exit 2), which is a refusal for the wrong reason. A working-tree copy carrying only parser.add_argument('--main-record') (never read, reverted immediately, never committed) shows the unfixed preparation accepting the stale parent: ready-local-proposal and freeze_prepared. This follows the 253-125 entry-2 precedent. Entries 1 and 3 (unchanged source) are recorded too."
  - "merge_preflight checks that both sides are local commits before it runs merge-tree. git 2.41 merge-tree exits 1, not >1, for an unknown object ('not something we can merge'), so the exit code alone would misreport it as a conflict. It raises on any exit outside 0/1 and on an exit 1 without a tree id or conflicted path."
  - "Check order in --prepare --main-record: record shape -> fetched main present locally -> server parent == fetched_main_sha -> local origin/main == fetched_main_sha. All four run before source_variants writes any object. The candidate merge test runs after the candidate is built and before the manifest is written."
  - "Check order in ci-pr-proof.sh: the r12 head without --main-record -> the record -> server parent == fetched_main_sha -> main_freshness present -> record sha256 -> merge_preflight(normal head, fetched main). Each refusal ends with '; network_requests 0'."
  - "The main-fetch record path is repository-relative in the manifest and freeze. An absolute path is accepted only if it resolves inside the repository. ci-pr-proof.sh binds it relative to ROOT when --repo-root is ROOT, and otherwise as the resolved absolute path, because check_freeze re-reads relative bound paths against ROOT."
  - "build_freeze binds the record only for the r12 pair. check_revision_freeze re-hashes it when the pair is r12 or when the binding is present, and re-validates the record (schema, status, fetched_main_sha) against the manifest's main_freshness. Legacy and r8-r11 freezes have neither the binding nor the check."
  - "The dry-run harness writes the synthetic record untracked, prepares with the unchanged --candidate-source (HEAD before the record commit), and then commits the record in its own commit before the publication commit. The publisher accepted that source, so the candidate tree and projection are unchanged: publication 19 requests, the same as 253-137."
estimate: {tokens: 60000, tasks: 3}
actuals:
  tokens: 26663
  tasks: 3
  commits: 6
commits: 6
plan_head_before: 07fa17051ffaf2d3fccb28c887e0d348bf041b27
plan_head_after: ed675e7422ef57a004be1830eec5914ec4c1cf96
duration: "00:52 to 01:37 local (-04:00) on 2026-10-19, about 45 min, most of it test runs"
completed: 2026-10-19
---

# Phase 253 Plan 138: recorded-fresh-main guard for publication, freeze and PR prepare Summary

**This closes the offline half of blind spot #4. An R12 publication, canary freeze or PR freeze can no longer be built on anything but the recorded fresh main.**

- **The publisher refuses a stale parent.** `ci-git-publication.py --prepare --main-record` refuses a server parent that is not the record's `fetched_main_sha`. It also refuses:
  - a record that is not a fetched `sigra.phase253.main-fetch/r12` record;
  - a fetched main that is missing from the local object store;
  - a local `origin/main` that differs from the record;
  - a candidate that does not merge cleanly into the recorded main.
- **The freeze requires and binds the proof.** `--build-freeze --ref-pair r12` requires the manifest's clean `main_freshness` and binds the record. `check_revision_freeze` re-hashes the record and never reads `origin/main`.
- **PR prepare enforces the same rule.** `ci-pr-proof.sh --prepare` requires `--main-record` for the r12 head and runs the same check through `publisher.merge_preflight`. The PR freeze records the clean `mergeability_preflight` and binds the record.
- **The dry-run harness exercises the guard.** Its derived r12 freeze passes the guard with a synthetic record bound to its own parent, and a stripped-manifest control is refused in the same clone.
- **RED was shown on the reproduced 253-134 shape first.** Before the fix, the stale-parent prepare was accepted (`ready-local-proposal`) and the stale-record PR prepare was accepted (`freeze_prepared`).
- **Earlier behaviour holds.** Pairs legacy and r8-r11 are unchanged, both r12 gates pass, and the r11 positive control still stops. There were zero GitHub requests.

CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Task commits

| Task | Commit | Subject |
|---|---|---|
| 1 RED (tracer) | `4c43ddcbc` | test(253-138): stale server parent and conflicting candidate are accepted (RED) |
| 1 GREEN | `ccdd1688b` | feat(253-138): require the recorded fresh main as the publication parent |
| 2 RED | `99d2f09b7` | test(253-138): PR prepare accepts a stale parent (RED) |
| 2 GREEN | `8fa1e8e11` | feat(253-138): PR prepare requires the recorded fresh main and a clean merge |
| 3 RED | `1ffa16d9b` | test(253-138): the dry-run r12 derived freeze is refused by the main-freshness guard (RED) |
| 3 GREEN | `ed675e742` | feat(253-138): dry-run r12 freeze carries a synthetic main record bound to its parent |

- **Commit count.** `commits: 6` is measured with `git rev-list --count 07fa17051..ed675e742`. This SUMMARY's commit adds a seventh.
- **Diff size.** The range touches 8 files, +906 / -27.

## RED -> GREEN

| Suite | RED (exit, result) | GREEN (exit, result) |
|---|---|---|
| ci-git-publication.test.py (entry 1, unfixed) | exit 1: 107 tests, failures=9 errors=2, all in the 7 new MainFreshnessTests. Every --main-record call fails with argparse "unrecognized arguments"; merge_preflight raises AttributeError | exit 0: 107 OK |
| ci-git-publication.test.py MainFreshnessTests (entry 2, unfixed + parsed option only) | exit 1: 7 tests, failures=7 errors=3. Stale parent **accepted**: `AssertionError: 0 == 0 : the stale server parent 6aabe6a0... was accepted: {... "status": "ready-local-proposal"}`. The bad records and the changed record (check-freeze) were also accepted | (same GREEN run) |
| ci-pr-proof.test.sh (entry 3, unfixed) | exit 1: 69 tests, errors=3. The setUpClass of PrPrepareMainFreshnessTests fails (argparse); R12RefPairTests and LivePolicyR12PRTests fail with the Task 1 guard "an r12 freeze needs a publication manifest with main_freshness", as expected until GREEN supplies their record | exit 0: 81 OK |
| ci-pr-proof.test.sh (entry 4, unfixed + parsed option only) | exit 1: 75 tests, failures=5 errors=3. Stale record **accepted** for both advanced mains: `AssertionError: 0 == 0 : accepted: {"status": "freeze_prepared", "freeze_sha256": "2140f884...", "network_requests": 0}` | (same GREEN run) |
| ci-gate-canary-dryrun.test.py DryRunR12MainRecordTests | exit 1: setUpClass ERROR `DryRunError: ... --build-freeze --manifest failed: ci-git-publication: PublicationError: an r12 freeze needs a publication manifest with main_freshness (prepare with --main-record)` (0 tests ran) | exit 0: 4 OK |
| ci-hermetic-live-audit.test.py | after each GREEN code change: only "anchor moved" problems, no unaudited site | exit 0: 36 OK |

- **RED receipt.** `253-LOAD-RECOVERY-MAIN-FRESHNESS-RED-R12.json`, final sha256 `19355af5012465988591d827a99304d501708a194fe4c0f5a9eed758cbefcd44` (schema `sigra.phase253.red-receipt/r12`).
  - Four entries, all with exit_code 1.
  - Entries 1-2 were produced on `07fa17051`, entries 3-4 on `ccdd1688b`.
  - It also records `stale_parent_accepted` and `task2.stale_record_accepted`.
- **Ordering.** The receipt was added in `4c43ddcbc`, which is an ancestor of the fix commit `ccdd1688b`.
- **Task 3 failure line.** As the plan requires, it is recorded here, not in the receipt.

## New error messages

**ci-git-publication.py:**
- `server parent is not the recorded fresh main: server parent <sha>, recorded fresh main <sha>` (--prepare and --build-freeze r12)
- `candidate does not merge cleanly into the recorded fresh main: <paths>` (--prepare and --build-freeze r12)
- `main-fetch record is not a fetched sigra.phase253.main-fetch/r12 record`
- `local origin/main differs from the main-fetch record: <sha|absent> != <sha>`
- `the recorded fresh main <sha> is not present in the local object store`
- `an r12 freeze needs a publication manifest with main_freshness (prepare with --main-record)`
- `the candidate's parent is not the recorded fresh main`
- `bound document main_freshness_record differs from the record the publication was prepared from` (build) / `... is missing or differs from its digest` (check) / `... is not the publication manifest's main-fetch record` (check)
- `manifest main_freshness block is malformed`
- merge_preflight: `merge preflight head|base '<x>' is not a commit in the local object store`, `git merge-tree failed (exit N): <stderr>`

**ci-pr-proof.sh** (each ends with `; network_requests 0`):
- `the r12 normal head requires --main-record`
- `server parent is not the recorded fresh main: server parent <sha>, recorded fresh main <sha>`
- `the publication manifest has no main_freshness (prepare the publication with --main-record)`
- `the manifest main_freshness record_sha256 differs from the main-fetch record`
- `the normal head does not merge cleanly into the recorded fresh main: <paths>`

## Verify blocks (verbatim, run under bash from scratchpad script files)

- **Task 1 (tracer gate):** exit 0. Publication 107 OK, audit 36 OK, plus the greps, the receipt jq check, the RED-before-fix ancestry and PRESERVATION-R12. The tree was clean except config.json. The tracer gate (interactive, end-of-phase, automated-only verify) re-ran the block green before expansion.
- **Task 2:** exit 0. pr-proof 81 OK, publication 107 OK, audit 36 OK, and no `merge-tree` in ci-pr-proof.sh code.
- **Task 3:** exit 0 in 451 s. The class passed 4 OK, both r12 gates passed, the r11 control failed as required, and audit was 36 OK. The real `refs/remotes/origin/main` (09df342a) and `refs/heads/main` (de9145da) did not move. The only addition to the verbatim chain was a `cp` of the three gate outputs into the scratchpad just before the block's own `rm`; it does not affect pass or fail (same as 253-137).

## Gate summaries (Task 3)

| Run | status | seeded_r8/r9/r10/r11_refs_changed | response_shape | requests_by_category |
|---|---|---|---|---|
| `--ref-pair r12 --seed-r8-refs --seed-r9-refs --seed-r10-refs --seed-r11-refs` (hermetic) | passed | false/false/false/false | ok, run_logs_checked true | artifact_downloads 10, artifact_metadata 6, attempt_jobs 7, cancellation 1, dispatch 7, failure_logs 6, pre_watch_rate 7, preflight 5, publication 19, run_discovery 7, terminal_polls 18 |
| same with `--live-policy` | passed, mode live-policy | false/false/false/false | ok, run_logs_checked true | identical |
| control `--ref-pair r11 --seed-r11-refs` | failed, evidence_status halted | n/a | not reached | stop: `PublicationError: scoped ref gsd/253-replan-r11-candidate already points to a different commit` |

The request projection matches 253-137 exactly, so the synthetic record did not change the candidate tree.

## Audit rows changed

The only changes in `253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json` are `line` values (ids, anchors, occurrences and coverage are unchanged). No new site was matched.

| Row | Line before | Line after |
|---|---|---|
| publication-628 | 628 | 753 |
| publication-629 | 629 | 754 |
| publication-731 | 731 | 856 |
| publication-879 | 879 | 1004 |
| publication-909 | 909 | 1034 |
| publication-912 | 912 | 1037 |
| publication-982 | 982 | 1107 |
| publication-1497 | 1500 | 1644 |
| pr-proof-132 | 132 | 164 |
| pr-proof-457 | 457 | 496 |

- **audit_head** stays `a8213226f`.
- **No dry-run rows.** ci-gate-canary-dryrun.py is not in the matcher's file list, so it has none.
- **Final sha256:** `c097bb2afcae7b97dd6443654ae1b981ffdabd88131e4f1b3fdd673da7460622`.

## Earlier-test edits (the permitted classes only)

- **(a) Optional main-record fixture arguments,** each defaulting to off:
  - `make_local_publication(main_record=False)`, which `freeze_environment` passes through and which commits the record with the manifest;
  - `write_main_record()` / `MAIN_RECORD_REL` in the publication tests;
  - `World(main_record=False)` / `LiveWorld(main_record=False)` and `World.advance_main()` in ci-pr-proof.test.sh.
- **(b) The 253-137 r12 tests now supply a main record** naming their synthetic parent; their assertions are unchanged:
  - publication: `test_build_freeze_accepts_r12_...`, `test_check_freeze_refuses_r12_mixed_...` and `test_r12_publication_creates_only_the_r12_refs_...` gain `main_record=True`;
  - pr-proof: the R12RefPairTests and LivePolicyR12PRTests universes gain `main_record=True`.
- **(c) ci-gate-canary-dryrun.py:** only the derived-freeze branch of prepare_clone changed, and only for `ref_pair == "r12"`.
- **r13 probes:** the unknown-pair probes stay untouched.

## Deviations from Plan

1. **[Interpretation of a halt condition] The RED for the stale-parent and stale-record tests uses the parsed-option shim.**
   - **What the plan says:** the stale-parent test must fail "by acceptance (the unfixed --prepare returns ready-local-proposal for P0)", or the plan halts.
   - **What actually happens:** the unfixed CLI cannot accept an invocation that carries `--main-record`, because argparse exits 2 first.
   - **What I did:** I recorded that real run (entry 1). I then re-ran against the unfixed logic with only the option parsed and never read (entry 2), which does return `ready-local-proposal` for P0. The shim was reverted with `git checkout` straight after the run and never committed (253-125 precedent). The same applied to ci-pr-proof.sh (entries 3 and 4).
   - **Why no halt:** I judged that the gap is exercised (the unfixed preparation logic accepts the stale parent), so the halt condition did not fire. If the orchestrator reads the condition strictly, the options are:
     - (a) accept the shim evidence as is;
     - (b) re-plan RED around a no-op option committed before the RED commit;
     - (c) treat the plan as halted.
2. **[Rule 1] merge_preflight checks that both sides are commits before running merge-tree.** git 2.41 returns exit 1 for an unknown object, so exit-code-only classification would call it a conflict.
3. **[Own-test fix before GREEN commit] One assertion in my new PR test now expects the resolved path.** The PR freeze binds the record at the resolved absolute path (`/private/var/...`), and the RED-commit assertion compared the unresolved `/var/...` path. The test is `test_the_r12_freeze_records_a_clean_mergeability_preflight_and_binds_the_record`; the fix landed with the GREEN commit `8fa1e8e11`.
4. **Additive strictness beyond the plan.** check_revision_freeze also re-validates the bound record's schema, status and fetched_main_sha against the manifest's main_freshness. ci-pr-proof.sh refusals carry the `; network_requests 0` suffix.

**Not done by design:**
- Per the orchestrator's hard constraints, the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, and WINDOWS.md and deferred-items.md were not written.
- The full dry-run test suite was not run; that is 253-140.

## Deferred Issues

- **The known 253-130 load-dependent flake fired once.** It hit `LivePolicyPRTests.test_live_policy_token_and_host_rules_hold_across_both_families`: the sleep log was `[60, 60, 60, 60, 60, 60, 0.001]`.
  - Cause: CPython's `Popen._wait` busy loop calls the process-wide patched `time.sleep(0.001)`.
  - That universe passes no `--main-record`, so this plan's code does not run there.
  - Two later full runs were 81 OK, including the verbatim Task 2 verify.
  - The fix suggested in 253-130 (ignore sub-second sleeps in the recorder) is still out of scope.

## Known Stubs

None.

## Threat Flags

None. No new network surface was added; every new path is offline.

- **T-253-297 is mitigated.** --prepare refuses a non-record parent, a non-fetched or non-r12 record, an absent object, and a stale or missing local origin/main. The freeze binds the record by sha256 and check_revision_freeze re-hashes it. This was RED-first on the reproduced 253-134 shape.
- **T-253-298 is mitigated.** There is one merge_preflight, and ci-pr-proof.sh loads it from the publisher. It must be clean for the publication candidate and for the PR normal head before any file is written, and conflicts are reported with their paths. PR refusals made zero requests (the World journal stayed unchanged).
- **T-253-319 is mitigated.** The dry-run record is clone-local, marked `synthetic: true` and `decided_by: dry-run-synthetic`, and bound to the clone's own parent. The stripped-manifest control is refused in the same clone, and the real checkout's refs are asserted unchanged.
- **T-253-SC:** no new dependency (stock git 2.41 merge-tree).

## Handoff for 253-139 onward

- **Real R12 publication prepare.** Use `python3 scripts/ci/ci-git-publication.py --prepare --candidate-source <HEAD> --server-parent 09df342a82e03c3d5d40173c912b70e827f7eadc --main-record .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-MAIN-FETCH-R12.json --fixture-file ... --workflow-path .github/workflows/ci.yml --output ...`.
  - Local `refs/remotes/origin/main` must still be 09df342a at prepare time (it is now).
  - `--build-freeze --ref-pair r12` then binds MAIN-FETCH-R12 (sha256 35fd1543a87d7abfe50949b1d1b616c3afd18f868e7382de871028681515b90e) as `bound_documents.main_freshness_record`.
- **Real R12 PR prepare.** Use `bash scripts/ci/ci-pr-proof.sh --prepare ... --main-record .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-MAIN-FETCH-R12.json`. Without it, the r12 head is refused.
- **The merge test is only meaningful as a product check where it compares the source's own history with main.** The candidate is a fresh child of the fetched main that carries the source product tree, so merge_preflight(candidate, fetched main) is clean by construction. The rebuilt R12 source must still contain main's changes, or the PR diff reverts them; that is the rebuild-as-child-of-main work the R12 plans own.
- **Pre-clock gates (253-140):**
  - `python3 scripts/ci/ci-gate-canary-dryrun.py [--live-policy] --ref-pair r12 --seed-r8-refs --seed-r9-refs --seed-r10-refs --seed-r11-refs` passes on HEAD ed675e742; add `--revision-freeze <FREEZE-R12>` once it is cut;
  - the r11 control `--ref-pair r11 --seed-r11-refs` must still fail with "already points to a different commit".
- **Record sha256s:**
  - RED-R12 receipt `19355af5012465988591d827a99304d501708a194fe4c0f5a9eed758cbefcd44`;
  - R12 audit `c097bb2afcae7b97dd6443654ae1b981ffdabd88131e4f1b3fdd673da7460622` (audit_head a8213226f);
  - PRESERVATION-R12 `72ea87c5c9fe7c7cb2a9798b20122a65435823dc1e04a9fdbc8d47c3344ad16d` still checks clean;
  - MAIN-FETCH-R12 `35fd1543...` is unchanged.
- **Untouched:** draft PR #337 and FREEZE-R11 (no `--check-only` was run against it).

## Self-Check: PASSED

- **Files:** all 8 files in the range exist.
- **Commits:** 4c43ddcbc, ccdd1688b, 99d2f09b7, 8fa1e8e11, 1ffa16d9b and ed675e742 are ancestors of HEAD, and `git rev-list --count 07fa17051..HEAD` = 6 before this SUMMARY's commit.
- **Ordering:** each RED commit precedes its GREEN commit.
- **Invariants:**
  - no `scripts/ci/__pycache__`;
  - `git status` shows only ` M .planning/config.json`;
  - config.json sha256 8e312f6c...0b8d;
  - state.json is 70229 bytes, sha256 prefix e45278c2cee0;
  - STATE.md, ROADMAP.md, REQUIREMENTS.md, state.json and HANDOFF.json are unchanged in the range;
  - PRESERVATION-R12 `shasum -c` is clean;
  - real refs/remotes/origin/main is 09df342a and refs/heads/main is de9145da, both unchanged.
