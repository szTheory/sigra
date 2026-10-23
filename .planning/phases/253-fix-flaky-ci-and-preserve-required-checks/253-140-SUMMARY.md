---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "140"
subsystem: ci-reliability / hermetic-vs-live audit, R12 review and publication projection
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, hermetic-live-audit, review, projection, r12]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-139 PR fake on the real R11 sequence-5 key set and the no-run verdicts; 253-138 merge_preflight and --main-record; 253-136 MAIN-FETCH-R12; the committed R11 canary (253-133) and PR (253-134) ledgers"
provides:
  - "ci-hermetic-live-audit.test.py check_fields_backed: every compared field is backed by a hash-, route-, sequence- and status-checked real sample, or has a per-field reason plus a residual risk"
  - "check_window_observed_routes: every 2xx/3xx route in CANARY-HTTP-LEDGER-R11 and PR-HTTP-LEDGER-R11 has a real-shape-test row that cites one of that window's own rows"
  - "PR_BODY_KEYS (pr_create, pr_read) enforced against fields_compared. A code scan (PR_READ_REGIONS) and a grep keep the list in step with ci-pr-proof.sh and the verifier in both directions"
  - "R12 audit: shape-pr_create real-shape-test on R11 PR seq 5; shape-pr_read justified, with the mergeability fields and a 253-144 residual risk; shape-cancel_run real-shape-test on R11 canary seq 73; every R11-observed route cites its window sample"
  - "R12 unobserved_live_shapes: ten entries, each with a 253-143/253-144 first window and a literal stop with file:line"
affects: ["253-141", "253-142", "253-143", "253-144"]
tech-stack:
  added: []
  patterns:
    - "A route that a committed window ledger saw answer 2xx/3xx must rest on that window's own bytes, not only on older ledgers."
    - "The list of response keys the code reads comes from a scan of the code's read sites, so a new read fails the checker until it is modelled."
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-140-SUMMARY.md
  modified:
    - scripts/ci/ci-hermetic-live-audit.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json
key-decisions:
  - "The window observed-route rule uses the stricter reading: each R11-observed route must cite a row of the R11 window ledger that observed it, not just any committed ledger. Truth 2 requires this ('every route 253-133 observed live ... cites its R11 canary ledger sample'), and it implies the weaker form in the behavior bullet."
  - "fields_backed is the existing per-field resolution, moved into check_fields_backed. Its one tightening is that a reasoned field now needs a residual_risk on any row, not only on a justified one."
  - "PR_BODY_KEYS lists mergeable and mergeable_state for pr_create as well as pr_read. GitHub returns them on create (null and 'unknown' in 253-134), and the PR fake models them from those bytes."
  - "pr_read also lists value:mergeable=False and value:mergeable_state=dirty, the conflict values no_run_verdict branches on. None of its fields has a real sample ('253-134 stopped before pr_read')."
  - "unobserved_live_shapes now lists exactly the R12 set the plan names. Four R11 entries that no R12 window will exercise (branch_protection 200, git_create_blob, git_get_tree, job_logs hop 1) are dropped from the list. Their rows keep their justification and residual risk, and the projection shows binary_blob_requests 0, so 253-143 does not call git_create_blob."
estimate: {tokens: 42000, tasks: 3}
actuals:
  tokens: 20805
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 89a3a62706a789a62401bae5fb5c6476b9710bb2
plan_head_after: ee90cfa4d9a2822135bc5725007235ca5da26987
duration: "06:45Z to 08:12Z on 2026-10-19, about 87 min, 56 min of it the dry-run suite"
completed: 2026-10-19
---

# Phase 253 Plan 140: fields_backed audit rule, R12 rows on real R11 bytes, final R12 review and projection Summary

