---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "146"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, pagination, hermetic-live, red-first, r13, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-143 halted R12 canary (ledger seq 21: check_runs on 09df342a, total_count 209, Link next/last in the /repositories/1207487684/ form)"
provides:
  - "PRESERVATION-R13.sha256: 152 lines (128 R12 lines unchanged + 24 R12 records/SUMMARYs/runners), sha256 178458587b7d93545433c5afeab7e1724f0e31dcb0fc86f84aa1d6547079eadb"
  - "R13 hermetic-vs-live audit record (schema r13), checker pointing at it, green"
  - "Transport: GITHUB_REPOSITORY_ID = 1207487684; live pagination accepts /repositories/1207487684/<same route suffix>"
  - "Verifier: check_run_page_set, multi-page native check sources ({sequences}), legacy {sequence} kept"
  - "Dry-run fake: server parent serves 209 check runs over 100/100/9 with GitHub's Link rels in the mode's form; paginated_reads summary"
affects: ["253-147", "253-148", "253-149", "253-150", "253-151", "253-152", "253-153", "253-154", "R13 replan of 253-146 Task 2/3"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PRESERVATION-R13.sha256
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R13.json
  modified:
    - scripts/ci/ci-hermetic-live-audit.test.py
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
key-decisions:
  - "Halted at Task 2, before any Task 2 edit. Task 2 requires ci-gate-canary.sh's per-name check to accept identity-consistent duplicate runs on the server parent. That makes an existing test in an undeclared file fail: ci-gate-canary-flow.test.py CanaryPreflightCheckSourceTests.test_preflight_rejects_missing_duplicated_or_foreign_identity, case 'duplicated producer' (base + a same-app duplicate of 'Library tests', asserted refused). Verified by a temporary probe of the planned jq rule, reverted with git checkout: rc 1, 'AssertionError: 0 == 0 : duplicated producer'. The plan's contract says a finding that needs another file halts the plan, so Task 2 and Task 3 were not started."
requirements-completed: []
estimate: {tokens: 70000, tasks: 3}
actuals:
  tokens: 56929
  tasks: 1
  commits: 4
commits: 4
plan_head_before: 7fc1abc6afb7de1a999297d5947d9da1c8d03767
plan_head_after: 7b653d6ad71a98106e0576926e560af1ca611ece
duration: 37min (checklist commit 20:54:59Z to halt 21:31Z)
completed: 2026-10-19
status: halted
---

# Phase 253 Plan 146: R13 pagination gap (blind spot #5) Summary

**Halted after Task 1 of 3. Task 1 is complete and its verify block exits 0: the 253-143 halt is reproduced offline and fixed. A 209-run main is read in three pages through GitHub's real `/repositories/1207487684/` Link form, the preflight spends 7 of 8, and the canary reaches the workflow lookup and full-pass in both modes. Task 2 needs a change to `scripts/ci/ci-gate-canary-flow.test.py`, which the plan does not declare. Its contract says that halts the plan. The conflict was verified, not inferred. Task 2 and Task 3 did not start. No GitHub request was made.**

## Preconditions (Task 1): all met

- 253-143 SUMMARY `status: halted`.
- PLANs 253-146..154 are in HEAD.
- `shasum -a 256 -c --quiet` on PRESERVATION-R12 exits 0 (128 lines).
- `refs/remotes/origin/main` = `09df342a82e03c3d5d40173c912b70e827f7eadc`.
- The tree was clean except config.json (sha256 `8e312f6c…0c7d0b8d`).

## Task 1 (complete)

### Step 1: preservation checklist

- `253-LOAD-RECOVERY-PRESERVATION-R13.sha256` holds every PRESERVATION-R12 line unchanged and in order (128), then **24 added lines** (1 + 8 + 9 + 6). That makes **152 lines**, with sha256 **`178458587b7d93545433c5afeab7e1724f0e31dcb0fc86f84aa1d6547079eadb`**.
- All 24 computed hashes equal the values pinned in the plan (diffed programmatically).
- `shasum -c` exits 0. The positive control, a scratch copy with line 1's first hex digit flipped, exits 1.
- Committed alone as `ee7c53765` "docs(253-146): R13 preservation checklist".

### Step 2: R13 audit record

- `253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R13.json` was copied from R12. Only two things changed: `schema` became `sigra.phase253.hermetic-live-audit/r13`, and `audit_head` became `ee7c537653e1af109cb84f136502c34b747834be` (HEAD before any code edit). Every row is unchanged.
- In the checker, `AUDIT_REL` names the R13 record. The checker passes (54 OK). The R12 record is byte-identical (pinned).
- Committed as `b3a201c64`.

### Step 3: RED (`5a23a264a`)

Recorded with exit codes.

**`python3 scripts/ci/ci-hosted-transport.test.py`: rc 1, 83 tests, failures=3, errors=1.** Only the new tests fail:
- `test_live_check_runs_read_follows_three_repositories_id_pages_but_requests_only_the_approved_route` fails with `ci-hosted-transport: pagination_destination_rejected: pagination link changed its approved API route`.
- `test_live_repositories_id_form_covers_workflow_runs_and_run_jobs_pagination` fails the same way in both subtests (workflow_runs, run_jobs).
- `test_repository_id_constant_equals_the_committed_real_repository_id` errors with `AttributeError … no attribute 'GITHUB_REPOSITORY_ID'`.
- Passing before: the refusal matrix (`test_live_repositories_id_form_refuses_every_other_id_route_host_page_or_query_before_a_second_request`) and the hermetic control.

**`python3 scripts/ci/ci-hosted-gate-verify.test.py`: rc 1, 144 tests, failures=6, errors=6.** Only `MultiPageCheckSourceTests` fail.
- Failing before:
  - The three-page acceptance and the three-page `verify_canary_checks` cases.
  - The max_pages case (TypeError: no `max_pages` kwarg).
  - The retained-sequences gap/short subtests.
  - The gap, two-page-1, total mismatch, short union, wrong n, and 2-of-3 short-read cases. Under the old rule these were refused, but by the single-transaction rule, not by their own rule.
- Passing before (the refusals that already hold under the single-page rule, plus the controls):
  - `test_single_page_short_read_needs_another_charged_page`
  - `test_pr_head_stop_one_page_of_100_runs_with_total_count_101_needs_another_charged_page`
  - `test_one_page_set_below_100_runs_is_accepted_on_both_paths`
  - `test_legacy_single_sequence_evidence_shape_is_still_accepted`

**`python3 scripts/ci/ci-gate-canary-dryrun.test.py DryRunPaginatedCheckRunsTests`: rc 1, 3 tests, failures=2.**
- **live-policy (the 253-143 failure, reproduced):** stop `ci-hosted-transport: pagination_destination_rejected: pagination link changed its approved API route`, `paginated_reads: []`.
- **hermetic:** stop `hosted-gate-verify: FAIL: measured preflight is missing branch rules, legacy protection or native check-run request`, which is the verifier's single-transaction rule. There the transport did fetch 3 `repos`-form pages, and preflight was 7.
- `test_the_fake_serves_209_runs_over_100_100_9_with_githubs_link_rels` passed.

### Step 4: GREEN (`7b653d6ad`)

- **Transport:**
  - `GITHUB_REPOSITORY_ID = 1207487684` sits beside `DEFAULT_REPO` (ci-hosted-transport.py:32).
  - The live branch of `_next_page_url` (ci-hosted-transport.py:1036-1041) computes the suffix from the approved path. It accepts `parsed.path` equal to the approved path or to `/repositories/1207487684/<suffix>`.
  - Every other check is unchanged. The hermetic branches and `fetch_pages`'s re-derived next request are untouched.
- **Verifier:**
  - `MAX_CHECK_RUN_PAGES = 10` and `check_run_page_set` (ci-hosted-gate-verify.py:269-311). The page set must be contiguous 1..n, each page a 200 on the typed URL with `page=k`, with one total_count. The checks then run in order: n ≤ max_pages, then "needs another charged page", then n == ceil(total/100), then union == total_count.
  - `hydrate_effective_checks` and `verify_effective_checks` take `max_pages`. Hydrate records `native_check_runs: {sequences: [...]}`; verify accepts that shape or the legacy `{sequence: N}`.
- **Audit:** 47 moved anchors were refreshed. Only line numbers changed, and the checker passes.

### Task 1 verify block: **exit 0**

The block was extracted verbatim and run under `caffeinate -i -s`. Results:
- Transport 83 OK.
- Verifier 144 OK.
- Audit 54 OK.
- Dry-run class 3 OK.
- Both explicit quick gates passed their jq (live-policy: preflight 7, one 3-page check_runs read with form `repositories-id`, blob_with 0, results_receiver_with 0; hermetic: preflight 7, form `repos`, seeded r11 unchanged).
- Commit order: checklist → RED → fix, with the fix subject on exactly one commit.
- Both checklists check clean. config.json and state.json (70229 B) are unchanged, and the tree is clean.

## Task 2: HALTED (not started)

**Why.** The plan's Task 2 requires `ci-gate-canary.sh`'s per-name check to accept identity-consistent duplicates: at least one run, all runs sharing one app id and slug. The plan contract says: "Work only in this plan's declared files. A finding that needs another file halts the plan (status halted)."

**Evidence (verified):**
1. The real page 1 (R12 ledger seq 21, decoded) has these per-name counts:
   - Library tests 3
   - Example unit smoke 2
   - Install smoke 2
   - Example HTTP smoke 2
   - Example Playwright smoke 3

   All runs are app 15368 `github-actions`, with head_sha `09df342a…`. The duplicates come from check suites 106223664960, 105952989384 and 105703365666.
2. `scripts/ci/ci-gate-canary-flow.test.py` is not in Task 2's `<files>` or the plan's `files_modified`. Its `CanaryPreflightCheckSourceTests.test_preflight_rejects_missing_duplicated_or_foreign_identity` (lines 257-271) has case `'duplicated producer': base + [native_run(REQUIRED_NAMES[0], 9)]`. `native_run` (line 180) gives every run app `{id: 15368, slug: github-actions}`, so this is an identity-consistent duplicate. The test asserts it is refused.
3. **Positive control:** the class passes on HEAD (`Ran 4 tests … OK`, rc 0).
4. **Probe:** I applied the planned jq rule to ci-gate-canary.sh:780 temporarily:

   ```
   [.check_runs[] | select(.name==$name)] as $runs | ($runs | length >= 1) and ($runs | all(<identity>)) and ([$runs[] | [.app.id, .app.slug]] | unique | length == 1)
   ```

   With it, the class fails: rc 1, `FAIL: … (case='duplicated producer')`, `AssertionError: 0 == 0 : duplicated producer`. The other cases still pass under the probe: four producers, missing slug, missing source, non-https source, and a run of a different commit.

   The file was restored with `git checkout -- scripts/ci/ci-gate-canary.sh`, and `git status` shows only config.json.

The plan's "Permitted edits to existing tests" clause covers restating a one-run-per-name server-parent assertion. But the contract also limits work to the declared files, and it states the halt rule explicitly. I followed the halt rule.

**A second finding for the replan (inferred, not run):**
- Task 2 also requires every server-parent run to carry `head_sha` equal to the frozen source.
- `check_run()` in ci-hosted-gate-verify.test.py (line ~817) builds runs without `head_sha`. So does Task 1's `MultiPageCheckSourceTests.runs()`.
- CanaryCheckSourceTests' accepting case (`test_server_parent_identity_accepts_any_conclusion_and_records_it_literally`) and Task 1's three-page acceptance tests would therefore fail under a strict head_sha rule. Task 2 says those Task 1 tests must "still pass unchanged".
- Two ways out: add `head_sha` to those fixtures, or check head_sha only when present. The replan should say which.

## Task 3: not run

`retained_preflight` still requires exactly one check_runs transaction (ci-gate-canary.sh:804). A full (non `--stop-after`) gate would re-read the preflight in `remaining`. Expected, not measured.

## Restated single-page assertions

None. No existing assertion was restated in Task 1. Every pre-existing test passes unchanged: transport 83, verifier 144, audit 54.

## Audit rows changed (R13 record)

Only `line` values changed, for 47 rows. The checker reported no unaudited site and no missing anchor.
- **Transport (26 rows):** transport-262, -274, -277, -278, -279, -280, -286, -291, -455, -461, -464, -479, -483, -507, -515, -570, -594, -599, -664, -673, -816, -818, -998, -1005, -1018, transport-948-supplementary.
- **Verifier (21 rows):** verifier-645, -677, -950, -951, -968, -969, -991, -1014, -1015, -1021, -1369, -1403, -1462, -1482, -1634, -1652, -1664, -1674, -1725, -1729, verifier-1655-supplementary.

## Quick-gate summaries (Task 1, `--stop-after full-pass`, r12 + r8-r11 seeds)

- **live-policy:**
  - status passed.
  - requests_by_category.preflight 7.
  - paginated_reads `[{route: check_runs, pages: 3, next_link_forms: [repositories-id]}]`.
  - authorization blob_with 0, results_receiver_with 0, shim_refusals [].
  - check_runs 3, workflow 1.
  - Seeds r8-r11 unchanged.
- **hermetic:** status passed, preflight 7, paginated_reads check_runs 3 pages with form `repos`, seeds unchanged.
- The pre-change baseline (live-policy, same flags) had preflight 5 and check_runs 1.
- Full gates (Task 3) were not run.

## Deviations from Plan

1. **[Rule 3] The SCHEMA constant was changed along with AUDIT_REL** in ci-hermetic-live-audit.test.py:71-72. The plan said to change only AUDIT_REL, but `check()` requires `record.schema == SCHEMA` and the plan requires the r13 schema. This follows the 253-137 precedent (c7cb40a6a changed both). Commit `b3a201c64`.
2. **Userinfo and fragment links are refused as `malformed_location`, not `pagination_destination_rejected`.** The response-header scrubber refuses them before `_next_page_url` runs, which is the same as the existing `/repos/` refusal test. They are still refused after exactly one ledger row and one journal request. All other 11 refusal cases stop with `pagination_destination_rejected`.
3. **Hermetic control at the unit level.** `_next_page_url` is called directly with a hermetic canary allocation: the `/repositories/` form is refused with "pagination link changed its approved API route", and the `/repos/` form is accepted.
4. **[Rule 1] A lone check_runs page with `page_ordinal: None` is accepted as page 1** (its URL must still say `page=1`). Without this, the pre-existing `V2VerifierContractTests.transport_fixture` (check row `page_ordinal` None) would fail. The plan requires legacy fixtures to pass unchanged.
5. **Halted at Task 2,** per the contract's another-file rule (above).

## Known Stubs

None.

## Remaining gaps

- 253-146 Task 2 (the real duplicate shape and the server-parent identity rule) and Task 3 (the contiguous retained preflight and both full gates) are not done. The replan must add `scripts/ci/ci-gate-canary-flow.test.py` to the declared files, or decide otherwise. It must also settle the head_sha fixture question.
- 253-147..154 depend on 253-146 and stay not started. CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Self-Check: PASSED

- Created files exist: PRESERVATION-R13.sha256 and HERMETIC-LIVE-AUDIT-R13.json.
- Commits `ee7c53765`, `b3a201c64`, `5a23a264a` and `7b653d6ad` are ancestors of HEAD.
- `git rev-list --count 7fc1abc6a..7b653d6ad` = 4; this SUMMARY's commit makes 5.
- Both checklists check clean.
- config.json sha256 is `8e312f6c…0c7d0b8d`; state.json is 70229 B.
- STATE.md, ROADMAP.md and state.json are untouched.
- `scripts/ci/__pycache__` is absent, and the tree is clean except config.json.
