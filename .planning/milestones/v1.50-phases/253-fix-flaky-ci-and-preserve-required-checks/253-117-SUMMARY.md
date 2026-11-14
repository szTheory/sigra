---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "117"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hermetic-fakes, response-shape, dry-run, r10]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-116 run-name identity rule and canary ledger binding, R10 preservation checklist and R10 audit record; 253-113 R9 HTTP ledger (real run 38906314106, seq 25/27/28/29)"
provides:
  - "Dry-run fake that serves GitHub's recorded run, listing, job, step and artifact shapes (read from the committed R9 ledger at run time)"
  - "response_shape gate block in both dry-run modes, with a bare-name fault (run-shape-bare-name) as its positive control"
  - "Closed set of four skipped-producer forms in verify_separate_verifier"
  - "Live-policy verifier-job model: the candidate's verify_sources on the decoded compact matrix (verifier_job_model verify_sources); hermetic keeps scenario-set"
  - "Real-shape verifier fixtures pinned by FixtureShapeFidelityTests on three real samples"
affects: ["253-118", "253-119", "253-120", "253-121", "253-122", "253-123", "253-124"]
key-files:
  created: []
  modified:
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R10.json
key-decisions:
  - "The reference shapes are decoded from the committed R9 ledger (sha256 9c3d7659981a3be0e2592d09d670e4ab0dfc8084771a8ce51d8d1075a5f34e01) at run time: seq 25 listing, 27 run, 28 jobs, 29 artifacts. Nothing is copied into a new committed fixture file."
  - "response_shape reads what the fake actually served, from the server journal (decoded response bodies), and classifies rows by request path, so it does not depend on ledger route ids."
  - "actor, triggering_actor, repository and head_repository in fake runs are the committed real objects (already scrubbed: avatar and notifications URLs read ?[REDACTED]), so the transport's scrubber leaves them byte-identical."
  - "The verifier run's skipped producer job is served as 'producer (${{ matrix.seam }})'. No real sample exists for this fixture; the closed set also accepts 'producer ()', 'producers' and the five expanded names, and nothing else."
  - "Live-policy only: the fake's verifier job runs the clone's decode_matrix_payload + verify_sources. Hermetic evidence keeps the scenario-set model because its fixture_ref_state is hermetic-unverified and the compact matrix carries no origin."
requirements-completed: []
estimate: {tokens: 44000, tasks: 3}
actuals:
  tokens: 21123
  tasks: 3
  commits: 4
commits: 4
plan_head_before: abd172693b046d957df6d51fbeec79355b4b0f0b
plan_head_after: 490e14af77ac68ad3e3cdbe995449f4b6eae2db9
closed_set_fix_commit: 58ebe9547
duration: 99min
completed: 2026-10-16
status: complete
---

# Phase 253 Plan 117: real GitHub response shapes in the canary fakes (R10) Summary

**The offline dry-run fake now returns what GitHub actually returns: every run has GitHub's key sets, its name and display_title are both the run-name, and its path is exactly `.github/workflows/ci.yml`. Jobs, steps and artifacts also match the recorded real shapes. Both dry-run gates now compare everything the fake served against the committed real responses and fail on any difference; a fault that brings back the old bare-name shape makes the gate fail even though the verifier still accepts that run. The verifier also accepts the unexpanded name GitHub shows for the skipped producer matrix job. In live-policy mode the fake's verifier job runs the same check the hosted job runs. Every offline suite passes, including the 42.6-minute dry-run suite, and no GitHub requests were made.**

## Performance

- **Duration:** about 99 min (15:32Z to 17:11Z), most of it in the dry-run suite (16:20:33Z to 17:03:07Z).
- **Tasks:** 3/3
- **Files:** 5 modified

## Task commits

