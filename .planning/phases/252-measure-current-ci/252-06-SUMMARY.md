---
phase: 252-measure-current-ci
plan: 06
subsystem: ci-measurement
tags: [github-actions, ci, timing, comparison]
requires: [252-05]
provides: [source-bound-current-baseline, immutable-hosted-evidence, matched-comparison-contract, reproducible-baseline-report]
affects: [252, 253, 254]
tech-stack:
  added: []
  patterns: [offline-source-bundle-replay, measured-versus-configured-runtime-identity, matched-cache-strata]
key-files:
  created:
    - scripts/ci/ci-run-metrics-comparison.test.sh
    - scripts/ci/exunit_timing_contract.py
    - scripts/ci/exunit_timing_contract_test.py
    - scripts/ci/ci-measure-report.sh
    - scripts/ci/ci-measure-report.test.sh
    - scripts/ci/ci_metrics_security.py
    - scripts/ci/ci-metrics-security.test.py
    - .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz
    - .planning/phases/252-measure-current-ci/252-BASELINE.json
    - .planning/phases/252-measure-current-ci/252-BASELINE.md
    - .planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json
    - .planning/phases/252-measure-current-ci/252-06-STATE-PRESERVATION.json
    - .planning/phases/252-measure-current-ci/252-06-SECURITY-REFRESH-PRESERVATION.json
    - .planning/phases/252-measure-current-ci/252-06-ACQUISITION-ATTEMPTS.json
    - .planning/phases/252-measure-current-ci/acquisition-attempts/
    - .planning/phases/252-measure-current-ci/252-06-SECURITY-REFRESH-PRESERVATION-72c71eb.json
  modified:
    - scripts/ci/ci-exunit-timing.test.sh
    - scripts/ci/sigra-dep-off.sh
    - scripts/ci/test-sigra-dep-off.sh
    - test/sigra/planning/ci_timing_formatter_test.exs
    - test/support/ci_timing_formatter.ex
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci-run-metrics.test.sh
    - scripts/ci/ci-run-metrics-replay.test.mjs
    - scripts/ci/ci-run-metrics-comparison.test.sh
    - scripts/ci/ci-metrics-security.test.py
    - scripts/ci/ci_metrics_security.py
    - scripts/ci/ci-measure-report.sh
    - scripts/ci/ci-measure-report.test.sh
    - .github/workflows/ci.yml
    - .planning/phases/252-measure-current-ci/252-06-SUMMARY.md
decisions:
  - Preserve the first ECR container-pull failure and its attempt cost; use only one diagnosed infrastructure retry.
  - Freeze the 20-pair method and measured cache stratum now, then predeclare candidate identity and exact UTC dates before any later comparison run.
  - Keep Playwright reporter overhead null because same-selection paired runs were not recorded.
metrics:
  duration: 84 minutes
  completed_date: 2026-10-12
  plan_head_before: 399f80d8c2f17120117d729a75d3e57f099ec9dc
  plan_head_after: 72b6a3ead036ab8ec3cedb422b279a40ca86e285
  commits: 57
actuals:
  tokens: 8676277
  tasks: 3
  commits: 57
status: complete
---

# Phase 252 Plan 06: Hosted baseline, reproducible report and comparison contract

The bounded source bundle now replays into a validated CI baseline, the report distinguishes wait from runner cost, and the later 20-pair comparison method is frozen against the measured hosted PR identity and cache vector.

## Tasks completed

| Task | Result | Commit |
| --- | --- | --- |
| 1. Capture a fresh bounded hosted snapshot and prove offline replay | Complete; source bundle and baseline are committed and hash-validated. | `a071875c7` |
| 2. Freeze the later matched comparison and test all outcome arithmetic | Complete; 20 pairs/40 families, one source-backed cache stratum, exact baseline revisions and fail-closed evaluator are recorded. | `45f3dcb61` |
| 3. Render a reproducible report with one-command replay instructions | Complete; report names event populations, provenance, costs, unknowns and reproduction commands. | `fa2d151e5` |

