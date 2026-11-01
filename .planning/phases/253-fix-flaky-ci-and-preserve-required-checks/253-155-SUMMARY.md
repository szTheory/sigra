---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "155"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, pagination, check-identity, retained-preflight, red-first, r14, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-146 Task 1 (halted plan): /repositories/<id> pagination form, multi-page check sources, 209-run 3-page fake"
provides:
  - "Driver: duplicate-tolerant server-parent per-name identity check (>= 1 run, all of the frozen commit, one app id+slug)"
  - "Verifier: server_parent_native_sources (strict head_sha, mixed-app refusal, int run ids, newest run is the source, duplicate_count re-derived on verify); PR-head rule unchanged"
  - "Fake: server-parent page 1 = committed R12 ledger sequence 21 body (head_sha rewritten), synthetic duplicate pages 2-3"
  - "Driver: retained_preflight accepts exactly one contiguous multi-page check_runs read"
  - "Both full offline gates (hermetic + live-policy, r12 pair, r8-r11 seeds) pass with preflight 7 and one 3-page check_runs read"
affects: ["253-156", "253-157", "253-158", "253-159", "253-160", "253-161", "253-162", "253-163", "R14 replan of the TransportSensitivityTests finding"]
key-files:
  created: []
  modified:
    - scripts/ci/ci-gate-canary.sh
    - scripts/ci/ci-gate-canary-flow.test.py
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R13.json
key-decisions:
  - "R8 server-parent check-source decision relaxed (decision record not edited): from exactly one run per required name to at least one identity-consistent run per name. Evidence: real main (R12 ledger seq 21, 100 of 209 runs on page 1) lists Library tests 3x, Example unit smoke 2x, Install smoke 2x, Example HTTP smoke 2x, Example Playwright smoke 3x, all app 15368 github-actions, all head_sha 09df342a."
  - "head_sha is strict on the server-parent path: missing, null or another commit is refused (RED showed the old verifier ACCEPTED all three: a fail-open hole now closed)."
  - "Halted in Task 3: the full dry-run suite fails 2 TransportSensitivityTests (old --transport-from transports reject the live-policy fake's /repositories/<id> pagination link at preflight page 2). The failure is not a permitted restatement (f)/(h) and its fix needs a test or fake decision, so the plan halts per its contract."
requirements-completed: []
estimate: {tokens: 80000, tasks: 3}
actuals:
  tokens: 11500
  tasks: 2
  commits: 4
commits: 4
plan_head_before: a03dc0b0e6e5c84b9af35d769ceaa712819d1f24
plan_head_after: 89b8c86188ee764e4ea3fb5b67149c4ade4f027c
duration: "3h14m wall (22:39Z to 01:53Z), including a session-limit pause and about 80 min of the full dry-run suite"
completed: 2026-10-20
status: halted
---

# Phase 253 Plan 155: R14 server-parent duplicate identity and contiguous retained preflight Summary

**Halted in Task 3, after Tasks 1 and 2 were completed, committed, and their verify blocks exited 0.**

- **What works now:** the real 253-143 page-1 duplicates go end to end through the fake, the driver and the verifier, under a strict head_sha rule. Both full offline gates pass the six-scenario window with preflight 7 and one 3-page check_runs read, and the remaining step re-verifies that read offline.
- **Why it halted:** the full dry-run suite (76 tests) has 2 failures in `TransportSensitivityTests`. Old transports, substituted with `--transport-from`, refuse the live-policy fake's `/repositories/1207487684/` pagination link at preflight page 2.
- **Where the failure comes from:** 253-146 Task 1 introduced that link form (fake change in `5a23a264a`, transport support in `7b653d6ad`). It went unseen because 253-146 never ran the full suite.
- **Why no fix:** these failures are not one of the permitted restatements, and fixing them needs a test or fake decision, so the contract says halt.
- **Network:** no GitHub request was made.

## Preconditions (Task 1): all met

