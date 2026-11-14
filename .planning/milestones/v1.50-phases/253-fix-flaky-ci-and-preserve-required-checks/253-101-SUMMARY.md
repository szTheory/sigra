---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "101"
subsystem: ci-reliability / hosted canary offline gate
status: complete
tags: [ci-reliability, load-recovery, hosted-canary, offline-dry-run, fake-github, r8]
requirements: ["CIREL-02"]
dependency_graph:
  requires: ["253-100"]
  provides: ["offline dry-run gate scripts/ci/ci-gate-canary-dryrun.py (--revision-freeze for 253-102/104)", "hermetic canary routing", "once-per-window preflight", "fail-closed halt marking", "request-free discovery wait and first-poll interval", "synthetic-only hermetic-https verification and completion gap"]
  affects: ["253-102", "253-104", "253-105"]
tech-stack:
  added: []
  patterns: ["temporary --shared clone of HEAD + local HTTPS fake extending ObjectServer", "exactly-once reintroduction patches as sensitivity controls", "ERR trap with errtrace for halt marking"]
key-files:
  created:
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
  modified:
    - scripts/ci/ci-gate-canary.sh
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
decisions:
  - "Halt marking uses an ERR trap with errtrace (installed once the allocation is known), not explicit fail calls; watch_run additionally calls fail itself because it always runs as an if-condition."
  - "The synthetic freeze uses the publisher's default label 253-91 (freeze_plan recorded); the first three-digit label is 253-102 Task 3."
  - "Publication rows get evidence receipts derived from the ledger, each checked against the publication receipt's pinned per-transaction digest (the publisher, not in this plan's files, discards its own transport receipts)."
  - "The verifier checks page ordinals sequentially (page N>1 must directly follow page N-1 of the same route) because a canary window legitimately repeats page-one requests."
metrics:
  started: 2026-10-15T13:01:01Z
  completed: 2026-10-15T17:08:55Z
  tasks: 3
  files: 7
estimate: {tokens: 44000, tasks: 3}
actuals:
  tokens: 28090
  tasks: 3
  commits: 7
plan_head_before: 5bd8be5e6beddecca49289f1bdada45e6f1c3d30
plan_head_after: f4589eaff07d4728f2157f9e9b46e95e923892f4
---

# Phase 253 Plan 101: Offline canary dry-run gate Summary

There is now an offline gate that runs the whole hosted canary before the clock starts. It runs the real `ci-gate-canary.sh` in a temporary clone (publish-only, then full-pass, then the five remaining scenarios with the cancel and the separate verifier). It uses the real transport, publisher and verifier against a fake GitHub on localhost, and finishes with the verifier's matrix check. The run is synthetic and green: 93 requests, every category within the frozen table, and zero GitHub requests.

The gate earned its keep straight away. Besides the four planned defects, it found eight more driver, transport and verifier defects that would each have stopped the live window. All are fixed and listed below.

## Commits

| Step | Commit | Message |
|---|---|---|
| Task 1 (tracer) | c0dfd1fda | feat(253-101): offline hermetic canary dry-run through the real driver, transport, publisher and verifier |
| Commit C | c5a9fc868 | fix(253-101): run the fresh preflight once per evidence window |
| Commit D | cbbe8c9fd | fix(253-101): mark the evidence halted on every nonzero exit after it exists |
| Task 2 feat | 2e1842b22 | feat(253-101): drive the whole six-scenario canary offline and gap synthetic completion |
| Commit E | 7c754539e | fix(253-101): request-free discovery wait and a first poll after one interval |
| Watch halt (Rule 1) | 471aa153e | fix(253-101): halt when a watch request is refused instead of polling until the clock |
| Task 3 feat | f4589eaff | feat(253-101): GitHub-behaviour models, accounting and reintroduction-patch sensitivity controls |

Ledger base 5bd8be5e6; 7 commits measured before this SUMMARY commit.

## RED → GREEN record

