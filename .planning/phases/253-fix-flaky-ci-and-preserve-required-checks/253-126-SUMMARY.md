---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "126"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, shape-probe, read-only, results-receiver, r11]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-125
    provides: the run_logs-only results-receiver hop in the transport (0226f20ae), the LivePolicyRedirectTests fixture pattern, the R11 audit record
  - phase: 253-122
    provides: R10 ledger sequences 45 (jobs body) and 47 (run_logs hop 0 302 to results-receiver), and ALLOCATION-R10's 42 download hosts
provides:
  - scripts/ci/ci-shape-probe.py, a read-only probe driver (--check-requests, --check-only, --run) that sends every GET through request_one / fetch_pages / follow_download
  - scripts/ci/ci-shape-probe.test.py, 19 tests: the live-policy rehearsal of the probe chain and the refusal matrix
  - 253-LOAD-RECOVERY-PROBE-REQUESTS-R11-PROBE.json, the five-GET list Jon's 253-127 approval binds (sha256 375c5758...)
  - the R11 audit record at schema r11 with the driver in its matcher
affects: [253-127, 253-128, 253-129]
tech-stack:
  added: []
  patterns: ["driver over the transport (no HTTP client of its own)", "exact ordered binding of allocation to request list", "refusal proven by an empty shim connect log after an unmodified positive control", "scratch Git repo so driver_commit checks are real ancestry"]
key-files:
  created:
    - scripts/ci/ci-shape-probe.py
    - scripts/ci/ci-shape-probe.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-REQUESTS-R11-PROBE.json
  modified:
    - scripts/ci/ci-hermetic-live-audit.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R11.json
key-decisions:
  - "The allocation is bound to the request list by equality, not by the transport's acceptance. The driver refuses an allocation whose window, caps, category table, repository or exact ordered download_hosts differ, so the pre-R11 42-host allocation is refused by the driver even though transport --check-only accepts it."
  - "Every refusal happens before any request. The driver also refuses to resume: an existing ledger, ledger lock, evidence or bodies file is refused, so a halted window cannot be retried by re-running."
  - "Evidence is written after every request. Until the last request completes, it says status halted with stop code incomplete, so a crash or kill leaves a truthful record. SIGTERM and SIGHUP become a halted record with stop code interrupted."
  - "full_base64 is kept only for a body of at most 262144 bytes whose raw bytes and every zip member pass the token scan. The scan adds a signed-URL query pattern ([?&]sig=, signature=, x-amz-signature=) to the plan's gh*_ / github_pat_ / bearer / authorization patterns."
estimate: {tokens: 42000, tasks: 2}
actuals:
  tokens: 19300
  tasks: 2
  commits: 3
commits: 3
plan_head_before: f0d06cc42d81e5ad399cf8a1f1c93b279e9031b2
plan_head_after: c6477becce02c0609698b02d7cbfa368076f878f
driver_commit: 82a5c3b52e7a78a8ba4a4e0a6f8fb71b58483b1b
request_list_commit: 2f960a01f32e3165c0183f5bd2ca333b1cc6bbe4
request_list_sha256: 375c5758b1029942883e45a1bdc215dc2d9f87d0bf00d3554d6f85f76b754301
duration: "about 15 minutes (22:42Z to 22:57Z)"
completed: 2026-10-16
---

# Phase 253 Plan 126: Read-only shape-probe driver and probe request list Summary

**A read-only probe driver now exists, and 253-127 can run it. It sends exactly five approved GETs, each one through the 253-125 transport. The driver has no HTTP client of its own. Before any request, it refuses anything that is not a GET on its five routes, a redirect-follow on any route but run_logs, any gsd/253-replan name, an unbound or edited request list, an approval that is not approve, and an allocation that differs from the request list in any bound field. Every refusal is proven with an empty shim connect log. The committed request list names the five GETs for window 253-127-probe-window-1 (at most 8 requests and 600 s). This plan made zero GitHub requests.**

## Task Commits

1. **Task 1 (tracer, RED then GREEN):** `82a5c3b52` feat(253-126): read-only shape-probe driver over the hosted transport. Driver and test are committed together, as the plan says. This is the request list's `driver_commit`.
2. **Task 2, request list (committed alone):** `2f960a01f` docs(253-126): R11 shape-probe request list
3. **Task 2, audit:** `c6477becc` docs(253-126): shape-probe driver in the R11 audit matcher

## Preconditions

