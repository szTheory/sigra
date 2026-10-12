---
phase: "252"
slug: "measure-current-ci"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-12"
---

# Phase 252 — Validation Strategy

All 15 task checks now have passing automated evidence. The three items previously escalated for ExUnit report scope pass against the corrected source-bound artifact and collector contract. Phase-level verification and requirements remain pending. The prior clean draft is recoverable at commit `dd38b5bbe6a979fc7b0ede8ce919ee196551df82` (SHA-256 `5f67bceacbacf8210834c73f516a6d1fe36e3ec6a7fbf41ecde8d24c44f2e43d`).

The exact eight Phase 252 plan/validation/coverage files before this checker revision remain recoverable at commit `bf0e88cd23ce23095d804aa8fce39c9e95d35398`; their paths, clean statuses, byte counts and SHA-256 identities were rechecked against `/private/tmp/sigra-phase252-plan/revision-prewrite.json` before replacement.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Existing hermetic Bash tests, ExUnit, built-in Playwright JSON, workflow contract tests |
| Config files | `mix.exs`, `test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts` |
| Quick command | `bash scripts/ci/ci-run-metrics.test.sh` |
| Full library command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci` |
| Browser validation | Use the five literal selections already present in `ci.yml`, existing boot/readiness and isolated databases/ports; keep one worker and zero retries. |
| Feedback budget | Quick contracts target under 30 seconds after warm preparation; this is a target, not measured duration. Hosted checks retain their existing timeout ceilings. |

## Sampling Rate

- After a collector/report task, run its hermetic self-test and check the output includes exercised fixtures.
- After an instrumentation task, run its focused contract and the affected existing test path. Preserve the original test exit status when report writing or validation fails.
- After a wave, run the affected subsystem checks. Run full `mix ci` after library instrumentation and the five existing browser selections after hosted integration; avoid unrelated repeats after passing checks.
- Before phase verification, replay the retained baseline offline, validate source identities/completeness, and inspect the producing hosted run. Missing hosted inputs remain diagnostic gaps.
- Every task has an automated verification command and an adjacent observable failure condition. No human UAT or blanket approval is required.

## Per-Task Verification Map

| Plan/task | Requirement | Automated verification | Coverage required | Status |
|---|---|---|---|
| 252-01 Task 1 | CIMEAS-01, CIMEAS-02 | `jq -e '(.status == "ready" or .status == "blocked") and (.request_count != null) and (if .status == "blocked" then (.missing_capabilities != null and .missing_capabilities != []) else true end)' .planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT.json >/dev/null && bash scripts/ci/ci-run-metrics.test.sh` | Every preflight/tracer GET obeys 600/60/core/retry bounds and durable interruption; current effective rules and changed-set diagnostic; blocked hosted input remains unknown while offline fixture replay passes, with final baseline still nonzero | green |
| 252-01 Task 2 | CIMEAS-01 | `bash scripts/ci/ci-run-metrics.test.sh` | Changed rules, check/job binding, multi-revision family, literal outcomes and unknown timestamp rejection | green |
| 252-02 Task 1 | CIMEAS-01 | `bash scripts/ci/ci-run-metrics.test.sh` | Frozen cutoff; latest 100/event in 30 days; API totals/capped state; all attempts and source-backed PR workload | green |
| 252-02 Task 2 | CIMEAS-01 | `bash scripts/ci/ci-run-metrics.test.sh` | Shared guard extends from Plan 01 through pagination, redirect hops and downloads: 600 requests/60 minutes; core ≤250; 403/429 hard stop; one counted transient retry; explicit GET; durable interruption ledger, lock and offline replay | green |
| 252-02 Task 3 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | Validate allowed HTTPS redirect destinations before following; reject lookalikes/downgrade/user-info/ports; count each hop; never persist signed URLs; producing run/SHA/attempt and digest/hash, safe ZIP bounds and expired/missing diagnostics | green |
| 252-03 Task 1 | CIMEAS-02 | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/planning/ci_timing_formatter_test.exs` | Opt-in ExUnit completed-test microseconds, result/identity, suite totals/skips and ordinary scheduling/CLI output | green |
| 252-03 Task 2 | CIMEAS-02 | `bash scripts/ci/ci-exunit-timing.test.sh` | Partial/write failure and deliberate test failure preserve nonzero result; shared suite time differs from summed tests | green |
| 252-04 Task 1 | CIMEAS-02 | `node --test scripts/ci/ci-playwright-report.test.mjs` | Built-in JSON alongside list/HTML; unique invocation paths; five seams, one worker and zero retries | green |
| 252-04 Task 2 | CIMEAS-02 | `node --test scripts/ci/ci-playwright-report.test.mjs` | Project/seam/invocation/retry, millisecond unit, skips, missing/partial detection, distinct equal costs and stable tie order; reporter overhead measured with same-selection pairs or explicitly null/unmeasured, never zero | green |
| 252-05 Task 1 | CIMEAS-02 | `node --test scripts/ci/ci-measure-workflow.test.mjs` | Single `mix ci` owner; exact five required names and browser seams; original exits, actual cache/image metadata, producing-job runtime version command output separate from pins or null, always-upload diagnostics | green |
| 252-05 Task 2 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | Separate critical-path wait and summed runner rankings; measured setup/cache/compile/database/app/test stages; unknown fields stay unknown | green |
| 252-05 Task 3 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | At most four newest failed families/event, twelve total and three recurring signatures; no invented flake; unknown logs ≠ no flake | green |
| 252-06 Task 1 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json` | Fresh bounded hosted sources, current enforced endpoint, producing PR, separate populations/workloads, source checks, runtime version provenance or null, overhead disclosures and test/job/step costs; missing required hosted evidence stays nonzero | green |
| 252-06 Task 2 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics-comparison.test.sh` | Fixed 20 pairs/40 families and later 48 hours; [1..20] median 10.5, p95 19; both timing paths instrumented identically with measured/unknown overhead retained; no replacement; miss/unknown/insufficient outcomes | green |
| 252-06 Task 3 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-measure-report.test.sh` | Short source-linked report, actual-versus-pinned toolchain and both overhead disclosures, literal replay/local timing commands, separate populations/rankings/limitations and deterministic regeneration | green |

## Prior Audit Results (2026-10-12; finding resolved below)

- `node --test scripts/ci/ci-run-metrics-replay.test.mjs` — 1 passed after repairing the stale snapshot fixture with hash-checked rate-limit/rules inputs and a source-hashed workflow file.
- `bash scripts/ci/ci-run-metrics.test.sh` — 39 passed, including cutoff, guarded-request, interruption, artifact-provenance, replay and embedded comparison contracts.
- `node --test scripts/ci/ci-run-metrics-replay.test.mjs scripts/ci/ci-measure-workflow.test.mjs scripts/ci/ci-playwright-report.test.mjs` — 13 passed. Standalone comparison and report tests passed; focused ExUnit timing tests passed (2 tests); the ExUnit process harness passed with `complete: true`.
- Saved baseline verification returned `ready` with no diagnostics; the saved preflight shape is `ready`, with four requests and no missing capabilities.
- **Prior blocker, now resolved:** In source bundle SHA-256 `169e5425870bd4486b0c7c6a07a4fd2c938c363fb7c156ffac27f4220f7426f0`, artifact 11773560061 for run 38307191464 contained only the dependency-off report. The corrected run and source-bound replacement are recorded below; the original report and costs remain here as history.

## Measurement Recheck (2026-10-12)

- The corrected source bundle SHA-256 is `5478c3337881eac2285764d57f35fe103191cb5eea1814fc3dd8b36357758d29`; baseline SHA-256 is `45029a440b8c00fb9aca6ad9b5ae427c443e5736bb7ae1164c44a5ce4caf0376`. Run `38317383419`, attempt 1, passed all five required contexts. Its `Library tests shard` producer job `115037170118` completed the contributor gate and both timing and metadata uploads successfully.
- Metadata artifact `11777487125` and timing artifact `11777372344` are accepted and bound to run `38317383419`, attempt 1, and their declared producer job. The timing ZIP digest is `sha256:0bd41fb24cdaf5721f7d2b9d63fb1a873e6e128a86e09598990d3826960f6e23`; it contains separate complete `ci-exunit-timing-main.json` and `ci-exunit-timing-threadline-guard.json` reports. The main report has 2,683 rows (2,671 passed, 12 skipped, 22 excluded, 0 failed) and 18,811,928µs summed test time. The child report has 65 rows (65 passed, 2,640 excluded, 0 failed) and 129,529µs summed test time. The baseline records both, totaling 18,941,457µs.
- All 65 child test IDs also occur in the main run, and the baseline retains 2,748 distinct row identities because each identity includes its invocation (`main` or `threadline_guard`). No repeated test identity is merged.
- `python3 scripts/ci/exunit_timing_contract_test.py` — 5 passed, including rejection of a legacy dependency-off-only artifact. The broader `bash scripts/ci/ci-run-metrics.test.sh` — 40 passed, including Test Z for missing or wrong invocation reports; `node --test scripts/ci/ci-run-metrics-replay.test.mjs scripts/ci/ci-measure-workflow.test.mjs` — 5 passed; and `bash scripts/ci/ci-measure-report.test.sh` passed.
- Current archive-backed baseline verification returns `ready` with no diagnostics. Two offline replays were byte-identical with SHA-256 `a8661ab14c1ee8ff8dca74edae321e2d1f589d4592b579c181b2a24ea22d67de`. The previous 65-row-only bundle and baseline were replayed from preserved commit `5cad1606`; verification now exits 1 with `status: insufficient_data`, including missing-main-report and missing-producer-contract diagnostics.
- The repaired `MIX_ENV=test mix ci` run recorded in `252-06-SUMMARY.md` passed with 2,652 main tests, 33 doctests, 3 properties, zero failures, and a separate successful 65-test dependency-off run. The timing process harness passed with failing child exits preserved as 2. `mix.lock` had identical SHA-256 before and after that harness (`b0f7f2e5a1cab359d82eae227f1854c48ced59e313c7c385c666e42a1a2fd045`), and `git diff --exit-code HEAD -- mix.lock` passed.

## Wave 0 Requirements

No dependency or new testing framework is needed. Create meaningful contract fixtures with each producing slice, before accepting its behavior:

- Collector API pages/attempts/checks/workload, first-live-request budget guard, request ledger, interruption, redirect destination validation, invalid schema and hash/origin mismatch fixtures are created in 252-01/02 before their behavior is accepted.
- Formatter events and report-write/test-exit failure cases are created in 252-03; Playwright complete/partial/failed/skipped report and overhead disclosure fixtures are created in 252-04.
- Workflow integration checks and source-bound cache/actual runtime-version metadata checks are created in 252-05.
- Percentile fixture: values 1 through 20 yield median 10.5 and nearest-rank p95 19 (`ceil(0.95 * 20) = 19`).
- Comparison fixtures that retain failed/cancelled/non-comparable families and reject replacement or a favorable window extension are created in 252-06.

The discovery files can seed fixtures, but cannot satisfy current baseline acceptance.

## Manual-Only Verifications

None. Unavailable logs, timestamps, artifact origin or cache conditions are recorded as unknown and never accepted by human override.

## Validation Sign-Off

- [x] Exact plan/task map finalized and checked by the independent plan checker
- [x] Every task behavior is verified with an automated command
- [x] Existing test targets and commands were exercised
- [x] No watch-mode tests or retry/sleep workaround
- [x] Source-bound baseline and offline replay were verified, including rejection of the prior dependency-off-only baseline
- [x] `nyquist_compliant: true` set after the required coverage passed

**Status:** Validated. All 15 task-map entries have passing automated coverage. This closes validation coverage only; phase-level verification and requirement status remain pending.

## Validation Audit 2026-10-12

| Metric | Count |
|---|---|
| Gaps found | 2 |
| Resolved | 1 |
| Escalated | 1 |
