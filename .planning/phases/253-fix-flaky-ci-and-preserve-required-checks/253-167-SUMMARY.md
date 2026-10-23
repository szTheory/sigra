---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "167"
subsystem: ci-reliability / hermetic-vs-live audit (R13)
status: halted
gap_closure: true
tags: [ci-reliability, load-recovery, hermetic-live-audit, pagination, review, projection, r13, r14, r15, halted]
requirements: [CIREL-02]
requirements-completed: []
requires: ["253-166 (complete)", "253-165 (complete)", "253-164 (complete)", "253-155 (halted; completed by R15)"]
provides:
  - "paginated_link_fields: rows of fetch_pages routes (parsed from ci-hosted-transport.py at check time) must compare header:link and meta:page_ordinal"
  - "link_forms_modelled(root): every rel=next/last destination in the committed window ledgers is the repos or the repositories-id form, and each observed form is emitted by a fake"
  - "the observed-routes rule reads CANARY-HTTP-LEDGER-R12"
  - "shape-check_runs compares header:link on the real R12 sequence-21 page"
  - "R13 unobserved_live_shapes: 15 entries, each with first_window 253-170 or 253-171 and a literal stop with file:line"
affects: ["253-168", "253-169", "253-170", "253-171", "253-172"]
tech-stack:
  added: []
  patterns: ["audit rules that read the product source and the committed ledgers at check time", "entry point taking a root path, run against a git-archived historical tree"]
key-files:
  created: []
  modified:
    - scripts/ci/ci-hermetic-live-audit.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R13.json
decisions:
  - "R15-FULL-SUITE trigger read as a fake emission line (the must_haves wording): 64c075d4b (253-166) matches /repos/ only in transport-route assertions, so it is listed but not counted"
  - "The canary attempt_jobs category has zero slack (7 of 7 in a full r13 run); recorded as an unobserved-shape stop, with no table change"
metrics:
  duration: "~1h55m (08:16Z-10:10Z)"
  completed: 2026-10-20
actuals:
  tokens: 13644
  tasks: 2
  commits: 4
plan_head_before: 85d17e98f0ee0b903f3642a058f3ed87719a51c5
plan_head_after: 3f1166de92bbacd2a8f67460aba10ead95a34cb2
---

# Phase 253 Plan 167: R13 pagination audit rules, unobserved shapes, review and projection Summary

**Halted at the Task 3 verify block.** Tasks 1 and 2 are complete, and every Task 3 check up to the defect passed. The block exited `VERIFY-EXIT 1` because of a defect in the block itself. It sets `N="$HOME/.asdf/installs/nodejs/20.18.1/bin/node"`, then reuses `N` for the full dry-run count (`N=$(sed -nE 's/^Ran ([0-9]+) tests? in .*/\1/p' …)`), then calls `"$N" scripts/ci/ci-registration-recovery.mjs …`. The shell tried to run the count as a command: `253-167-task3-verify.sh: line 2: 90: command not found`. The block fails this way on every tree, whatever the code does. A toy reproduction showed the same thing (`82: command not found`, rc 127; the positive control with a real binary gave rc 0). Per the contract, a nonzero VERIFY-EXIT is a real failure and is never re-run. The plan does not let me edit its verify block, so it halts here.

The fix for a successor plan: rename one of the two variables, for example `NODE` for the binary.

## Precondition (Task 1)

- The 253-166 SUMMARY is complete, PRESERVATION-R13 checks clean, and the tree was clean except config.json.
- R15 deadline guard, margin 1: `R13 canary deadline guard: margin 1 d, projected check_runs pages 4 of 10, canary deadline 2026-11-02T19:18:40.000Z`, exit 0.
- Positive control, margin 20: `projected check_runs pages 14 of 10`, exit 1.

## Task 1: pagination audit rules (RED e1e593863, GREEN 44ce53f4b)

Two rules added to the checker:

