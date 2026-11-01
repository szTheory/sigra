---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "128"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, hermetic-fakes, response-shape, run-logs, cancelled-run, r11]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-127
    provides: the R11 read-only probe records (ledger, evidence, bodies) with GitHub's run_logs chain and cancelled run 38141825287
  - phase: 253-125
    provides: results-receiver admitted by the transport and verifier only as run_logs hop 1
  - phase: 253-117
    provides: the response_shape gate pattern (served objects compared with recorded bytes inside the gate)
provides:
  - the dry-run fake's failed-log chain driven at run time by the committed probe records and R10 ledger seq 47
  - response_shape.run_logs_checked and response_shape.cancelled_run_checked, both required for a full gate run
  - authorization.results_receiver_with (must be 0)
  - faults run-logs-legacy-blob-redirect and cancelled-shape-drift (positive controls)
  - the transport test that replays the probe-observed run_logs chain
  - the verifier's cancelled-scenario fixture built on the recorded cancelled run
affects: [253-129, 253-131]
tech-stack:
  added: []
  patterns: ["fake driven by committed real-response records at run time", "rules read off the real sample and self-checked against it", "fault per new shape assertion (positive control)"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-128-SUMMARY.md
  modified:
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R11.json
key-decisions:
  - "Cancelled branch: CAPTURED. The probe recorded 200 for both cancelled-run (seq 2) and cancelled-jobs (seq 3), so cancelled_run_checked is a real check (true), not the unavailable marker."
  - "The recorded cancelled run's job vocabulary includes failure (3 jobs failed before the cancel), so 'a job reports failure' is not by itself outside the vocabulary. The cancelled-shape-drift fault turns the run's only cancelled job into failure, which breaks the recorded rule that a cancelled run lists at least one cancelled job. The hosted verifier also rejects that run (cancellation not observed), so this fault fails on response_shape and on the verifier, not on response_shape alone."
  - "The probe ledger redacts the signed query (only has_query is kept), so the fake's query parameter names are synthetic (sig, se). The gate compares has_query, not parameter names."
  - "results-receiver's 200 is served chunked with no Content-Length, as recorded. The fake's log zip is written to a non-seekable stream, so its local-header magic is the recorded 504b030414000800."
  - "Product transport, verifier and driver are unchanged. failure_logs stays 6 = 3 x h (h = 2), at the frozen limit of 6. No budget was changed."
estimate: {tokens: 44000, tasks: 3}
actuals:
  tokens: 16500
  tasks: 3
  commits: 4
commits: 4
plan_head_before: b8199823140c25c562d0d59310ba5fa424021a0e
plan_head_after: 2e6a4197770f28c59bf7898ed01be3a06a7fb3d9
duration: "about 3 h (2026-10-16T23:21Z to 2026-10-17T02:30Z), mostly two 52-minute dry-run suite runs"
metrics:
  completed: 2026-10-17
---

# Phase 253 Plan 128: Probe-driven run_logs chain and cancelled-run shape in the offline fakes Summary

**The dry-run fake now sends failed logs through the chain GitHub actually returned to the 253-127 probe: a 302 from api.github.com (text/html;charset=utf-8, empty body) to `results-receiver.actions.githubusercontent.com/rest/runs/<uuid>/logs?<signed query>`, then results-receiver's own 200 application/zip, chunked with no Content-Length, with members `{n}_<job>.txt` and `<job>/system.txt`. Its cancelled run and jobs are checked against real cancelled run 38141825287. Both are read from the committed probe records at run time, and the gate fails if either drifts. Zero GitHub requests.**

These probe records are real-shape fixtures only, never acceptance evidence. CIREL-02 stays open. Full Phase 253 verification stays not_started. FREEZE-R11 is not cut (253-131 owns it).

## Task Commits

| Task | Commit | Subject |
|---|---|---|
| 1 | `39f7e13d1` | feat(253-128): GitHub's recorded log-redirect chain from the dry-run fake with a run_logs response_shape gate |
| 2 | `f4f890650` | feat(253-128): GitHub's recorded cancelled-run shape in the fake and the verifier fixture |
| 3 | `98d879255` | test(253-128): run_logs transport test on the probe-observed chain; retained pre-R11 predicate test renamed |
| 3 (deviation fix) | `2e6a41977` | fix(253-128): list results-receiver in the live dry-run allocation only for a transport that admits it |

`commits: 4` is measured: `git rev-list --count b81998231..2e6a41977`. The SUMMARY commit adds a fifth.

## Reference files read at run time (sha256)

Nothing was copied into a new fixture file. The fake, the gate and the tests read these committed files at run time.

| file | sha256 | used for |
|---|---|---|
| 253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json | 6980e6e58cf086d77bc1b7583d93ae1c46703e523baeb6c01a341046572a82de | run-log-chain hops (status, safe-header names, content-type, content-length, Location host/path pattern/has_query/port); cancelled-run/cancelled-jobs statuses and sequences |
| 253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json | 79e8b4d320c410e9179aa610a614b8c4fa97d4aada692e004484134b59e10018 | cross-check of each hop (seq 5, 6); cancelled run (seq 2) and jobs (seq 3) bodies, each checked against its response_sha256 |
| 253-LOAD-RECOVERY-PROBE-BODIES-R11-PROBE.json | 3b8d5bf4cc0af7fcf302fe3897eaeef3e2219de0822a98d871032c9f4b6c9523 | final-hop magic `504b030414000800` and the 12 zip member names (pattern only; raw log bytes are never reconstructed) |
| 253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R10.json | 3b0dd91e85612a973012bbcdadcc925afa3b1dc5cbe4b95a1c5349c6ed226c33 | seq 47 must equal the probe's hop 0 (status, content-type, content-length, Location host/port/has_query/path pattern) |

`load_log_reference` raises if the probe evidence, the probe ledger, the bodies record and seq 47 disagree with each other. The path pattern comes from the probe driver's own `_path_pattern` (`ci-shape-probe.py`), so both sides use the same instrument.

## Cancelled branch chosen: captured

The probe recorded **200 for both** cancelled-run (seq 2) and cancelled-jobs (seq 3). So `cancelled_run_checked` is a real check (it is `true` in both gates), not the `unavailable` marker.

- The recorded run's top-level and nested key sets already equal R9 seq 27's, so the fake's run builder did not need new keys. The gate now also checks the fake against the cancelled sample: key sets, `completed/cancelled`, and the type of every top-level value. Event-dependent values such as `pull_requests` are compared by type only.
- Vocabulary read off the sample:
  - jobs: completed/{cancelled, skipped, success, failure};
  - steps: completed/{success, skipped, cancelled, failure}.
- Rules read off the sample (the loader checks the sample satisfies all of them):
  - a skipped job lists no steps and no runner;
  - a cancelled job with steps has exactly one cancelled step, no failed or cancelled step after it, and ends with a successful `Complete job`;
  - at least one job is cancelled (11 in the sample).
- The fake's cancelled jobs already followed those rules: the `Upload` step is `always()`, as GitHub's `Upload shard diagnostics` is, so it stays success after the cancel. The fake's cancelled job output is unchanged.
- The verifier's cancelled-scenario fixture (`scenario_fixture("cancelled", …)`) is now built on the recorded cancelled run and job templates (its `node_id` is the sample's). The CLI still verifies it as `verified_non_green`.