- **Task 1:**
  - 253-125-SUMMARY.md says `status: complete`.
  - The tree was clean except config.json.
  - `git log --all --grep 'admit results-receiver for the run_logs redirect hop only'` finds exactly 1 commit.
- **Task 2:** Task 1 was committed (`82a5c3b52`).

## RED / GREEN (Task 1)

- **RED, first attempt:** a load failure, so it was not counted as RED.
  - The first test draft copied the driver into its scratch repository at module setup, so the missing driver failed `setUpModule` with FileNotFoundError and 0 tests ran.
  - I changed the setup so an absent driver becomes an empty file. Every test then runs and fails on its own assertion.
- **RED, counted:** `python3 scripts/ci/ci-shape-probe.test.py` exited 1. 19 tests ran: 16 failures and 3 errors.
  - All 15 refusal tests fail at the positive control in `setUp`: `'check-only OK' not found in ''`, because the empty driver prints nothing.
  - The 4 rehearsal tests fail in two ways:
    - the halt test fails on its exit-code assertion;
    - the other 3 error with FileNotFoundError on `evidence.json` / `bodies.json`, because no records were written.
  - **Assessment:** every target test ran and failed because the behaviour was missing, not because of a fixture fault.
- **GREEN:** 19/19 pass in 15.3 s, with no warnings in the output and no `__pycache__` left.

## The driver (`scripts/ci/ci-shape-probe.py`, sha256 `6aab53a2…16207` at `82a5c3b52`)

**Modes.**
- `--check-requests R` checks the request list alone, offline.
- `--check-only --requests R --allocation A --approval AP` adds the binding checks.
- `--run` takes the same three plus `--ledger L --evidence E --bodies B`.
- Exit 0 on success; 1 on a refusal or a halted window; 2 on a usage error.
- A refusal prints `ci-shape-probe: REFUSED: <field>: <reason>` on stderr. Field prefixes are `list.`, `approval.`, `allocation.`, or `transport`.

**Request list.** Every field is required and no unknown field is allowed:
- `schema_version` must be `sigra.phase253.shape-probe-requests/v1`; `repository` must be szTheory/sigra; `window_id` is required.
- `max_requests` ≤ 12; `max_elapsed_seconds` ≤ 600; `max_response_bytes` ≤ 4194304.
- `max_pages` is 1 or 2; `max_hops` is 2. All of these must be exact integers.
- `category_limits` are positive integers that sum to max_requests.
- `download_hosts` is unique and ordered. Every entry must pass `_pre_r11_download_host` or equal `RESULTS_RECEIVER_HOST`.
- `source_pointers`:
  - each entry is `{path, sha256}` plus exactly one of `pointer` or `sequence`;
  - the file's bytes at `HEAD` must hash to the recorded sha256, and the working-tree file must equal them;
  - the pointer or sequence must resolve.
- `driver_commit`:
  - must be a full SHA and an ancestor of HEAD;
  - the driver and the transport must be committed at both driver_commit and HEAD;
  - `git diff --quiet driver_commit HEAD` must pass for both files, and so must `git diff --quiet HEAD` (the working tree).
- `requests`: each item is exactly `{id, route_id, method, category, params, query, mode}`.
  - route_id is one of rate_limit, run, run_jobs, run_logs, job_logs, and method is GET.
  - mode is `one` on any of the five routes, `pages` only on run_jobs, and `follow` only on run_logs.
  - params must be exactly the route's parameters. The only query key allowed is `per_page` on run_jobs.
  - Any "253-replan" in an item or its path is refused.
  - The transport's `_route` must accept the item.
  - Worst-case cost (one 1, pages max_pages, follow 1+max_hops) must fit each category's limit and max_requests.

**Binding.** sha256(R) must equal `approval.section_sha256` and `allocation.source_sha256`.
- **Approval:** exactly the 11 fields; schema `sigra.phase253.shape-probe-approval/v1`; section shape_probe; decision approve; `requests_path` resolving to R.
- **Allocation:** exactly the 14 transport fields; schema v1; mode live; kind canary.
  - repository, window_id, max_requests, max_elapsed_seconds, max_response_bytes, max_pages, max_hops, category_limits and download_hosts each equal the request list's. JSON types must match, and download_hosts must match as an ordered list.
  - `bound_documents` must be exactly `[R, AP]` with their sha256.
- **Transport:** then `_validate_allocation`, `_check_bound_documents`, and `_route` plus `_request_category` for every request.

