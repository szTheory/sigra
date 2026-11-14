---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "109"
subsystem: ci-reliability / PR proof offline gate
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, pull-request, live-policy, offline, r9]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-107 live-policy shim, redirect fix (375b4113) and dry-run window guard; 253-108 chain_interpreter_sitecustomize and live-policy fake pattern"
provides:
  - "ci-pr-proof.test.sh LiveWorld: the PR universe on the LIVE transport policy (live publication and production allocations, Host-routed TLS fake, 302-to-blob producer ZIPs, shim env with a dummy token)"
  - "LivePolicyPRTests: normal and docs-only families, the pair, the completion gap, token/host scoping and a live required-check-failure negative"
  - "LivePolicySensitivityTests: the pre-fix transport (FC^) fails the live normal family with origin_rejected; FC passes; the hermetic pre-fix result is recorded"
affects: ["253-110", "253-111", "253-113", "253-114"]
tech-stack:
  added: []
  patterns:
    - "hermetic-default hooks on the World builder (tls_san, after_server_start, adapt_allocation, subprocess_env, handler, poll_interval); a subclass turns the same universe live"
    - "transport substitution in a temporary scripts/ci copy: the copied collector resolves ROOT from its own path"
key-files:
  created: []
  modified:
    - scripts/ci/ci-pr-proof.test.sh
key-decisions:
  - "No live-only defect was found on the PR path, so ci-pr-proof.sh, ci-hosted-gate-verify.py and its test are unchanged."
  - "The live World uses ref_pair legacy. The live publisher refuses a live allocation without the canary freeze and approval, and 253-108 put the R9 derived freeze on the legacy pair."
  - "'Publication of the docs objects through the publisher's live origin path' is read as two checks: the seed publication receipt is actual-github, and the publisher's derive_origin labels the collector's 14 docs_publication rows actual-github. The collector, not ci-git-publication.py --publish-docs, publishes docs objects on the 253-114 path."
actuals:
  tokens: 10084
  tasks: 3
  commits: 4
commits: 4
plan_head_before: 084d0e99f1c4505057a259e98480bd68109c793c
plan_head_after: 4374a31ebd346983295ecdc22fef5c77b5296aa9
duration: "about 1h 14m (57 minutes of it the final regression, mostly the dry-run suite)"
completed: 2026-10-16
---

# Phase 253 Plan 109: Live-policy PR families offline Summary

**Both PR families and their pair now run offline through the live transport policy. That means a live production allocation (exactly 120, the frozen categories, the trusted download_hosts list, a `253-dryrun-live-policy-` window, no test fields), producer ZIPs that 302 from api.github.com to productionresultssa17.blob.core.windows.net, and the token kept off the blob host. The pre-fix transport fails the live normal family with the 253-104 stop line, and the fixed transport passes. No live-only defect was found on the PR path. There were zero GitHub requests.**

## Performance

- **Started:** 2026-10-16T00:18:48Z
- **Completed:** 2026-10-16T01:32:51Z
- **Tasks:** 3/3
- **Files modified:** 1 (scripts/ci/ci-pr-proof.test.sh: +527 / -9, the 9 being World builder lines turned into hooks)

## Live-policy PR universe

The universe is `LiveWorld(World)` with `LivePRHandler(PRHandler)`:
- The World builder gained hooks whose hermetic defaults leave every existing universe unchanged: `handler`, `poll_interval`, `tls_san`, `after_server_start`, `adapt_allocation`, `subprocess_env`, and a `proof=` argument on `collect`. No `test_*` contract was edited; the 9 removed lines are all World builder and `collect` lines.
- The TLS identity has SANs localhost, api.github.com, `*.blob.core.windows.net` and pipelines.actions.githubusercontent.com.
- The fake routes by Host header:
  - api.github.com must carry `Bearer dryrun-live-policy-not-a-credential` and never serves a download path;
  - the blob host must carry no Authorization and serves only the issued `/blob/<id>?sv=…&sig=…` paths;
  - any other host gets a 421 and is recorded as a violation.
- Allocations:
  - Production: mode live, allocation_kind production, 120, `PRODUCTION_CATEGORY_LIMITS`, the 42 trusted hosts from ALLOCATION-R8, window `253-dryrun-live-policy-<pid>`.
  - The seed canary publication allocation is live too: kind canary, window `253-dryrun-live-policy-publication-<pid>`.