1. **Task 1 (tracer): real run shape and the response_shape gate** - `6aa741c85` feat(253-117): real GitHub run shape from the dry-run fake with a response_shape gate
2. **Task 2: jobs, steps, artifacts, closed set and live-policy verifier job**
   - `58ebe9547` fix(253-117): accept the unexpanded name of the skipped producer matrix job (subject checked absent before the commit; appears once)
   - `5a3329768` feat(253-117): real job, step and artifact shapes and the live-policy verifier-job model
3. **Task 3: real-shape verifier fixtures and the audit refresh** - `490e14af7` test(253-117): real-shape verifier fixtures with a fidelity test and the R10 audit line refresh

## Task 1: real run shape and the response_shape gate

### RED

- `-k test_fake_run_object_matches_the_recorded_github_shape -k test_response_shape_fault_fails_the_gate`: 2 tests, exit 1, 1 error and 1 failure.
  - The shape test errored with `AttributeError: ... has no attribute 'build_run'` (the builder did not exist yet).
  - The fault test failed because `--fault run-shape-bare-name` was not a valid choice (argparse exit 2, no summary).
- `-k test_both_quick_gates_report_a_passing_response_shape`: 1 test, 2 failing subtests. Both quick gates passed (exit 0) but had no `response_shape` block (`None is not True : {}`). This is the planned failure.

### GREEN

- `build_run` builds a run with the R9 seq-27 key set. Dynamic fields come from the fake's record: id, run_number, head_branch, head_sha, status, conclusion, URLs containing the run id, and head_commit (id, tree_id, message and author/committer from the fake's stored fixture commit). Fixed fields: run_attempt 1, event workflow_dispatch, workflow_id 259268962, pull_requests [], previous_attempt_url null.
- The fake's control flow is unchanged: polls needed, visibility delay, cancellation and conclusions all work as before.
- ResponseShapeTests: 3 tests OK (345 s).
- **Tracer gate:** Task 1's full `<verify>` passed (rc 0 and a clean tree).

| Quick gate (`--ref-pair r9 --seed-r8-refs --stop-after full-pass`) | status | response_shape | requests |
|---|---|---|---|
| hermetic | passed | ok, runs_checked 4, scenarios [full-pass] | 33: publication 18, preflight 5, dispatch 1, run_discovery 1, pre_watch_rate 1, terminal_polls 3, attempt_jobs 1, artifact_metadata 1, artifact_downloads 2 |
| live-policy | passed | ok, runs_checked 4 | same 33 |
| hermetic with `--fault run-shape-bare-name` | **failed** | ok false, 2 mismatches | same 33; every invocation exited 0 and the verifier accepted full-pass |

The two fault mismatches name `name` and `path`: run 40500215401 has `name 'Phase 253 Gate Canary'` where the run-name is expected, and `path '.github/workflows/ci.yml@refs/heads/gsd/253-replan-r9-fixture'` where the exact path is expected. So the shape assertion catches fake drift that the verifier accepts by design.

## Task 2: jobs, steps, artifacts, the skipped producer job and the verifier-job model

### RED

- **Verifier (`SkippedProducerFormTests` on the unchanged verifier):** 3 tests, 10 failing subtests (exit 1).
  - 4 errors: the unexpanded name and `producer ()` were refused with `separate hosted verifier job set is unexpected`, in both job orders.
  - 6 failures: a non-skipped unexpanded or empty producer was refused by the names check, not by the result check (`job identity or result mismatch`).
  - The refusal test already passed. That is expected: it is the negative side.
- **Dry run (`-k test_the_verifier_job_ran_verify_sources_on_the_compact_matrix`):** 1 test failed with `None != 'verify_sources'`, even though that live-policy full gate passed. Its Task 1 response_shape was already ok, with 46 runs checked.

### GREEN