**Run.**
- It refuses an existing ledger, ledger lock, evidence or bodies file.
- It takes `window_wall_start_epoch` immediately before the first request.
- Each request goes through `transport.request_one`, `transport.fetch_pages` or `transport.follow_download`.
- Evidence and bodies are written after every request with `transport._atomic_json`.
- It stops on the first error and never retries. It deletes the ledger lock and its private temp directory on every path.
- It sets `sys.dont_write_bytecode`, so a run leaves no `scripts/ci/__pycache__` (confirmed: none after the `--check-requests` run).

**Evidence** (`sigra.phase253.shape-probe-evidence/v1`):
- Top level: `window_id`; the requests, approval and allocation sha256; `driver_commit` (HEAD at run time); `window_wall_start_epoch`, `ended_epoch`, `elapsed_seconds`; `request_count` (equal to the ledger length); `status`; `stop`; `results`; and `transport_ledger` (a copy of the ledger).
- Each result has:
  - `{id, route_id, mode, category, status}`;
  - `receipts`: the transport's receipts, or the ledger rows for a halted request;
  - `observed.hops`, each with sequence, hop_ordinal, page_ordinal, host, status, state, `path_pattern` (UUIDs, then 20+ hex runs, then digit runs replaced by placeholders), has_query, content_type, content_length, safe_header_names, and `location {host, path_pattern, has_query, port}` or null.

**Bodies** (`sigra.phase253.shape-probe-bodies/v1`, under `entries`):
- **JSON responses:** `{id, hop_ordinal, page_ordinal, kind json, sha256 (raw), bytes}` only.
- **Download final responses** carry:
  - sha256 and bytes, magic_hex (first 8 bytes), and content_type;
  - `zip_members [{name, size, compressed_size, crc}]`;
  - `head_sample_base64`: the first 2048 bytes after `transport._scrub_text`; for a zip, a list of `{name, head_sample_base64}`, one per member;
  - `token_scan` (clean or matched), `token_scan_complete`, and `full_base64`.
- The body's digest is checked against the receipt's `raw_observation_sha256`.

## Rehearsal and refusal results (Task 1)

**Setup.**
- **Scratch repository:** a Git repo with the driver, the transport, 252-BASELINE.json, LEDGER-R10 and ALLOCATION-R10, and three commits: an older driver revision, the driver, and an orphan.
- **Live allocation and shim:** the in-child shim maps api.github.com, results-receiver.actions.githubusercontent.com, productionresultssa16.blob.core.windows.net and evil.example.com to one local TLS fake. The token is a dummy.

**Rehearsal tests:**
- **`test_live_probe_records_the_seq47_chain_to_results_receiver`:** status complete with 6 ledger rows:
  - rate 200; run 200; jobs 200 (1 page); job_logs 302; run_logs hop 0 302; results-receiver hop 1 200.
  - The connect log is api×5 then results-receiver. The fake's journal shows `Bearer` only on api.github.com.
  - job_logs has one hop with Location host productionresultssa16 and no blob socket.
  - The Location `path_pattern` is `/rest/runs/{uuid}/logs`.
  - The bodies record has the zip member list (names, sizes, CRCs), token_scan clean, and full_base64 that decodes to the served zip.
  - Neither the dummy token nor the synthetic signature appears in any record.
- **`test_live_probe_records_a_results_receiver_to_blob_chain`:** run_logs rows are api 302, then results-receiver 302, then blob 200. The body entry is at hop 2.
- **`test_live_probe_halts_on_an_untrusted_hop_and_keeps_partial_records`:**
  - exit 1, evidence halted, `stop {redirect_rejected, run-log-chain}`, and the ledger's terminal_stop is redirect_rejected;
  - the four earlier results are complete and kept, with their bodies;
  - run-log-chain is halted, with hops api 302 and results-receiver 302 (Location evil.example.com);
  - there was no evil.example.com socket.
- **`test_live_probe_large_body_keeps_only_digest_and_head_sample`:** a 300000-byte clean body gets `full_base64 null` and a 2048-byte head sample.

