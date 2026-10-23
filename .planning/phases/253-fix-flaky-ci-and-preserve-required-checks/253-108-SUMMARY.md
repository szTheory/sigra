---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "108"
subsystem: ci-reliability / offline gate
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, offline-dry-run, live-policy, fake-github, r9]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-107 live approved-redirect hop (redirect_fix_commit 375b4113), live-policy shim, dry-run window guard"
provides:
  - "ci-gate-canary-dryrun.py --live-policy: the whole canary runs offline through the LIVE transport policy (live allocation, TLS fake routed by Host header, 302-to-blob downloads)"
  - "--transport-from (253-104 sensitivity control), --seed-r8-refs, --sleep-scale, and a truthful --ref-pair help"
  - "new summary keys: mode, live_hops, authorization, requested_sleeps, shim_refusals, shim_connect_hosts, violations, allocation, publication, transport_from, seeded_r8_refs_changed"
  - "publication receipts now carry origin.window_id (a live-only defect this gate found, fixed RED-first)"
affects: ["253-109", "253-110", "253-111", "253-113"]
tech-stack:
  added: []
  patterns:
    - "offline live-policy gate: the real driver, publisher, transport and verifier run on a live allocation; only the socket/TLS layer is redirected"
    - "a recording sleep classifies each wait by the request before it, not by its value"
key-files:
  created: []
  modified:
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
    - scripts/ci/ci-git-publication.py
key-decisions:
  - "The publication receipt's missing origin.window_id (the 253-107 handoff) is a live-only defect this gate found. It got its own RED and its own fix commit in ci-git-publication.py."
  - "The shim's generated sitecustomize hides Homebrew Python's own sitecustomize, which is what puts PyYAML on the path. The runner chains the original from its work-dir copy instead of editing the 253-107 shim source."
  - "The sensitivity commit is resolved only by its unique subject 'allow the live approved-redirect hop' and checked against the 253-107 SUMMARY. The latest fix(253-107) commit is the later hole fix e72466b1c, so using it would hide the defect."
actuals:
  tokens: 11200
  tasks: 3
  commits: 7
commits: 7
plan_head_before: 024e93379a4eb2241535d2896e117990db787d3b
plan_head_after: d3a21662d42877979f9a401d8a2a732a369c5126
duration: "about 2h 32m (mostly three 25-45 minute runs of the dry-run suite)"
completed: 2026-10-15
---

# Phase 253 Plan 108: Live-policy offline gate Summary

**The offline gate can now run the whole canary through the live transport policy: a live allocation, a 302 from api.github.com to productionresultssa17.blob.core.windows.net, and the token kept off the blob host. It fails on the exact 253-104 defect (`origin_rejected: live transport is restricted to api.github.com`) and passes once that defect is fixed. It found one more live-only defect, the publication receipt's missing window id, which is now fixed. There were zero GitHub requests.**

## Performance

- **Started:** 2026-10-15T21:44:09Z
- **Completed:** 2026-10-16T00:16:16Z
- **Tasks:** 3/3
- **Files modified:** 3

## Live-policy green summary (`--live-policy --seed-r8-refs`, the Task 3 verify run)

- **Result:** exit 0, status `passed`, synthetic `true`, all six scenarios accepted as synthetic, separate verifier `passed`, `seeded_r8_refs_changed` false.
- **Requests:** 93 of 117, equal to the fake's journal.

  | Category | Used / frozen |
  |---|---|
  | publication | 19/24 |
  | preflight | 5/8 |
  | dispatch | 7/7 |
  | run_discovery | 7/7 |
  | pre_watch_rate | 7/7 |
  | terminal_polls | 18/18 |
  | attempt_jobs | 7/7 |
  | artifact_metadata | 6/7 |
  | artifact_downloads | 10/12 |
  | failure_logs | 6/6 |
  | cancellation | 1/1 |
  | infrastructure_retry | 0/13 |