## RED / GREEN counts

| Step | Command | Result |
|---|---|---|
| Task 1 RED | `ci-gate-canary-dryrun.test.py -k test_fake_log_redirect_matches_the_probe_recorded_chain -k test_run_logs_legacy_blob_fault_fails_the_gate` | exit 1; 2 ran: 1 error (`AttributeError: … no attribute 'load_log_reference'`), 1 failure (`--fault run-logs-legacy-blob-redirect` rejected by argparse, so there was no summary) |
| Task 1 GREEN | same | 2/2 ok |
| Task 2 RED, dry-run | `-k test_fake_cancelled_run_matches_the_probe_recorded_shape -k test_cancelled_shape_drift_fault_fails_the_gate` | exit 1; 2 ran: 1 error (no `load_cancelled_reference`), 1 failure (unknown fault, exit 2) |
| Task 2 RED, verifier | `ci-hosted-gate-verify.test.py -k test_live_probe_cancelled_run_fixture_matches_the_recorded_shape` | exit 1; 1 failure (`'WFR_kwLOR_jMxM8AAAAJDv89eg' != 'WFR_kwLOR_jMxM8AAAAI4W4RBw'`: the fixture was still on R9 seq 27) |
| Task 2 GREEN | dry-run targeted 3/3 ok; verifier suite 123/123 | |
| Task 3 RED | `ci-hosted-transport.test.py -k test_live_probe_observed_run_logs_chain_is_followed` | exit 1; 1 error (`NameError: name 'probe_run_logs_chain' is not defined`) |
| Task 3 GREEN | transport suite | 74/74 (73 + 1) |