**Refusal matrix.** Each case: exit 1 with the named field; an empty connect log, refusal log and fake journal; no ledger, lock, evidence or bodies file. Every test first checks that the unmodified `--check-requests` and `--check-only` pass.
- **Plan refusals:**
  - POST (`list.requests[0].method`);
  - dispatch, cancel_run, create_ref, get_ref, pr_create and artifact_zip (`list.requests[1].route_id`);
  - follow on job_logs (`list.requests[3].mode`);
  - "253-replan" in a param, a query value or an id (`list.requests[2]`);
  - list edited after approval (`approval.section_sha256`);
  - reject (`approval.decision`);
  - hermetic-test (`allocation.mode`);
  - production (`allocation.allocation_kind`);
  - category_limits (`allocation.category_limits`);
  - bound_documents without the approval (`allocation.bound_documents`).
- **Extra refusal:** existing records (`evidence`).
- **`test_check_only_refuses_an_allocation_without_results_receiver`:** the driver refuses `allocation.download_hosts`. Control: transport `--check-only` on the same 42-host allocation exits 0.
- **`test_check_only_refuses_each_allocation_field_that_differs_from_the_request_list`:** 11 subTests, each refused by both `--check-only` and `--run`:
  - window_id, max_requests 9, max_elapsed_seconds 599, max_response_bytes 2097152, max_pages 1, max_hops 1;
  - category_limits, repository;
  - download_hosts without results-receiver, with productionresultssa41 added, and with the first two hosts swapped.
- **`test_check_requests_refuses_each_missing_or_altered_field`:** 17 subTests, each with an empty connect log:
  - each of the 13 fields removed;
  - an unknown field (`list.extra_field`);
  - `list.source_pointers[0].sha256` altered;
  - driver_commit set to the orphan (not an ancestor) and to the older revision (driver changed since).
- **`test_the_driver_imports_no_http_client_of_its_own`:** the plan's regex finds nothing in the driver. Positive control: the same regex matches the transport and `from http import client`.

**Task 1 `<verify>`** (verbatim, plan line 106, run after the commit on a clean tree): exit 0. Driver 19/19, transport 73/73. The tracer gate passed because the re-run was green before expansion.

## Derived ids (Task 2, offline, each with a control)

| Id | Source pointer | Value read | Control |
|---|---|---|---|
| cancelled run 38141825287 | 252-BASELINE.json (`f397a462…9843`) `/failure_analysis/families/5/run` | id 38141825287, workflow_id 259268962, status completed, conclusion cancelled, path .github/workflows/ci.yml | families[4].run is 38143881058, failure |
| failed job 117183276622 | LEDGER-R10 (`3b0dd91e…6c33`) sequence 45, decoded response_body_base64 | "producer (admin_behavior)", conclusion failure, run_id 38963239851 | the same body lists the other producers as success and the verifier as skipped |
| log run 38963239851 | LEDGER-R10 sequence 47 | route run_logs, hop 0, status 302, Location host results-receiver.actions.githubusercontent.com, URL `.../runs/38963239851/logs` | sequence 46 is run_artifacts 200 |
| 42 download hosts | ALLOCATION-R10 (`19f88204…9edb`) `/download_hosts` | 42 entries, then results-receiver appended (43) | — |

## Request list (`253-LOAD-RECOVERY-PROBE-REQUESTS-R11-PROBE.json`)

- **Identity:** sha256 `375c5758b1029942883e45a1bdc215dc2d9f87d0bf00d3554d6f85f76b754301`, committed alone in `2f960a01f`.
- **Window and caps:** window `253-127-probe-window-1`; 8 requests / 600 s; max_response_bytes 4194304; max_pages 2; max_hops 2.
- **Categories:** `{preflight 1, cancelled_shape 3, job_log_shape 1, failure_logs 3}`.
- **Download hosts:** 43, the 42 ALLOCATION-R10 hosts in order, then results-receiver.
- **Pointers:** the four source pointers above. `driver_commit` is `82a5c3b52e7a78a8ba4a4e0a6f8fb71b58483b1b`.
- **Requests, in order:**
  1. `rate`: rate_limit.
  2. `cancelled-run`: run 38141825287.
  3. `cancelled-jobs`: run_jobs 38141825287, per_page 100, pages.
  4. `job-log-redirect`: job_logs 117183276622, mode one.
  5. `run-log-chain`: run_logs 38963239851, follow.
- **Worst case:** 1 + 1 + 2 + 1 + 3 = 8.

## Offline binding rehearsal (Task 2; scratch files in `$TMPDIR` behind a trap, never committed, all removed)

- **Positive control:**
  - `--check-requests` exits 0;
  - `--check-only` with the scratch approval and allocation exits 0 (scratch allocation sha256 `b89b33da…5f99`, a scratch value only).
