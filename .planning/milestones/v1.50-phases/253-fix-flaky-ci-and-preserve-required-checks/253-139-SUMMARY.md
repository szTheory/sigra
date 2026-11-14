---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "139"
subsystem: ci-reliability / PR window mergeability and moving main (R12)
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, mergeability, pull-request, red-first, r12]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-138 merge_preflight, the r12 PR freeze's source.fetched_main_sha / mergeability_preflight, World(main_record=True) and advance_main; 253-136 MAIN-FETCH-R12; the committed R11 PR ledger (253-134)"
provides:
  - "ci-pr-proof.sh --main-preflight --freeze PR-FREEZE --current-main SHA --output FILE [--repo-root DIR]: offline step-0 preflight, schema sigra.phase253.pr-main-preflight/r12, exclusive-create, status clean|conflicted|rewritten, exit 0 only for clean"
  - "ci-pr-proof.sh --family normal on an r12 freeze requires --main-preflight FILE, re-derived before any write or request; evidence.base_preflight = the file's fields + sha256; docs-only on r12 records {status: not_applicable, reason}; pre-r12 records nothing"
  - "a created PR base other than base_preflight.current_main stops the window ('main moved between the step-0 preflight and PR creation')"
  - "no run after both discovery attempts: one diagnostic pr_read (pr_identity) and one of three verdicts"
  - "ci-hosted-gate-verify.py verify_base_preflight, called from verify_pr_family right after check_pr(created)"
  - "ci-pr-proof.sh --family docs-only --docs-publication-receipt OUT: exclusive-create sigra.phase253.pr-docs-publication-receipt/r12 built only from the ledger's docs_publication rows"
  - "PR fake models 253-134: real R11 sequence-5 create key set (read at test time), base.sha = the fake's current main, pr_read mergeability, no run for conflicted/unknown/no-run heads, three-dot compare"
  - "253-LOAD-RECOVERY-PR-MERGEABILITY-RED-R12.json (RED receipt, two entries)"
affects: ["253-140", "253-141", "253-144"]
tech-stack:
  added: []
  patterns:
    - "A moved main is accepted only if the frozen main is its ancestor and the frozen head merges cleanly into it; the check is offline and runs before any request."
    - "The verifier binds base_preflight.current_main to the base.sha in the ledger's pr_create response body, never to a collector claim."
    - "The failure-path diagnostic read lives inside the existing pr_identity allotment; the success path is unchanged."
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PR-MERGEABILITY-RED-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-139-SUMMARY.md
  modified:
    - scripts/ci/ci-pr-proof.sh
    - scripts/ci/ci-pr-proof.test.sh
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json
key-decisions:
  - "RED for the conflicted-head replay uses the parsed-option shim (253-125 / 253-138 entry-2 precedent). The unfixed CLI rejects --main-preflight at argparse (entry 1, exit 2). A working-tree copy carrying only parser.add_argument('--main-preflight') (never read, reverted with git checkout right after the run, never committed) shows the unfixed collector stopping with the generic 'no pull_request workflow run was discovered for the published head' after 7 requests (entry 2). The moved-main test fails by acceptance in both entries (no shim needed)."
  - "The replay test builds its clean preflight document in Python (expected_preflight, which uses publisher.merge_preflight); a separate test asserts the CLI writes exactly that document for an unmoved main. This keeps the replay independent of the new CLI mode, which is what lets entry 2 show the real unfixed stop."
  - "--main-preflight is one option with two uses: alone it selects the step-0 mode (argparse nargs='?' with a sentinel const); with FILE it is the --family normal input. It is refused for docs-only and for pre-r12 freezes."
  - "A rewritten main (frozen main not an ancestor) wins over a conflicted one. If git merge-tree cannot run (for example unrelated histories), merge_preflight records clean false with an error string instead of raising, so the rewritten file is still written."
  - "The re-validation in --family recomputes the whole document (ancestry and merge_preflight) and requires byte-for-field equality with the file, after the freeze sha, head, frozen main, status and local-presence checks; every refusal ends with '; network_requests 0'."
  - "The verifier also checks schema, frozen_main, ancestor true, moved == (current_main != frozen_main), and that merge_preflight is a clean merge of the frozen head into current_main. Pre-r12 normal evidence is not inspected at all, so it verifies exactly as before."
  - "The docs receipt takes freeze_sha256 from the freeze (its identity binding); every other field is derived from the ledger's docs_publication rows. It is written in a finally around publish_docs, so the publishing, already-published and partial paths all leave it before any Stop propagates."