- **live_hops:** 8 hop-1 transactions, all status 200 on productionresultssa17.blob.core.windows.net: 5 artifact_zip and 3 run_logs. Each download is two transactions (a 302 on api.github.com, then a 200 on the blob host).
- **Authorization:** 85 api.github.com requests carried the dummy bearer token. None was missing it, and none of the 8 blob-host requests had one (85 + 8 = 93).
- **Shim:** 0 refusals. Connections went only to api.github.com and productionresultssa17.blob.core.windows.net on 443. The fake recorded 0 violations.
- **Requested sleeps:** 7 discovery waits, all 20 s (one per dispatch). 18 poll intervals, all 60 s (one per terminal poll). No unclassified sleep. `test_overrides` was empty.
- **Publication:** origin `actual-github`, status `published-actual-github`, `fixture_ref_state` verified (the driver's live `--verify-publication --require-live-origin` branch ran). `origin.window_id` is `253-dryrun-live-policy-<pid>`, and the verifier's `dryrun_window(receipt)` returns true.
- **Elapsed:** 120.7 s modeled at `--sleep-scale 0.01`. The hermetic default run in the same verify passed in 144.3 s, also with 93 requests.

## Sensitivity result (Task 2)

FC was resolved with `git log --format=%H --fixed-strings --grep='allow the live approved-redirect hop' -- scripts/ci/ci-hosted-transport.py`. That gives exactly one match, `375b4113805618e48a925d2841ca66545987a2f4`, which equals 253-107's `redirect_fix_commit`.

| Run | Exit | Status | Stop line / notes |
|---|---|---|---|
| `--live-policy --transport-from FC^ --stop-after full-pass` | 1 | failed | `ci-hosted-transport: origin_rejected: live transport is restricted to api.github.com`. artifact_zip sent once (hop 0 only), no hop-1 transaction, connections only to api.github.com, evidence `halted`. |
| `--live-policy --transport-from FC --stop-after full-pass` (positive control) | 0 | passed | One artifact_zip hop 1 to productionresultssa17.blob.core.windows.net with status 200. |
| hermetic `--transport-from FC^ --stop-after full-pass` (recorded, not gated) | 0 | passed | Stop null; hop 1 went to localhost. The hermetic allocation is exempt from the live origin check, so 253-101's gate was blind to the defect. |

The stop line is word for word the one that halted 253-104.

## r8 create-only control

`--live-policy --ref-pair r8 --seed-r8-refs` exits nonzero during publish-only. The stop line contains "already points to a different commit", no `create_ref` is sent, both r8 refs are unchanged (7a1ba235… / ad015ec1…), and the evidence is `halted`. With the derived freeze on the legacy pair, the seeded r8 refs are never touched (`seeded_r8_refs_changed` false).

## Found live-only defects

**1. The publication receipt had no window identity** (the gap the 253-107 handoff predicted).
- **RED:** the live-policy run of `test_the_live_publication_is_actual_github_verified_and_labelled_with_its_dry_run_window`, recorded after runner commit d53adcfa8. The receipt said `actual-github` with `origin_window_id` None, and `verifier_dryrun_window` was false. So the 253-107 completion guard could never gap a dry-run publication. Classifier: RED_EVIDENCE_OK.
- **Fix:** `a6884f77b`. `derive_origin` now records `allocation.window_id` in both origin kinds. `verify_publication` only reads `kind`, so earlier receipts still verify; ci-git-publication.test.py passes 66/66.

No other live-only defect was found. Live publication verification, the verified REF_STATE, live pagination, the live allocation checks, failed-log 302s, the cancel path and the verifier dispatch all passed through the live policy unchanged. ci-gate-canary.sh was not edited.

## Coverage statement

**Covered offline by the live-policy gate:**
- every live transport branch on the canary path: `_validate_allocation` for a live allocation, `_route` to api.github.com:443, the hop-0 origin check in `request_one`, `_approved_redirect` and `_trusted_download_host` for the blob host, the hop-1 re-check, live `_next_page_url`, and system TLS trust replaced only by the shim's CA, with SNI still using the real hostnames;
- token scoping: the token is sent to api.github.com only and never to a download host;
- live publication: `derive_origin` actual-github, `--verify-publication --require-live-origin`, and `fixture_ref_state` verified;
- the live timing constants (20 s discovery, 60 s poll), requested unchanged and only scaled at the sleep binary;
- the driver's live refusal of every `SIGRA_CANARY_TEST_*` variable;
- the verifier's dry-run window guard on the evidence and on the publication receipt.

**Not covered:** real GitHub latency and eventual consistency, real redirect hosts other than productionresultssa17 (including pipelines.actions.githubusercontent.com for logs), real check runs and Actions behaviour, and real authentication, token scopes, rate limits, secondary limits and 403/429 headers.

## Task Commits

| # | Hash | Subject |
|---|---|---|
| 1 | bb1f04166 | test(253-108): live-policy full-pass and truthful --ref-pair help (RED) |
| 2 | d53adcfa8 | feat(253-108): live-policy dry-run mode through the live transport policy |
| 3 | a6884f77b | fix(253-108): publication origin carries its allocation window_id |
| 4 | 43ec8dba6 | test(253-108): 253-104 sensitivity control pinned to the redirect-fix subject (RED) |
| 5 | fbba6b27a | test(253-108): full live-policy sequence, live waits, seeded r8 refs (RED) |
| 6 | 61a65befa | feat(253-108): --transport-from for the 253-104 sensitivity control |
| 7 | d3a21662d | feat(253-108): --seed-r8-refs and the full live-policy sequence |

## TDD record

- **Task 1 RED:** 7 failures out of 7. `--live-policy` was not a recognised option, and the help text still said "never passed here". `gsd-tools check tdd-red-evidence` gave RED_EVIDENCE_OK for `test_the_ref_pair_help_is_truthful_and_names_the_publishers_ref_pairs` and for `test_live_policy_publish_only_and_full_pass_pass_end_to_end`.
  - Semantic check: each test failed on its planned assertion (no summary produced, or stale help text). There were no fixture or load faults; a first attempt that failed in setUpClass was rejected by the classifier as an incomplete report, so the test was restructured.
- **Task 1 GREEN:** 6 of 7 passed after the runner commit. The 7th was the found defect above, which went green after a6884f77b.
- **Task 2 RED:** 3 failures (`--transport-from` not recognised). The trap control passed. RED_EVIDENCE_OK for the pre-fix and fix targets. **GREEN:** 4/4.
- **Task 3 RED:** 8 failures (`--seed-r8-refs` not recognised). RED_EVIDENCE_OK for `test_the_seeded_r8_refs_never_move` and `test_an_r8_pair_publication_stops_on_the_seeded_r8_refs_with_no_ref_created`. The two live halt-marking tests already passed under the Task 1 code, because they use only `--inject`, `--fault` and `--reenter`. **GREEN:** 10/10.
- **REFACTOR:** none.

## Verification

- **Task 1 `<verify>`, the tracer gate, run before any expansion:** rc 0. Dry-run suite 28/28 in 1490 s.
- **Task 2 `<verify>`:** rc 0. Dry-run suite 42/42 in 2043 s, plus the pre-fix, fix and hermetic runs above.
- **Task 3 `<verify>`, verbatim:** rc 0.

  | Suite | Result |
  |---|---|
  | ci-hosted-transport.test.py | 49 OK |
  | ci-git-publication.test.py | 66 OK |
  | ci-hosted-gate-verify.test.py | 87 OK |
  | ci-gate-canary-flow.test.py | 22 OK |
  | ci-gate-canary-recovery.test.py | 5 OK |
  | ci-gate-canary-dryrun.test.py | 42 OK in 2684 s |
  | ci-gate-canary.test.sh | passed |
  | ci-pr-proof.test.sh | 39 OK |

  Also in that verify: both gate modes passed (hermetic default, and `--live-policy --seed-r8-refs`). The v1 and r2-r8 `--check-only` commands exited 0, `--require-target-disposition` exited 0, `--require-target-accepted` exited 3, and `shasum -c` on PRESERVATION-R9 exited 0.
- **Positive controls for the negative results:**
  - Fake guards (in-process, live fake behind the shim): a blob-host request with Authorization, a non-download path on the blob host, an api.github.com request without the token, a download path on api.github.com, and an unknown Host were each refused or recorded. The counters read `{api_with: 2, api_without: 1, blob_with: 1}` and there were five violations. So the zero counts in the gate runs mean something.
  - The hermetic run lists its three `SIGRA_CANARY_TEST_*` variables, so the empty live `test_overrides` is not a reporting gap.
  - The pre-fix run's `shim_connect_hosts` is `["api.github.com"]` while the fix run's adds the blob host, so the connect log records real hop-1 connections.
  - The shim's refusal path was proven in 253-107.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The shim's sitecustomize hid Homebrew Python's sitecustomize**
- **Found during:** Task 1, on the first live-policy run.
- **Issue:** publish-only failed with "fixture YAML is invalid: No module named 'yaml'". The driver's check-only imports PyYAML, which Homebrew's sitecustomize adds to the path. The shim's generated sitecustomize on PYTHONPATH replaced it.
- **Fix:** the runner prepends a chain loader to its work-dir copy of the generated sitecustomize. The chain loads the next sitecustomize on sys.path and only changes paths. The 253-107 shim source is unchanged.
- **Files modified:** scripts/ci/ci-gate-canary-dryrun.py, in d53adcfa8.

**2. [Process] Kept the RED steps meaningful**
- My first Task 1 commit also contained the Task 2/3 options. I amended that commit, before anything else built on it, to remove them, so each task's options were added only after its RED.
- The Task 3 RED tests were committed before the Task 2 verify ran, so the Task 2 verify (which runs the whole dry-run suite) was run after the Task 3 GREEN.

**3. [Behaviour note] Runner CLI defaults**
- `--discovery-wait` and `--poll-seconds` now default to None. Hermetic mode still uses 4 s and 0.05 s, and live-policy mode refuses both options.
- `--visibility-delay` defaults to 3 s in hermetic mode and 0.05 s in live-policy mode.
- `--ref-pair` now uses argparse choices (legacy, r8). An unknown name is refused by argparse instead of by the publisher.

## Known Stubs

None.

## Threat Flags

None. The only product change adds `window_id` to the publication origin label. The dummy token `dryrun-live-policy-not-a-credential` exists only in the clone's driver environment, and the real GH_TOKEN/GITHUB_TOKEN are unset (T-253-222).

## Notes for 253-109 and later

- **The shim's sitecustomize hides any interpreter sitecustomize.** Any process that needs Homebrew site-packages (PyYAML) will break under `shim.prepare()`. 253-109 should reuse `chain_interpreter_sitecustomize` from the runner, or replan a fix to ci-live-policy-shim.py.
- **The shim's `ssl.create_default_context` patch only applies to callers that pass that context explicitly.** `http.client.HTTPSConnection` without a context still uses the system trust store. The transport passes a context explicitly, so it is unaffected, but new callers should not rely on the patch.
- **Pipelines host not exercised.** The gate never exercises `pipelines.actions.githubusercontent.com`; every 302 here goes to productionresultssa17. If 253-110's audit wants that host covered, it needs a variant Location.
- **Freezes must be rebuilt.** Since the publisher changed, FREEZE-R8 no longer matches this tree. 253-111 freezes the fixed source and can run `--live-policy --seed-r8-refs` as its pre-clock gate.
- **Verification status.** Full Phase 253 verification remains not_started.

## Invariants

- `git status --short` shows only ` M .planning/config.json`. config.json sha256 is 8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d. state.json is 70229 bytes with sha256 prefix e45278c2cee0.
- STATE.md, ROADMAP.md, REQUIREMENTS.md, state.json and HANDOFF.json were not touched, and no gsd state, roadmap or config writer verbs were run.
- No pinned PLAN, SUMMARY, R7/R8 record or PRESERVATION-R9 file changed (`shasum -c` rc 0).
- scripts/ci/__pycache__ was removed after every python run. The dry-run deleted its temporary directories.
- Zero GitHub requests, no push and no fetch.

## Self-Check: PASSED

All seven commits are ancestors of HEAD, the three modified files exist, and the commit count measured from the plan ledger is 7 (024e93379..d3a21662d).
