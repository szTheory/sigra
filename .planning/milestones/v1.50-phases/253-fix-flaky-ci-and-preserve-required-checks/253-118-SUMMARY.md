---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "118"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, audit, response-shape, pr-families, r10]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-117 real-shape canary fakes, fidelity tests and the R10 audit line refresh; 253-116 RunIdentityTests and CanaryBindingTests on EVIDENCE-R9; 253-113 R9 ledger (sha256 9c3d7659...)"
provides:
  - "Response-shape class in the R10 audit record (schema sigra.phase253.hermetic-live-audit/r10): 29 rows, one per non-test ROUTES route plus the canary-fixture and ci.yml workflow sources"
  - "Checker for the class: route completeness against the imported ROUTES, hashed real-sample locators (ledger sequence, JSON pointer, archive member, source file), per-field resolution in real bytes, consumer symbols, real-sample markers on cited tests; 13 positive controls"
  - "PR real-shape tests: ci.yml job inventory after matrix expansion, the expansion rule against GitHub's real job names, the shared attempt/run job schema, check-run to job links, and the canary driver's preflight jq reads on real R9 bodies"
  - "Publication real-shape test on the R9 ledger and receipt"
  - "Real-shape compact matrix test: 34764 characters for six real-derived receipts, margin 29747 under 64511"
affects: ["253-119", "253-120", "253-122", "253-123"]
key-files:
  created: []
  modified:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R10.json
    - scripts/ci/ci-hermetic-live-audit.test.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - scripts/ci/ci-git-publication.test.py
key-decisions:
  - "The Phase 252 bundle (252-CI-SOURCE-BUNDLE.tar.gz, sha256 95334957...) is a committed real sample. It holds GitHub's raw responses for pull_request run 38317383419, including its attempt jobs, run and PR-head check runs, so attempt_jobs, pull_requests[].number and every PR check-run field resolve in real bytes. The plan assumed no PR-shaped sample existed."
  - "A locator that the checker cannot route-check (a JSON pointer or an archive member) must carry route_evidence, which says why it is that route's response. Archive members are also pinned by member_sha256."
  - "A cited test counts as real-shape coverage only if its body, class header, setUp or setUpClass visibly reads committed real bytes (REAL_SAMPLE_MARKER). Like LIVE_MARKER, this is a floor."
  - "Routes with a committed sample are real-shape-test rows, each backed by a test that compares against that sample. justified is used only where no sample exists: cancel_run, run_logs, job_logs, git_create_blob, git_get_tree, pr_create, pr_read, compare and repo_contents."
  - "The ci.yml source sample is sha256-pinned, so any ci.yml change forces the audit to be refreshed and the inventory test to be re-run."
requirements-completed: []
estimate: {tokens: 40000, tasks: 2}
actuals:
  tokens: 31304
  tasks: 2
  commits: 2
commits: 2
plan_head_before: 87d78b1352ec77525a62e66dd0d4652205d25860
plan_head_after: e1ef4f30c5f8fc72c9de9e7e293ec7d70f3377a0
duration: 45min
completed: 2026-10-16
status: complete
---

# Phase 253 Plan 118: response-shape audit class (R10) Summary

**Every GitHub response that the canary and PR proofs compare against is now listed in the R10 audit. Each listed field must either appear in a committed real response (located by sha256-pinned locator) or carry a stated residual risk and the hosted window where it first runs. A checker fails if a route row is missing, a locator points at the wrong place, a field resolves nowhere, or a cited test does not read real bytes. Four new real-source tests cover the PR job inventory against ci.yml, GitHub's real PR job and check shapes, the canary preflight reads and the R9 publication readbacks. A fifth confirms that the hosted verifier's input fits: six receipts derived from the real R9 one compact to 34764 characters, 29747 under the 64511 limit. No GitHub requests were made.**

## Performance

- **Duration:** about 45 min (about 17:00Z to 17:45Z)
- **Tasks:** 2 of 2
- **Files:** 4 modified

## Task commits

1. **Task 1 (tracer): the response-shape class and its checker.** `d009ed608` feat(253-118): response-shape audit class with durable checker
2. **Task 2: real-shape compact matrix test and regression.** `e1ef4f30c` test(253-118): real-shape compact matrix size and round trip for the hosted verifier input

## Task 1

### RED