## Verify blocks (each run verbatim under bash from the checkout root)

- **Task 1 `<verify>`:** exit 0 at `39f7e13d1`, and again at the final HEAD `2e6a41977`.
- **Task 2 `<verify>`:** exit 0 at `f4f890650`, and again at the final HEAD.
- **Task 3 `<verify>`, first run (at `98d879255`):** exit 1. Everything passed up to the dry-run suite. The suite ran 58 tests in 2989.7 s with 2 failures: `TransportSensitivityTests.test_the_pre_fix_transport_fails_the_live_policy_gate_at_artifact_zip_with_origin_rejected` and `test_the_redirect_fix_transport_passes_the_same_gate`. Both stopped on `download_host_allocation: live allocation contains a host outside the trusted policy`; see Deviations.
- **Task 3 `<verify>`, second run (at `2e6a41977`, 01:18Z to 02:17Z under caffeinate):** **exit 0.** Results:
  - audit checker 30/30;
  - transport 74/74;
  - verifier 123/123;
  - publication 85/85;
  - shape-probe 19/19;
  - canary-flow 22/22;
  - canary-recovery 5/5;
  - **dry-run suite 58/58 in 3119.6 s**;
  - `ci-gate-canary.test.sh` passed;
  - `ci-pr-proof.test.sh` 64/64;
  - acceptance `--require-target-disposition` 0 and `--require-target-accepted` 3 (unchanged);
  - v1 and r2-r10 `--check-only` all 0;
  - `PRESERVATION-R11.sha256` passes;
  - config.json pin, state.json 70229 bytes and the clean tree all hold.

## Gate summaries (`--ref-pair r10 --seed-r8-refs --seed-r9-refs`, final code)

| field | hermetic | live-policy |
|---|---|---|
| status | passed | passed |
| requests_total / journal | 93 / 93 | 93 / 93 |
| requests_by_category | artifact_downloads 10, artifact_metadata 6, attempt_jobs 7, cancellation 1, dispatch 7, **failure_logs 6**, pre_watch_rate 7, preflight 5, publication 19, run_discovery 7, terminal_polls 18 | identical |
| live_hops (hop 1) | 5 artifact_zip and 3 run_logs, all 200, host `localhost` | 5 artifact_zip on `productionresultssa17.blob.core.windows.net` and **3 run_logs on `results-receiver.actions.githubusercontent.com`**, all 200 |
| response_shape | ok, mismatch_count 0; runs 46, jobs 45, steps 177, artifacts 33; run_logs_checked true (3 chains); cancelled_run_checked true; verifier_run_checked true | same numbers |
| authorization | all 0 (hermetic refuses credentials) | api_with 85, api_without 0, blob_with 0, **results_receiver_with 0** |
| shim_connect_hosts | n/a | api.github.com, productionresultssa17.blob.core.windows.net, results-receiver.actions.githubusercontent.com |
| verifier / job model | passed / scenario-set | passed / verify_sources |
| seeded r8 / r9 refs changed | false / false | false / false |

**failure_logs = 6 = 3 failed scenarios x h (2 hops per fetch), at the frozen limit of 6 with zero slack (as 253-127 recorded). No budget was changed.**

### Fault runs (positive controls)

- **`--live-policy … --fault run-logs-legacy-blob-redirect`:** status failed with 30 mismatches. All three driver invocations exit 0, all six scenarios verify, the verifier passes, and the run_logs hop 1 rows go to the blob host. **The only problem is response_shape** (the gate fails on the shape assertion alone). The first mismatches are:
  - `run_logs hop 0 (…/runs/<id>/logs) safe headers [… no content-type …] differ from GitHub's recorded [… content-type …]`;
  - `content-type None is not GitHub's recorded 'text/html;charset=utf-8'`;
  - `Location host 'productionresultssa17.blob.core.windows.net' is not GitHub's recorded 'results-receiver.actions.githubusercontent.com'`;
  - `Location path '/_downloads/logs/<id>' is not GitHub's recorded '/rest/runs/{uuid}/logs'`.