- Only the names check in `verify_separate_verifier` changed. The four forms are the five expanded names, `producers`, `producer (${{ matrix.seam }})` and `producer ()`, each with Browser verdict and verifier. The "every non-verifier job skipped" check and the verifier step checks are unchanged. The verifier suite runs 111 tests, OK (112 after Task 3).
- **Fake jobs:**
  - Every job has the seq-28 key set, and workflow_name is the run-name, as GitHub returns it.
  - Producer steps are Set up job, Run the named synthetic tiny command, Upload this producer's synthetic receipt, Complete job.
  - Browser verdict follows the real 10-step list, including both post-checkout steps; only the validator step's conclusion varies by scenario.
  - Skipped jobs list no steps and have null runner fields, like GitHub's skipped verifier job.
  - In missing-seam, the admin_checkpoints upload step reports skipped, because the fixture's `if` excludes it.
  - Job conclusions per scenario are unchanged.
- **Fake artifacts:** every artifact has the seq-29 key set, with workflow_run (id, repository_id, head_repository_id, head_branch, head_sha).
- **Verifier run:**
  - Jobs are `producer (${{ matrix.seam }})` skipped, Browser verdict skipped, and verifier.
  - The verifier job's steps are modeled from the fixture workflow, because no real sample exists: Set up job, Checkout candidate verifier by pinned commit, Verify immutable candidate verifier checkout, Verify retained source matrix independently, Retain separate verifier result, Post Checkout candidate verifier by pinned commit, Complete job.
- **response_shape** now also checks every served jobs and artifacts page:
  - job and step key sets;
  - workflow_name and run_id;
  - the real producer and Browser verdict step lists for jobs that ran;
  - no steps on skipped jobs;
  - artifact and workflow_run key sets, and workflow_run.id.
- **Live-policy verifier job:** concludes success exactly when `verify_sources(decode_matrix_payload(matrix_evidence))` from the clone's verifier returns without error.
- **Summary fields:** `verifier_job_model` and `verifier_job`, with the result, executed jobs, payload length, the limit and the dispatch ledger row's input metrics. A full sequence whose modeled verifier job did not report its expected result is a gate problem.

### Full gates (Task 2 `<verify>`, re-run on the clean tree: rc 0)

| | hermetic | live-policy |
|---|---|---|
| status | passed | passed |
| verifier (`--scenario matrix`) | passed | passed |
| verifier_job_model | scenario-set | verify_sources |
| verifier_job result | scenario_set_complete | sources_verified, executed_jobs 35 |
| compact matrix payload (characters) | 15740 | 15720 |
| dispatch input metrics (verifier dispatch, seq 87, HTTP 204) | 5 keys, 15958 scalars | 5 keys, 15938 scalars |
| response_shape | ok; runs 46, jobs 45, steps 177, artifacts 33; all six scenarios plus verifier | same |
| authorization | n/a | api_with 85, api_without 0, blob_with 0 |
| shim_refusals | n/a | 0 |
| seeded_r8_refs_changed | false | false |

- **Payload limit:** the compact matrix payload is 15720 characters against the 64511-character limit (MATRIX_PAYLOAD_LIMIT). The first Task 2 run measured 15628 hermetic and 15636 live-policy. The halt condition did not fire.
- **Requests by category** were identical in both gates (93 total): publication 19, preflight 5, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6, cancellation 1.

## Task 3: real-shape verifier fixtures, the fidelity test and the audit

### RED

`FixtureShapeFidelityTests.test_verifier_fixtures_match_the_recorded_github_shapes` ran against the old fixtures: 1 test, 84 failing subtests, all assertion failures, no errors. They were:
- key-set differences for runs (21), jobs (14) and artifacts (6);
- producer step lists (35) and Browser verdict step lists (6);
- the failure-shaped Browser verdict comparison (1);
- a skipped Browser verdict that still listed steps (1).

### GREEN

- New module helpers in the test file build every object from the committed R9 ledger at test time: `real_bodies`, `real_run`, `real_job`, `real_steps`, `real_artifact`, `source_jobs` and `verifier_run_receipt`.
- `fixture()`, `scenario_fixture()` and the separate-verifier builders now use these helpers.
- **The fidelity test compares** every builder with R9 seq 27/28/29, the R8 run poll (38791286863) and run 38347679431, key set by key set. It also checks:
  - name == display_title in all three real samples and in every fixture;
  - the real producer and Browser verdict step lists;
  - that the actual-failure Browser verdict steps (names and conclusions) equal 38347679431's failure-shaped verdict;
  - that both verifier-run forms (`producers` and the unexpanded name) have the real shapes.