- Every subprocess (the publisher, the collector and its transport calls) gets the shim env:
  - 253-108's `chain_interpreter_sitecustomize`, so PyYAML stays importable;
  - a requested-wait recorder appended to the work-dir sitecustomize;
  - sleep scale 0.001;
  - the dummy GH_TOKEN. The real GH_TOKEN/GITHUB_TOKEN stay unset.
- The freeze is prepared with the production 60 s poll interval.

## Per-family request counts and live hops (main live universe)

| | normal | docs-only | combined |
|---|---|---|---|
| Requests | 27 | 39 | 66 / 120 |
| artifact_zip hop 1 (blob host, 200) | 5 | 5 | 10 |

Combined categories:

| Category | Count |
|---|---|
| artifact_downloads | 20 (5 hop 0 302s on api.github.com + 5 hop 1 200s on the blob host, per family) |
| docs_publication | 14 |
| pr_identity | 8 |
| terminal_polls | 6 |
| preflight | 4 |
| run_discovery | 4 |
| artifact_metadata | 2 |
| attempt_jobs | 2 |
| native_checks | 2 |
| pr_create | 2 |
| pre_watch_rate | 2 |

These match the hermetic universe's asserted counts (14 docs_publication, 20 artifact_downloads, 4 preflight, 4 run_discovery, 2 pr_create).

- **Authorization:**
  - all 56 api.github.com requests carried the dummy bearer token;
  - none of the 10 blob-host requests carried any Authorization;
  - fake violations 0, shim refusals 0, shim connections only to api.github.com and the blob host.
- **Requested waits:** six, all 60 s (one discovery wait and two terminal-poll waits per family), slept at 0.001.
- **Normal family verify:** `--mode pr --family normal` exits 0 with `synthetic_pr_family_verified`, synthetic true, accepted_live false.
- **Docs-only verify:** `--mode pr --family docs-only` exits 0, synthetic true.
- **Pair:** `--family both` exits 0 with `synthetic_pr_pair_verified`. It is one allocation and one append-only window, with 66 requests.
- **Labelling:** the collector itself writes `synthetic: false` on a live allocation, as verify_pr_transport requires. The 253-107 window guard is what turns every family and pair result synthetic.

## Sensitivity result (Task 2)

FC was resolved with `git log --format=%H --fixed-strings --grep='allow the live approved-redirect hop' -- scripts/ci/ci-hosted-transport.py`. That gives exactly one match, `375b4113805618e48a925d2841ca66545987a2f4`, which equals 253-107's `redirect_fix_commit`. The blob is substituted into a temporary copy of scripts/ci plus `.github/workflows/ci.yml`. The real scripts/ci is never written.

| Run | Exit | Stop line / notes |
|---|---|---|
| live-policy normal, transport FC^ | 1 | `artifact_zip: ci-hosted-transport: origin_rejected: live transport is restricted to api.github.com`. One artifact_zip charged (hop 0, api.github.com, 302), no blob-host request in the fake journal, shim connections only `["api.github.com"]`, shim refusals empty (the transport refused, not the shim), verifier exit 1. |
| live-policy normal, transport FC (positive control) | 0 | Five hop 1 200s on productionresultssa17.blob.core.windows.net, connections to api and blob, verifies `synthetic_pr_family_verified`. |
| hermetic normal, transport FC^ (recorded, not gated) | 0 | Stop null, hop 1 hosts `["localhost"]`. The hermetic allocation is exempt from the live origin check, so the existing PR suite was blind to 253-104. |

The stop line is word for word the one that halted 253-104 and that the 253-108 canary sensitivity control reproduced.

## Live negatives and their positive controls

- **Required check failing on the PR head (live branch of `_view_for_checks`):**
  - Set-up: the fake returns `Example unit smoke (ExUnit + ConnTest)` with conclusion failure, and the run itself stays success.
  - The collector completes (exit 0). The check_runs transaction is on api.github.com with an `https://api.github.com/` URL, so no rewrite was needed.
  - The verifier exits 1 with `hosted-gate-verify: FAIL: native producer did not pass: Example unit smoke (ExUnit + ConnTest)`.
  - Positive control: the same live universe without the failing check verifies.