- **`--fault cancelled-shape-drift` (hermetic):** status failed. response_shape reports `jobs page of cancelled run <id> lists no cancelled job (conclusions ['failure', 'skipped', 'success']); GitHub's recorded cancelled run lists 11 cancelled jobs`. The hosted verifier also stops the remaining step: `cancellation was not observed on a hosted fixture job`. See key-decisions: this fault is caught by both response_shape and the verifier.

## Edited existing tests

| file | test | change |
|---|---|---|
| ci-gate-canary-dryrun.test.py | `LivePolicyFullPassTests.test_the_allocation_is_live_with_the_trusted_hosts_and_no_test_fields` | download_hosts expectation is now the R8 list **+ results-receiver** |
| ci-gate-canary-dryrun.test.py | `LivePolicyFullSequenceTests.test_every_download_is_a_302_hop_then_a_200_on_the_blob_host` | **renamed** `…_on_its_recorded_download_host`. Artifacts are still on the blob host; run_logs hop 1 must now be on results-receiver; it also asserts run_logs_checked. No audit ref cited the old name. |
| ci-gate-canary-dryrun.test.py | `LivePolicyFullSequenceTests.test_the_token_shim_and_fake_stay_clean_over_the_whole_sequence` | adds `results_receiver_with == 0`, and **shim_connect_hosts == [api.github.com, productionresultssa17…, results-receiver…]** for the live full run (the `--stop-after full-pass` expectation in `LivePolicyFullPassTests` is unchanged: no logs are fetched there) |
| ci-gate-canary-dryrun.test.py | `LivePolicyFullSequenceTests.test_every_served_run_has_the_recorded_github_shape_including_the_verifier_run` | adds run_logs_checked and cancelled_run_checked true |
| ci-gate-canary-dryrun.test.py | `FullSequenceTests.test_every_served_run_has_the_recorded_github_shape_including_the_verifier_run` | adds run_logs_checked true, 3 chains, cancelled_run_checked true |
| ci-hosted-transport.test.py | `test_run_logs_follow_to_pipelines_host_without_authorization` | **renamed** `test_run_logs_retained_pre_r11_pipelines_predicate_without_authorization`, with a one-line comment; assertions unchanged |
| ci-hosted-transport.test.py | `LiveHostHandler` (test server) | a route whose headers include `Transfer-Encoding: chunked` is sent chunked with no Content-Length. Every other route is byte-identical to before. |
| ci-hosted-gate-verify.test.py | `real_run`, `real_job`, `source_jobs`, `scenario_fixture` | optional recorded template. The cancelled scenario uses the probe's cancelled run and job. `real_run` always sets `event` to `workflow_dispatch`, which the R9 template already had, so other scenarios are unchanged. |

New tests:
- `RunLogsShapeTests.test_fake_log_redirect_matches_the_probe_recorded_chain` and `test_run_logs_legacy_blob_fault_fails_the_gate`;
- `CancelledShapeTests.test_fake_cancelled_run_matches_the_probe_recorded_shape` and `test_cancelled_shape_drift_fault_fails_the_gate`;
- `FixtureShapeFidelityTests.test_live_probe_cancelled_run_fixture_matches_the_recorded_shape`;
- `LivePolicyRedirectTests.test_live_probe_observed_run_logs_chain_is_followed`.

## Audit rows touched (253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R11.json)