**The audit checker now fails whenever the code compares or branches on a response field that is not modelled on committed real bytes. On the record as 253-139 left it, the checker fails on exactly the blind spot #4 rows. pr_create now rests on the real 253-134 create response, and every route the R11 windows observed cites that window's bytes. Each remaining R12 unknown is named with its fail-closed stop. The review of all R12 product code found nothing to fix. The publication still fits the budget on fresh main 09df342a, using 17 of 22 requests, and the full offline regression passes.**

There were zero GitHub requests, no fetches and no pushes. CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Task commits

| Task | Commit | Subject |
|---|---|---|
| 1 RED (tracer) | `e2f7054a4` | test(253-140): fields_backed audit rule (RED on pr_create and pr_read) |
| 1 GREEN | `cb32f8b9d` | docs(253-140): R12 audit rows on the real R11 samples |
| 2 | `ee90cfa4d` | docs(253-140): R12 unobserved live shapes with their stops |
| 3 | (none) | The review changed no file and no audit line moved, so the line-refresh commit was skipped as the plan allows |

- **Commit count.** `commits: 3` is measured with `git rev-list --count 89a3a6270..ee90cfa4d`. This SUMMARY's commit adds a fourth.
- **Diff size.** 2 files, +740 / -159.
- **Product files.** No product file changed. `git diff --name-only cb32f8b9d HEAD -- scripts/ci` is empty, and the Task 3 verify asserts it.

## Task 1: the rule, RED then GREEN

**The new rules in ci-hermetic-live-audit.test.py:**
- `check_fields_backed`. Every `fields_compared` entry resolves in a loaded real sample, or has a reason in `fields_without_real_sample`, and then `residual_risk` must be non-empty. A `meta:` field resolves against the ledger transaction and a `header:` field against `scrubbed_headers`. A fabricated locator loads nothing, so it backs nothing and is reported. That covers a wrong path, sha256, sequence, route or status.
- `check_window_observed_routes`. This works over `WINDOW_LEDGERS_R11` (CANARY-HTTP-LEDGER-R11 and PR-HTTP-LEDGER-R11). Every route with a 2xx/3xx row needs a real-shape-test row that cites one of that ledger's 2xx/3xx rows for the route. A missing ledger is reported as a vacuous rule.
- `PR_BODY_KEYS`. Each listed key must be in its route's `fields_compared`.
  - pr_create: number, state, draft, merged, head.ref, head.sha, head.repo.full_name, base.ref, base.sha, base.repo.full_name, mergeable, mergeable_state.
  - pr_read: the same keys plus merge_commit_sha.
- `REAL_SAMPLE_MARKER` now also accepts `R11_PR_LEDGER`, `R11_CANARY_LEDGER`, `REAL_CREATE_KEYS`, `R11_EMPTY_DISCOVERY_BODY` and `window_ledger_tx(`.

**New self-tests (18 tests; the file went from 36 to 54):**
- **FieldsBackedTests (4).** Every PR row lists every consumed key. Three tests compare real bytes, and the rows cite them:
  - R11 PR seq 5 carries every pr_create key. Its values are open, draft, unmerged, mergeable null, mergeable_state "unknown" and merge_commit_sha present but null. Positive control: `mergeable_statez` does not resolve.
  - Seq 6 and 7 are exactly `{"total_count":0,"workflow_runs":[]}` for `event=pull_request&head_sha=2b239a98…`.
  - R11 canary seq 73 matches the typed `cancel_run` route: POST, 202, body `{}`, and the driver's 202 check (ci-gate-canary.sh:898).
- **FieldsBackedPositiveControls (5).** Each of these makes the checker fail:
  - pr_read without mergeable, mergeable_state or merge_commit_sha;
  - pr_create without mergeable_state;
  - a fabricated pr_create sample (wrong sha256, sequence 6, status 200, or a missing path), which also leaves mergeable_state unbacked;
  - an unbacked `meta:` or `header:` field;
  - a reasoned field without a residual risk. The same field with a residual risk is well-formed, as a control.