estimate: {tokens: 52000, tasks: 3}
actuals:
  tokens: 25353
  tasks: 3
  commits: 4
commits: 4
plan_head_before: be0aa9661e1f24f244916ffca1457fd934423802
plan_head_after: 2c792367c280056472734c1898d8feb57f5cbf3f
duration: "01:45 to 02:45 local (-04:00) on 2026-10-19, about 60 min, most of it test runs"
completed: 2026-10-19
---

# Phase 253 Plan 139: step-0 main preflight, no-run verdicts and the docs publication receipt Summary

**This closes the live half of blind spot #4. The fake now answers like GitHub did in 253-134. A conflicting or unmergeable R12 PR stops with GitHub's own reason. A main that moved after the freeze is checked offline before any request. A docs-only run leaves a publication receipt built from the ledger.**

- **The fake models 253-134 from real bytes.** The PR create response carries every key of the committed R11 sequence-5 body, read at test time, with `mergeable` null and `mergeable_state` "unknown". Its `base.sha` is the fake's current main, which defaults to the publication parent.
  - `pr_read` answers clean by default, false/"dirty" under `conflicted_head`, and null/"unknown" under `mergeability_unknown`.
  - Under those flags (and `no_run_while_mergeable`), workflow-runs never lists a run. The empty bodies equal the real R11 sequence-6 bytes `{"total_count":0,"workflow_runs":[]}`.
- **Step-0 preflight.** `ci-pr-proof.sh --main-preflight` is offline and exclusive-create, and exits 0 only for clean. An r12 `--family normal` requires a clean preflight file and re-derives it before any write or request. The evidence carries `base_preflight` with the file's `sha256`.
- **Main moving after the preflight is caught.** If the created PR's base differs from `base_preflight.current_main`, the window stops after `pr_create`.
- **No run gets a verdict.** Both discovery attempts empty → one `pr_read` (pr_identity) → one of three literal verdicts. The success path still uses pr_identity 3 + 5 = 8. `PRODUCTION_CATEGORY_LIMITS` and the budget document are unchanged, and a test asserts both.
- **The verifier requires the binding.** `verify_base_preflight` requires, for r12 normal evidence, a clean preflight for the freeze, head and frozen main. It also requires a 64-hex sha256 and the ledger pr_create `base.sha` equal to `current_main`. Docs-only must be `not_applicable`.
- **The docs receipt gap is closed.** `--docs-publication-receipt OUT` is now written on the publishing, already-published and partial paths, and a test re-derives it from the ledger.

There were zero GitHub requests, no fetches and no pushes. CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Task commits

| Task | Commit | Subject |
|---|---|---|
| 1 RED (tracer) | `8240e08e7` | test(253-139): a conflicting PR stops silently and a moved main goes unchecked (RED) |
| 1 GREEN | `380bccca3` | feat(253-139): step-0 main preflight and a specific verdict when GitHub makes no PR run |
| 2 | `46d967dc1` | feat(253-139): verify the step-0 main preflight against the created PR base |
| 3 | `2c792367c` | feat(253-139): write the docs publication receipt from the ledger |

- **Commit count.** `commits: 4` is measured with `git rev-list --count be0aa9661..2c792367c`. This SUMMARY's commit adds a fifth.
- **Diff size.** The range touches 6 files, +1014 / -32.
- **Single commits for Tasks 2 and 3.** These are tdd tasks, but the plan names one commit for each, so RED was run and recorded but not committed separately.

## RED -> GREEN