- The 253-146 SUMMARY has `status: halted`, sha256 `cadd04ee…d7ac07`.
- Commits `ee7c53765`, `b3a201c64`, `5a23a264a`, `7b653d6ad` and `6f69ff0ff` are ancestors of HEAD.
- PLANs 253-155..163 are in HEAD.
- Both PRESERVATION-R12 and PRESERVATION-R13 check clean.
- `refs/remotes/origin/main` = `09df342a82e03c3d5d40173c912b70e827f7eadc`.
- The tree was clean except config.json (sha256 `8e312f6c…`). state.json is 70229 B, sha256 prefix `e45278c2cee0`.

## Inventory

### Pre-edit (at a03dc0b0e, before any edit): exactly the 16 listed lines

| Hit | Disposition |
|---|---|
| ci-gate-canary-flow.test.py:261 `'duplicated producer': …` | restated (a) |
| ci-gate-canary-flow.test.py:271 `assertIn('native check-run app/source identity is missing or duplicated'…` | kept (g) |
| ci-gate-canary-dryrun.test.py:134 `def test_the_second_invocation_issues_zero_preflight_requests_and_reverifies_the_retained_preflight` | kept (g) |
| ci-gate-canary-dryrun.test.py:136 `…get("preflight"), 5…` | restated (f) |
| ci-gate-canary-dryrun.test.py:138 `…retained_preflight_reverified…` | kept (g) |
| ci-gate-canary-dryrun.test.py:141 `…get("check_runs"), 1…` | restated (f) |
| ci-gate-canary-dryrun.test.py:290 `assertIn("native check-run app/source identity is missing"…` | kept (g) |
| ci-gate-canary-dryrun.test.py:305 `control("preflight-repeat", "if retained_preflight; then", …)` | kept (g) |
| ci-gate-canary-dryrun.test.py:1362 `runs = runner.server_parent_check_runs("f" * 40, 209)` | kept unchanged (h: the call stays) |
| ci-gate-canary-dryrun.test.py:1365 `…== name), 1, name)` | restated (h) |
| ci-hosted-gate-verify.test.py:763 `native_bytes = … "check_runs": native_runs …` | kept (g) |
| ci-hosted-gate-verify.test.py:817 `def check_run(…)` | restated (c) |
| ci-hosted-gate-verify.test.py:851 `set_body(… "check_runs": runs …)` | kept (g) |
| ci-hosted-gate-verify.test.py:918 `"six producers": …` | restated (b) |
| ci-hosted-gate-verify.test.py:977 `def runs(count, start=1):` | restated (d) |
| ci-hosted-gate-verify.test.py:2918 `per_check = ('([.check_runs[] | select(.name==$name)] | length == 1) …` | restated (e) |

No hit was in an undeclared file.

### Post-change (at 89b8c8618): 19 lines, all in the three declared files

```
ci-gate-canary-dryrun.test.py:134  def test_the_second_invocation_…_retained_preflight            (g, unchanged)
ci-gate-canary-dryrun.test.py:138  assertTrue(…retained_preflight_reverified…)                      (g, unchanged)
ci-gate-canary-dryrun.test.py:292  assertIn("native check-run app/source identity is missing"…     (g, unchanged; moved by +2 lines)
ci-gate-canary-dryrun.test.py:307  control("preflight-repeat", "if retained_preflight; then", …)   (g, unchanged)
ci-gate-canary-dryrun.test.py:1374 assertTrue(invocations["remaining"]["retained_preflight_reverified"]…   (new full-gate check)
ci-gate-canary-dryrun.test.py:1392-1399,1422  test_the_retained_preflight_is_exactly_one_contiguous_check_runs_read  (new predicate test)
ci-gate-canary-dryrun.test.py:1430 runs = runner.server_parent_check_runs("f" * 40, 209)        (h, call unchanged)
ci-gate-canary-dryrun.test.py:1434 assertGreaterEqual(sum(… == name), 1, name)                  (h, restated)
ci-gate-canary-flow.test.py:271    assertIn('…identity is missing or duplicated'…)               (g, unchanged)
ci-hosted-gate-verify.test.py:763  native_bytes … native_runs                                    (g, unchanged)
ci-hosted-gate-verify.test.py:817  def check_run(…)                                              (c)
ci-hosted-gate-verify.test.py:851  set_body(… "check_runs": runs …)                              (g, unchanged)
ci-hosted-gate-verify.test.py:918  "six producers, mixed app": …                                 (b)
ci-hosted-gate-verify.test.py:1012 "native check app or source identity is missing or duplicated: Library tests"  (new PR-head control)
ci-hosted-gate-verify.test.py:1061 def runs(count, start=1, sha=SERVER_PARENT):                  (d)
```