- The checker functions, positive controls and a skeleton record (schema r10, only the `run` row) were written first.
- `python3 scripts/ci/ci-hermetic-live-audit.test.py` ran 30 tests: exit 1, 24 failures, 0 errors.
- Every failure has the planned cause: the committed-record test and every control's unmutated-copy precondition reported 28 missing rows.
  - 26 of them are `route X has no response-shape row` for artifact_zip, attempt_jobs, branch_protection, cancel_run, check_runs, compare, create_ref, dispatch, get_ref, git_create_blob, git_create_commit, git_create_tree, git_get_blob, git_get_commit, git_get_tree, job_logs, pr_create, pr_read, rate_limit, repo_contents, rules_main, run_artifacts, run_jobs, run_logs, workflow and workflow_runs.
  - The other 2 are the workflow-source ids.
- No import, syntax or fixture errors occurred.

### GREEN

- **All 29 rows enumerated.** The first checker run on the full record then found 19 problems, each a true finding:
  - **One field was absent from the real data.** `[].parameters.required_status_checks[].integration_id` does not appear: GitHub returns `context` only, because all five rules are any-app. That field is now justified per field.
  - **18 cited tests showed no real-sample read**, because they load their real bytes in setUp or setUpClass. The marker rule now also scans the cited test's class fixtures, and `bundle_member(` was added to the marker. No row was weakened.
- **Branch rows, matcher, match_counts and audit_head:** byte-identical to HEAD apart from `schema`, checked with `jq -S` diff.
- **Tracer gate:** after the commit, Task 1's full `<verify>` was re-run on the clean tree: rc 0. Expansion followed.

### Rows: per route and coverage kind

| Route | Families | Coverage | Real samples | Justified fields |
|---|---|---|---|---|
| rate_limit | both | real-shape-test | R9 seq 18, 26; R8 18; R7 18 | none |
| rules_main | both | real-shape-test | R9 19; R8 19; R7 19 | header:link, [].parameters.required_status_checks[].integration_id |
| branch_protection | both | real-shape-test | R9 20; R8 20; R7 20 (all 404) | required_status_checks.contexts, .checks[].context, .checks[].app_id (the 200 body) |
| check_runs | both | real-shape-test | R9 21; R8 21; bundle check-runs.json (PR head) | none |
| workflow | both | real-shape-test | R9 22; R8 22 | none |
| dispatch | canary | real-shape-test | R9 24; R8 24 (204) | meta:dispatch_inputs.matrix_evidence |
| workflow_runs | both | real-shape-test | R9 25; R8 25 | none |
| run | both | real-shape-test | R9 27; R8 27; 38347679431 /run; bundle run.json (pull_request) | none (pull_requests[].number resolves in the bundle run) |
| run_jobs | canary | real-shape-test | R9 28; R8 28; 38347679431 /jobs | none |
| attempt_jobs | pr | real-shape-test | bundle jobs-attempt-1.json | meta:url, meta:page_ordinal |
| run_artifacts | both | real-shape-test | R9 29; R8 29 | none |
| artifact_zip | both | real-shape-test | R9 30 (302), 31 (200); R8 30 (302) | none |
| git_get_commit | both | real-shape-test | R9 1, 6, 10; R8 6 | none |
| git_create_tree | both | real-shape-test | R9 2, 8; R8 2 | none |
| git_create_commit | both | real-shape-test | R9 5, 9; R7 5 | none |
| git_get_blob | both | real-shape-test | R9 7, 11; R8 7 | none |
| get_ref | both | real-shape-test | R9 12 (404), 14, 15 (404), 17; R8 14 | none |
| create_ref | both | real-shape-test | R9 13, 16; R8 13 | none |
| cancel_run | canary | justified | none | meta:actual_status |
| run_logs | canary | justified | none | meta:actual_status, meta:hop_ordinal, header:location.host |
| job_logs | both | justified | none (never requested) | meta:actual_status |
| git_create_blob | both | justified | none (no binary upload in R7-R9) | sha, meta:actual_status |
| git_get_tree | both | justified | none (never requested) | meta:actual_status |
| pr_create | pr | justified | none; nearest: bundle run.json /pull_requests/0 | all 11 fields |
| pr_read | pr | justified | none; nearest: the same | all 12 fields, including merge_commit_sha |
| compare | pr | justified | none; nearest: bundle PR 331 files page | files, files[].filename, ahead_by, behind_by, meta:url, meta:actual_status |
| repo_contents | pr | justified | none; nearest: R9 git_get_blob seq 7 | type, encoding, path, content, sha, meta:url, meta:actual_status |
| workflow-source:canary-fixture | canary | real-shape-test | R9 28 (run_jobs); 38347679431 /jobs; fixture YAML | the two verifier step names and the skipped producer name `producer (${{ matrix.seam }})` |
| workflow-source:ci-yml | pr | real-shape-test | ci.yml (sha256 9773952b...); bundle jobs-attempt-1.json | none |