- Three `coverage.refs` entries (the rows citing the renamed transport test, record lines 282, 335 and 372) now name `test_run_logs_retained_pre_r11_pipelines_predicate_without_authorization`.
- No matcher file changed. ci-hosted-transport.py, ci-gate-canary.sh, ci-pr-proof.sh, ci-git-publication.py, ci-hosted-gate-verify.py and ci-shape-probe.py are untouched, and ci-gate-canary-dryrun.py is not an audited matcher file. So no `line` field moved and no new matcher site exists.
- The checker passes 30/30 with zero gap rows.
- `shape-run_logs` stays `justified`. Moving it to `real-shape-test` on the probe rows is 253-129's Task 1, as that plan says.
- The R9 and R10 audit records still cite the old test name. They are pinned historical records and the checker reads only R11.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The live dry-run allocation broke the `--transport-from` sensitivity tests**
- **Found during:** Task 3 (the first full regression run).
- **Issue:** Task 1 added results-receiver to the live allocation unconditionally. `TransportSensitivityTests` run the live-policy gate with the 253-107 transports (`--transport-from 375b41138^` and `375b41138`), which predate 253-125. Those transports refuse any allocation that lists results-receiver (`download_host_allocation`). 2 of the 58 dry-run tests failed.
- **Fix:** add results-receiver only when the transport under test defines `RESULTS_RECEIVER_HOST` (the clone's transport is loaded and checked). Older transports get the R8 list a real window of their time would have had.
- **Result:** the failing class plus the allocation test pass 5/5. The full Task 3 verify then passed, and the Task 1 and 2 verifies were re-run green on the final HEAD.
- **Files modified:** scripts/ci/ci-gate-canary-dryrun.py.
- **Commit:** `2e6a41977`.

### Plan interpretations (no change in scope)

**2. Synthetic query parameter names.** The plan asks for "the recorded parameter names, synthetic values". The ledger redacts the whole query (`?[REDACTED]`) and keeps only `has_query`, so no parameter names were recorded. The fake uses synthetic names (`sig`, `se`), and the gate compares `has_query`.

**3. The cancelled-shape-drift fault is caught by more than response_shape.** The recorded vocabulary includes `failure`, so the plan's "jobs report conclusion failure" is in vocabulary by itself. The fault replaces the run's only cancelled job with failure. That breaks the recorded "at least one cancelled job" rule, which response_shape names. The hosted verifier's own cancelled rule rejects the same run, so this fault does not isolate response_shape the way the legacy-blob fault does.

**4. Refactors that keep output identical.**
- The handler's jobs builder moved to the module-level `build_jobs_page` so tests can build a jobs page directly. The fault hook is the only addition.
- `_send` gained `always_type` (Content-Type on an empty 302) and `chunked` (no Content-Length).
- Journal rows gained `raw_magic_hex` and `zip_member_names`. The verifier compares an explicit field list, so the extra fields are ignored.

Poll counts, visibility delay, conclusions, cancellation and artifacts are unchanged.

## Known Stubs

None. The fake's log text and zip bytes are synthetic by design, so no real log bytes are reconstructed or committed.

## Threat Flags

None. results-receiver appears only in the offline model, with `results_receiver_with` asserted 0. No product transport, verifier or driver file changed.

## Remaining gaps / handoff to 253-129

- **shape-run_logs is still `justified`** in the R11 audit record, and its justification text still says hop 1 is unobserved. 253-129 Task 1 flips it to `real-shape-test` with the probe seq 5/6 rows (plus seq 47), and adds the "observed route must cite the probe" checker rule. The probe rows for shape-run and shape-run_jobs (cancelled seq 2/3) and shape-job_logs (seq 4) are likewise for 253-129.
- **job_logs** is unchanged in the fake. The probe saw a 302 to `productionresultssa18.blob.core.windows.net`, but the canary never calls job_logs.
- **The failure_logs budget has zero slack** (6/6). If GitHub ever adds a run_logs hop, the frozen canary limit is exceeded; that would be a budget re-decision, not a fake change.
- **R9 and R10 audit records** still cite the old transport test name (pinned, not read by the checker).
- FREEZE-R11 is not cut; 253-131 owns it. `--check-only` was not run against FREEZE-R10.

## Invariants (at SUMMARY write)

- `git status`: only ` M .planning/config.json` (plus this SUMMARY before its commit).
- config.json sha256 `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d` (unchanged; never staged).
- state.json: 70229 bytes, sha256 prefix `e45278c2cee0` (unchanged).
- `scripts/ci/__pycache__`: absent.
- Zero GitHub requests: no push, fetch, gh or curl. Every gate ran against the local fake through the live-policy shim, with 0 shim refusals.
- No gsd-tools writer was run. STATE.md, state.json, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json are untouched.

## Self-Check: PASSED

- FOUND: scripts/ci/ci-gate-canary-dryrun.py, scripts/ci/ci-gate-canary-dryrun.test.py, scripts/ci/ci-hosted-transport.test.py, scripts/ci/ci-hosted-gate-verify.test.py and the R11 audit record.
- FOUND: 39f7e13d1, f4f890650, 98d879255 and 2e6a41977 are ancestors of HEAD.