| Suite | RED (exit, result) | GREEN (exit, result) |
|---|---|---|
| ci-pr-proof.test.sh, entry 1 (unfixed collector, on `be0aa9661` + test edits) | exit 1: 94 tests, failures=22 errors=1. These are the 13 new tests plus R12RefPairTests and LivePolicyR12PRTests (their auto preflight needs the new mode). The replay is refused by argparse (exit 2). The moved-main family without a preflight is **accepted**: `AssertionError: 0 == 0 : no-preflight: accepted: {... "status": "freeze_valid"}` | exit 0: 95 OK (Task 1 verify) |
| ci-pr-proof.test.sh, entry 2 (unfixed + parsed option only) | exit 1: 94 tests, failures=23 errors=1. The replay is the **silent no-run**: `{"exit": 1, "requests": 7, "stop": "no pull_request workflow run was discovered for the published head"}`. The unknown and no-run-while-mergeable replays show the same stop. The moved-main test is accepted again. Also fired: the known 253-130 flake (see Deferred Issues) | (same GREEN run) |
| ci-hosted-gate-verify.test.py (Task 2 RED) | exit 1: 130 tests, failures=1 errors=19, all in the new PRBasePreflightTests (`AttributeError: ... no attribute 'verify_base_preflight'`, plus the source-wiring assertion) | exit 0: 130 OK |
| ci-pr-proof.test.sh (Task 3 RED) | exit 1: 100 tests, failures=4 errors=1, all in the new DocsPublicationReceiptTests (no receipt written; argparse rejects the flag) | exit 0: 100 OK |
| ci-hermetic-live-audit.test.py | after each code change: only moved `line` values, no unaudited site | exit 0: 36 OK |

- **RED receipt.** `253-LOAD-RECOVERY-PR-MERGEABILITY-RED-R12.json`, sha256 `252d65ae716b5828cd957fcb244ee3d36896698ed80d3f2f03cbf68568061037`, schema `sigra.phase253.red-receipt/r12`, `produced_on_head` `be0aa9661`.
  - It has two entries, both exit_code 1.
  - It also records `silent_no_run` (entry 2) and `unchecked_moved_main` (entries 1-2).
  - It was added in `8240e08e7`, which is an ancestor of the fix commit `380bccca3`.

## The three verdict strings (ci-pr-proof.sh `Collector.no_run_verdict`)

- `pull request #N has merge conflicts with its base (mergeable false, mergeable_state dirty); GitHub creates no pull_request run for it`
- `pull request #N mergeability is still unknown (mergeable null, mergeable_state unknown); GitHub has not created a pull_request run for it`
- `no pull_request run although pull request #N is mergeable (mergeable_state clean)`

The `mergeable_state` value is GitHub's own value, interpolated. The moved-between stop is `main moved between the step-0 preflight and PR creation: the created PR base is <sha>, the preflight current_main is <sha>`.

## Per-category request counts (hermetic, test-asserted)

| Path | preflight | pr_create | run_discovery | pr_identity | total |
|---|---|---|---|---|---|
| conflicted / unknown / mergeable-without-run (normal) | 4 | 1 | 2 | 1 | 8 |
| main moved again after the preflight (normal) | 4 | 1 | 0 | 0 | 5 |
| clean moved main, normal + docs-only success | within PRODUCTION_CATEGORY_LIMITS | 2 | 4 | **8** | <= 120 |

- **Refusals make no requests.** Every refusal leaves the server journal empty, writes no ledger and no evidence. This covers: no preflight, conflicted, rewritten, another freeze, another head, current main absent locally, a clean-claiming conflicted file, wrong schema, docs-only with a preflight, and a missing file.
- **The transport table is unchanged.** `ci-hosted-transport.py` `PRODUCTION_CATEGORY_LIMITS` equals the table at the 253-138 fix commit `8fa1e8e11` (loaded from `git show` at test time), and `pr_identity` stays 8.
- **The budget document is unchanged.** `253-LOAD-RECOVERY-BUDGETS.md` sha256 `87964f42…` equals the sha256 PR-FREEZE-R11 binds for it.

## Audit rows changed (253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json)

Only `line` values changed; ids, anchors, occurrences and coverage are unchanged. No new matcher site appeared. `audit_head` stays `a8213226f`.