- The verifier suite runs 112 tests, OK.

### Edited existing tests (no assertion weakened)

- **`fixture()`:** the run, jobs and artifacts are now real shapes. The run lost its non-GitHub `run_id` key, and the artifact's workflow_run lost its non-GitHub `run_attempt` key; no test read either key.
- **`scenario_fixture()`:** builds the run with `real_run` and the jobs with `source_jobs`, with the same per-scenario conclusions as before. A skipped Browser verdict (cancelled) now lists no steps, as GitHub's does. The artifact uses `real_artifact`.
- **`HostedGateVerifierTests.test_rejects_wrong_fixture_workflow_identity_and_unexpected_job`:** the tiny-command step is now found by name. The real list starts with Set up job, so index 0 would have failed a step the verifier does not check. The test still asserts a refusal.
- **`HostedGateVerifierTests.test_final_matrix_checks_separate_verifier_and_recounts_executions`:** the verifier run and jobs come from `verifier_run_receipt(999, ('producers',))`. Before, all three jobs had id 8.
- **`RunIdentityTests.separate_verifier_evidence`:** uses `verifier_run_receipt(..., ('producers',))`, and only the title varies.
- **`CanaryBindingTests.verifier_evidence`:** uses `verifier_run_receipt(run_id, ('producers',), first_job_id=900)`. Job ids are unchanged (900-902), and the verifier is still at index 2 for the tamper.
- **`SkippedProducerFormTests.evidence_with`** (added in Task 2): uses `real_run` and `real_job`.
- **In the dry-run test file**, no existing test was edited. New methods were added:
  - `FullSequenceTests` and `LivePolicyFullSequenceTests`: `test_every_served_run_has_the_recorded_github_shape_including_the_verifier_run` and `test_every_served_job_step_and_artifact_has_the_recorded_github_shape`;
  - `LivePolicyFullSequenceTests`: `test_the_verifier_job_ran_verify_sources_on_the_compact_matrix`;
  - a new `ResponseShapeTests` class with 4 tests.

### Audit record (`253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R10.json`)

- **audit_head:** `9f796f4b5…` changed to `5a33297685477339bf2e34489aaa91c79535e87c`. That commit is an ancestor of HEAD and contains the verifier change.
- **19 verifier rows** had `line` refreshed, each +5 after the closed-set change: verifier-950, -951, -968, -969, -991, -1014, -1015, -1021, -1369, -1403, -1462, -1482, -1634, -1652, -1664, -1674, -1725, -1729 and verifier-1655-supplementary.
- **match_counts** are unchanged: transport 25, canary.sh 6, pr-proof 2, publication 8, verifier 28. There are no new matcher sites (the closed-set lines contain no topic word), so no row was added. Gap rows: 0.
- The checker passes: 14 tests OK.

### Task 3 `<verify>`: full offline regression (rc 0, under `caffeinate -i -s`)

| Check | Result |
|---|---|
| ci-hermetic-live-audit.test.py | 14 OK |
| ci-hosted-gate-verify.test.py | 112 OK |
| ci-hosted-transport.test.py | 59 OK |
| ci-git-publication.test.py | 76 OK |
| ci-gate-canary-flow.test.py | 22 OK |
| ci-gate-canary-recovery.test.py | 5 OK |
| **ci-gate-canary-dryrun.test.py** | **51 OK in 2553.9 s (42.6 min)** |
| ci-gate-canary.test.sh | passed |
| ci-pr-proof.test.sh | 59 OK |
| `--require-target-disposition` / `--require-target-accepted` | exit 0 / exit 3 (unchanged) |
| v1 and r2-r9 reconcile `--check-only` | all exit 0 |
| PRESERVATION-R10 checklist (62 lines) | `shasum -c` rc 0 |
| config.json sha256, state.json size, clean tree | 8e312f6c…, 70229 bytes, only ` M .planning/config.json` |