That is 20 real-shape-test rows and 9 justified rows, with 0 gaps.

### Real-sample files and hashes

| Sample | sha256 |
|---|---|
| 253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json | 9c3d7659981a3be0e2592d09d670e4ab0dfc8084771a8ce51d8d1075a5f34e01 |
| 253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R8.json | b0341dd567f840baad429ae4a683fa9b20ea6cc9aeb0c09e629413db2cc806e8 |
| 253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R7.json | 485872806046b07925a203d21d4bdd7a75cba58c35e4063ef9db96948fe0416f |
| 253-CANARY-FAILED-RUN-38347679431.json | e9062f00250c89f1e49684f6cd4a4bc859077c6b8a307db03902ccbe42ff8a41 |
| 253-LOAD-RECOVERY-CANARY-WORKFLOW.yml | 3c31cb72c3168c4e86a1ea529f16bfdd40b4405551459ca27b9b989cb762df7b |
| .github/workflows/ci.yml | 9773952b78d025c273b056ecf4c65645e4ca344803646cf0d801e5b7d89f2dc5 |
| 252-CI-SOURCE-BUNDLE.tar.gz | 95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30 |
| bundle member ./raw/families/38317383419/jobs-attempt-1.json | c2db679349f5f5b0baad9d2550c939695cf184dcef9e83d1d856c16362c250e0 |
| bundle member .../run.json | 8b8fb94523674dce3624592e905952fe902ad2640134ad9ccbb547927e9ad30b |
| bundle member .../check-runs.json | 16901fc90406e1d2210a08226f6e2661911fc928261141ef2c39941481e8bc2e |
| bundle member .../changed-paths-page-1.json | fb1611bc9b74e60afb24d1065dad7de29883b4c5046b72414c6066771cb9bfb9 |

### Justified fields: residual risk and first hosted window

- **cancel_run** (253-122): no cancel request has ever been sent. If the call fails, the driver stops with "identified canary cancellation failed". If GitHub accepts it but never cancels a job, verify_scenario refuses the receipt. Both are fail-closed, after five source scenarios.
- **run_logs** (253-122): no failure scenario has run live. A redirect to a host outside the frozen download hosts is refused before its socket, and download_no_follow then fails at the first failure scenario.
- **job_logs** (no planned window): never requested; it is typed in ROUTES only.
- **git_create_blob** (only if a candidate carries a binary file): a sha mismatch raises before any tree, commit or ref is created.
- **git_get_tree** (no planned window): never requested.
- **pr_create** (253-123): any field difference fails check_pr right after creation. The window then halts with one open, never-merged draft PR, which the operator must close.
- **pr_read** (253-123): a missing or unchanged merge_commit_sha stops collection or fails "PR has no distinct tested merge commit". Fail-closed after the run.
- **compare** (253-123): missing fields fail "compare file inventory is empty, malformed or incomplete", or fail the docs ahead/behind check.
- **repo_contents** (253-123): a wrong type, encoding, path or blob sha fails "source read is not a base64 file response" or "source blob differs from the frozen blob".
- **rules_main** (any window, only if the ruleset changes):
  - `header:link`: every real page was a single short page. A page of 100 records forces a second charged page, so this is fail-closed.
  - `integration_id`: the real rules are any-app. A rule pinned to an app would be compared against the native check's app id; this has never been observed.
- **branch_protection** (only if classic protection is added): the 200 body has never been observed. A malformed or extra-context body fails at preflight, before dispatch.
- **dispatch** (253-122):
  - `matrix_evidence`: the verifier dispatch has never run live. Its size is now pinned on real-shape receipts.
  - Still open, not loosened: the driver accepts a 202 or 204 dispatch status, but the binding requires 204. Real GitHub returned 204 in R8 and R9.