| Row | Line before | Line after |
|---|---|---|
| pr-proof-132 | 164 | 190 |
| pr-proof-457 | 496 | 680 |
| verifier-1369 | 1427 | 1472 |
| verifier-1403 | 1461 | 1506 |
| verifier-1462 | 1520 | 1565 |
| verifier-1482 | 1688 | 1733 |
| verifier-1634 | 1840 | 1885 |
| verifier-1652 | 1858 | 1903 |
| verifier-1664 | 1870 | 1915 |
| verifier-1674 | 1880 | 1925 |
| verifier-1725 | 1931 | 1976 |
| verifier-1729 | 1935 | 1980 |
| verifier-1655-supplementary | 1664 | 1709 |

Final sha256: `bedafdc73423917fef155bcdcfbb203d790d1ee530967825ab3dd6fe0ea69c03`.

## Verify blocks (verbatim, run under bash from scratchpad script files)

- **Task 1 (tracer gate):** exit 0. pr-proof 95 OK and audit 36 OK. The block also passed:
  - the greps;
  - the transport-unchanged check (positive control: the 253-138 fix commit is found);
  - the budget-binding jq and the RED receipt jq;
  - the RED-before-fix ancestry with exactly one fix commit;
  - PRESERVATION-R12, config.json, state.json and a clean tree.
  This green re-run on the committed slice was the tracer feedback gate before expansion.
- **Task 2:** exit 0. Verifier 130 OK, pr-proof 95 OK, audit 36 OK.
- **Task 3:** exit 0. pr-proof 100 OK, publication 107 OK, transport 78 OK, verifier 130 OK, audit 36 OK, PRESERVATION-R12 clean.

## Earlier-test edits (harness only; every old assertion kept)

- **The PR fake.**
  - The create response now carries the real key set.
  - `base.sha` comes from `server.current_main`, which defaults to the parent.
  - `pr_read` adds mergeability.
  - Compare uses three-dot (`low...high`). This is identical to the old two-tree diff whenever the base is an ancestor of the head, as in every earlier universe. It is needed so a moved base lists only the head's changes, which is how GitHub compares.
- **The World helper.**
  - `World.set_current_main` and `World.main_preflight` are new.
  - `World.collect(main_preflight="auto", extra_args=())`: "auto" makes a CLI preflight for the fake's current main, and only for an r12 normal family. So R12RefPairTests and LivePolicyR12PRTests run unchanged; pre-r12 universes pass nothing.

## Deviations from Plan

1. **[Interpretation of a halt condition, same as 253-138] The RED replay uses the parsed-option shim (entry 2).**
   - **What the plan says:** the replay must fail on the generic no-run stop before the fix.
   - **What actually happens:** the unfixed CLI rejects `--main-preflight` at argparse.
   - **What I did:** entry 1 records that real refusal. Entry 2 records the unfixed logic with only the option parsed, which gives the generic stop after 7 requests. The shim was reverted immediately and never committed.
   - **Why no halt:** the moved-main RED needed no shim, because it fails by acceptance in both entries. If the orchestrator reads the condition strictly, the options are:
     - (a) accept the shim evidence;
     - (b) re-plan RED around a no-op option committed first;
     - (c) treat the plan as halted.
2. **[Rule 2 - strictness] Additions beyond the plan's list.**
   - **ci-pr-proof.sh:** refuses `--main-preflight` on docs-only and on pre-r12 freezes, and requires `frozen_main` to equal the freeze's `fetched_main_sha`.
   - **Verifier:** also checks schema, `frozen_main`, ancestor and moved consistency, and the merge_preflight body.
3. **[Rule 3 - fake fidelity] The fake's compare is three-dot** (see Earlier-test edits). Without it, a clean moved main would make the fake list main's own file in the PR diff, which GitHub does not do.
4. **[Own bug, fixed before the Task 2 commit] A misplaced `@fail_closed` decorator.** It ended up above the new constant (a SyntaxError), and the first audit refresh ran against that broken file. I restored the audit record with `git checkout` of that one file, moved the decorator back onto `verify_pr_family`, and re-ran the refresh. The refresh script now uses the checker's own `anchor_line`, so supplementary rows are refreshed too.