## Deviations from Plan

1. **[Rule 2 - Missing critical] A full sequence also fails when the modeled verifier job did not report its expected result** (Task 2, `5a3329768`). Without this, a live-policy run whose verify_sources failed would rely only on the driver failing. Both full gates pass with it.
2. **[Rule 2 - Missing critical] In missing-seam, the fake reports the admin_checkpoints upload step as skipped** (Task 2). The fixture's `if` excludes that step, so GitHub would report it skipped. This is step data only; job conclusions and the control flow are unchanged.
3. **Tests beyond the plan's list:**
   - `test_both_quick_gates_report_a_passing_response_shape`;
   - `test_job_step_and_artifact_shape_checks_refuse_the_pre_253_117_fake_shapes` (positive control for the job, step and artifact checks);
   - the full-sequence response_shape assertions;
   - extra refused forms: `producer ( )`, another expression, mixed forms, a missing Browser verdict and an extra job.

   All are tighter than planned, none looser.
4. **The Task 2 `<verify>` was run twice.** The first run's gate chain passed (rc 0), but its final clean-tree check failed. Task 3's fidelity test was already being written in the verifier test file while the gates ran. After the Task 3 commit it was re-run on a clean tree: rc 0, and the numbers above come from that run.
5. **The RED for the two shape builders failed with AttributeError,** not an assertion, because the builders did not exist yet. The planned assertion failures came from the quick-gate test (no response_shape block), the fault test and the fidelity test (84 assertion failures). This matches how 253-116 recorded its helper REDs.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. `.planning/config.json` (sha256 `8e312f6c…`) and `state.json` (70229 bytes, `e45278c2cee0…`) are untouched.

## Remaining gaps / handoff (for 253-118 and later)

- **Justified response-shape row needed in 253-118: the verifier run's skipped producer job.**
  - GitHub has never been observed reporting it for this fixture.
  - The fake serves `producer (${{ matrix.seam }})`, and the verifier accepts exactly four forms.
  - The nearest real sample is the Phase 252 bundle's skipped install_matrix job, reported once under its literal name.
  - Residual risk: GitHub might use a fifth form, for example one per seam with an empty or partial expansion. That would halt the window after the six scenarios with `separate hosted verifier job set is unexpected`, which is fail-closed.
- **The verifier job's step list is modeled, not observed.** The verifier checks only its two named steps, so an unexpected extra or missing GitHub step (other than those two) does not change acceptance.
- **The compact matrix payload size is measured on fake receipts.** Real receipts carry more unique ids and timestamps. One real R9 full-pass receipt alone compacts to about 7300 characters, so six would be about 44K, still under 64511, though less margin than the fake's 15720. The driver fails closed (`compact verifier matrix exceeds its bounded dispatch input`) before dispatching if it were over.
- **Still open from 253-116:** the driver accepts dispatch 202 or 204, but the binding requires 204. The fakes send 204, and real GitHub returned 204 in R9. Not loosened.
- **FREEZE-R9 no longer validates the tree** (scripts/ci changed again). 253-120 cuts FREEZE-R10.
- **CIREL-02 stays open.** Full Phase 253 verification stays not_started.

## Known Stubs

None.

## Threat Flags

None. The changes are offline test harness fakes, test fixtures and one closed-set extension. No new network endpoint, auth path or trust boundary.

## Self-Check: PASSED

- All five modified files exist. The four task commits (`6aa741c85`, `58ebe9547`, `5a3329768`, `490e14af7`) are ancestors of HEAD.
- Each RED preceded its fix or GREEN commit: Task 1 RED before `6aa741c85`, the closed-set RED before `58ebe9547`, the fidelity RED before `490e14af7`.
- `git rev-list --count abd172693..490e14af7` = 4. No `scripts/ci/__pycache__` remains. `git status` shows only ` M .planning/config.json`.