- **attempt_jobs** (253-123): `meta:url` and `meta:page_ordinal` have no ledger row, because the real body came from the Phase 252 tooling. A mismatch fails "job page is not for the terminal run attempt".
- **workflow-source:canary-fixture** (253-122):
  - The verifier job's two checked step names are in the fixture source but have never been reported by GitHub.
  - The skipped producer name `producer (${{ matrix.seam }})` has never been observed. The nearest real sample is the bundle (sha256 95334957...), member ./raw/families/38317383419/jobs-attempt-1.json (sha256 c2db6793...). It records install_matrix skipped as one job named exactly "Install matrix (flag combinations)", and the bundle records that skip 9 times. The checker verifies this citation through `nearest_real_samples` with `shows`.
  - That sample proves a skipped matrix job is reported once under its literal name. It does not prove how a skipped `${{ matrix.seam }}` renders. A fifth rendering would halt the window after the six scenarios, at the separate verifier ("separate hosted verifier job set is unexpected"), which is fail-closed.

### PR job inventory found in ci.yml (expanded, 30 names)

Release ref guard; Detect docs-only change; Fast checks (milestone/installer/contracts/snapshot/ledger guards); Install golden + idempotency contract (subprocess harness); Library tests shard; Library tests; Library tests (dep-off — Threadline absent); Example unit smoke (ExUnit + ConnTest); Install smoke (fresh phx.new + sigra.install); Upgrade smoke (published source series -> local candidate); Passkeys manual fallback smoke; Install matrix (flag combinations); Install matrix (flag combinations) (--no-passkeys); Install matrix (flag combinations) (--no-organizations); Install matrix (flag combinations) (--no-organizations --no-passkeys); Passkeys opt-out smoke; Example HTTP smoke (boot + curl critical routes); Example Playwright shard (admin_behavior); Example Playwright shard (admin_checkpoints); Example Playwright shard (design_gallery); Example Playwright shard (non_admin_smoke); Example Playwright shard (demo_showcase); Example Playwright smoke (full lifecycle); Generated admin Playwright smoke; ci-gate; Notify on red ci-gate (release-lane-rot); Recapture admin-design baselines (in-CI); Recapture admin-checkpoint baselines (in-CI); Admin eval render + probe (hard signal on push/schedule/dispatch; not in ci-gate); Nightly probe (forced-failure self-test).

- Each of the five REQUIRED_NAMES, the classifier job and the five `Example Playwright shard (seam)` names appears exactly once.
- One `Library tests shard` job exists.
- The classifier job has exactly one step named "Detect docs-only change".
- Negative controls fail as expected:
  - a copy with "Example HTTP smoke" renamed reports "appears 0 times";
  - a duplicated classifier step reports "exactly one step named".
- The expansion rule itself was checked against GitHub's real names in the bundle:
  - per-seam names come from pull_request run 38317383419;
  - the four `Install matrix ...` names come from push run 38146312411; the empty flag gets no suffix.

## Task 2: real-shape compact matrix

- **`test_live_real_shape_compact_matrix_fits_and_round_trips`** (publication test file) builds six receipts from the real R9 full-pass receipt (EVIDENCE-R9, sha256 a3ca8cc0...). Each derived receipt has:
  - its own run, job and artifact ids;
  - the run-name for its scenario;
  - timestamps shifted per scenario;
  - random node ids and runner ids;
  - fresh random archive bytes of the real length (933), with the matching digest.

  Every scenario keeps an archive, which the real cancelled scenario would not, so the measured size is an upper bound.
- **Compact matrix: 34764 characters; limit 64511; margin 29747.** The real R9 full-pass receipt alone compacts to 7300 characters. The 253-117 fake-receipt figure was 15720.
- The real receipt round-trips through compact_matrix, the verifier's decode_matrix_payload and `verify_scenario("full-pass")`, which returns verified for run 38906314106.
- **Negative control:** the six receipts padded with incompressible bytes raise `PublicationError: compact matrix payload is N characters; the dispatch input cap is 65535 ...`.
- The test passed on first run: the hosted verifier's input was within the cap and verified after compaction, so there was no product defect and no halt. The dispatch and canary-fixture rows cite it.

### Task 2 `<verify>`: full offline regression (rc 0, under `caffeinate -i -s`, 17:37Z to 17:44Z)

| Check | Result |
|---|---|
| ci-hermetic-live-audit.test.py | 30 OK (was 14) |
| no gap rows (branch and response-shape) | jq true |
| ci-hosted-gate-verify.test.py | 117 OK (was 112) |
| ci-git-publication.test.py | 78 OK (was 76) |
| ci-hosted-transport.test.py | 59 OK |
| ci-gate-canary-flow.test.py | 22 OK |
| ci-pr-proof.test.sh | 59 OK |
| `--require-target-disposition` / `--require-target-accepted` | exit 0 / exit 3 (unchanged) |
| v1 and r2-r9 reconcile `--check-only` | all exit 0 |
| PRESERVATION-R10 checklist (62 lines) | `shasum -c` rc 0 |
| config.json sha256, state.json size, clean tree | 8e312f6c..., 70229 bytes, only ` M .planning/config.json` |