- **paginated_link_fields** (`check_paginated_link_fields`). The route set is parsed from the `fetch_pages` source line, `initial.get("route_id") not in {...}`, and test_page is removed. Parsed set: workflow_runs, rules_main, check_runs, run_jobs, run_artifacts, attempt_jobs, compare. The rule fails if check_runs or rules_main is missing from the set, and a set that cannot be parsed raises an error rather than passing.
- **link_forms_modelled(root)**. It reads the ledgers CANARY-HTTP-LEDGER-R7..R12, PR-HTTP-LEDGER-R11 and PROBE-HTTP-LEDGER-R11-PROBE. It reads rel=next/last links only; the dispatch `deprecation` links are ignored. Each destination is classified as `repos` (`^/repos/szTheory/sigra/`) or `repositories-id` (`^/repositories/[0-9]+/`, and the id must be 1207487684). Any other form fails. For each observed form, at least one fake source must emit it: ci-gate-canary-dryrun.py, ci-hosted-transport.test.py or ci-pr-proof.test.sh, grepped for the literal prefix, plus `1207487684` for the id form. If no ledger carries a link, the rule reports itself vacuous instead of passing.
- **Observed-routes rule.** `WINDOW_LEDGERS` now includes CANARY-HTTP-LEDGER-R12. WindowObservedRouteTests.EXPECTED gained the nine R12 routes. copy_audited_tree now copies the new ledgers and fakes.
- **Self-tests (12):**
  - PaginationRuleTests: the route set is parsed from the transport; R12 sequence 21 yields the repositories-id form; the committed record passes.
  - PaginationRulePositiveControls (9):
    - rules_main without header:link;
    - check_runs without meta:page_ordinal;
    - a route added to fetch_pages;
    - a renamed route-set line (the parse raises an error);
    - fakes with no /repositories/;
    - fakes with no repository id;
    - an unknown link form;
    - another repository id;
    - no link in any ledger (reported as vacuous).

### RED evidence

**Rule (1) on the record as 253-166 left it.** `Ran 66 tests`, `FAILED (failures=43)`. Most of the failures are positive-control setUps, which require the unmutated copy to pass. The record problems were:

- `shape-check_runs: route check_runs is paginated by fetch_pages but fields_compared lacks header:link (paginated_link_fields)`
- shape-workflow_runs, shape-run_jobs and shape-run_artifacts each lack header:link and meta:page_ordinal; shape-attempt_jobs lacks header:link; shape-compare lacks both.
- Control: shape-rules_main was **not** reported, because it already compares header:link.
- The R12 observed-routes rule: check_runs, create_ref, get_ref, git_create_commit, git_create_tree, git_get_blob, git_get_commit, rate_limit and rules_main each "observed live in window ledger …R12.json but the row cites none of its rows".

**Rule (2) on the pre-R13 tree.** I extracted `git archive 3bd9758a99c8a4c21cb261a43fe1cac16be3a6e5 scripts/ci .planning/phases/253-…` under `$TMPDIR` (it was never checked out in place) and ran `link_forms_modelled(<tmp>)`. It gave 1 problem, rc 1: `link form repositories-id observed live (…CANARY-HTTP-LEDGER-R12.json sequence 21: /repositories/1207487684/commits/09df342a…/check-runs) is emitted by no fake in [ci-gate-canary-dryrun.py, ci-hosted-transport.test.py, ci-pr-proof.test.sh] (link_forms_modelled: '/repositories/' with id 1207487684)`. On HEAD it gave 0 problems, rc 0. The temporary tree was deleted.

### GREEN rows (record only)

- **shape-check_runs** adds header:link after meta:page_ordinal. It adds the real sample {CANARY-HTTP-LEDGER-R12, sha256 f7d80a2b…0c0c, sequence 21, actual_status 200} and keeps its R8, R9, R11 and Phase 252 samples.
- **shape-workflow_runs, shape-run_jobs, shape-run_artifacts** add meta:page_ordinal, which resolves: the ledger transactions carry the key. They also add header:link, with fields_without_real_sample "no committed window has paginated this route".
- **shape-attempt_jobs** adds header:link in the same way. **shape-compare** adds header:link and meta:page_ordinal; both are reasoned, since no compare response exists.
- **Residual risk** on each of those five rows names the first window (253-170 or 253-171) and the transport stops: ci-hosted-transport.py:1041 (route), :1044 (query key) and :1047 (page step).
- **shape-rules_main** is unchanged: it already compares header:link, with its own reason.
- **R12 samples** were added for the nine routes the R12 window answered 2xx/3xx: rate_limit 18, rules_main 19, check_runs 21, git_get_commit 1, git_create_tree 2, git_create_commit 5, git_get_blob 7, get_ref 14, create_ref 13.
- **transport-1018** live_behavior now names both link forms. It now cites the three 253-146 live /repositories/ tests: test_live_check_runs_read_follows_three_repositories_id_pages_but_requests_only_the_approved_route, test_live_repositories_id_form_covers_workflow_runs_and_run_jobs_pagination, and test_live_repositories_id_form_refuses_every_other_id_route_host_page_or_query_before_a_second_request. No other 253-146 live-branch row exists: the id-form lines at :1036-1041 are not matcher sites.
- **audit_head** is e1e593863fa4d97cf52710c69d6dd0cb65cb4f00. The checker run: `Ran 66 tests`, `OK`.
- Task 1 verify: **VERIFY-EXIT 0**.