- **Task 1, transport:** 22 RED (15 errors raising `live_allocation_required`, 7 failures), then 33/33 GREEN. One RED assertion was my own mistake: a live allocation with test fields is refused as `allocation_field_rejected` before `test_origin_rejected`. I corrected the expectation.
- **Task 1, runner, against the unchanged driver and verifier:** publish-only passed with 17 requests. Full-pass was rejected at the preflight with `retained response receipts are incomplete`: the publication rows had no evidence receipts. Further GREEN iterations exposed the rest of the defects (see below). Final full-pass run: passed, 33 requests, journal equal to the ledger.
- **Task 1, sensitivity control I1:** with `--driver-from 97665bd2a` (the frozen R7 driver) the run exits 1 with `ci-hosted-transport: invalid_route_parameter: commit_sha must be a full lowercase Git SHA`. It stops at 20 requests with no verifier call and no halted status, the same shape as the real 253-97 halt.
- **Commit C (c5a9fc868):** RED was 2 of 3 new tests failing. The second invocation spent 3 preflight requests and stopped at `category preflight allocation is exhausted`. GREEN 3/3: the second invocation makes zero preflight requests, re-verifies the retained preflight offline, holds exactly one check_runs transaction, and writes the five copies beside the evidence.
- **Commit D (cbbe8c9fd):** RED, on the commit-C driver, was 2/2 failing. An injected check-runs 403 left the evidence without `status: halted`. With an artifact-digest verifier failure the evidence was also not halted, and re-entry went on to spend requests. GREEN 2/2: both are halted with a diagnostic naming the command, route and endpoint, and re-entry is refused with 0 requests.
- **Task 2, completion:** RED was 1 failure, a hermetic canary link reported `accepted`. GREEN: it becomes the gap `synthetic:canary:...` and CIREL-02 stays open.
- **Commit E (7c754539e):** RED, on the commit-D driver, was a Task 3 run of 12 tests with 7 failures. The timing test failed with `dispatch receipt not found for full-pass` under the 3 s visibility model. GREEN: both timing tests pass, with exactly one discovery listing and a first poll at least one interval after the pre-watch rate read.
- **Watch halt (471aa153e):** under the extra-poll accounting model, the commit-E driver kept polling for 26 minutes after the ledger recorded `terminal_polls category_budget_exhausted`. watch_run runs as an if-condition, so errexit and the ERR trap were suspended. GREEN: it halts at once with the budget message and `status: halted`.

## Default green run (final verification run)

- status `passed`, synthetic `true`, freeze_plan `253-91`, verifier `passed` (matrix)
- scenarios (verifier-accepted, in order): full-pass, docs-only, actual-failure, missing-seam, unexpected-skip, cancelled
- requests by category: preflight 5, publication 19, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6, cancellation 1. infrastructure_retry is 0. Every category is within the frozen table (8/24/7/7/7/18/7/7/12/6/1).
- requests_total 93, journal_requests 93. Per invocation: publish-only 17, full-pass 16, remaining 60.
- modeled elapsed time 167 s, with a 3 s visibility delay, a 4 s hermetic discovery wait, a 0.05 s poll interval and polls of 3/3/2/2/2/3/3.

## Sensitivity results (all fail at their named point)

| Control | Exit | Stop |
|---|---|---|
| R7 driver (`--driver-from 97665bd2a`) | 1 | `ci-hosted-transport: invalid_route_parameter: commit_sha must be a full lowercase Git SHA` (preflight 3 requests, no check_runs) |
| check-source-candidate | 1 | `native check-run app/source identity is missing or duplicated: Library tests` |
| errexit-tail | 1 | ERR-trap halt on the `"$case_name" == unexpected-skip ]]` guard line right after the full-pass receipt (evidence halted) |
| preflight-repeat | 1 | `ci-hosted-transport: category_budget_exhausted: category preflight allocation is exhausted` (remaining invocation) |
| halt-unmarked | 1 | `ci-hosted-transport: http_403 ...` with evidence status left null |
| discovery-race | 1 | `dispatch receipt not found for full-pass` |
| create-only (`--seed-legacy-refs`) | 1 | `scoped ref gsd/253-replan-candidate already points to a different commit`; seeded refs unchanged, no create_ref |

Each patch is an exact text substitution written in the test and asserted to apply exactly once.

## Defects found by the gate and fixed (Deviations, Rule 1)

1. **[Transport] Dispatch input metrics were never recorded.** `request_one` read `.get("inputs")` from the serialized bytes rather than from the request dict. The driver would have failed "transmitted dispatch input count differs" on every dispatch. Fixed in c0dfd1fda and pinned by a transport test.
2. **[Driver] Dispatch sent no `workflow_id`,** so the transport refused it before any request with invalid_route_parameter. Fixed in c0dfd1fda.
3. **[Driver] Cancel sent a null body,** which the typed POST route refuses. It now sends `{}`. Fixed in c0dfd1fda.
4. **[Driver] Publication rows had no evidence receipts.** The publisher discards its own transport receipts. They are now derived from the ledger and checked against the receipt's pinned digests. Fixed in c0dfd1fda.
5. **[Transport] Download hops lost their receipts:** only the final hop's receipt survived. `follow_download` now adds `hops` to the receipt; the top-level fields are unchanged for existing readers. Fixed in c0dfd1fda.
6. **[Verifier] Dispatch canonical bytes were compared in sorted-key order.** The ledger is written sorted, while the transmitted body kept its original order. The canonical bytes now come from the transmitted body. Fixed in c0dfd1fda.
7. **[Verifier] Page-ordinal uniqueness rejected every repeated page-one request** (polls, rate reads, per-run listings). It is now a sequential rule. Fixed in c0dfd1fda.
8. **[Driver] `run_attempts` was never written,** so matrix verification could never pass. Fixed in 2e1842b22.
9. **[Driver] The separate verifier re-read its terminal run,** a 19th terminal poll against the frozen 18. Removed in 2e1842b22, since watch_run already captures it.
10. **[Driver] A refused watch request looped until the 60-minute clock** (see 471aa153e above).