The implementation fixes were committed separately: `1c7bd817a`, `8bd4d6392`, `b26243c3a`, `b5d1632e6`, `e40889292`, `a76bfd85c`, `2ecbb09dd`, `eb4615dc3`, `2d548f967`, `0461f3118`, `9e882feab`, `dc7ff1965`, `15248bfba`, `705558fe5`, `34ab7d50b`, `ae864e5dc`, and `b9bb12907`.

The plan-state SDK transition was committed and byte-verified at `2c50a2a213a7ca52f2733e694e4b8bc4a630796f` before the handoff text and next route were curated. File hashes and the preserved bytes' original clean-state hashes are in `252-06-STATE-PRESERVATION.json`.

## Hosted evidence

Draft evidence PR [#331](https://github.com/szTheory/sigra/pull/331) produced workflow run [38307191464](https://github.com/szTheory/sigra/actions/runs/38307191464). Its five required checks passed on attempt 2: Library tests; Example unit smoke (ExUnit + ConnTest); Install smoke (fresh phx.new + sigra.install); Example HTTP smoke (boot + curl critical routes); and Example Playwright smoke (full lifecycle). The browser jobs reported Playwright 1.59.1. The PR remains a non-publishing draft; it was not merged.

Attempt 1 failed before Example unit tests began because PostgreSQL container pulls from public ECR hit `Data limit exceeded` on three pulls. Attempt 2 succeeded. The report retains attempt 1's 2,147 runner seconds and the 23-second failed unit-job setup, plus attempt 2's 2,178 runner seconds; total runner cost is 4,325 seconds. No failed attempt was replaced or omitted.

The immutable source bundle digest is `169e5425870bd4486b0c7c6a07a4fd2c938c363fb7c156ffac27f4220f7426f0`. The measured app/workflow revision is `0e15a5713da5aeeec5a81110970011d76486eae1`; its producer jobs checked out merge source `dc94d895317a91e164aa29d47135710641008814`. The workflow file digest is `d5dcdb22303ed7426fc3d597fa47b5c9401fa80f7a5501fdc472ac01642049f6`; the separate measured workload digest is `682515c962a366c31e8c6acada380d58294976d8282ca2d7b081d26c530191db`.

At the fixed cutoff `2026-10-12T21:04:28Z`, the collector selected 100 of 267 pull-request runs (capped), all 81 main-push runs and all 30 scheduled runs. The source-bound full PR sample completed all five required contexts in 594 seconds. It records 1,470 seconds across the six timing producer jobs, ExUnit test time of 188,522 microseconds and Playwright test time of 881,789 milliseconds. The measured cache vector had hits for library dependencies and for example dependencies and browser binaries across all five Playwright seams. The observed runner was Linux X64 on `ubuntu24`, image `20261004.327.1`.

ExUnit's separate five-pair historical overhead measurement remains `-60,547µs` by its saved median method. The current hosted run has no paired uninstrumented sample, and Playwright overhead remains `null` with reason `paired_same_selection_runs_not_recorded`. No overhead estimate is subtracted from later improvement targets. Pure queue time and dependency edges remain unknown where the saved API does not expose them; configured runtime pins stay separate from command-observed versions.

The comparison contract fixes 20 equivalent pairs, 40 primary families, nearest-rank `ceil(0.95*n)` p95 (the 19th sorted value at n=20), the 20% median target, non-increasing p95 and total runner cost, one diagnosed infrastructure retry per original family, and no replacement families or window extension. Its cache allocation assigns all 20 pairs to the only observed full-PR cache vector. Candidate revision and exact UTC dates are intentionally unset; they must be frozen before the first later comparison run. No comparison runs were launched in this plan.

## Deviations from plan

**1. [Rule 2 - Missing critical workflow output] Create the ExUnit timing destination before CI.**

- **Found during:** Hosted full-PR CI.
- **Issue:** The ExUnit producer writes `test-results/ci-exunit-timing.json`, but the workflow did not create `test-results` before `mix ci`.
- **Fix:** Add a directory-creation step and an ordering assertion to the existing workflow contract test. Apply the same repair to the local implementation and scoped evidence PR.
- **Files modified:** `.github/workflows/ci.yml`, `scripts/ci/ci-measure-workflow.test.mjs`.
- **Commit:** `2ecbb09dd` (local implementation; evidence PR carries its own corresponding commit).

**2. [Rule 1 - Replay portability bug] Resolve artifact members from their verified family IDs.**

- **Found during:** Archive replay.
- **Issue:** Collected artifact-member paths named the temporary staging directory, which is absent after the bundle moves.
- **Fix:** Replay resolves members under the family directory using the source-verified numeric artifact ID.
- **Files modified:** `scripts/ci/ci-run-metrics.sh`.
- **Commit:** `705558fe5`.

**3. [Rule 1 - macOS temporary-path bug] Canonicalize extraction paths before invoking Node.**

- **Found during:** Offline replay through the normal repository command.
- **Issue:** macOS's `/var/folders` temporary path alias prevented the Playwright normalizer's CLI entrypoint check from matching, so Node exited without producing normalized output.
- **Fix:** Canonicalize the temporary extraction directory before replay and baseline verification.
- **Files modified:** `scripts/ci/ci-run-metrics.sh`.
- **Commit:** `705558fe5`.

**4. [Rule 1 - Verification output bug] Force JSON output inside baseline verification and comparison evaluation.**

- **Found during:** Running the documented verification command without `--format json`.
- **Issue:** Internal replay inherited the default table format and could not be compared as structured baseline data.
- **Fix:** Make these validator paths request JSON internally; require the baseline to contain the exact source archive SHA-256.
- **Files modified:** `scripts/ci/ci-run-metrics.sh`.
- **Commits:** `dc7ff1965`, `705558fe5`.

**5. [Hosted infrastructure retry] Preserve the failed attempt and its cost.**

- **Found during:** Run 38307191464, attempt 1.
- **Issue:** Public ECR rejected PostgreSQL pulls due to its data-transfer limit; test setup did not start.
- **Fix:** Used one retry after recording the failed attempt and diagnosing the external pull limit. Attempt 2 passed.
- **Files modified:** None.

**6. [TDD evidence gap] The task-level RED/GREEN/REFACTOR sequence was not preserved as separate commits.**

- The report and comparison tests pass, but implementation commits preceded a separately committed failing-test (RED) record for these task-level changes. This is recorded as an execution-process deviation; no retroactive RED evidence is claimed.

## Validation

- `bash scripts/ci/ci-run-metrics.test.sh` — 39 passed, 0 failed.
- `bash scripts/ci/ci-run-metrics-comparison.test.sh` — passed, including 20-pair arithmetic, median 10.5 and p95 19 for the synthetic 1–20 fixture, insufficient-data handling and cache-allocation mismatch.
- `bash scripts/ci/ci-measure-report.test.sh` — passed; repeated report generation is byte-identical.
- `node --test scripts/ci/ci-measure-workflow.test.mjs` — 4 passed.
- `bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json` — `ready`, no diagnostics.
- Two `--replay` invocations over the committed archive were byte-identical; `bash -n` and `git diff --check` passed.

## Self-Check: PASSED

The source bundle, JSON baseline, report, comparison contract and all 20 plan commits exist on the expected branch. The baseline verifies against the committed bundle digest and offline replay is deterministic.

## Next

Plan 252-06 implementation is complete. Phase 252 remains pending phase-level verification; its requirements stay unchecked until that verification is recorded. Continue with `$gsd-execute-phase 252` for the phase verification/closeout workflow; do not start Phase 253 in this plan.

## Measurement repair correction (2026-10-12)

The earlier hosted evidence section above records the initial source-bound run, but its 65-row ExUnit artifact was the dependency-off child invocation. That artifact was incorrectly described as the primary suite measurement. The independent Phase 252 validation audit identified this as a blocker. The old bundle and baseline bytes were preserved and read back in `252-06-REPAIR-PRESERVATION.json` before the refreshed evidence replaced them. The corrected evidence below supersedes the old ExUnit timing claim while retaining the old run, diagnostics, and costs as history.

Draft evidence PR [#331](https://github.com/szTheory/sigra/pull/331) now points to `d4dcc1939bd1f1590f6ca01d55b861e31acc745f`; the successful full-PR workflow run is [38317383419](https://github.com/szTheory/sigra/actions/runs/38317383419), attempt 1. All five required contexts passed, and the browser jobs observed Playwright 1.59.1. Its measured application/workflow revision is `d4dcc1939bd1f1590f6ca01d55b861e31acc745f`; the timing producer checked out source `cc8cd273bfe8bbbfbab6b33564efdede4d9f0d17`. The source-backed workflow file SHA-256 is `42f2205d651969ca4dd1e7fb14a8d30525c03bb73decbd282069d76a7319dc16`, verified against GitHub tree blob `20fe1218f8cc075ddb146e8b627bfde25ae1ea2f`. The six-file workload identity SHA-256 is `2f4ece52eb21e9a065a61a943036c88632a2b93b33117db6d992b18b93ca06aa`.

The corrected library artifact `11777372344` contains both invocation reports. The main `mix ci` suite records 2,683 rows: 2,671 passed, 12 skipped, 22 excluded, zero failed, 18,811,928µs summed test duration and 11,404,623µs suite elapsed time. Its separate `threadline_guard` child records 65 rows: 65 passed, 2,640 excluded, zero failed, 129,529µs summed test duration and 6,875,354µs suite elapsed time. Duplicate test identities remain scoped by invocation. The baseline includes both durations (18,941,457µs total) without merging or overwriting reports. Total runner cost is 2,042 seconds, including 1,358 seconds across timing producer jobs; Playwright test time is 798,348ms. Cache results were hits for library dependencies and for example dependencies and browser binaries in all five Playwright seams. The current ExUnit overhead remains unmeasured (`null`) for the single instrumented run; historical five-pair ExUnit overhead remains `-60,547µs`. Playwright reporter overhead remains unmeasured with the saved reason `paired_same_selection_runs_not_recorded`.

The two earlier failed PR attempts remain in the immutable source bundle and are not counted as retries of the successful source revision: run [38314896976](https://github.com/szTheory/sigra/actions/runs/38314896976), head `daa0f6fc43b5af97dae662231ddd903fcc0deeef`, failed fast checks and library timing checks (2,162 summed job seconds by saved start/end timestamps); run [38316396580](https://github.com/szTheory/sigra/actions/runs/38316396580), head `0f2462fffd02361eea9a0cd7d49657f58b00a2ab`, failed fast checks and the `demo_showcase` shard after a public ECR data-limit failure (1,939 summed job seconds). The successful corrected run is preserved separately at 2,042 seconds. The full attempt/run records and captured failure logs are retained in the source archive.

The refreshed collection cutoff is `2026-10-12T22:41:22Z`: 125 API requests, 100 of 270 pull-request runs selected (capped), all 81 main pushes and all 30 scheduled runs. Bundle SHA-256 is `5478c3337881eac2285764d57f35fe103191cb5eea1814fc3dd8b36357758d29`; baseline SHA-256 is `45029a440b8c00fb9aca6ad9b5ae427c443e5736bb7ae1164c44a5ce4caf0376`; report SHA-256 is `5bb582b266e7d2f2ccedd01c4b749939ae13c0d1430ce85cec5037c9c713413a`; comparison contract SHA-256 is `c485b54ace77d9bfa871261889e40b6c52ea0c21c0db7ef9e20b2ca468a9193f`. Two offline replays were byte-identical (`a8661ab14c1ee8ff8dca74edae321e2d1f589d4592b579c181b2a24ea22d67de`), and the archive-backed baseline verifier returned `ready` with no diagnostics. The frozen contract still requires 20 equivalent pairs/40 families over a fixed 48-hour window, 20% median improvement, non-increasing nearest-rank p95 and total runner cost; no comparison families were run. Candidate identity and actual window dates remain unset until before the later comparison starts. Requirements remain pending phase-level verification.

Repair verification also passed `python3 scripts/ci/exunit_timing_contract_test.py` (5 tests), `bash scripts/ci/ci-run-metrics.test.sh`, `bash scripts/ci/ci-run-metrics-comparison.test.sh`, `bash scripts/ci/ci-measure-report.test.sh`, and `node --test scripts/ci/ci-run-metrics-replay.test.mjs scripts/ci/ci-measure-workflow.test.mjs` (5 tests). The local forced-compile `MIX_ENV=test mix ci` run passed with 2,652 main tests, 33 doctests, 3 properties, zero failures, and a separate 65-test dependency-off run. Earlier hosted failures and the local retry race/cache-permission diagnostics remain preserved; this repair does not waive them.

## Security remediation correction (2026-10-12)

The independent audit identified eleven open controls. The implementation changes below address the findings with adversarial tests; the parent security auditor will recheck the controls separately. The security register and audit files remain unchanged until that re-audit.

| Findings | Implemented control | Verification |
| --- | --- | --- |
| T-252-01, T-252-13 | Required check runs bind to run ID, attempt, job ID, head SHA, GitHub Actions app, and completion result. | Wrong-attempt and wrong-check-ID fixtures fail closed. |
| T-252-02 | Source hashes cover PR, main, schedule, manual and release populations; accepted artifact JSON members are hash-checked against the saved ZIP and consumed extraction bytes. | Population-tampering and ZIP-member mismatch fixtures; strict archive replay. |
| T-252-06, T-252-15 | Failed-log download is capped at 1 MiB; retained excerpts are capped at 16 KiB and redact environment assignments/dumps, credentials, bearer values and URLs. | Oversized-log, environment-secret and useful-diagnostic fixtures. |
| T-252-07 | Every API request and retry debits the locally observed core budget; refreshes can lower the remaining count. | A starting budget of 251 permits one read, then stops at 250; 403/429 is not retried. |
| T-252-08 | ExUnit reports require both identified invocations, rows, valid result enums and microsecond units; counts and duration totals reconcile, including excluded rows. | Eight consumer contract tests reject empty, wrong-identity, negative, invalid-enum and mismatched-count reports. |
| T-252-12, T-252-16 | Producer artifacts bind to the API run, job attempt, exact artifact owner/name, successful upload step interval, producer merge commit parents, PR head/base and workflow tree/blob bytes. | Producer binding and source-provenance fixtures; independently collected GitHub source facts for run 38317383419. |
| T-252-17 | Comparison families bind to a frozen reservation and append-only, hash-chained API run registration; each run must be created inside the exact declared window. | Run substitution, out-of-window timestamp, duplicate registration and chain tampering fixtures. |
| T-252-19 | Report URLs use a strict GitHub path allowlist; prose is escaped and redacted, including unsafe links and Markdown payloads. | Adversarial Markdown/URL fixture; report retains the PR population SHA-256 digest. |

The security repair commits are `282091eaa` (source bindings, hashes, bounded diagnostics, report safety and ExUnit validation), `362c84008` (immutable comparison registrations and source acquisition), `0cdc4e40f` (independent producer-source API collection), `a97017e50` (report identity digest preservation), `654f771bf` (artifact repository-owner binding), and `c97bf641e` (register comparison runs while queued or in progress, before a conclusion exists). All five focused suites pass: 10 security fixtures, 8 ExUnit contract tests, 41 collector tests, comparison fixtures, and report fixtures. The contract suite exercises exact 20-pair median/p95 and runner-cost enforcement; no comparison runs were launched.

### Refreshed source proof and retained acquisition attempts

The bounded population attempt `security-window-20261012-01` stopped after 68 API requests because one failed-log download was unavailable. The distinct retry acquisition `security-window-20261012-02` completed after 97 requests and retained the capped populations (264 PR events/100 selected, 10 manual records and 38 release records), but did not contain a fully bound instrumented artifact sample: the candidate artifact evidence hash did not match. Both ledgers, manifest hashes and outcomes are retained in `252-06-ACQUISITION-ATTEMPTS.json`; neither attempt is represented as a successful full baseline.

For run 38317383419, a separate five-request GitHub source collection verified PR #331 head `d4dcc1939bd1f1590f6ca01d55b861e31acc745f`, base `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97`, producer merge checkout `cc8cd273bfe8bbbfbab6b33564efdede4d9f0d17`, and the exact workflow blob. Reproduce that source check with `bash scripts/ci/ci-run-metrics.sh --collect-producer-source --source-bundle /private/tmp/phase252-06-producer-source-38317383419 --producer-source-sha cc8cd273bfe8bbbfbab6b33564efdede4d9f0d17 --run-id 38317383419`. Strict offline replay also verifies each accepted artifact ZIP and every consumed JSON member. The resulting archive SHA-256 is `e0e662a8e546c95386651a33407341b23046524d50083eb740d1b2689e37640a`; baseline SHA-256 is `a70f1f1dd41568d4977a9847c3908a9526bc593d6680f97e6079939da0b023e5`; report SHA-256 is `1dd28ed10fe7605cd52526cc5d1de0739530dd05d30693ef4ea9f5ed84b90a3d`. Archive-backed `--verify-baseline` returns `ready` with no diagnostics.

The corrected sample has 2,042 seconds total runner cost across one attempt, 1,358 seconds in timing producer jobs, main ExUnit 2,683 rows (2,671 passed, 12 skipped, 22 excluded), and `threadline_guard` 65 rows (65 passed, 2,640 excluded). Test durations remain separate at 18,811,928µs and 129,529µs. Playwright test duration is 798,348ms; reporter overhead remains explicitly unmeasured because paired selections were not recorded. Run 38317383419 has no rerun attempts, so its runner-job set contains no reused physical job IDs. The earlier failure records and 4,325-second attempt history remain in the prior sections and preserved archive history.

The original archive, baseline, report, comparison contract and summary bytes were read from and matched against HEAD `0cdc4e40f` before refresh; exact hashes and recovery ref are committed in `252-06-SECURITY-REFRESH-PRESERVATION.json` at `6b3990d0b`. The comparison still has no candidate identity, dates or future family IDs. Its 20-pair/40-family, exact 48-hour, no-replacement method stays frozen, while no 40-run comparison has been performed.

No new producer change was needed, so PR #331 was not modified and no new CI run was dispatched. Requirements remain pending phase-level verification; independent security re-audit remains outstanding.

## Security refresh self-check: PASSED

The refreshed source bundle, baseline, report, comparison contract, acquisition ledger, durable request ledgers and write-ahead preservation record exist. Commits `282091eaa`, `362c84008`, `0cdc4e40f`, `a97017e50`, `654f771bf`, `c97bf641e` and `cae9eb2f8` are ancestors of the current branch. The refreshed archive replays byte-identically and archive-backed baseline verification returns `ready` with no diagnostics. Phase verification and independent security re-audit are still pending.

## Independent security re-audit repair correction (2026-10-12)

The subsequent independent audit found ten remaining gaps in alternate replay and comparison paths. The repairs below supersede the earlier security-table claims where they conflict. The security auditor still needs to recheck the implementation; no finding is self-closed here.

| Findings | Repair | Behavioral evidence |
| --- | --- | --- |
| T01 | Family replay binds each API run to exactly one saved population row and checks its repository, run, attempt, expected attempt-jobs request, and check-run-to-physical-job graph. | Collector fixtures reject an unbound check ID and verify all five required context/job links. |
| T02 | Every retained changed-path page has an exact path and SHA-256 in its family manifest, and its page URL must exist in the hashed API request ledger. | Missing, extra, modified, and unrequested page fixtures fail closed; refreshed archive replays offline. |
| T06/T15 | Bounded failure-log redaction strips shell trace prefixes and `export`/`declare` assignments, removes environment dumps and arbitrary assignments, redacts credentials and URLs, and caps input/output bytes. | Trace-prefixed AWS secrets, exported values, declarations, environment dumps, large logs and useful diagnosis lines are covered. |
| T08 | Both generic and selected-sample ExUnit readers require validated main and child invocation identities, valid result enums, integer/nonnegative counts, row/count reconciliation, and microsecond duration units. | Twelve security fixtures and eight ExUnit consumer tests pass; missing or empty main/child reports cannot count as complete timing. |
| T12 | Generic timing rows are accepted only through the same full source-bound producer validator: API artifact owner/name, run/attempt/head, successful upload step/time, producer source and artifact-member bytes. | The old unbound generic timing path is now unknown; the selected PR's both-invocation reports remain accepted through the verified archive. |
| T13 | Every ranking row must carry the requested API run ID, attempt, head SHA, repository identity, and numeric physical job ID. | Generic ranking fixture includes the authenticated identity; absent or mismatched identity is rejected. |
| T16 | Workflow bytes are accepted only when the commit's `commit.tree.sha` equals the retrieved tree SHA and that tree binds the exact workflow blob bytes. | A commit/tree SHA mismatch fixture is rejected. |
| T17 | Contract baseline archive SHA must equal the immutable archive supplied to evaluation. Every queued-run registration retains the exact API response bytes in a hash-chained record, and the evaluator checks them against reservation, run ID, head, event, null outcome, and the fixed 48-hour window. | Baseline digest mismatch, changed response bytes, changed run ID, duplicate reservation, altered chain and out-of-window fixtures fail. Candidate/window/future family IDs remain pending; no comparison runs started. |
| T19 | Failure-log replay reads only the canonical contained path whose bytes match the saved hash. Report prose escapes Markdown delimiters and only links canonical GitHub repository URLs. | Traversal, alternate path, wrong hash, JavaScript/protocol-relative Markdown links, injected links and unsafe URL fixtures are rejected or rendered inert. |

The repair commits are `e942dc76d` (shared security validators, collector/replay/report enforcement and adversarial tests), `a7932e425` (refreshed source archive, baseline, report and contract), and `72b6a3ead` (generic ranking fixture with required identity fields). The old evidence was verified byte-for-byte against the durable preservation record before refresh at `1a83fe30e`; it remains recoverable there.

The current archive SHA-256 is `95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30`; baseline SHA-256 is `f397a4624c1a18e5418795b00b3e7510fab34bd858f9540f2f76f2c386319843`; report SHA-256 is `7d0f7fff31b0a266ecc0c76853f8e6a98a193860c97ddea866bca1c3f6018237`; contract SHA-256 is `8d3d0d991eff2955b9d8e29bd845df1d848150352ef808984350b801ed018d6c`. The comparison contract now records this exact archive digest and the prior digest used before the security refresh. Two replay outputs have identical SHA-256 `0e047cb23f8c33e4aa41cb03da7fc6043f46047ed49e26842f80d58b4501643a`; `--verify-baseline` returns `ready` with no diagnostics.

Final focused checks: `python3 scripts/ci/ci-metrics-security.test.py` (12 passed), `python3 scripts/ci/exunit_timing_contract_test.py` (8 passed), `bash scripts/ci/ci-run-metrics.test.sh` (41 passed), `bash scripts/ci/ci-run-metrics-comparison.test.sh`, `bash scripts/ci/ci-measure-report.test.sh`, and `node --test scripts/ci/ci-run-metrics-replay.test.mjs scripts/ci/ci-measure-workflow.test.mjs` (5 passed). Shell syntax checks and `git diff --check` pass. No hosted run or comparison family was started because producer source did not change and no comparison is authorized in this phase. Requirements remain pending phase verification, and the parent security auditor must perform the independent re-audit.

## Final security refresh self-check: PASSED

The current archive, baseline, report and contract hashes above match disk; the source archive reproduces the baseline byte-for-byte and strict baseline verification passes. Commits `e942dc76d`, `a7932e425` and `72b6a3ead` are on the authorized `phase-244-playwright-measurement` branch. The only remaining action is the independent security audit and phase-level verification; this summary does not claim either has passed.