- **Negative controls, each exit 1 and naming its field:**
  - approval decision reject: `approval.decision`;
  - allocation max_requests 9: `allocation.max_requests`;
  - allocation without results-receiver: `allocation.download_hosts`. Control: transport `--check-only` on the same allocation (42 hosts) exits 0 and writes no ledger;
  - max_pages 3: `allocation.max_pages`;
  - max_response_bytes 2097152: `allocation.max_response_bytes`;
  - list copy with request 4 mode follow: `list.requests[3].mode`.

## Audit (R11 record and checker)

- **Checker:**
  - `FILES` gains `scripts/ci/ci-shape-probe.py`;
  - `TEST_FILES` and `LIVE_POLICY_GATE_FILES` gain `scripts/ci/ci-shape-probe.test.py`;
  - `SCHEMA` is `sigra.phase253.hermetic-live-audit/r11`;
  - the docstring line about "five" files was updated.
- **Record:**
  - schema r11; `audit_head` `2f960a01f`; matcher equal to the checker's (`files` now 6);
  - match_counts: transport 25, canary.sh 6, pr-proof 2, publication 8, verifier 28, shape-probe 1;
  - record sha256 `abdd7ab1…1a25`.
- **Row added:** the scan finds one driver site, `shape-probe-351` (`if allocation.get("mode") != "live":`, line 351).
  - It is offline-live-test.
  - It cites `test_live_probe_refuses_a_hermetic_test_allocation_before_any_socket` and `test_live_probe_records_the_seq47_chain_to_results_receiver`.
- **Checks:**
  - No other row changed; all lines are unchanged, because the other five files did not change. There are zero gap rows.
  - Checker 30/30.
  - Ad-hoc positive control: with the driver row removed, the checker reports `unaudited site scripts/ci/ci-shape-probe.py:351`.

## Task 2 `<verify>` (verbatim, plan line 144, under caffeinate)

Exit 0. In order:
- the id and request-list jq checks, and `--check-requests`;
- the scratch binding: driver refusal, transport-accept control, and scratch cleanup;
- audit 30/30, driver 19/19, transport 73/73, verifier 122/122;
- `--require-target-disposition` 0 and `--require-target-accepted` 3;
- v1 and r2-r10 `--check-only` all 0;
- `PRESERVATION-R11.sha256` passes;
- the request list was added by a one-file commit;
- config.json sha256, state.json at 70229 bytes, and a clean tree.

## Deviations from Plan

1. **[Rule 1 - test design] RED made assertion-level.** The first draft's RED was a module-setup load failure. The test now treats an absent driver as an empty file, so the counted RED (16 failures, 3 errors) is the target tests failing on their assertions. Nothing was loosened.
2. **[Rule 2 - hardening beyond the plan]** None of these is required by the plan; each makes a check stricter:
   - the driver refuses existing records and a ledger lock, so a window can never be resumed or retried;
   - per-category worst-case budget check;
   - driver_commit also requires both files committed at driver_commit and HEAD, and the working tree equal to HEAD;
   - source pointers are hashed from the `HEAD` bytes, and the working tree must match them;
   - intermediate evidence says `halted/incomplete`, and SIGTERM/SIGHUP become `interrupted`;
   - the body digest is cross-checked against its receipt;
   - the token scan adds signed-URL query keys and scans every zip member (capped at 64 MiB; past the cap the result is `matched`, `token_scan_complete: false`);
   - `sys.dont_write_bytecode`.
3. **[Naming choices the plan left open]**
   - The request list, evidence and bodies use the key `schema_version` (the plan said "schema"), matching the approval and allocation.
   - Refusal fields are prefixed `list.` / `approval.` / `allocation.`.
   - Bodies live under `entries`, which is what the 253-127 Task 4 verify reads.
   - For a zip, `head_sample_base64` is a per-member list.
   - Bodies gain a `token_scan_complete` field.
   - For a halted request, `receipts` holds that request's ledger rows, because the transport returns no receipt when it raises.
4. **Cosmetic, not fixed.** Every allocation-field refusal message ends with "(download_hosts must match in order)", even for non-host fields. The field name is still exact. Fixing the text would change the driver after `driver_commit` and move the request list.

**Total:** 2 auto-fixed or hardening groups, plus naming notes. **Impact:** every change only adds refusals; no plan check was weakened.

## Known Stubs

None.

## Handoff to 253-127