Other notes:
- The runner resolves its temp dir, because macOS `/var` is a symlink and the receipt path would otherwise not be repo-relative. The runner has an `--overlay-worktree` test aid that copies uncommitted `scripts/ci` edits into the clone; every run records the paths it overlaid, and the default run tests HEAD exactly.
- The plan said the override refusal would be a "flow test". It lives in `ci-gate-canary-dryrun.test.py`, because `ci-gate-canary-flow.test.py` is not in this plan's files.
- The discovery wait sits at the end of `api_post_dispatch`, which the flow test stubs. This keeps `dispatch_scenario` free of new collaborators.
- `ci-gate-canary-recovery.test.py` needed no change, because its watch tests stub `sleep`.

## Coverage statement

**Covered:** the frozen driver's route mapping and control flow, transport validation and per-category accounting, ledger/receipt/evidence/journal shapes, approval and allocation binding (synthetic stand-ins inside the clone), ref names and dispatch inputs from the freeze, create-only publication, halt marking and the re-entry guard, and acceptance by the real verifier (preflight, every scenario, the matrix).

**Not covered:** real GitHub latency and eventual consistency beyond the modeled delays; whether check runs really exist on the decided commit; real authentication and rate limits; real fixture-workflow runtimes and artifact contents (the honest-skip verdict is modeled, and the verifier job's outcome is modeled by decoding the matrix); and anything after the canary.

## Verification

- The Task 1 and Task 2 `<verify>` blocks exited 0 after their commits. The Task 3 `<verify>` block, run verbatim against HEAD f4589eaff, exited 0. That covers all eight offline suites (dryrun 21 tests, flow 22, `ci-gate-canary.test.sh`, recovery 5, transport 33, verifier 77, publication, `ci-pr-proof.test.sh`) and v1–r7 reconcile `--check-only`, all with exit 0.
- `--require-target-disposition` exits 0 and `--require-target-accepted` exits 3, so CIREL-01 stays partial.
- **Preservation:** no `.planning` file changed in this plan's commits. The R7 pins all match: approval fb6c554c, allocation 72284acc, evidence e5be2150, ledger 48587280, receipt 3aa75308, freeze f608a445, manifest 6813630f, readback-RED d745038c, R7 contract 8b077547, workflow 3c31cb72, 253-97-SUMMARY de6b8ee0. config.json is 8e312f6c and was never staged. state.json is 70229 bytes.
- Zero GitHub requests, no push and no fetch. No state, roadmap or requirements writer was run. `scripts/ci/__pycache__` was deleted after every Python run.
- An earlier full-suite run was interrupted while it looped (the watch-halt defect). I stopped it with SIGINT and removed its one leftover temp dir by literal path.

## Deferred / remaining gaps

- The default runner's `first_poll_delays` (~0.43 s) reflect the 0.05 s test interval. The 2 s timing test is the proof that the first poll waits a full interval.
- R8 freeze identity, the `--ref-pair` publisher option and three-digit plan labels belong to 253-102.
- Full Phase 253 verification stays not_started. The offline gate is an implementation check, not hosted proof.

## Known Stubs

None in product code. The fake models listed above are intentional test doubles.

## Threat Flags

None beyond the plan's register. T-253-203 is mitigated: only explicitly canary-kind hermetic allocations route locally, live routing goes only to api.github.com, the fake refuses credentials, and test overrides are refused with a live allocation (all tested). T-253-204 is mitigated: results carry synthetic true, hermetic-unverified is required, completion records a synthetic gap, and every halt is marked.

## Self-Check: PASSED

- FOUND: scripts/ci/ci-gate-canary-dryrun.py, scripts/ci/ci-gate-canary-dryrun.test.py
- FOUND on HEAD: c0dfd1fda, c5a9fc868, cbbe8c9fd, 2e1842b22, 7c754539e, 471aa153e, f4589eaff