## Restated assertions (file:line before → after)

- **(a)** ci-gate-canary-flow.test.py:261: `'duplicated producer'` was replaced in the same dict by `'mixed producer'` (:261), which adds a duplicate with app `{id 99999, slug other-app}` and is refused with the same message. The new test `test_preflight_accepts_identity_consistent_duplicates_on_the_server_parent` (:273) checks that the same-app duplicate is accepted with rc 0 and `preflight-reads-passed`. The other five cases and :271 are byte-unchanged.
- **(b)** ci-hosted-gate-verify.test.py:918: `"six producers"` became `"six producers, mixed app"` (:918, duplicate app `{456, other-app}`). The accepting case moved to `test_identity_consistent_duplicate_on_the_server_parent_is_accepted_and_counted` (:931), which uses int ids. It asserts that source = the newest run (id 2000, job/9), duplicate_count is 2 for Library tests, and 1 for the other four.
- **(c)** ci-hosted-gate-verify.test.py:817 `check_run`: now has `"head_sha": SERVER_PARENT` as a default field. PR-path callers are unaffected. `test_pr_family_view_still_requires_five_successful_checks_on_its_head` passes unchanged with runs whose head_sha (SERVER_PARENT) differs from the PR head (`e`*40), which shows the PR-head rule does not read head_sha.
- **(d)** ci-hosted-gate-verify.test.py:977 → :1061: `runs(count, start=1, sha=SERVER_PARENT)` passes `head_sha=sha`. `paged()` (:1078) passes its own sha.
- **(e)** ci-hosted-gate-verify.test.py:2918-2920 → :3002-3005: `per_check` is now the new driver expression, verbatim. Its jq run on the real R9 sequence-21 body passes for all five names.
- **(f)** ci-gate-canary-dryrun.test.py:136: preflight 5 → 7 (:136). At :140-141 the method was renamed `test_the_window_ledger_holds_one_contiguous_three_page_check_runs_read_within_the_preflight_category`, check_runs 1 → 3, and it now asserts `paginated_reads` == `[{route check_runs, pages 3, next_link_forms [repos]}]`. The `assertLessEqual(preflight, 8)` line is unchanged.
- **(h)** ci-gate-canary-dryrun.test.py:1365 → :1432-1437. It now asserts at least one run per required name, every run of a name with app `(15368, github-actions)`, and at least one name with two or more runs. The call at :1362 (now :1430) is unchanged; the signature only gained an optional `page=None` argument. Result before the fake change: counts [1,1,1,1,1], so `any >= 2` is False and the test would fail. After: counts [4,3,3,3,4], and it passes.

## The R8 decision relaxation

The R8 server-parent check-source decision (`253-LOAD-RECOVERY-CHECK-SOURCE-DECISION-R8.json`, identity only) is relaxed from exactly one run per required name to at least one identity-consistent run per name. The decision record is not edited.

The real per-name counts on page 1 (R12 ledger seq 21: total_count 209, 100 runs, ids 117310379350..117934942749 newest-first, all app 15368 github-actions, all head_sha `09df342a…`):

| Required name | Runs on page 1 |
|---|---|
| Library tests | 3 |
| Example unit smoke (ExUnit + ConnTest) | 2 |
| Install smoke (fresh phx.new + sigra.install) | 2 |
| Example HTTP smoke (boot + curl critical routes) | 2 |
| Example Playwright smoke (full lifecycle) | 3 |

Success is still not required on the server parent. The PR-head rule (exactly one successful run per name) is unchanged.

## Task 1: complete (RED `42516baf4` → GREEN `fe0730aa5`)

### RED (`42516baf4`)

The fake change (page 1 = the committed sequence-21 bytes) is in this commit, as the plan's test scaffolding.

**`ci-gate-canary-flow.test.py`: rc 1, 23 tests, failures=1.**
- `test_preflight_accepts_identity_consistent_duplicates_on_the_server_parent` failed with `AssertionError: 1 != 0 : ci-gate-canary: FAIL: native check-run app/source identity is missing or duplicated: Library tests`.
- `'mixed producer'` was already refused before the fix.

