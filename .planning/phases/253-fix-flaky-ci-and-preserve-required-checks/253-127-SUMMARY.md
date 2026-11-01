---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "127"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, shape-probe, read-only, github, operator-run, r11]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-126
    provides: scripts/ci/ci-shape-probe.py (driver) and the five-GET request list 253-LOAD-RECOVERY-PROBE-REQUESTS-R11-PROBE.json (sha256 375c5758...4301)
  - phase: 253-125
    provides: the run_logs-only results-receiver hop in the transport, token sent to api.github.com only
provides:
  - real-shape fixtures (fixtures only, never acceptance evidence) for 253-128/129, in the R11 probe allocation, ledger, evidence and bodies records
  - "observed: run_logs hop 0 is a 302 to results-receiver.actions.githubusercontent.com, and hop 1 is a 200 application/zip from results-receiver itself, with no hop 2 (h = 2)"
  - "observed: the real cancelled ci.yml run (38141825287) and its 27 jobs: key sets and conclusion values"
  - "observed: job_logs is a 302 to productionresultssa18.blob.core.windows.net"
affects: [253-128, 253-129]
tech-stack:
  added: []
  patterns: ["operator-run window from a committed runner", "offline classification from committed ledger bytes, one positive control per claim"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-127-SUMMARY.md
  modified: []
key-decisions:
  - "Halt rules 1-5 all pass from committed bytes. The round is complete: h = 2, the failure_logs need is 6 against a limit of 6 (no slack), and the projected canary ledger is 2,562,073 bytes against a limit of 7,340,032."
  - "results-receiver serves the zip itself (hop 1 is a 200), so option A as built (results-receiver scoped to run_logs hop 1) matches the real chain. No hop-2 host exists, so the pre-R11 hop-2 predicate is never exercised."
estimate: {tokens: 30000, tasks: 4}
actuals:
  tokens: 9000
  tasks: 4
  commits: 4
commits: 4
plan_head_before: f9c267a39e2b87811256f40653884ca2b2d323a9
plan_head_after: 64679fcc3
metrics:
  completed: 2026-10-16
  window_elapsed_seconds: 5
  window_requests: 6
---

# Phase 253 Plan 127: R11 Read-Only Shape Probe Summary

**Jon ran a GET-only window: 6 requests in 5 s, against caps of 8 requests and 600 s. It shows that the run_logs chain for run 38963239851 is `api.github.com 302 -> results-receiver 200 application/zip` (h = 2, no hop 2). It also records a real cancelled run with its 27 jobs, and a real job-log 302 to `productionresultssa18.blob.core.windows.net`. Every halt rule passes.**

These records are real-shape fixtures for 253-128 and 253-129 only (D-17/D-19/D-21). They are never acceptance evidence. CIREL-02 stays open, and the 253-89 CIREL-01 disposition is unchanged. Full Phase 253 verification stays not_started.

## Who did what

| Step | Actor | Result |
|---|---|---|
| Task 1: offline gates + approval checkpoint | orchestrator ran the gates (exit 0); Jon answered through AskUserQuestion | Jon's decision, verbatim: **"Approve (Recommended)"**, no note, 2026-10-16T23:01:51Z |
| Task 2: approval record + operator runner + self-check | an earlier executor | approval `b29f589ef` (sha256 `65f0e269…0ec8`); runner `8af57192a` (sha256 `2604d5e9…1dee`); receipt `.git/sigra-253-R11-probe-self-check.txt`: `SELF-CHECK OK head=8af57192a… runner_sha256=2604d5e9…1dee` |
| Task 3: the window | **Jon**, `! bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-PROBE-OPERATOR.sh` | the runner committed allocation `2f585bb5a` alone, then records `64679fcc3` |
| Task 4: offline verify + classification + SUMMARY | this executor (zero GitHub requests) | verify exit 0; all halt rules pass |

Runner lines Jon reported (verbatim):

```
CLOCK STARTS 2026-10-16T23:08:48Z (window 253-127-probe-window-1)
WINDOW DEADLINE 2026-10-16T23:18:48Z (now + 600 s)
WINDOW LEFT 600 RESERVED 240 (8 requests x 30 s per-request deadline)
ci-shape-probe: {"elapsed_seconds": 5, "request_count": 6, "status": "complete", "stop": null}
64679fcc3 docs(253-127): R11 shape-probe records
DONE probe 2026-10-16T23:08:54Z
```

## Task 4 `<verify>` (verbatim, run under bash from the checkout root)

The verify ran byte-for-byte from the plan, through a scratchpad copy. It exited **0**. Output:

```
ci-shape-probe: check-only OK requests_sha256=375c5758b1029942883e45a1bdc215dc2d9f87d0bf00d3554d6f85f76b754301 allocation_sha256=79869fd022112cf8fe7ef4e5a0d994d0c3e31360564842b8f6bdcd0eea24bc99
{"h":2,"failure_logs_need":6,"limit":6,"final_raw_bytes":24644,"final_scrubbed_bytes":43481,"projected_ledger_bytes":2562073,"ledger_limit":7340032}
```

The node JSON line is the positive control for the chain: it prints only after every jq gate before it has passed. Exit 0 also covers the ancestry, the committer time, the preservation sha256 manifest, the config.json pin and the clean-tree checks that come after it.

- **h = 2.** Two run_logs rows: hop 0 and hop 1.
- **failure_logs need = 3 x 2 = 6, against the CANARY_CATEGORIES limit of 6.** Exactly at the limit, with zero slack.
- **Projected canary ledger = 2,562,073 bytes, against 7,340,032.**
  - R10 ledger part: 910,412 bytes / 47 transactions x 117 = 2,266,344.8, rounded up to 2,266,345.
  - Download part: B = max(43,481 scrubbed, 3 x 24,644 = 73,932) = 73,932, then 3 x ceil(4/3 x 73,932) = 3 x 98,576 = 295,728.
  - Total: 2,266,345 + 295,728 = 2,562,073 (34.9% of the limit).

## Halt rules

| # | Rule | Result | Proof (committed bytes) |
|---|---|---|---|
| 1 | probe stopped before run-log-chain completed | **pass** | evidence `status: complete`, `stop: null`; ledger `terminal_stop: null`; runner printed `DONE probe`, not STOP; run-log-chain result `status: complete` |
| 2 | hop 0 not a 302 to results-receiver | **pass** | ledger seq 5: `actual_status 302`, `location.host results-receiver.actions.githubusercontent.com` (jq gate in verify) |
| 3 | chain not ending in 200 within max_hops 2, or a hop-2 host outside the pre-R11 predicate | **pass** | ledger seq 6 (hop_ordinal 1) is a 200, and it is the last run_logs row. No hop_ordinal 2 exists, so the hop-2 predicate is vacuous. Control: the verify's `hops[-1].status == [200]` gate and its h < 2 check (exit 5) both passed. |
| 4 | failure_logs need above 6 (exit 3) | **pass, at the limit** | need 6, limit 6 |
| 5 | projected ledger above 7,340,032 (exit 4) | **pass** | 2,562,073 |

## Observed shapes

| id (seq) | route | host | status | content-type | content-length / bytes | Location (host, path pattern, has_query, port) |
|---|---|---|---|---|---|---|
| rate (1) | rate_limit | api.github.com | 200 | application/json; charset=utf-8 | 1236 | none |
| cancelled-run (2) | run | api.github.com | 200 | application/json; charset=utf-8 | 11662 | none |
| cancelled-jobs (3), page 1 | run_jobs | api.github.com | 200 | application/json; charset=utf-8 | 70213 | none |
| job-log-redirect (4) | job_logs | api.github.com | 302 | text/html;charset=utf-8 | 0 | `productionresultssa18.blob.core.windows.net`, `/actions-results/{uuid}/workflow-job-run-{uuid}/logs/job/job-logs.txt`, has_query true, port null |
| run-log-chain hop 0 (5) | run_logs | api.github.com | 302 | text/html;charset=utf-8 | 0 | `results-receiver.actions.githubusercontent.com`, `/rest/runs/{uuid}/logs`, has_query true, port null |
| run-log-chain hop 1 (6) | run_logs | results-receiver.actions.githubusercontent.com | **200** | **application/zip** | **no content-length header**; raw 24,644 bytes, scrubbed 43,481 | none |

### run-log-chain (run 38963239851)

- **Hop 0:** a 302 from api.github.com with an empty body. Its Location points at results-receiver `/rest/runs/{uuid}/logs?<signed query>`.
- **Hop 1:** results-receiver answered **200 `application/zip` itself**. It did not redirect again.
  - Safe header names on the hop-1 response: `content-type`, `date`, `x-github-request-id` only. No `content-length`, so the body was probably chunked.
  - The stored URL is redacted (`?[REDACTED]`).
- **Hop 2: none.** A single run_logs fetch charges h = 2 requests.
- The body is a zip: magic `504b030414000800`, raw sha256 `2f75cce8…5c60c`.
  - 12 members, matching `{n}_<job name>.txt` plus `<job name>/system.txt`: Browser verdict, and producer (admin_checkpoints / design_gallery / admin_behavior / non_admin_smoke / demo_showcase).
  - Uncompressed sizes are 710 to 54,064 bytes.
  - `full_base64` is null, so the full bytes were **not** kept. Head samples were kept (16,616 bytes).
- Positive control (scrub expansion): the ledger's `response_body_base64` decodes to 43,481 bytes, equal to `scrubbed_response_bytes`. Its sha256 equals `response_sha256`, while `raw_observation_sha256` is different, and the magic `PK\x03\x04` survives. So the ledger holds the UTF-8-replaced scrub of the zip, not the zip itself, as the plan's factor-3 bound assumed. 43,481 is at most 3 x 24,644, as required.

### cancelled-run (38141825287)

- **Status:** 200, `status: completed`, `conclusion: cancelled`, `name: CI`, `event: pull_request`, `path: .github/workflows/ci.yml`, `run_attempt: 1`.
- **Top-level keys (35):** actor, artifacts_url, cancel_url, check_suite_id, check_suite_node_id, check_suite_url, conclusion, created_at, display_title, event, head_branch, head_commit, head_repository, head_sha, html_url, id, jobs_url, logs_url, name, node_id, path, previous_attempt_url, pull_requests, referenced_workflows, repository, rerun_url, run_attempt, run_number, run_started_at, status, triggering_actor, updated_at, url, workflow_id, workflow_url.
- **Positive control:** the decoded body's sha256 equals the row's `response_sha256`.

### cancelled-jobs (38141825287, per_page=100, page 1 only)

- **Status:** 200. Top-level keys `jobs`, `total_count`; total_count 27, 27 jobs on one page.
- **Job keys:** check_run_url, completed_at, conclusion, created_at, head_branch, head_sha, html_url, id, labels, name, node_id, run_attempt, run_id, run_url, runner_group_id, runner_group_name, runner_id, runner_name, started_at, status, steps, url, workflow_name.
- **Step keys:** completed_at, conclusion, name, number, started_at, status.
- **Job (status, conclusion) counts:**
  - completed/cancelled 11
  - completed/skipped 8
  - completed/success 5
  - completed/failure 3
- **Step (status, conclusion) counts:**
  - completed/success 183
  - completed/skipped 71
  - completed/cancelled 10
  - completed/failure 3
- 9 jobs have empty or absent `steps`.
- **Positive control:** the decoded body's sha256 equals `response_sha256`.

### job-log-redirect (job 117183276622)

- **Status:** a 302 with an empty body. The Location host is `productionresultssa18.blob.core.windows.net` (one of the 42 pre-R11 download hosts), and the path pattern is in the table above.
- No hop 1 was fetched, by design.
- Not a halt; this is recorded for 253-129.

### Bodies record

| id | kind | bytes | magic | zip members | full kept | token_scan |
|---|---|---|---|---|---|---|
| rate | json | 1236 | n/a | n/a | n/a | n/a |
| cancelled-run | json | 11662 | n/a | n/a | n/a | n/a |
| cancelled-jobs | json | 70213 | n/a | n/a | n/a | n/a |
| job-log-redirect | download | 0 | empty | null | yes (empty) | clean |
| run-log-chain (hop 1) | download | 24644 | `504b030414000800` | 12 (pattern above) | **no** | **matched** (flagged below) |

## Window invariants (from the ledger)

- **GET only.** All 6 rows have `method: GET` (verify jq gate). No URL contains `253-replan`.
  - Control: the same jq gate requires exactly one `rate_limit` row, and it found one.
- **Token on api.github.com only.**
  - Rows 1-5 have host `api.github.com`. The only other host is row 6, `results-receiver.actions.githubusercontent.com`, with `route_id: run_logs` and `hop_ordinal: 1` (verify gates: no non-api host off run_logs, none at hop 0).
  - The transport attaches `Authorization` only when `host == API_HOST` (`scripts/ci/ci-hosted-transport.py` :665-680), and every request uses a new connection (`Connection: close`). So the bearer token went only to api.github.com.
  - No ledger row stores a request header. The ledger file and the bodies file contain no `gh?_…` or `github_pat_…`-shaped token (0 matches; the regex was positive-controlled on a synthetic string).
- **Counts per category, against the probe allocation:**
  - preflight 1/1
  - cancelled_shape 2/3
  - job_log_shape 1/1
  - failure_logs 2/3
  - total 6/8
- **Time:** elapsed 5 s of 600.
- **Commit order:** approval `b29f589ef` (ct 1792191783), then runner `8af57192a` (1792191907), then allocation `2f585bb5a` (1792192128, committed alone), then records `64679fcc3` (1792192133).
  - `window_wall_start_epoch` = 1792192128. The approval ct is not later than it, and the allocation commit is in the same second as the clock start.
  - The evidence `driver_commit` is `2f585bb5a…`, so the driver ran on the allocation commit.
  - The first request's `date` is 23:08:49Z.
- No ledger lock file and no untracked record remain.

## Record sha256

| file | sha256 |
|---|---|
| 253-LOAD-RECOVERY-PROBE-REQUESTS-R11-PROBE.json | 375c5758b1029942883e45a1bdc215dc2d9f87d0bf00d3554d6f85f76b754301 |
| 253-LOAD-RECOVERY-PROBE-ACTION-APPROVAL-R11-PROBE.json | 65f0e2697a5981287565f8ac9c7bc43e2ac57aa2b70494bfcfa5fde7af3a0ec8 |
| 253-R11-PROBE-OPERATOR.sh | 2604d5e9dc648e4de1d3ad75411e515803f63d7db3b095596328e48b8a741dee |
| 253-LOAD-RECOVERY-PROBE-ALLOCATION-R11-PROBE.json | 79869fd022112cf8fe7ef4e5a0d994d0c3e31360564842b8f6bdcd0eea24bc99 |
| 253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json | 79e8b4d320c410e9179aa610a614b8c4fa97d4aada692e004484134b59e10018 |
| 253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json | 6980e6e58cf086d77bc1b7583d93ae1c46703e523baeb6c01a341046572a82de |
| 253-LOAD-RECOVERY-PROBE-BODIES-R11-PROBE.json | 3b8d5bf4cc0af7fcf302fe3897eaeef3e2219de0822a98d871032c9f4b6c9523 |

## Task Commits

| Task | Commit | Who |
|---|---|---|
| 2 (approval) | b29f589ef | executor |
| 2 (runner) | 8af57192a | executor |
| 3 (allocation, alone, before the clock) | 2f585bb5a | Jon's runner |
| 3 (ledger + evidence + bodies) | 64679fcc3 | Jon's runner |
| 4 (this SUMMARY) | the docs commit that adds this file | executor |

`commits: 4` is measured as `git rev-list --count f9c267a39..64679fcc3`. The SUMMARY commit adds a fifth.

## Flags for Jon / residual risk (not halts)

1. **Token scan on the run-log zip: `matched`.** The match is not quoted here. Because of it, the driver kept no full copy (`full_base64: null`). Neither the committed scrubbed ledger body nor the committed head samples match the scan pattern (0 matches each), and no `gh?_`/`github_pat_` token-shaped string appears in any committed record. The match is therefore in bytes that were not committed: compressed zip data or uncommitted parts of the members. Please glance at it, but it does not look like a leak in the repo.
2. **The failure_logs budget has zero slack.** 3 scenarios x h = 2 is exactly 6. If GitHub ever adds a hop, or a retry hits run_logs, the frozen canary limit is exceeded. That would be a later re-decision: move infrastructure_retry slack inside the unchanged 117 total, or fetch logs for fewer scenarios.
3. **Hop 1 has no `content-length`.** The response was probably chunked. 253-128 fakes must not assume a content-length on the results-receiver 200.
4. **The ledger stores the scrubbed (U+FFFD-expanded) zip, not the zip.** Anything that tries to unzip `response_body_base64` from a hop-1 row will fail. Fixtures must model raw size and scrubbed size separately (24,644 vs 43,481 here).
5. **Two interleaved rate-limit counters.**
   - Rows 1 and 3: remaining 4851 then 4850, reset 1792193189.
   - Rows 2, 4 and 5: remaining 4999, 4998, 4997, reset 1792195729.
   - The records don't explain this. The transport takes the token from one source per run.
6. **The job-log host is a blob host** (sa18), not results-receiver. Recorded for 253-129.
7. **Local preservation refs.** The ledger lists 5 `refs/gsd/phase253-http-ledger/*` preserved revisions. These are local refs written by the transport, all present locally; no request was made.

## Deviations from Plan

None. Task 4 was run as written: the verify was verbatim, no record was edited, and no request was made. As instructed by the orchestrator, the state-update steps were skipped (no gsd-tools writers; STATE.md, state.json, ROADMAP.md and REQUIREMENTS.md untouched).

## Known Stubs

None.

## Handoff to 253-128 / 253-129

- The response_shape reference for run_logs is ledger seq 5 (hop 0: 302, `text/html;charset=utf-8`, content-length 0, Location results-receiver `/rest/runs/{uuid}/logs`, has_query) followed by seq 6 (hop 1: 200 `application/zip` from results-receiver, no content-length, safe headers content-type/date/x-github-request-id).
- Fakes must stop at hop 1. A results-receiver 302 to a blob host is not the real shape.
- Model the cancelled-run and jobs fakes on seq 2 and seq 3: the key sets above, run `completed/cancelled`, jobs with mixed cancelled/skipped/success/failure, and 9 jobs with no steps.
- The job_logs fake is a 302 to `productionresultssa{N}.blob.core.windows.net/actions-results/{uuid}/workflow-job-run-{uuid}/logs/job/job-logs.txt?<query>`.
- Budget inputs: h = 2, failure_logs need 6/6, projected ledger 2,562,073 / 7,340,032 bytes.
- These records are fixtures only. Do not cite them as acceptance evidence.

## Invariants (at SUMMARY write)

- `git status`: only ` M .planning/config.json` (plus this SUMMARY before its commit).
- config.json sha256: `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d` (unchanged).
- state.json: 70229 bytes, sha256 prefix `e45278c2cee0` (unchanged).
- `scripts/ci/__pycache__`: absent.

## Self-Check: PASSED

- FOUND: all six R11 probe records and the runner (sha256 values above).
- FOUND: b29f589ef, 8af57192a, 2f585bb5a and 64679fcc3 are ancestors of HEAD; the verify's ancestry gates passed.