- **Runner:** `253-R11-PROBE-OPERATOR.sh` does not exist yet; 253-127 Task 2 writes it. Its live step must be exactly this command, run from the repository root:

  ```
  caffeinate -i -s python3 scripts/ci/ci-shape-probe.py --run \
    --requests .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-REQUESTS-R11-PROBE.json \
    --allocation .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-ALLOCATION-R11-PROBE.json \
    --approval .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-ACTION-APPROVAL-R11-PROBE.json \
    --ledger .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json \
    --evidence .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json \
    --bodies .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-BODIES-R11-PROBE.json
  ```

  - On success it exits 0 and prints `ci-shape-probe: {"elapsed_seconds":…,"request_count":…,"status":"complete","stop":null}`. On a refusal or halt it exits 1.
  - It refuses the run if the ledger, `ledger.lock`, evidence or bodies file already exists. It deletes the lock itself, and the runner's trap should still delete it too.
- **Offline pre-clock commands**, run with GH_TOKEN, GITHUB_TOKEN, PYTHONPATH and SIGRA_LIVE_POLICY_SHIM unset, deleting `scripts/ci/__pycache__` after each:
  - `python3 scripts/ci/ci-shape-probe.py --check-requests <request list>`;
  - `python3 scripts/ci/ci-shape-probe.test.py`;
  - `python3 scripts/ci/ci-hosted-transport.test.py`;
  - `python3 scripts/ci/ci-hermetic-live-audit.test.py`;
  - `git diff --quiet 2f960a01f HEAD -- scripts/ci/ci-hosted-transport.py scripts/ci/ci-shape-probe.py`;
  - after the approval exists: `python3 scripts/ci/ci-shape-probe.py --check-only --requests <list> --allocation <tmp allocation> --approval <approval>`.
- **The allocation's sha256 cannot exist before the approval.** The allocation's `bound_documents` includes the approval's sha256. So Jon's fresh approval binds the request-list sha256 (`375c5758b1029942883e45a1bdc215dc2d9f87d0bf00d3554d6f85f76b754301`). 253-127 Task 2 then builds the allocation and embeds it in the runner at the sha256 it records.
- **Allocation fields:** schema v1, kind canary, mode live, repository szTheory/sigra, window 253-127-probe-window-1, 8 / 600 / 4194304 / 2 / 2, the same category table, the 43 hosts in order, and bound_documents `[request list, approval]`.
- **The approval itself:**
  - `schema_version sigra.phase253.shape-probe-approval/v1` and section `shape_probe`, with exactly the 11 fields the driver reads;
  - `requests_path` must name the committed request list;
  - `decision` must be exactly `approve`; any other string is refused.
- **What Jon's approval must name:**
  - window `253-127-probe-window-1`; at most 8 requests and 600 s;
  - request-list sha256 `375c5758…4301`;
  - targets: run 38141825287 (run and jobs), job 117183276622 (logs, hop 0 only), and run 38963239851 (logs, followed);
  - hosts: api.github.com at hop 0 (the only host that receives the token), results-receiver.actions.githubusercontent.com at hop 1 of run_logs only, and at most one hop 2 to an already-trusted pipelines or productionresultssaN blob host in the 43-host list.
- **Runner reservation:** the transport's per-request deadline is 30 s (`ci-hosted-transport.py:689`, `deadline = time.monotonic() + 30`; the connect timeout at :576 is also 30). So `WINDOW LEFT 600 RESERVED 240` is 8 × 30 s.
- **Side effect inside the window:** the transport's `_preserve` writes local-only refs `refs/gsd/phase253-http-ledger/<digest>` for the untracked ledger before each request after the first. This is existing behaviour, the same as the R10 canary. Nothing is pushed.

## Invariants

- The tree is clean except config.json; config.json sha256 is `8e312f6c…0b8d`.
- state.json is 70229 bytes with sha256 prefix e45278c2cee0. STATE.md, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json are unchanged against HEAD.
- No gsd-tools writer verbs were run. There is no `scripts/ci/__pycache__`, and no scratch files remain in `$TMPDIR`.
- Only this plan's five declared files changed (`git diff --name-only f0d06cc42 HEAD`).
- Zero GitHub requests, fetches or pushes. Full Phase 253 verification stays not_started.

## Self-Check: PASSED

- The driver, test and request-list files exist.
- `82a5c3b52`, `2f960a01f` and `c6477becc` are ancestors of HEAD.
- `git rev-list --count f0d06cc42..c6477becc` is 3.
- The request list was added by a one-file commit.