**`ci-hosted-gate-verify.test.py`: rc 1, 150 tests, failures=9, errors=2.** Failing:
- `test_identity_consistent_duplicate_…_accepted_and_counted` and `test_a_stored_duplicate_count_…`: ERROR `native check source is missing or duplicated: Library tests`.
- `test_server_parent_duplicates_need_int_run_ids` (2 subtests): got `native check source is missing or duplicated` instead of `…need run ids`.
- `test_server_parent_duplicates_with_differing_apps_are_refused` (2): got the old message, not `identity differs across duplicate runs`.
- `test_server_parent_runs_must_carry_the_frozen_source_head_sha`:
  - head_sha missing, null, and of another commit: **`VerificationError not raised`**. The old verifier accepted all three, which was a fail-open hole.
  - duplicate of another commit: refused, but with the old message.
- `test_live_r9_preflight_responses_satisfy_the_canary_driver_reads`: the new pinned expression was not yet in the driver.

Passing before the fix: `'six producers, mixed app'`, and the PR-head duplicate control `test_a_duplicate_required_name_on_a_pr_head_is_still_refused`.

**`ci-gate-canary-dryrun.test.py DryRunPaginatedCheckRunsTests`: rc 1, 3 tests, failures=2.**
- Both quick gates stopped with `ci-gate-canary: FAIL: native check-run app/source identity is missing or duplicated: Library tests`. This is the halt the 253-143 bytes predict.
- The fake test (h) passed.

### GREEN (`fe0730aa5`)

- **Driver** (ci-gate-canary.sh:782): `[.check_runs[] | select(.name==$name)] as $runs | ($runs | length >= 1) and ($runs | all(.head_sha==$sha and <identity>)) and ([$runs[] | [.app.id, .app.slug]] | unique | length == 1)`. The fail text is unchanged.
- **Verifier** (ci-hosted-gate-verify.py:308): `server_parent_native_sources(native_runs, sha)` is used by both `hydrate_effective_checks` and `verify_effective_checks` when check_source is set. The PR-head loops are unchanged in behaviour.
  - **Refusal messages:**
    - `native check source run is not of the frozen source commit: <name>`
    - `native check app or source identity is missing: <name>`
    - `native check source identity differs across duplicate runs: <name>`
    - `native check source duplicates need run ids: <name>` (requires int and distinct ids)
  - **Source and duplicate_count:** the newest run (highest id) is the source, and producer_checks gain `duplicate_count`. verify_effective_checks re-derives duplicate_count from the measured bodies. It refuses a stored value that differs or is missing (`declared producer duplicate_count differs from the measured check runs for <name>`, :481). duplicate_count is kept out of the four-key comparison.
- **Audit:** 21 R13 anchors moved, all in the verifier, and only their `line` values changed:
  - verifier-645, -677, -950, -951, -968, -969, -991, -1014, -1015, -1021, -1369, -1403, -1462, -1482, -1634, -1652, -1664, -1674, -1725, -1729
  - verifier-1655-supplementary

  Every one moved by +54 lines. audit_head stays `ee7c5376…`, which the checker accepts. No driver or dry-run anchor moved.

### Task 1 verify block: **exit 0**

Extracted verbatim and run under `caffeinate -i -s`:
- flow 23 OK, verifier 150 OK, dry-run class 3 OK, `ci-gate-canary.test.sh` passed, audit 54 OK.
- The grep, commit-order, preservation, config and state checks all passed.

## Task 2: complete (RED `e38c74aac` → GREEN `89b8c8618`)

### RED (`e38c74aac`)

Added:
- full-run hermetic and live-policy cases to DryRunPaginatedCheckRunsTests;
- a direct predicate test of the driver's real `retained_preflight` on 8 window-ledger cases;
- restatement (f).

