---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "143"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-canary, github, operator-run, r12, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-136 main fetch (09df342a), 253-137 r12 ref names, 253-141 FREEZE-R12/PUBLICATION-R12 (candidate rebuilt on the fetched main), 253-142 R12 reconciliation contract"
provides:
  - "Committed fresh canary-section approval bound to the R12 outward_actions.canary sha256 (e5068578...bd29), committed by Jon via ! (W1 fallback)"
  - "Committed self-contained operator runner (253-R12-CANARY-OPERATOR.sh, sha256 650acc67...1733)"
  - "Runner-committed live canary allocation (117 requests / 3600 s, window 253-143-canary-window-1, 43 hosts) bound to FREEZE-R12 (fd1a27cb...f309)"
  - "Actual server publication: both r12 create-only refs exist at the frozen SHAs (live-origin receipt valid)"
  - "First live paginated GitHub response: check_runs on fetched main 09df342a, total_count 209, Link rel next/last in the /repositories/<numeric id>/ form, refused by the transport"
  - "Halted partial evidence, HTTP ledger (21 of 117 requests) and publication receipt"
affects: ["253-144", "253-145", "R13 gap-closure replan"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R12-CANARY-OPERATOR.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ALLOCATION-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-EVIDENCE-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R12.json
  modified: []
key-decisions:
  - "Halted honestly in the canary preflight, before any dispatch. The preflight's check_runs read on the candidate's parent (the fetched main 09df342a, ledger seq 21) returned 200 with total_count 209, so GitHub paginated it. Its Link header named the next page as /repositories/1207487684/commits/09df342a.../check-runs (GitHub's numeric repository id form), not /repos/szTheory/sigra/... The live pagination rule at ci-hosted-transport.py:1034 requires the next link's path to equal the approved route, so it refused with pagination_destination_rejected before a second request. This is the fifth hermetic-vs-live blind spot: R8-R11 read check_runs on 84ebcea6 (total_count 63, one page, no Link), and no fake ever emits a /repositories/<id>/ next link or more than 100 check runs. No source edit, reseal, retry or extra window. Options are recorded, not chosen."
requirements-completed: []
estimate: {tokens: 34000, tasks: 4}
actuals:
  tokens: 9000
  tasks: 4
  commits: 5
commits: 5
plan_head_before: 626159d66774bc9fdec46dc9ead99a6a9c14c993
plan_head_after: 18ed14e63cac7e9eda0f4c8eba5db761717b9a1b
duration: 7min (approval commit 19:11:49Z to halt commit 19:18:41Z; hosted window 26 s of requests, 86 s by the evidence clock)
completed: 2026-10-19
status: halted
---

# Phase 253 Plan 143: Hosted canary (R12, operator-run) Summary

**Halted in the preflight, before any workflow dispatch. Under Jon's fresh R12 approval, the runner committed the allocation alone, passed the pre-clock asserts and published: both r12 create-only refs now exist on GitHub at the frozen SHAs, and the publication receipt is valid. The preflight then read the rate limit, main's rules, the (absent) legacy protection and the check runs of the candidate's parent, the fetched main `09df342a`. That last read returned 200 with `total_count` 209, so GitHub sent a `Link` header. Its `rel="next"` points at `/repositories/1207487684/commits/09df342a…/check-runs`, GitHub's numeric repository id form, not the approved `/repos/szTheory/sigra/…` route. The transport refused the page-2 link (`pagination_destination_rejected: pagination link changed its approved API route`, `ci-hosted-transport.py:1034`), and the driver stopped at `ci-gate-canary.sh:766`. The window used 21 of 117 requests (publication 17, preflight 4), 0 jobs and 0 runs. `remaining` was not run.**

## Task 1: offline gates and decision (orchestrator)

- The orchestrator ran the pre-presentation gates on FREEZE-R12 offline and reported them passed. This executor did not re-run them.
- **Decision:** Jon was asked fresh via AskUserQuestion, relayed by the orchestrator at about 2026-10-19T18:41Z. His verbatim selection was "Approve (Recommended)", with an empty note. The approval record's `decision_text` is `Approve (Recommended)` and its `note` is `""`.

## Task 2: approval, allocation and runner (executor, plus Jon via W1)

- **Approval:** `253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R12.json`, sha256 `32f3bbb7a59727cee3095fc87b285877eab4ea6131f8ccd6bb588289ac314299`. Section `canary`, section_sha256 `e506857812ea12e17e0ccd06e640a3ffd2582b6b90e3d3df6dba395a0456bd29`, freeze_sha256 `fd1a27cb2c3e40e1f598b51576083ddb2fc89527e5a3933cfa81cd56cf2bf309` (equal to the FREEZE-R12 file hash). It has 7 `authorizes` entries.
  - It was committed alone in `7b6dc4dbd` (committer time 1792437109, 19:11:49Z). That is before the evidence's `window_wall_start_epoch` 1792437434 (19:17:14Z).
- **W1 deviation:** the auto-mode classifier refused the executor's Write of the approval, citing "Instruction Poisoning". Following the plan's W1 fallback, Jon wrote and committed the record himself via `!`. Its `decided_by` says so: "recorded by Jon via ! (W1 fallback after the classifier refused the executor's write)".
- **Runner:** `253-R12-CANARY-OPERATOR.sh`, sha256 `650acc673d713404845b3f47923c923f15518081649aec963919d4a473c21733`, committed alone in `5bf43ae2a` (19:14:59Z).
- **Allocation:** embedded in the runner at sha256 `239361df06fd2ab46afa27312f45cc49661b69ff71b27bc98b5ffc23dc1c7839`. The committed file has the same hash, and so does the ledger's `allocation_sha256`. It is live and canary, with window `253-143-canary-window-1`, 117 requests / 3600 s, `max_pages` 10 and 43 download hosts. Its category limits are publication 24, preflight 8, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 7, artifact_downloads 12, failure_logs 6, cancellation 1 and infrastructure_retry 13 (expired).

## Task 3: live window (Jon ran step 1 of the runner himself)

Jon's relayed output, verbatim:

```
== commit the allocation alone
e4df08154 docs(253-143): declare the R12 live canary HTTP allocation
== pre-clock asserts (offline)
CLOCK STARTS 2026-10-19T19:17:10Z (publish-only)
ci-gate-canary: counted publication verified (requests=17/117; no workflow dispatch)
publication receipt valid
== full-pass 2026-10-19T19:18:30Z
ci-hosted-transport: pagination_destination_rejected: pagination link changed its approved API route
ci-gate-canary: FAIL: command exited 1 at line 766: return $? (last route check_runs, endpoint commits/09df342a82e03c3d5d40173c912b70e827f7eadc/check-runs?per_page=100, HTTP 200)
18ed14e63 docs(253-143): halted R12 canary records (full-pass exit 1)
STOP: full-pass exit 1
```

- **The tripped stop:** `STOP: full-pass exit 1`, caused by `pagination_destination_rejected: pagination link changed its approved API route`.
- **Allocation commit:** `e4df08154` (19:16:58Z) adds exactly one path, the allocation, before the first request.
- **Halt records:** `18ed14e63` (19:18:41Z) adds exactly three files: the evidence (sha256 `bb7f0f1b…6de6`), the ledger (sha256 `f7d80a2b…0c0c`) and the publication receipt (sha256 `f5d84a29…2653`).
  - The evidence has `status: "halted"`, 0 scenarios, and `separate_verifier: {status: "pending"}`. Its `diagnostics` contain the canary-stop message quoted above.
  - Its budget is `request_count` 21, `actual_jobs` 0 and `elapsed_seconds` 86.
  - Its `action_approval` names commit `7b6dc4dbd…`, sha256 `32f3bbb7…`, section `canary` and window start 1792437434.
- The ledger's `terminal_stop` is `{code: "pagination_destination_rejected", status: 200}`, so the stop came from the transport.
- No `-PREFLIGHT-*.json` copies were written; the preflight never completed. Step 2 (`remaining`) was not run, and must not be.

## Ledger (decoded from committed bytes)

Times are seconds from the ledger's `started_monotonic_ns`.

| seq | category | route | method | status | start | note |
|---|---|---|---|---|---|---|
| 1 | publication | git_get_commit | GET | 200 | 0.00 | parent `09df342a`, message "ci: Dependabot grouping + Playwright cache fixes (#332)" |
| 2-4 | publication | git_create_tree | POST | 201 | 0.54-5.65 | |
| 5 | publication | git_create_commit | POST | 201 | 7.14 | |
| 6 | publication | git_get_commit | GET | 200 | 7.83 | candidate `6e4f8765…` |
| 7 | publication | git_get_blob | GET | 200 | 8.39 | candidate workflow blob `072a1ea3…` |
| 8 | publication | git_create_tree | POST | 201 | 9.05 | |
| 9 | publication | git_create_commit | POST | 201 | 9.82 | |
| 10 | publication | git_get_commit | GET | 200 | 10.48 | fixture `b37f0542…` |
| 11 | publication | git_get_blob | GET | 200 | 11.08 | fixture workflow blob `f4c9e2f2…` |
| 12 | publication | get_ref | GET | 404 | 11.72 | r12-candidate absent |
| 13 | publication | create_ref | POST | 201 | 12.33 | r12-candidate → `6e4f8765…` |
| 14 | publication | get_ref | GET | 200 | 13.42 | readback `6e4f8765…` |
| 15 | publication | get_ref | GET | 404 | 14.00 | r12-fixture absent |
| 16 | publication | create_ref | POST | 201 | 14.71 | r12-fixture → `b37f0542…` |
| 17 | publication | get_ref | GET | 200 | 15.57 | readback `b37f0542…` |
| 18 | preflight | rate_limit | GET | 200 | 22.18 | core remaining 4909 |
| 19 | preflight | rules_main | GET | 200 | 23.03 | |
| 20 | preflight | branch_protection | GET | 404 | 23.82 | |
| 21 | preflight | check_runs | GET | 200 | 24.80 | `commits/09df342a…/check-runs?per_page=100&page=1`, 307434 B, total_count 209, Link next/last |

- The terminal stop is at 26.10 s, 8 ms after seq 21 ended (26.10 s). No second check_runs page was requested.
- The seq-21 `date` header is 19:18:40 GMT, and the halt commit came at 19:18:41Z.
- **Methods:** 13 GET and 8 POST, all on `api.github.com`. The 8 POSTs are 4 create_tree, 2 create_commit and 2 create_ref. No PUT, PATCH or DELETE, no dispatch and no cancel.

## Requests by category (21 of 117)

| Category | Used / limit |
|---|---|
| publication | 17/24 |
| preflight | 4/8 |
| dispatch | 0/7 |
| run_discovery | 0/7 |
| pre_watch_rate | 0/7 |
| terminal_polls | 0/18 |
| attempt_jobs | 0/7 |
| artifact_metadata | 0/7 |
| artifact_downloads | 0/12 |
| failure_logs | 0/6 |
| cancellation | 0/1 |
| infrastructure_retry | 0/13 (expired) |

Jobs: 0 of 45. Elapsed: 26 s of requests, 86 s by the evidence clock, against 3600 s. Run IDs: none. No run of any scenario and no verifier run exists.

## Diagnosis (read-only, re-derived from committed bytes)

1. **Ledger sequence: confirmed.** There are 21 transactions: publication 1-17 (create_ref 201 at seq 13 and 16) and preflight 18-21 (rate_limit 200, rules_main 200, branch_protection 404, check_runs 200). There is no dispatch route in the ledger.
   - The preflight's next call, `actions/workflows/259268962`, was never made. The evidence shows 0 scenarios.
2. **The parent is the fetched main: confirmed.** Seq 1 reads commit `09df342a82e03c3d5d40173c912b70e827f7eadc`, whose message is the #332 squash. It is in the local object store (`git cat-file -t` → `commit`), and `refs/remotes/origin/main` equals it.
   - This also settles the point 253-134 left open: `09df342a` is #332.
3. **Seq 21 body: confirmed.** The decoded body is 308134 B, with `total_count` **209** and 100 `check_runs` on page 1, all with head_sha `09df342a…`. At 100 per page, 209 is 3 pages.
4. **The link path: confirmed.** The scrubbed `link` header has two entries, `rel: next` and `rel: last`. Both have host `api.github.com`, `has_query: true` and path `/repositories/1207487684/commits/09df342a82e03c3d5d40173c912b70e827f7eadc/check-runs`.
   - The request URL was `/repos/szTheory/sigra/commits/09df342a…/check-runs?per_page=100&page=1`.
   - `1207487684` is this repository's id. It appears 82 times in the committed R11 canary evidence, e.g. at `scenarios.full-pass.run.repository.id` (control: the value 999 appears 0 times).
5. **The refusing line: confirmed.** In `ci-hosted-transport.py`, the live (non-hermetic) branch first checks the host at :1030-1031, which passed because the host is api.github.com. It then requires `parsed.path == expected_path` from `_route()` at :1032-1034, and raises `"pagination link changed its approved API route"` at **:1034**.
   - :1023 carries the same message, but only for `mode == "hermetic-test"`. The allocation's mode is `live`, so :1034 fired.
   - Line 766 of `ci-gate-canary.sh` is `api_get "commits/$CHECK_SOURCE_SHA/check-runs?per_page=100" "$CHECK_RUNS_RESPONSE"`.
6. **Pagination never happened live before: confirmed.** In the R8, R9, R10 and R11 canary ledgers, seq 21 is check_runs on `84ebcea60…` with `total_count` 63 and `link` null.
   - Across all nine committed HTTP ledgers, the only earlier transactions with a `link` header are dispatch responses, where it is `rel: deprecation` to `/en/rest/about-the-rest-api/api-versions`. No ledger before R12 has a `rel: next`. R12 seq 21 is the first.
7. **Blind spot #5: confirmed.**
   - The dry-run fake's `_check_runs` (`ci-gate-canary-dryrun.py:1099-1105`) returns one page holding `len(REQUIRED_CHECKS)` runs, with no `Link`.
   - The transport tests' live pagination fixture builds its next link from `_route()`, so it is always the `/repos/…` form (`ci-hosted-transport.test.py:1513-1515, 1533`).
   - `grep -rln '/repositories/' scripts/ci/` finds nothing. Control: `rel="next"` is found in `ci-hosted-transport.test.py`.
   - The R12 audit row `shape-check_runs` compares no `header:link` field. Control: `shape-rules_main` does.
   - The audit's live pagination row `transport-1018` is covered only by offline tests using the `/repos/` form.
   - The earlier blind spots were #1, the 253-104 redirect host; #2, the 253-113 run-name; #3, the 253-122 log host; and #4, the 253-134 stale parent and mergeability.
8. **Budget is not the blocker: confirmed.** The preflight limit is 8 and 4 were used. A full read would be rate_limit, rules_main, branch_protection, check_runs ×3 and workflow, which is 7 of 8, and allocation `max_pages` is 10.
   - **But note:** this plan's Task 4 verify requires `check_runs` transactions ≤ 1 in the evidence. A 3-page read would fail that assertion as written, so any replan that paginates must change it too.
9. **The cause is the path form, not the depth: inferred.** That GitHub always emits `/repositories/<id>/` next links for this route is not proven: only this one response was observed. Whether pages 2-3 would have passed the other checks (query keys `page`/`per_page`, page = 2) cannot be shown offline, because the query is scrubbed to `has_query: true`.

## What is and isn't proven

- **Proven live:** the R12 publication against the fetched main (both create-only refs, readback equal) and a valid live-origin receipt. The preflight rate_limit, rules_main and branch_protection reads succeeded. The transport fails closed on an unexpected pagination route before a second request.
- **Not proven:** every canary scenario (full-pass, docs-only, actual-failure, missing-seam, unexpected-skip, cancelled), the cancellation, the separate verifier, the five preflight copies, and anything about the R12 candidate's hosted behaviour. CIREL-02 stays open.
- **Unobserved R12 audit entries, first_window 253-143:** the only one is `canary-failure_logs-zero-slack` (shape-run_logs). It was not reached. The other nine entries are first_window 253-144.

## GitHub state now

- `refs/heads/gsd/253-replan-r12-candidate` → `6e4f87657254ed9d4a3c8b661d5e707751bc5214` (seq 13 201, seq 14 readback)
- `refs/heads/gsd/253-replan-r12-fixture` → `b37f05424b2b497b3c786fc604caa4dab4dbcdf0` (seq 16 201, seq 17 readback)
- The r8, r9, r10 and r11 refs are untouched. No ledger URL contains `253-replan-r8`, `-r9-`, `-r10-` or `-r11-` (control: URLs containing `253-replan-r12-` are present).
- Draft PR #337 (253-134) is still open. All scoped refs (r8-r12) and #337 remain for Jon's optional manual cleanup. No agent closes or deletes anything.

## Task 4: offline verification (this executor)

- **The Task 3 verify block** (extracted verbatim to a scratch script) exits **0**. The allocation and ledger are committed, no lock file remains, and the tree is clean except config.json.
- **The verbatim Task 4 verify block** exits **1**, as expected for a halt. The first failing check is `hosted-gate-verify: FAIL: measured transport ledger has a terminal stop`, from `--scenario full-pass`.
- **Checks that apply to a halted window, run one by one:**
  - **Pass:**
    - `--verify-publication --require-live-origin` rc 0.
    - `--check-approval --section canary` against FREEZE-R12 rc 0. Controls: `--section docs_and_prs` rc 1, and FREEZE-R11 rc 1.
    - The receipt's r12 refs check (jq) rc 0.
    - Ledger ≤117 transactions.
    - The evidence checks: no r8-r11 URL, at least one r12 URL, window ids, `request_count` equal to the ledger length, and no infrastructure_retry. rc 0.
    - Ancestry approval `7b6dc4dbd` → allocation `e4df08154` → ledger `18ed14e63`, rc 0. Control: reversed, rc 1.
    - The allocation commit has exactly 1 path.
    - The node approval/allocation binding, rc 0. It checks the commit, sha256, section, committer time ≤ window start, live/canary/window/117/3600, the freeze-bound category table, and 43 hosts with results-receiver once. Control: an exit-3 probe returned 3.
    - `PRESERVATION-R12.sha256` (128 lines) rc 0.
    - config.json sha256 `8e312f6c…`.
  - **Fail (halt):** `(.status // "") != "halted"`, and full-pass, sources and matrix verification.

## Options for Jon (not chosen here)

- **(a) R13 gap round.** The transport accepts GitHub's `/repositories/<numeric id>/` pagination form, bound to the repository id from a committed real response, with the route otherwise equal. The fakes emit that form with more than 100 check runs (209, 3 pages), RED-first. Then a new freeze, new r13 refs, a fresh canary approval and a re-run. 253-144/145 follow. The Task 4 `check_runs ≤ 1` assertion would also need restating, per point 8.
- **(b) The same as (a), plus a smaller preflight check_runs read** (e.g. a filter), so it doesn't depend on main's check count.
- **(c) Stop Phase 253 here.**

## Commits

- `7b6dc4dbd`: docs(253-143): record Jon's R12 canary action approval (Jon via !, W1)
- `5bf43ae2a`: docs(253-143): R12 canary operator runner (Jon runs the live steps)
- `e4df08154`: docs(253-143): declare the R12 live canary HTTP allocation (runner, Jon)
- `18ed14e63`: docs(253-143): halted R12 canary records (full-pass exit 1) (runner, Jon)
- This SUMMARY: docs(253-143): halted SUMMARY (preflight check_runs pagination on fetched main)

## Deviations from Plan

1. **[W1 fallback] The approval was written and committed by Jon via `!`.** The classifier refused the executor's Write ("Instruction Poisoning"). The record content and its single-file commit match the plan; only the author differs, and `decided_by` records it.
2. **Otherwise as written.** The halt follows the plan's rule: no source edit, reseal, rerun or extra window. The STATE, ROADMAP and REQUIREMENTS writers were skipped per the orchestrator's hard constraints.

## Remaining gaps

- **CIREL-02 stays open:** no R12 canary scenario has been proven.
- **CIREL-01** stays partial under the 253-89 not_reproduced disposition.
- **253-144 and 253-145 are blocked** by this halt. Full Phase 253 verification stays not_started.

## Known Stubs

None.

## Self-Check: PASSED

- The six 253-143 records exist and are committed. The five `-PREFLIGHT-*.json` copies are absent, as expected for a preflight halt.
- `7b6dc4dbd`, `5bf43ae2a`, `e4df08154` and `18ed14e63` are ancestors of HEAD, and `git rev-list --count 626159d66..18ed14e63` = 4. With this SUMMARY the count is 5.
- The tree is clean except config.json (sha256 `8e312f6ccd34…`). state.json is 70229 bytes, prefix `e45278c2cee0`. `scripts/ci/__pycache__` is absent.
