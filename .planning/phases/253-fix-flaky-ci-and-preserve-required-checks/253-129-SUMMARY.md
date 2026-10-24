---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "129"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, audit, response-shape, residual-risk, r11]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-127
    provides: the committed read-only probe records (HTTP ledger seq 1-6, bodies, evidence, allocation)
  - phase: 253-128
    provides: the probe-driven run_logs and cancelled-run tests that the audit rows now cite
provides:
  - observed-route checker rule test_probe_observed_routes_are_not_justified, with four positive controls
  - shape-run_logs and shape-job_logs on real probe samples (real-shape-test); probe samples on rate_limit, run and run_jobs
  - top-level unobserved_live_shapes (14 entries), each with its fail-closed stop and first hosted window
affects: [253-130, 253-131, 253-133, 253-134]
tech-stack:
  added: []
  patterns: ["observed live means real-shape-test: a probe ledger row forces its route off justified", "residual risk = unobserved + exact stop + first window"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-129-SUMMARY.md
  modified:
    - scripts/ci/ci-hermetic-live-audit.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R11.json
key-decisions:
  - "The rule is part of check_response_shapes, so the committed-record test and every shape positive control enforce it. It reads every -R11-PROBE file in the phase directory; only files with a transactions list are ledgers (only the HTTP ledger qualifies). If it finds no ledger with a 2xx/3xx row it reports itself vacuous instead of passing."
  - "shape-job_logs had to become real-shape-test, because the probe saw a 302 (seq 4). No existing test read that row, so the new real-shape ref is a test in the checker file (ProbeObservedRouteTests.test_live_probe_job_logs_hop0_matches_the_typed_download_route). It compares the transport's typed job_logs route and its _trusted_download_host predicate with the recorded 302. The checker file and ci-hosted-transport.test.py joined SHAPE_TEST_FILES (see Deviations)."
  - "REAL_SAMPLE_MARKER now also recognises R10_LEDGER, PROBE_(LEDGER|EVIDENCE|BODIES), probe_run_logs_chain( and self.seq47(. All of them read committed real bytes. The hermetic-only positive control still fails."
  - "branch_protection's 200 body gets first window 253-133, not the plan's 253-134. Both windows read this route at preflight and the canary runs first."
  - "git_create_blob is 'not called by any R11 hosted window'. Its only caller (ci-git-publication.py:809) runs for binary blobs only, and every R7 to R10 publication manifest records binary_blob_requests 0. PUBLICATION-R11 does not exist yet (253-131 builds it), so this is conditional; see handoff. git_get_tree has no caller."
  - "No budget changed. failure_logs stays 6/6 with zero slack. It is recorded as residual risk on shape-run_logs."
estimate: {tokens: 30000, tasks: 2}
actuals:
  tokens: 13700
  tasks: 2
  commits: 2
commits: 2
plan_head_before: 758935bef854dc1699af7a12bc38b1d7993cb2d0
plan_head_after: 1b1e2cc406bfa249e69a484adde38df54934eb6c
duration: "about 50 min (2026-10-17T02:05Z to 02:55Z)"
metrics:
  completed: 2026-10-17
---

# Phase 253 Plan 129: Probe-observed response shapes on real samples, and the R11 residual list Summary

**Every route the 253-127 probe saw answer 2xx/3xx is now real-shape-test on that probe's committed rows: rate_limit, run, run_jobs, job_logs and run_logs. A new checker rule fails if any of them slides back to justified or loses its probe sample. Every shape still unobserved live is listed in `unobserved_live_shapes` with the exact stop that ends the window and the first hosted window that will see it. shape-run_logs-fresh-run is listed for 253-133. Zero GitHub requests.**

CIREL-02 stays open. Full Phase 253 verification stays not_started. FREEZE-R11 is not cut (253-131).

## Task Commits

| Task | Commit | Subject |
|---|---|---|
| 1 | `77542f76f` | feat(253-129): probe-observed response shapes on real samples |
| 2 | `1b1e2cc40` | docs(253-129): R11 residual risks for still-unobserved shapes |

`commits: 2` is measured with `git rev-list --count 758935bef..1b1e2cc40`. The SUMMARY commit adds a third.

## Rows flipped or extended (probe ledger sha256 79e8b4d3…0018)

| row | before | after | probe samples added | fields added | refs added |
|---|---|---|---|---|---|
| shape-run_logs | justified (seq 47 only) | **real-shape-test** | seq 5 (302), seq 6 (200); bodies record `/entries/4` (run-log-chain, sha256 3b8d5bf4…9523) beside R10 seq 47 (3b0dd91e…6c33) | meta:host, header:content-type, header:content-length, magic_hex, zip_members[].name | transport `LivePolicyRedirectTests.test_live_r10_seq47_results_receiver_location_is_followed_without_authorization` and `.test_live_probe_observed_run_logs_chain_is_followed`; dry-run `RunLogsShapeTests.test_fake_log_redirect_matches_the_probe_recorded_chain` |
| shape-job_logs | justified, no samples | **real-shape-test** | seq 4 (302 to productionresultssa18) | header:location, header:location.host, header:content-type, header:content-length; magic_hex in fields_without_real_sample (hop 1 never followed) | checker `ProbeObservedRouteTests.test_live_probe_job_logs_hop0_matches_the_typed_download_route` |
| shape-run | real-shape-test | unchanged kind | seq 2 (cancelled run 38141825287, 200) | value:conclusion=cancelled | verify `FixtureShapeFidelityTests.test_live_probe_cancelled_run_fixture_matches_the_recorded_shape`; dry-run `CancelledShapeTests.test_fake_cancelled_run_matches_the_probe_recorded_shape` |
| shape-run_jobs | real-shape-test | unchanged kind | seq 3 (200) | value:jobs[].conclusion=cancelled, value:jobs[].conclusion=skipped, value:jobs[].steps[].conclusion=cancelled | the same two cancelled tests |
| shape-rate_limit | real-shape-test | unchanged kind | seq 1 (200) beside R7/R8/R9 | none | none. The residual risk now records the two interleaved core counters (body and its headers: 4851, reset 1792193189; other responses' headers: 4999/4998/4997, reset 1792195729). The drivers read only the body's `resources.core.remaining`. |

Cancelled and job-log samples were all captured with the recorded status, so no row claims a sample the probe did not take.

## unobserved_live_shapes (record top level, 14 entries)

| id | first window | stop if the real shape differs |
|---|---|---|
| shape-cancel_run | 253-133 | 'identified canary cancellation failed' / 'identified canary cancellation returned HTTP <status>' (ci-gate-canary.sh:897-898); 'cancellation was not observed on a hosted fixture job' |
| shape-run_logs-fresh-run | 253-133 | non-200 final hop: 'failed-log retrieval failed for run <id>' (ci-gate-canary.sh:916), no retry. An extra hop hits failure_logs 6/6 (category_budget_exhausted). Another host: redirect_rejected before its socket |
| workflow-source:canary-fixture | 253-133 | fifth producer form: 'separate hosted verifier job set is unexpected'. Missing steps: 'separate verifier did not confirm its candidate checkout and source matrix' |
| shape-dispatch-matrix_evidence | 253-133 | refused before the request by serialize_dispatch_inputs (dispatch_inputs_invalid/too_large) and the 64511-character MATRIX_PAYLOAD_LIMIT ('compact verifier matrix exceeds its bounded dispatch input'). After the request: 'dispatch returned HTTP <status>' / 'separate verifier dispatch failed'. A 202 halts at the 204 binding |
| scenario-missing-seam-run | 253-133 | 'actual terminal conclusion does not match missing-seam' / 'hosted job set is missing, duplicated, or unexpected'; driver 'negative source unexpectedly concluded success' |
| scenario-unexpected-skip-run | 253-133 | same as missing-seam, for unexpected-skip |
| shape-branch_protection-200 | 253-133 | 'legacy branch-protection checks are malformed' or the exact-five rule at preflight. Seen only if an operator adds classic protection |
| shape-pr_create | 253-134 | check_pr '<label> is not the same open unmerged draft PR' / head-base identity |
| shape-pr_read | 253-134 | 'the PR has no tested merge commit or base identity' / 'PR has no distinct tested merge commit' |
| shape-compare | 253-134 | 'compare file inventory is empty, malformed or incomplete' / docs ahead-behind |
| shape-repo_contents | 253-134 | 'source read is not a base64 file response' / 'source blob differs from the frozen blob' |
| shape-git_create_blob | not called by any R11 hosted window | becomes 253-133 only if PUBLICATION-R11 records binary_blob_requests > 0 |
| shape-git_get_tree | not called by any R11 hosted window | no caller in scripts/ci |
| shape-job_logs-hop-1 | not called by any R11 hosted window | no R11 caller; results-receiver is refused on job_logs before its socket |

attempt_jobs stays real-shape-test and is not listed; its residual window moved from the never-run 253-123 to 253-134. The residual risks for pr_create, pr_read, compare and repo_contents also moved from 253-123 to 253-134, and rules_main now names 253-133. Every message quoted above was grepped in the non-test sources under scripts/ci and found in exactly one file. The created-PR message is built as `f"{label} is not the same open unmerged draft PR"`, and check_pr is called with label "created PR".

git_create_blob/git_get_tree callers were re-derived with `grep -rn` over scripts/ci (non-test files):
- git_create_blob: only `ci-git-publication.py:809`.
- git_get_tree: only `ci-hosted-transport.py` (ROUTES and the routable list).
- Positive control: the same grep finds git_create_tree's callers in ci-git-publication.py, ci-pr-proof.sh and ci-hosted-gate-verify.py.

## RED / GREEN counts

| step | result |
|---|---|
| Task 1 RED (rule and controls added, pre-update record) | exit 1: 36 ran, **28 failures**. The rule itself reported 7 problems: run_logs and job_logs justified, and no probe row cited by rate_limit, run, run_jobs, run_logs and job_logs. Because the rule sits inside check_response_shapes, every shape and branch positive control's "unmodified copy passes" setUp failed too. The new job_logs real-shape test passed (it reads only committed bytes). |
| Task 1 GREEN | 36/36 OK; Task 1 `<verify>` exit 0 after commit `77542f76f` |
| Task 2 checker | 36/36 OK |
| Task 2 `<verify>` (verbatim, under caffeinate, after commit `1b1e2cc40`) | **exit 0**. audit 36/36, transport 74/74, verifier 123/123, publication 85/85, shape-probe 19/19, canary-flow 22/22, ci-pr-proof 64/64. Acceptance `--require-target-disposition` 0 and `--require-target-accepted` 3 (unchanged). v1 and r2-r10 `--check-only` all 0. PRESERVATION-R11.sha256 passes. config.json pin, state.json 70229 bytes and the clean tree all hold |

Positive controls (each mutates a temporary copy and must fail; all pass as tests):
- shape-run_logs reverted to justified;
- its probe sample removed ('cites none of its rows [5, 6]');
- a probe locator moved to seq 1 ('sequence 1 is not a 2xx/3xx run_logs row of that probe ledger');
- the probe ledgers deleted ('would be vacuous').

The rule test also checks its own input:
- the observed set is exactly {rate_limit:[1], run:[2], run_jobs:[3], job_logs:[4], run_logs:[5,6]};
- every -R11-PROBE file is git-tracked.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] shape-job_logs needed a real-shape test ref that no existing test supplied**
- **Found during:** Task 1.
- **Issue:** The rule requires real-shape-test for every probe-observed route, and the probe saw job_logs answer 302. A real-shape-test row needs a ref to a test that reads real bytes, and no existing test reads probe seq 4. Test files outside files_modified could not be edited.
- **Fix:** add `ProbeObservedRouteTests.test_live_probe_job_logs_hop0_matches_the_typed_download_route` in the checker file (in scope). It checks the following against seq 4:
  - ROUTES['job_logs'] (GET, download, the recorded path);
  - the recorded 302, empty body and Location shape;
  - `_trusted_download_host` admitting the recorded sa18 host for job_logs hop 1 under the probe allocation.

  Its positive controls are results-receiver and a lookalike host, both refused. The checker file and `ci-hosted-transport.test.py` (needed for the plan's two transport refs) joined SHAPE_TEST_FILES.
- **Files modified:** scripts/ci/ci-hermetic-live-audit.test.py.
- **Commit:** `77542f76f`.

**2. [Rule 3 - Blocking] REAL_SAMPLE_MARKER did not recognise the probe and R10 readers**
- **Issue:** The plan's run_logs and cancelled refs read `R10_LEDGER`, `PROBE_LEDGER(_R11)`, `PROBE_EVIDENCE`, `PROBE_BODIES`, `probe_run_logs_chain()` and `self.seq47()`. The 253-118 marker only knew R7 to R9 names, so it would have rejected them as "no real-sample read".
- **Fix:** extend the marker with exactly those names. Each one loads a committed ledger or probe record.
- **Commit:** `77542f76f`.

### Plan interpretations

**3.** The first window for branch_protection's 200 body is 253-133, not 253-134. The canary preflight reads the route before the PR proof does. Both are named.

**4.** The job_logs hop-1 field is named `magic_hex`, the bodies-record name for a final-hop body, and listed in fields_without_real_sample. The ledger syntax has no per-hop field, and every meta/header field already resolves on hop 0.

**5.** copy_audited_tree now also copies every -R11-PROBE file, so the positive-control trees can always see the probe ledger even when a control removes its locator.

## Known Stubs

None.

## Threat Flags

None. Only an audit record and its checker changed. No product transport, driver or verifier file changed, and no network request was made.

## Remaining gaps / handoff to 253-130

- **Fresh-run log shape (253-133).** `shape-run_logs-fresh-run` is the main residual. Hop 1 seconds after a canary failure may answer non-200, and the driver stops at 'failed-log retrieval failed for run <id>' with no retry. failure_logs is 6/6 with zero slack, so a three-hop chain also halts. No budget was changed. If 253-130/131 want slack or a retry, that needs its own plan.
- **binary_blob_requests (253-131).** When 253-131 builds PUBLICATION-R11, check its `binary_blob_requests`. If it is > 0, the shape-git_create_blob row and its unobserved_live_shapes entry must change from "not called by any R11 hosted window" to 253-133. This checker will not catch that by itself.
- **Canary checkpoint.** The `unobserved_live_shapes` list is the input for the 253-133 canary checkpoint; 11 of its 14 entries have a hosted window (7 in 253-133, 4 in 253-134).
- **Two rate-limit counters.** They are recorded on shape-rate_limit. The drivers read only the body's counter.
- **Pinned records.** The R9/R10 audit records were not touched; they still cite the old transport test name.
- **Freeze.** FREEZE-R11 is not cut. ci-gate-canary.sh --check-only was not run against FREEZE-R10.

## Self-Check: PASSED

- FOUND commits 77542f76f and 1b1e2cc40 (ancestors of HEAD)
- FOUND the checker, the R11 audit record and this SUMMARY