**`DryRunPaginatedCheckRunsTests PreflightOnceTests`: rc 1, 9 tests, failures=4.**
- **Full gates and PreflightOnceTests:** both full gates and `test_the_second_invocation_…` stopped with `ci-hosted-transport: category_budget_exhausted: category preflight allocation is exhausted`. That is the remaining step re-running the fresh preflight, as predicted.
- **Predicate test, case "three contiguous pages of 209":** `1 != 0`.
- **Predicate refusals passing before the fix:** pages 1 and 3, two page-1 reads, the 2-of-3 short read, a non-200 page, two commits, and no read. "One page of 7" was also accepted under the old rule.

### GREEN (`89b8c8618`)

`retained_preflight` (ci-gate-canary.sh:807) uses jq over the window ledger's check_runs rows. It requires `page_ordinal == [1..n]`, every row a 200, one commit parsed from the URL, and `n == max(1, ceil(total_count/100))` from the page-1 body. The call site `if retained_preflight; then` appears exactly once. No audit anchor moved, and the checker passes.

- The class run was rc 0 (9 tests OK, 720 s).

### Task 2 verify block: **exit 0**

- 23:55Z to 00:14Z.
- Covered: the classes (9 OK), `ci-gate-canary.test.sh`, both full CLI gates with their jq, the r11 positive control (fails with `already points to a different commit`), the audit (54 OK), commit order, and the preserved files.

### Full gate summaries (r12 pair, `--seed-r8/r9/r10/r11-refs`, no `--stop-after`)

| | hermetic | live-policy |
|---|---|---|
| status / stop | passed / null | passed / null |
| requests_by_category | artifact_downloads 10, artifact_metadata 6, attempt_jobs 7, cancellation 1, dispatch 7, failure_logs 6, pre_watch_rate 7, **preflight 7**, publication 19, run_discovery 7, terminal_polls 18 (total 95) | identical (total 95) |
| paginated_reads | `[{route check_runs, pages 3, next_link_forms [repos]}]` | `[{route check_runs, pages 3, next_link_forms [repositories-id]}]` |
| live_hops | 8: artifact_zip hop 1 → localhost, run_logs hop 1 → localhost | 8: artifact_zip hop 1 → productionresultssa17.blob.core.windows.net, run_logs hop 1 → results-receiver.actions.githubusercontent.com |
| response_shape | ok true, run_logs_checked true | ok true, run_logs_checked true |
| remaining invocation | preflight 0, retained_preflight_reverified true | preflight 0, retained_preflight_reverified true |
| verifier | passed | passed |
| scenarios | all six | all six |
| authorization | api_with 0, blob_with 0, results_receiver_with 0 | api_with 87, api_without 0, blob_with 0, results_receiver_with 0 |
| shim_refusals | [] | [] |
| seeded r8-r11 refs changed | false ×4 | false ×4 |

Preflight stays at 7 of the R13 table's 16, so the canary table, growth guard and deadline are unchanged.

## Task 3: HALTED

The Task 3 verify block ran under `caffeinate -i -s` from 00:20Z to 01:40Z. **Exit 1.**

**`python3 scripts/ci/ci-gate-canary-dryrun.test.py` (full suite): Ran 76 tests in 4789 s, FAILED (failures=2).**

```
FAIL: test_the_pre_fix_transport_fails_the_live_policy_gate_at_artifact_zip_with_origin_rejected (TransportSensitivityTests)
  ci-gate-canary-dryrun.test.py:505  AssertionError: 'origin_rejected' not found in
  'ci-hosted-transport: pagination_destination_rejected: pagination link changed its approved API route'
FAIL: test_the_redirect_fix_transport_passes_the_same_gate (TransportSensitivityTests)
  ci-gate-canary-dryrun.test.py:514  AssertionError: 1 != 0  (stop: the same pagination_destination_rejected)
```

**Cause (verified):**
- Both tests run the live-policy gate with `--transport-from 375b41138` (the 253-107 redirect fix) or its parent.
- Neither of those transports has `GITHUB_REPOSITORY_ID`: `git show 375b41138:…transport.py | grep -c` = 0. The current transport has it (2 hits), and the `/repositories/<id>/` acceptance arrived in `7b653d6ad`.
- The live-policy fake has emitted the `/repositories/1207487684/` next link for the server parent's check runs since `5a23a264a` (253-146 Task 1 RED; `7b653d6ad^` already has it).
- So those old transports stop at preflight page 2, before they reach artifact_zip.
- This comes from 253-146 Task 1, not from 253-155: the 253-155 diff does not touch the link form or the transport. 253-146 ran only `DryRunPaginatedCheckRunsTests`, never the full suite, so the regression stayed hidden until now.