**Not done by design:**
- Per the orchestrator's hard constraints, the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, and WINDOWS.md and deferred-items.md were not written.
- The dry-run gates and the full dry-run suite were not run (that is 253-140). ci-gate-canary-dryrun.py does not invoke ci-pr-proof.sh.

## Deferred Issues

- **The known 253-130 load-dependent flake fired in 3 of 9 full pr-proof runs.** It hit `LivePolicyPRTests.test_live_policy_token_and_host_rules_hold_across_both_families`: the sleep log was `[60 x6, 0.001]`, from CPython `Popen._wait` busy-looping on the patched `time.sleep`. The three runs were RED entry 2, one pre-commit GREEN run and one pre-commit Task 3 suite pass.
  - That universe is pre-r12: `required_base_preflight` returns before any subprocess and nothing new runs on that path.
  - Control: in one window, an archive export of the pre-plan tree (`git archive be0aa9661`, not a worktree) passed the class 5/5, and this tree also passed 5/5. An earlier window on this tree gave 2 failures in 5, so the result is inconclusive about whether the frequency changed.
  - All three verify blocks passed on their first run. The flake is out of scope here (the test file is declared, but the flake predates this plan) and is not fixed.
- **The `shape-pr_create` and `shape-pr_read` response-shape rows are stale.** In the R12 audit they are still `justified` with "no create-PR response in any committed ledger". The committed R11 PR ledger now has a real pr_create 201 (sequence 5), and the collector now compares `mergeable` and `mergeable_state`. This plan only refreshes moved anchors, so the rows were not upgraded to real-shape-test. A later plan should cite R11 sequence 5 and add those two fields.

## Known Stubs

None.

## Threat Flags

None. The new outputs are local exclusive-create files. The diagnostic `pr_read` uses an existing route inside the existing pr_identity allotment.

## Handoff for the next plan

- **HEAD:** `2c792367c` (before this SUMMARY's commit). The tree is clean except config.json.
- **Preflight (253-144 step 0, after the approved fetch):**
  `bash scripts/ci/ci-pr-proof.sh --main-preflight --freeze <PR-FREEZE-R12> --current-main <fetched main SHA> --output <committed preflight path> --repo-root <checkout>`
  It exits 0 only for clean. Then pass `--main-preflight <that file>` to `--family normal` only, never to docs-only.
- **Docs receipt:** `--family docs-only ... --docs-publication-receipt <OUT>` (exclusive-create; OUT must not exist).
- **Verification:** `verify_pr_family` (and so `--verify` and `verify_pr_pair`) now requires `base_preflight` on r12 normal evidence and `not_applicable` on r12 docs-only evidence. 253-144 Task 4 can compare `.base_preflight.sha256` with the committed preflight file's bytes.
- **Record sha256s:**
  - RED-R12 mergeability receipt `252d65ae716b5828cd957fcb244ee3d36896698ed80d3f2f03cbf68568061037`
  - R12 audit `bedafdc73423917fef155bcdcfbb203d790d1ee530967825ab3dd6fe0ea69c03` (audit_head `a8213226f`)
  - PRESERVATION-R12 `72ea87c5c9fe7c7cb2a9798b20122a65435823dc1e04a9fdbc8d47c3344ad16d` (checks clean)
  - BUDGETS `87964f4234975c64967023f5ad37780c5bb29c871c704a5d2644fb3c8fe2fa0c` (unchanged)
- **Line refreshes:** later edits to ci-pr-proof.sh or the verifier move these rows again: pr-proof-132/457 and verifier-1369…1729 plus 1655-supplementary.

## Self-Check: PASSED

- **Files exist:** the RED receipt, this SUMMARY and the four modified scripts.
- **Commits are ancestors of HEAD:** `8240e08e7`, `380bccca3`, `46d967dc1` and `2c792367c`.
- **Invariants hold:** PRESERVATION-R12 clean, config.json sha256 `8e312f6c…`, state.json 70229 bytes with prefix `e45278c2cee0`, and no `scripts/ci/__pycache__`.