## Task 2: R13 unobserved live shapes (0d5ca0df8, refreshed in 3f1166de9)

There are 15 entries, all with first_window 253-170 or 253-171 and a literal stop.

- **Carried (10).** Each first window was retargeted: 253-143 became 253-170 and 253-144 became 253-171. I re-read each stop against the current source and corrected moved lines:
  - verifier :1274→1361, :1290→1377, :1310→1397, :1318→1405, :1338→1425, :1340→1427, :1373→1460, :1404→1491, :1353→1440, :1359→1446, :1209→1296, :1256→1343;
  - transport :625→628;
  - driver :916→926.
  - The step-0 entry now names the 253-171 runner.
  - The canary failure_logs 6/6 zero-slack entry is otherwise unchanged.
- **New (5):**
  - `check_runs-next-link-query-keys` (253-170): "pagination link has an unapproved or repeated query key" (ci-hosted-transport.py:1044); a wrong page step stops at :1047.
  - `check_runs-server-parent-pages-2-plus` (253-170): "native check source identity differs across duplicate runs" (ci-hosted-gate-verify.py:335); "pagination link changed its approved API route" (ci-hosted-transport.py:1041); "native check source run is not of the frozen source commit" (ci-hosted-gate-verify.py:328).
  - `check_runs-main-nightly-growth` (253-170): 55/day, from the only complete day on 253-143's page 1 (2026-10-18), starting at 209. The effective ceiling is 10 pages: MAX_CHECK_RUN_PAGES = 10 at ci-hosted-gate-verify.py:269 binds, and the allocation's max_pages of 12 does not. The stops are:
    - before the window, "STOP: projected check_runs pages exceed the preflight budget" in 253-R13-CANARY-OPERATOR.sh, which 253-170 writes (no line yet; zero requests);
    - an eleventh page is charged and then refused with "native check-run pages exceed the allocation's max_pages" (ci-hosted-gate-verify.py:301);
    - twelve or more pages hit category_budget_exhausted on preflight (ci-hosted-transport.py:628) inside the driver's read (ci-gate-canary.sh:766).
  - `check_runs-pr-head-over-100` (253-171): "native check-run response is incomplete or needs another charged page" (ci-hosted-gate-verify.py:302). This includes carry-forward finding (1): the collector still finishes `collected` with exit 0 (ci-pr-proof.sh:721), so the refusal surfaces at verification, not collection.
  - `paginated-listing-two-page` (253-170, also 253-171): the one transport rule, :1041/:1044/:1047. The review refresh (below) added the zero-slack attempt_jobs stop.
- No entry names a shape 253-143 observed (rate_limit, rules_main, branch_protection, check_runs page 1).
- Task 2 verify: **VERIFY-EXIT 0**.

## Task 3: review, projection, regression

### Review findings and dispositions