- **WindowObservedRouteTests (2).** The observed-route map of both ledgers equals the expected map, which is the positive control on the rule's input. Both ledgers are tracked by git. Every real-sample path is a committed file; the control is that an uncommitted path is refused.
- **WindowObservedRoutePositiveControls (4):**
  - cancel_run reverted to justified;
  - pr_create without its seq-5 sample;
  - a run_logs window locator on seq 46;
  - the PR ledger removed, which is reported as vacuous.
- **PRBodyKeysTrackTheCodeTests (3).**
  - Every listed key's leaf is quoted in ci-pr-proof.sh or the verifier. Positive control: `mergeable_state` is found in ci-pr-proof.sh. Negative control: `mergeable_statez` is not found.
  - Every PR-body read in four delimited regions is listed. The regions are the collector's pr_create→pr_read stretch, `no_run_verdict`, the verifier's `check_pr`/`verify_pr_family` stretch and `verify_base_preflight`'s created-base line. Positive controls: the scan sees mergeable, mergeable_state, merge_commit_sha, base.sha, head.repo.full_name, number and draft.
  - An injected `(pr or {}).get("rebaseable")` is caught. A renamed region anchor raises an error rather than producing a silent empty scan.

**RED** (on `89a3a6270`'s record plus the new checker, run in the foreground; `__pycache__` deleted after):
- Exit 1: 54 tests, failures=37. The record has 29 problems. The 33 control tests fail in setUp, which asserts that the unmutated record passes. The two PRBodyKeys tests and the three real-bytes tests pass.
- **shape-pr_create:**
  - mergeable not listed;
  - mergeable_state not listed;
  - observed live in PR-HTTP-LEDGER-R11 seq 5, but coverage is `justified`;
  - the row cites none of rows [5].
- **shape-pr_read:** mergeable not listed; mergeable_state not listed.
- **shape-cancel_run:** observed live (canary seq 73) but justified, and cites none of [73].
- **Canary rows citing no R11 canary row (16):** artifact_zip, check_runs, create_ref, dispatch, get_ref, git_create_commit, git_create_tree, git_get_blob, git_get_commit, rate_limit, rules_main, run, run_artifacts, run_jobs, run_logs, workflow, workflow_runs.
- **PR rows citing no R11 PR row:** rate_limit [1], rules_main [2], workflow [4], workflow_runs [6, 7].

**GREEN** (record rows only; `audit_head` is set to the RED commit `e2f7054a4`, which the checker requires to be an ancestor of HEAD):

| Row | Change |
|---|---|
| shape-pr_create | real sample PR-HTTP-LEDGER-R11 sha256 `9e896130…76fcf` seq 5 (201). Adds mergeable and mergeable_state. Class `real-shape-test`. The refs are the audit's seq-5 test and the pr-proof `test_a_clean_moved_main_collects_both_families_inside_the_production_budget` (REAL_CREATE_KEYS). The "never observed" text and the nearest sample are dropped. The residual risk keeps the operator-close note and adds the moved-main stop |
| shape-pr_read | Adds mergeable, mergeable_state, `value:mergeable=False` and `value:mergeable_state=dirty`; merge_commit_sha was already listed. Still `justified`, with every field "253-134 stopped before pr_read". The residual risk is the plan's text verbatim (it names 253-144). The nearest sample is the PR seq 5 create (shows mergeable_state) |
| shape-workflow_runs | Adds R11 canary seq 25 and PR seq 6 and 7 (the empty pull_request bodies), and the audit's discovery test ref |
| shape-cancel_run | real sample canary seq 73 (202). `real-shape-test` with the audit's cancel test. The residual risk says observed in 253-133 and keeps the three stops |
| shape-dispatch | Adds canary seq 24 and 78 (the verifier dispatch). `meta:dispatch_inputs.matrix_evidence` now resolves, so it leaves `fields_without_real_sample` |
| shape-run | Adds canary seq 27, 54, 64 and 75 (full-pass, missing-seam, unexpected-skip, cancelled). The residual risk is rewritten |
| shape-run_logs | Adds canary seq 47 and 48 (fresh-run hop 0 302, then the results-receiver hop 1 200). The residual risk no longer calls the fresh run unobserved |
| shape-source-canary-fixture | Adds canary seq 82 (route run_jobs). The verifier steps and `producer (${{ matrix.seam }})` now resolve, so all three of its without-sample fields go |
| others | One R11 canary sample each: git_get_commit 1, git_create_tree 2, git_create_commit 5, git_get_blob 7, get_ref 14, create_ref 13, rate_limit 18 (+ PR 1), rules_main 19 (+ PR 2), check_runs 21, workflow 22 (+ PR 4), run_jobs 28, run_artifacts 29, artifact_zip 30 and 31. rate_limit's last sentence notes both R11 windows |

After GREEN the checker reports 0 problems and passes 54 tests.

## Task 2: R12 unobserved_live_shapes

**Removed as observed.** These six were observed by 253-133: shape-cancel_run, shape-run_logs-fresh-run, workflow-source:canary-fixture, shape-dispatch-matrix_evidence, scenario-missing-seam-run and scenario-unexpected-skip-run. shape-pr_create was observed by 253-134. All their rows now cite the sample.

**Dropped as not exercised by any R12 window.** These are shape-branch_protection-200, shape-git_create_blob (projection binary_blob_requests 0), shape-git_get_tree and shape-job_logs-hop-1. See the key decisions.

**The ten R12 entries.** Every cited line was asserted against the tree when the list was written.

| id | row | first window | stop |
|---|---|---|---|
| shape-pr_read-real-pr | shape-pr_read | 253-144 | Collector: 'the PR has no tested merge commit or base identity' (ci-pr-proof.sh:636). Verifier: check_pr 'read PR is not the same open unmerged draft PR' (verify:1274) and 'PR has no distinct tested merge commit' (verify:1290) |
| shape-compare-tested-merge | shape-compare | 253-144 | 'compare file inventory is empty, malformed or incomplete' (verify:1310); docs 'docs-only head is not one commit ahead of the docs base' (verify:1318) |
| shape-repo_contents-tested-merge | shape-repo_contents | 253-144 | 'source read is not a base64 file response' (verify:1338) / 'source blob differs from the frozen blob' (verify:1340) |
| shape-attempt_jobs-pr-head | shape-attempt_jobs | 253-144 | 'job page is not for the terminal run attempt' (verify:1373) |
| shape-check_runs-pr-head | shape-check_runs | 253-144 | 'native check is not a successful check of the PR head: <name>' (verify:1404) |
| shape-workflow_runs-populated-pull_request | shape-workflow_runs | 253-144 | Collector takes only a run with the head_sha and event pull_request (ci-pr-proof.sh:613), otherwise a no_run_verdict stop (ci-pr-proof.sh:664). Verifier: 'exactly one discovered pull_request run for the PR head is required' (verify:1353) and 'run is not the actual PR workflow run for the published head' (verify:1359) |
| shape-pr_read-conflicted-pr | shape-pr_read | 253-144 | no_run_verdict (ci-pr-proof.sh:664): the conflict, unknown or mergeable verdict, each a stop |
| step-0-moved-clean-main | step-0 main preflight | 253-144 | A conflicting move stops before any request at step 0: --main-preflight exits 1 (ci-pr-proof.sh:335) and --family normal refuses ('the step-0 main preflight is not clean', ci-pr-proof.sh:370). A move during the window stops after pr_create with 'main moved between the step-0 preflight and PR creation' (ci-pr-proof.sh:607) and leaves one open draft PR for Jon. The verifier binds the base (verify:1209) |
| docs-only-scoped-ref-publication | shape-create_ref | 253-144 | publish_docs tree/commit/readback/ref stops (ci-pr-proof.sh:533, 537, 540, 549); verifier 'scoped docs refs were not created exactly once from absent and read back' (verify:1256) |
| canary-failure_logs-zero-slack | shape-run_logs | 253-143 | category_budget_exhausted at the predebit (ci-hosted-transport.py:625), then 'failed-log retrieval failed for run <id>' (ci-gate-canary.sh:916). Carried from R11 unchanged at 6 of 6; 253-133 used exactly 6 |

## Task 3: review of every R12 product change (253-137..139)

The scope was `git diff a8213226f 2c792367c` over ci-gate-canary-dryrun.py, ci-git-publication.py, ci-hosted-gate-verify.py, ci-hosted-transport.py and ci-pr-proof.sh. ci-gate-canary.sh is unchanged in that range.

| # | Check | Result | Disposition |
|---|---|---|---|
| 1 | The r12 pair and head are exact strings in the four sites, and nothing else widened | Each site adds only the literal `gsd/253-replan-r12-candidate`: publisher REF_PAIRS (with `-r12-fixture`), verifier PR_NORMAL_HEADS, transport PR_HEAD_REFS and pr-proof NORMAL_HEADS. The only transport change is PR_HEAD_REFS. ROUTES, hosts, categories and patterns are untouched | pass |
| 2 | The dry-run r12 derived freeze satisfies the main-freshness guard with no skip | Under `if args.ref_pair == "r12"`, a synthetic record (`synthetic: true`, fetched_main_sha = its server parent) is committed only in the temporary clone. Only the clone's `refs/remotes/origin/main` is updated, the real `--main-record` is passed, and there is no skip or override flag | pass |
| 3 | merge_preflight is the only merge-tree call site | The only `merge-tree` invocation in product code is ci-git-publication.py:396 inside `merge_preflight` (positive control: the helper at :389 and its callers pr-proof :174, :303 and publication :454 are found). Exit 0 is clean, exit 1 must name paths, and any other exit, a missing commit or a malformed first line raises. The pr-proof step-0 wraps a raise as `clean: false` with an `error` string | pass |
| 4 | No new network path | `--main-preflight`, the family refusals and `--prepare` leave the fake journal unchanged (pr-proof tests at :2770, :2843, :1414-1439). No product script contains `git fetch` or `ls-remote` (control: it is found in 253-R12-MAIN-FETCH-OPERATOR.sh) | pass |
| 5 | Diagnostic pr_read only on the failure path; category tables unchanged | `no_run_verdict` is called only under `if run_id is None`. The Task 3 verify's diff of PRODUCTION_CATEGORY_LIMITS / CANARY_CATEGORIES and the per-category lines since the 253-136 fetch commit is empty (control: the commit is found) | pass |
| 6 | The verifier reads the created base from ledger bytes; pre-R12 fixtures unchanged | `verify_base_preflight` reads `tx_json(creates[0]).base.sha` from the ledger. `git diff --name-status a8213226f HEAD -- .planning/` lists only added files | pass |
| 7 | The docs receipt is derived only from ledger rows | `docs_publication_receipt` builds rows, refs, commits and complete from `self.ledger()` docs_publication transactions. Only `freeze_sha256` comes from the freeze, as its identity binding (253-139 decision) | pass |
| I-1 | (informational) `check_revision_freeze` still says "(legacy or r8)" when the ref pair is unknown | Stale wording that predates R12; it still refuses | not fixed (product file); no behavior impact |
| I-2 | (informational) `write_docs_receipt` runs in a `finally`; an exclusive-create failure there would mask the original stop | Existence is refused up front in run_family, so only a race could trigger it. It still stops either way | not fixed (product file); fail-closed |

No finding was accepted for a fix, so the plan did not halt.

## Early publication projection (no commit; output deleted)

The command was the plan's `--prepare` on HEAD `ee90cfa4d`, with `--server-parent 09df342a82e03c3d5d40173c912b70e827f7eadc` and `--main-record` MAIN-FETCH-R12. Local `refs/remotes/origin/main` = `09df342a` (checked first).

| | R12 (this run) | R11 (CANARY-PUBLICATION-R11) | Limit |
|---|---|---|---|
| status | ready-local-proposal | ready-local-proposal | ready |
| server parent | 09df342a | 84ebcea60 | MAIN-FETCH-R12 fetched_main_sha |
| projected_total_requests | 17 | 17 | <= 22 |
| tree_request_count | 4 | 4 | |
| binary_blob_requests | 0 | 0 | <= 10 |
| largest_tree_body_bytes | 2,082,931 | 2,094,030 | <= 2,097,152 (headroom 14,221) |
| tree bodies | 2,070,800 / 2,082,931 / 1,404,652 / 17,686 | 2,001,252 / 2,094,030 / 1,278,302 / 17,686 | each <= 2,097,152 |
| fixed / parent preflight | 12 / 1 | 12 / 1 | |

- **main_freshness:** fetched_main_sha `09df342a…`, record_sha256 `35fd1543…515b90e`, candidate_parent_is_fetched_main true, and merge_preflight clean (exit 0, no conflicts).
- **Merge-preflight head.** The candidate helper commit is `8360fa1a…`. An identical run after Task 1 (HEAD cb32f8b9d) gave the same numbers, with head `2263acc4…`.
- **No fallback needed.** The fallback was not triggered, and no cap, table or parent was touched.

## Verify blocks (verbatim, extracted to scratchpad scripts, run under bash)

- **Task 1:** exit 0. Audit 54 OK. The block also checked the greps, the pr_create and pr_read jq, the RED commit before the rows commit, PRESERVATION-R12, config.json and a clean tree. This green re-run on the committed slice was the tracer feedback gate.
- **Task 2:** exit 0. Audit 54 OK. The block confirmed ten entries, each with a first window and a stop, a moved-main entry, and no pr_create entry.
- **Task 3:** exit 0. It ran under `caffeinate -i -s` in the background with polling, because the tool caps a foreground run at 10 minutes. The run took about 70 minutes and finished at 08:09:56Z. Results, in block order:

| Step | Result |
|---|---|
| projection jq | ready, 17 requests, bodies within the cap |
| dry-run r12 hermetic | status passed, seeded_r11_refs_changed false, response_shape ok, run_logs_checked |
| dry-run r12 --live-policy | passed, results_receiver_with 0, blob_with 0, verifier_job_model verify_sources |
| ci-hermetic-live-audit.test.py | 54 OK |
| ci-git-publication.test.py | 107 OK |
| ci-hosted-transport.test.py | 78 OK |
| ci-shape-probe.test.py | 19 OK |
| ci-pr-proof.test.sh | 100 OK. The known 253-130 flake did **not** fire |
| ci-hosted-gate-verify.test.py | 130 OK |
| ci-gate-canary-flow.test.py | 22 OK |
| ci-gate-canary-dryrun.test.py | 70 OK in 3368 s |
| ci-gate-canary.test.sh | passed |
| ci-gate-canary-recovery.test.py | 5 OK |
| disposition predicates | target-disposition exit 0; target-accepted exit 3 |
| v1 and r2-r11 reconcile --check-only | all exit 0 |
| category tables since the fetch commit | unchanged |
| product files changed by this plan | none |
| PRESERVATION-R12, config.json, state.json, tree | clean, 8e312f6c…, 70229 bytes / e45278c2cee0, clean except config.json |

## Deviations from Plan

1. **[Interpretation] The window observed-route rule is per-window.** It requires a sample from the observing R11 ledger, not just from any committed ledger. This is stricter than the behavior bullet and is what truth 2 states. As a result, rows that already cited R7-R9 samples also gained R11 samples.
2. **[Interpretation] Four R11 unobserved entries were dropped** rather than kept with a non-R12 first window. The plan's verify requires every entry's first_window to be 253-143 or 253-144, and the list must be "exactly" the R12 set. See the key decisions.
3. **[Rule 2 - honesty] Rows beyond the plan's named three were rewritten.** shape-dispatch, shape-run, shape-run_logs, shape-source-canary-fixture and shape-rate_limit were updated because the newly cited R11 bytes back fields or facts their text had called unobserved. The checker forces this: a field that resolves cannot stay listed without a sample.
4. **[Process] The Task 3 verify ran in the background with polling** rather than in a foreground shell. The tool caps a foreground run at 10 minutes, and the block ran to completion before anything else happened.

Per the orchestrator's hard constraints:
- The STATE, ROADMAP and REQUIREMENTS writer steps were skipped.
- WINDOWS.md and deferred-items.md were not written.

## Deferred Issues

- **I-1 and I-2** (informational review notes, product files, no behavior impact) are recorded above for a later plan that touches ci-git-publication.py or ci-pr-proof.sh.

## Known Stubs

None.

## Threat Flags

None. The checker is test code that reads committed files, and the projection wrote only a deleted temporary file.

## Handoff for the next plan

- **HEAD:** `ee90cfa4d` (before this SUMMARY's commit). The tree is clean except config.json.
- **R12 audit record:** sha256 `c0c508c7c78feb4eb485fe5cd36b120311c41d9484898bfb003e67c5fe830c0c`, audit_head `e2f7054a4cef5607709f2369c53f606f8403b644`, schema `sigra.phase253.hermetic-live-audit/r12`.
- **Unchanged records:**
  - MAIN-FETCH-R12 `35fd1543…515b90e`
  - PRESERVATION-R12 `72ea87c5…ad16d` (checks clean)
  - R11 PR ledger `9e896130…76fcf`
  - R11 canary ledger `78b01fe3…94278`
- **Projection on the fresh parent:** 17 requests, 4 trees, largest 2,082,931 B, 0 binary blobs, main_freshness clean. FREEZE-R12 can be cut. Use `--prepare ... --server-parent 09df342a82e03c3d5d40173c912b70e827f7eadc --main-record <MAIN-FETCH-R12>`, then `--build-freeze --ref-pair r12`. Local `refs/remotes/origin/main` must still be `09df342a`.
- **Dry-run gates:** `python3 scripts/ci/ci-gate-canary-dryrun.py [--live-policy] --ref-pair r12 --seed-r8-refs --seed-r9-refs --seed-r10-refs --seed-r11-refs`. Add `--revision-freeze <FREEZE-R12>` once it is cut.
- **The checker now requires:**
  - any new response key read inside the four PR_READ_REGIONS to be added to PR_BODY_KEYS and to the row's fields_compared;
  - a later R12 window ledger, once committed, to be added to WINDOW_LEDGERS_R11 (or an R12 counterpart), so its observed routes are held to its own bytes;
  - a renamed region anchor line in ci-pr-proof.sh or the verifier to update PR_READ_REGIONS.
- **Line references in the unobserved list.** The cited lines are ci-pr-proof.sh 335/370/533/537/540/549/607/613/636/664, verifier 1209/1256/1274/1290/1310/1318/1338/1340/1353/1359/1373/1404, ci-hosted-transport.py:625 and ci-gate-canary.sh:916. The checker does not check them, so a plan that moves those lines should refresh the stop text.

## Self-Check: PASSED

- **Files exist:** this SUMMARY, the checker and the audit record.
- **Commits are ancestors of HEAD:** `e2f7054a4`, `cb32f8b9d` and `ee90cfa4d`.
- **Invariants hold:**
  - PRESERVATION-R12 is clean;
  - config.json sha256 `8e312f6c…`;
  - state.json is 70229 bytes with prefix `e45278c2cee0`;
  - there is no `scripts/ci/__pycache__`;
  - the projection output was deleted.