- **Fake guards (positive control for the zero counts):**
  - A probe to the blob host with `Authorization: Bearer probe` is recorded as "Authorization reached the blob host", and the journal records the header.
  - A tokenless api.github.com probe is recorded as "without the dummy bearer token".
- **Docs readback on the live path:**
  - The fake strips one trailing newline, as GitHub does, and the evidence verifies.
  - The verbatim message also verifies.
  - Rejected, for both commits: an extra newline, two characters stripped, CRLF, a trailing space, and a missing message.
- **Completion:**
  - A record linking the live pr_normal and pr_docs_only documents comes back `open`: CIREL-02 open, phase_verification not_started.
  - The gaps include `synthetic:pr_normal:dry-run window cannot satisfy live acceptance` and `synthetic:pr_docs_only:dry-run window cannot satisfy live acceptance`.
  - `--require-accepted` exits 1 with that gap named, and an embedded `accepted: true` claim exits 1.
- **Live docs publication:**
  - 14 docs_publication rows, all on api.github.com with family docs-only.
  - `get_ref` 404 comes immediately before each of the 2 `create_ref` 201s, and a `get_ref` 200 follows each.
  - The publisher's `derive_origin` labels the rows actual-github on the dry-run window.
  - The seed publication receipt is `actual-github`, its window_id is dry-run, and `verifier.dryrun_window(receipt)` is true.

## Found live-only defects

None found. The normal and docs-only collectors, the publisher's live publish and its receipt verification under `--prepare`, `verify_pr_transport`'s live host rule, `_view_for_checks`' live branch, `verify_pr_pair` and `verify_completion` all passed through the live policy unchanged. The PR collector has no log download, so the plan's "log Locations" has no PR-side counterpart.

## TDD record

- **Task 1 (tracer):**
  - No RED: the first run of the 6 live contracts had 5 pass and 1 error, and the error was a test bug (the guard probe asked for a nonexistent ZIP id, then raced the fake's journal append). Both were fixed in the test. 0 product failures.
  - The unexpected green was investigated, not waved through. The live branches were already correct. That the tests can see a live-only defect is shown by Task 2's sensitivity control, and that the check view rejects on the live path is shown by the check-failure negative.
  - Tracer gate: the Task 1 `<verify>` passed (pr-proof 45 OK, gate-verify 87 OK) before any expansion.
- **Task 2:**
  - RED: the substitution helper started as a stub that returned the real collector. The target `test_the_pre_fix_transport_stops_the_live_normal_family_at_the_first_artifact_hop_with_origin_rejected` failed on its planned first assertion (`0 != 1`). The other three passed. `gsd-tools check tdd-red-evidence` returned RED_EVIDENCE_OK (target_test_failed). RED commit c51b838c1.
  - GREEN: 4/4 after the helper (a8b998f63).
- **Task 3:** No RED. The 5 new contracts passed on their first run, and no product change was needed. The negatives inside them (the readback variants and the completion claims) each have a positive control in the same test.
- **REFACTOR:** none.

## TDD Gate Compliance

- A `test(253-109)` commit (c51b838c1, RED) exists. The first `feat(253-109)` commit (95a718e8a, Task 1) comes before it, because Task 1 had no failing test to commit: the plan's RED step is "run and record which fail", and nothing in the product failed.
- Both feat commits contain only tests and test harness, since no product defect was found. They follow the plan's required commit type.

## Verification

- **Task 1 `<verify>`:** passed (ci-pr-proof.test.sh 45 OK in 123 s, ci-hosted-gate-verify.test.py 87 OK). The tree-clean clause passed after the commit.
- **Task 2 `<verify>`, verbatim:** rc 0. Exactly one FC match, present in the 253-107 SUMMARY; ci-pr-proof.test.sh 49 OK in 141 s.
- **Task 3 `<verify>`, verbatim:** rc 0, final clause 0, 3409 s.

  | Suite | Result |
  |---|---|
  | ci-pr-proof.test.sh | 54 OK in 140 s (39 existing + 15 new) |
  | ci-hosted-gate-verify.test.py | 87 OK |
  | ci-hosted-transport.test.py | 49 OK |
  | ci-git-publication.test.py | 66 OK |
  | ci-gate-canary-flow.test.py | 22 OK |
  | ci-gate-canary-recovery.test.py | 5 OK |
  | ci-gate-canary-dryrun.test.py | 42 OK in 2714 s |
  | ci-gate-canary.test.sh | passed |

  - Gate modes: the hermetic default passed with 93 requests, and `--live-policy --seed-r8-refs` passed with 93 requests (85 api_with, 0 api_without, 0 blob_with, 8 live hops, 0 shim refusals).
  - Records: `--require-target-disposition` exited 0 and `--require-target-accepted` exited 3. The v1 and r2-r8 `--check-only` commands exited 0, and `shasum -c` on PRESERVATION-R9 exited 0.
  - Invariants: config.json sha and state.json size were checked inside the verify.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, test-only] Guard probe asked for an artifact id the fake does not hold, then raced the journal append**