**Why halt and not restate:** Task 3 permits only restatements of lines under (f) or (h), or of an assertion that names a check_runs count or a full-pass preflight count of 5. These two assertions are about the 253-104 redirect defect (`origin_rejected` at artifact_zip). Any fix needs a decision outside Task 3's scope. Two options for the replan:
1. The fake keeps the `repos` link form (or one page) when `--transport-from` names a transport without `GITHUB_REPOSITORY_ID`. That is a product-file change to ci-gate-canary-dryrun.py, which Task 3 does not allow.
2. TransportSensitivityTests passes a flag that disables `/repositories/` links for historical transports. That is a test change outside the permitted restatements, plus a new fake flag.

**Every other listed suite was run separately after the halt** (the `&&` chain had stopped at the dry run). All of them passed:
- `ci-gate-canary-flow.test.py`: 23 OK
- `ci-hosted-gate-verify.test.py`: 150 OK
- `ci-hosted-transport.test.py`: 83 OK
- `ci-gate-canary-recovery.test.py`: 5 OK
- `ci-shape-probe.test.py`: 19 OK
- `ci-git-publication.test.py`: 107, rc 0
- `ci-hermetic-live-audit.test.py`: 54 OK
- `bash ci-gate-canary.test.sh`: passed
- `bash ci-pr-proof.test.sh`: OK

The other 74 of the 76 dry-run tests passed. That includes PreflightOnceTests with (f), all of DryRunPaginatedCheckRunsTests, SensitivityControlTests (`test_preflight_repeat` still fails at `category preflight allocation is exhausted`; `test_check_source_candidate` still fails at `native check-run app/source identity is missing`), and every live-policy class.

No Task 3 commit was made, and no file changed in Task 3.

## Deviations from Plan

1. **[Rule 2] The verifier refuses a missing stored `duplicate_count` on the server-parent path, not only a differing one.** The plan says to never trust the stored value. Live evidence holds no stored effective_checks, so the verifier always hydrates and the stored value always exists there. No existing test broke. A new test, `test_a_stored_duplicate_count_that_differs_from_the_measured_runs_is_refused`, covers this.
2. **[Rule 2] Duplicate run ids must also be distinct,** under the same `need run ids` message. Without that, highest-id selection would be ambiguous.
3. **Server-parent identity failures use `native check app or source identity is missing: <name>`.** The PR path keeps both of its old texts.
4. **The PR-head duplicate control asserts both PR texts.** Hydrate refuses with `native check source is missing or duplicated`. Verify, on a body swapped in after a clean hydrate, refuses with `native check app or source identity is missing or duplicated: Library tests`.
5. **`server_parent_check_runs` gained an optional `page=None` argument.** The call at the old :1362 is unchanged.
6. **Halted at Task 3,** per the contract (above).

## Known Stubs

None.

## Remaining gaps

- **TransportSensitivityTests (2 tests)** fail on the full dry-run suite: historical `--transport-from` transports versus the live-policy `/repositories/<id>` link form. A replan must decide between a fake change and a test change.
- **Task 3 has not closed.** Its verify block, the inventory re-run in that verify (already recorded above) and the "no product file after the Task 2 fix" diff check have not passed as one block.
- **Downstream plans are blocked:** 253-156..163 depend on a green 253-155. CIREL-02 stays open, and full Phase 253 verification stays not_started.

## Self-Check: PASSED

- Commits `42516baf4`, `fe0730aa5`, `e38c74aac` and `89b8c8618` are ancestors of HEAD.
- `git rev-list --count a03dc0b0e..89b8c8618` = 4; this SUMMARY's commit makes 5.
- The 253-146 SUMMARY sha256 `cadd04ee…` and the PRESERVATION-R13 sha256 `17845858…` are unchanged, and both checklists check clean.
- config.json is `8e312f6c…` and state.json is 70229 B.
- STATE.md, ROADMAP.md and state.json are untouched.
- `scripts/ci/__pycache__` is absent, and the tree is clean except config.json.