| # | Item | Result | Disposition |
|---|---|---|---|
| 1 | /repositories/ acceptance in the live branch only | The only transport hunk in `_next_page_url` is after both hermetic returns. The id path is `/repositories/{GITHUB_REPOSITORY_ID}/{suffix}`, where the suffix is the approved path minus `/repos/szTheory/sigra/`, and an unprefixed path is refused. `next_url` is used only for termination and cycle detection (:945-973). Each request is `dict(initial)` plus `page`. No code path requests a Link URL. | pass |
| 2 | Hermetic branches unchanged since ee7c53765 | 0 changed lines mention hermetic. Positive control: 2 changed lines carry id_path. | pass |
| 3 | Duplicate rule only on the server-parent source; PR-head rule unchanged; strict head_sha | `server_parent_native_sources` is called only when `check_source`. Its head_sha check is strict (`run.get("head_sha") == sha`, with no when-present branch). The PR-head loop keeps "missing or duplicated". Observation: the PR-head page check is now `check_run_page_set`, which accepts a complete single page of exactly 100 (the old rule was `< 100`). Still fail-closed, since union must equal total_count. | pass (observation recorded) |
| 4 | retained_preflight is one contiguous read | Ordinals 1..n, all 200, one commit captured from the URL (null is refused), and n = max(1, ceil(total/100)) from page 1. | pass |
| 5 | r13 pair and head are exact strings; one main-freshness pair set | REF_PAIRS r13, PR_HEAD_REFS, NORMAL_HEADS, PR_NORMAL_HEADS and MAIN_RECORD_HEADS all use exact literals. `MAIN_FRESHNESS_PAIRS = ("r12", "r13")` is used by both build_freeze and check_revision_freeze. | pass |
| 6 | Legacy tables byte-unchanged since FREEZE-R12 (74857cfe0) | CANARY_CATEGORIES, PRODUCTION_CATEGORIES and PRODUCTION_CATEGORY_LIMITS are identical (CANARY block non-empty: 5 lines). CANARY_CATEGORIES_R13 has preflight 16, infrastructure_retry 5, others equal, sum 117, and is selected only for r13 via PAIR_CANARY_CATEGORIES. | pass |
| 7 | No new network path | The dry-run reads the R12 ledger with `read_bytes()` only, and there is no urlopen, http.client or create_connection in it. | pass |
| 8 | --repos-link-form knob | Refused without --live-policy plus --transport-from (`parser.error(REPOS_LINK_FORM_SCOPE)`, :2154); refused for a transport with `GITHUB_REPOSITORY_ID == 1207487684` (:1866-1870); refused with --paged-listings (:2151-2152). The default live base line is byte-identical at 7b653d6ad, fe0730aa5, 89b8c8618, 31782efcf, b5313790c, 87b30a3c7, 840c7f4a4 and HEAD. Default-path summaries showed `link_form_override: null` in the hermetic, live and paged runs. | pass |
| 9 | Zero-slack attempt_jobs in the canary table | Running `--live-policy --paged-listings --ref-pair r13` with r8-r12 seeds as a **full** run gave `status failed`, stop `ci-hosted-transport: category_budget_exhausted: category attempt_jobs allocation is exhausted`. A default full r13 run spends attempt_jobs 7 of 7, and the forced extra page makes 8. In 253-165's scoped form (`--stop-after full-pass`) it **passes**: check_runs 3 pages, run_jobs 2 and run_artifacts 2, all repositories-id, with shim_refusals 0, violations 0 and blob_with 0. The product behaviour is correct (fail-closed). A real second jobs page is not expected: 35 jobs against per_page 100. | Recorded as a stop on `paginated-listing-two-page` (3f1166de9). No table change; Jon approves the table at 253-170. |
| 10 | R15-FULL-SUITE (commits since 31782efcf touching the three fake files with a Link/Location/repositories/repos line) | See the table below. | pass |

R15-FULL-SUITE table:

| Commit | Plan | Matching lines | SUMMARY full-suite record |
|---|---|---|---|
| 87b30a3c7 | 253-164 | 8 | `Ran 78 tests in 4822.597s, OK` (gate 78 or more) |
| 840c7f4a4 | 253-165 | 9 | `Ran 82 tests in 4375.693s` and `OK` (gate 79 or more) |
| 69978462e | 253-165 | 8 | same record |
| b210be31a | 253-165 | 5 | same record |
| 64c075d4b | 253-166 | 3, all `assertEqual(..._route(...)[3], "/repos/szTheory/sigra/pulls" or "/git/refs")` in ci-hosted-transport.test.py | none (253-166 PLAN: "R15-FULL-SUITE does not bind here") |
| 40e13c178, 3e3111f52, d5f83ba01 | 253-166 | 0 | n/a |

The 64c075d4b lines check the transport's own route template for the r13 head. They are not a fake emitting a Link header, route path, Location or host, which is the must_haves trigger ("emission line"). They were therefore not counted as a halting finding. This plan's own full suite ran at HEAD, after them, and passed (below). **This is a judgement call:** a strict literal reading of the Task 3 action ("adds or removes a line matching") would make it a halting finding. The plan is halted either way.

No product file was changed in this plan. `git diff --name-only 85d17e98f HEAD -- scripts/ci` lists only scripts/ci/ci-hermetic-live-audit.test.py.

### Early publication projection (review run, then again inside the verify block, both ok)

| | R13 (HEAD, on fetched main 09df342a) | R12 (253-141) |
|---|---|---|
| status | ready-local-proposal | ready-local-proposal |
| projected_total_requests | 17 of 22 (max_requests 24) | 17 of 22 |
| tree_request_count | 4 | 4 |
| binary_blob_requests | 0 | 0 |
| largest_tree_body_bytes | **2,096,775** of 2,097,152 | 2,082,931 |
| tree_requests[].body_bytes | 2,094,034 / 2,096,775 / 1,513,109 / 17,686 | (largest 2,082,931) |
| main_freshness | fetched_main_sha 09df342a, merge_preflight.clean true | clean |

The largest tree body is within the cap, but the margin is now **377 bytes**; it was 14,221 at R12. Any growth in the packed product delta before the 253-168 freeze is likely to exceed 2,097,152 and trip the 253-140 Task 3 fallback. This is flagged for 253-168, not a halt here.