- **Found during:** Task 1, on the first run.
- **Issue:** The probe requested `/blob/1`, a KeyError in the fixture. After that was fixed, it indexed `journal[-2]` while the fake appends the row after writing the response.
- **Fix:** The probe uses a real artifact id and searches the journal rather than indexing it.
- **Files modified:** scripts/ci/ci-pr-proof.test.sh, in 95a718e8a, before the commit.

**2. [Interpretation] Docs "receipt is actual-github"**
- The collector publishes docs objects itself on the 253-114 path and writes no docs receipt.
- The behaviour is asserted two ways: the seed publication receipt is actual-github, and the publisher's `derive_origin` labels the collector's docs rows actual-github. `ci-git-publication.py --publish-docs` was not exercised. Its receipt rows carry no `family`, so verify_pr_family would refuse them; it is not on the PR-window path.

**3. [Process] The live World uses `ref_pair="legacy"`**
- The publisher refuses a live allocation without the canary freeze and approval. The legacy pair matches 253-108's R9 derived freeze.

## Known Stubs

None.

## Threat Flags

None. No product file changed. The dummy token `dryrun-live-policy-not-a-credential` exists only in the subprocess env built by LiveWorld. Every temp directory (universes, transport copies) is removed by test cleanup.

## Notes for 253-110 and later

- **Coverage 253-110 can cite:**
  - for ci-pr-proof.sh and ci-hosted-gate-verify.py: `LivePolicyPRTests` (11 contracts) and `LivePolicySensitivityTests` (4 contracts) in scripts/ci/ci-pr-proof.test.sh;
  - live branches exercised: verify_pr_transport's live host rule, `_view_for_checks` without rewrite, live publish plus receipt verify under `--prepare`, `follow_download` to a trusted blob host, live `verify_pr_pair`, and the completion dry-run gap.
- **Not covered:**
  - real GitHub behaviour (latency, eventual consistency, real check runs, auth scopes, rate limits, 403/429);
  - redirect hosts other than productionresultssa17;
  - `ci-git-publication.py --publish-docs`, which is not on the PR path;
  - the PR collector's own 60 s waits are recorded as requested, but the hosted watcher cadence is not modeled.
- **Hermetic blindness confirmed for the PR path.** The pre-fix transport passes the hermetic PR universe, so the hermetic suite alone cannot gate live transport changes. Keep the live classes in the gate.
- **The `World` hooks are reusable.** A future live variant (for example a pipelines-host Location) can subclass `LiveWorld` and override `LivePRHandler.do_GET`.
- **Verification status.** Full Phase 253 verification remains not_started.

## Invariants

- `git status --short` shows only ` M .planning/config.json`. config.json sha256 is 8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d. state.json is 70229 bytes with sha256 prefix e45278c2cee0.
- STATE.md, ROADMAP.md, REQUIREMENTS.md, state.json and HANDOFF.json were not touched, and no gsd state, roadmap, config or requirements writer verbs were run.
- No pinned PLAN, SUMMARY, R7/R8 record or PRESERVATION-R9 file changed (`shasum -c` rc 0).
- scripts/ci/__pycache__ was removed after every python run.
- Zero GitHub requests, no push, no fetch, no gh or curl.

## Self-Check: PASSED

All four task commits are ancestors of HEAD, scripts/ci/ci-pr-proof.test.sh exists, and the commit count measured from the plan ledger is 4 (084d0e99f..4374a31eb).