The dry-run suite (42 min) is not in this plan's verify list and was not run. This plan changed no dry-run or product file.

## RED/GREEN counts

- Task 1 RED: 30 tests, 24 failing on the planned "no response-shape row" reason. GREEN: 30 OK.
- The new verifier tests (5) and publication tests (2) pin existing behaviour against real bytes, so they were expected to pass and did pass first time. The one exception was a test-construction fault in a draft, fixed before commit: a draft check-run key-set assertion compared against R9, whose check runs carry `deployment`. It now asserts the fields the verifier reads.

## Deviations from Plan

1. **[Rule 2 - Missing critical] The Phase 252 bundle is used as a real sample.**
   - The plan said no pull_request sample existed, and that pull_requests[].number and attempt_jobs would be justified.
   - The committed bundle holds GitHub's raw responses for pull_request run 38317383419.
   - With it, pull_requests[].number resolves. attempt_jobs became a real-shape-test row: `test_live_attempt_jobs_and_run_jobs_share_one_job_schema_in_real_responses` proves the plan's "shared job schema" justification on real bytes, with identical job, step and document key sets to R9 seq 28. Its URL and page ordinal stay justified.
   - This is stronger than the plan, not looser.
2. **[Rule 2] Extra real-shape tests where the plan expected existing ones.** The plan expected existing preflight and publication tests that read committed R8/R9 rows; none existed for rate_limit, workflow or the publication routes. Rather than mark routes that have committed samples as justified, three tests were added:
   - `test_live_r9_preflight_responses_satisfy_the_canary_driver_reads` runs the canary driver's exact jq reads on R9 seq 18-22. It asserts each expression is still verbatim in ci-gate-canary.sh, and has a negative control.
   - `test_live_real_pr_check_runs_link_each_required_check_to_its_attempt_job`.
   - `RealPublicationShapeTests.test_live_r9_real_publication_ledger_proves_every_receipt_identity_and_readback_field` (with a negative control), committed with Task 1 although the publication test file is Task 2's.
3. **Checker extensions beyond the plan's list, all tighter:**
   - archive-member locators (member_sha256 and route_evidence);
   - source samples and `value:` / `source:` fields;
   - consumer-symbol existence;
   - nearest_real_samples with `shows`;
   - a refusal when a justified field actually resolves.

   Controls were added for an added transport route, a status mismatch, changed sample bytes, a consumer symbol and a hermetic-only test cited as real-shape coverage.
4. **The real-sample marker counts the cited test's own setUp and setUpClass** (see GREEN). Without this, tests that load real bytes in class fixtures (CanaryBindingTests, RealPublicationShapeTests, the dry-run ResponseShapeTests) could not be cited.

**Not done by design:** STATE, ROADMAP and REQUIREMENTS writer steps were skipped per the orchestrator's hard constraints. config.json and state.json are untouched.

## Remaining gaps / handoff

- The 9 justified rows above are the known residual risks for 253-122 (cancel_run, run_logs, verifier-run job names and steps, matrix_evidence dispatch) and 253-123 (pr_create, pr_read, compare, repo_contents, attempt_jobs URL).
- The driver accepts a 202 or 204 dispatch status, but the binding requires 204. This is still open and was not loosened.
- **ci.yml is sha256-pinned in the audit:** any ci.yml edit must refresh the ci-yml row's sha256 and re-run the inventory test. The fixture YAML, ledgers and bundle are pinned the same way.
- **253-119 edits product files the audit reads.** The branch-row line numbers, match_counts and consumer symbols must stay current, and the checker will name any drift.
- FREEZE-R9 still does not validate the tree. 253-120 cuts FREEZE-R10.
- CIREL-02 stays open. Full Phase 253 verification stays not_started.

## Known Stubs

None.

## Threat Flags

None. The changes are an audit record and tests, with no network, endpoint or product change.

## Self-Check: PASSED

- All four modified files exist.
- `d009ed608` and `e1ef4f30c` are ancestors of HEAD, and `git rev-list --count 87d78b135..HEAD` = 2 (before this SUMMARY's commit).
- Each RED preceded its GREEN.
- No `scripts/ci/__pycache__` remains, and `git status` showed only ` M .planning/config.json` after the regression.