### Regression (Task 3 verify block, verbatim, long-run protocol)

- Run under `caffeinate -i -s` in the background, from 2026-10-20T08:42:21Z to about 10:06Z. `pmset -g ps` first line: `Now drawing from 'AC Power'`. The block's text was confirmed byte-equal to the plan's third `<automated>` element.
- In the order the block ran them:
  - projection: ok;
  - hermetic r13 gate (preflight 7, seeded_r12_refs_changed false): passed;
  - live-policy r13 gate: passed;
  - ci-hermetic-live-audit: `Ran 66 tests`, OK;
  - ci-git-publication.test.py: `Ran 118 tests`, OK;
  - ci-hosted-transport.test.py: `Ran 85 tests`, OK;
  - ci-shape-probe.test.py: `Ran 19 tests`, OK;
  - ci-pr-proof.test.sh: `Ran 110 tests`, OK. The known flake LivePolicyPRTests.test_live_policy_token_and_host_rules_hold_across_both_families did not fire;
  - ci-hosted-gate-verify.test.py: `Ran 151 tests`, OK;
  - ci-gate-canary-flow.test.py: `Ran 23 tests`, OK;
  - **full ci-gate-canary-dryrun.test.py (no filter): 90 tests, OK.** The count comes from the failing line `90: command not found`, since N held the count. The block passed its own `test "$N" -ge 79` and `grep -q '^OK'` gates, then deleted the log;
  - the 253-164 and 253-165 SUMMARY greps, the default live base line grep and the paged/knob refusal grep: pass;
  - ci-gate-canary.test.sh: pass;
  - ci-gate-canary-recovery.test.py: `Ran 5 tests`, OK;
  - then `"$N" scripts/ci/ci-registration-recovery.mjs …` → `90: command not found` → **VERIFY-EXIT 1**.
- **Diagnostic only, not a verify substitute and not a re-run.** I ran the unexecuted tail with the node path in a separate `NODE` variable:
  - --require-target-disposition rc 0;
  - --require-target-accepted rc 3 (expected 3);
  - v1 reconcile --check-only rc 0;
  - r2 through r12 check-only all 0;
  - R13 table predicate rc 0;
  - product files since the rows commit: none;
  - PRESERVATION-R13 clean;
  - config.json sha256 8e312f6c…, state.json 70229 bytes;
  - tree clean except config.json.

## Deviations from Plan

1. **[Rule 1 - record] Carried stop lines refreshed.** The plan said to keep each stop "with its current file:line", and twelve verifier lines, one transport line and one driver line had moved, so I updated them. Record only.
2. **[Review fix, declared file] Zero-slack attempt_jobs.** Added as a stop on `paginated-listing-two-page` (commit 3f1166de9, "R13 audit line refresh after review").
3. **Review-only runs outside the verify block.** Before the verify, I ran the hermetic, live and live `--paged-listings` r13 gates once, for link_form_override and paginated_reads. Because the paged full run failed, I re-ran that gate once to read its stop. That re-run was a diagnostic, not a verify block. I also ran a default live run (attempt_jobs 7 of 7) and the scoped `--stop-after full-pass` paged run (passed).
4. **No source change to the verify block.** The N collision was not fixed (see the halt).

## Halt record

- **Cause:** a defect in the Task 3 verify block: `N` holds both the node binary and the dry-run test count. This is not a product or code finding.
- **Next step:** a successor plan reruns the Task 3 verify with the binary variable renamed (for example `NODE`). It should also re-decide whether the live `--paged-listings` gate is meant as a full run (which fails closed on the zero-slack attempt_jobs 7) or the 253-165 `--stop-after full-pass` form, and watch the 377-byte tree-body margin before the 253-168 freeze.
- **Carry-forward (2):** the known flake did not recur in this plan's runs. It was not acted on, since this plan does not permit it.
- Zero GitHub requests, fetches or pushes. Full Phase 253 verification stays not_started.

## Commits

- e1e593863 test(253-167): pagination audit rules (RED on check_runs and the unmodelled link form)
- 44ce53f4b docs(253-167): R13 pagination rows on the real 253-143 page
- 0d5ca0df8 docs(253-167): R13 unobserved live shapes with their stops
- 3f1166de9 docs(253-167): R13 audit line refresh after review

## Self-Check: PASSED

- The files exist: scripts/ci/ci-hermetic-live-audit.test.py and 253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R13.json.
- Commits e1e593863, 44ce53f4b, 0d5ca0df8 and 3f1166de9 are ancestors of HEAD.
- The halt is recorded as status halted.
