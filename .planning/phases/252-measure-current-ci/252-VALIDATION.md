---
phase: "252"
slug: "measure-current-ci"
status: partial
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-12"
---

# Phase 252 — Validation Strategy

Twelve task checks passed during this audit. Three task outcomes remain escalated because the retained ExUnit artifact contains the dependency-off test run instead of the primary `mix ci` suite. Phase-level verification remains pending. The prior clean draft is recoverable at commit `dd38b5bbe6a979fc7b0ede8ce919ee196551df82` (SHA-256 `5f67bceacbacf8210834c73f516a6d1fe36e3ec6a7fbf41ecde8d24c44f2e43d`).

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
| 252-05 Task 2 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | Separate critical-path wait and summed runner rankings; measured setup/cache/compile/database/app/test stages; unknown fields stay unknown | escalated: uploaded ExUnit timing covers the dependency-off subprocess |
| 252-05 Task 3 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | At most four newest failed families/event, twelve total and three recurring signatures; no invented flake; unknown logs ≠ no flake | green |
| 252-06 Task 1 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json` | Fresh bounded hosted sources, current enforced endpoint, producing PR, separate populations/workloads, source checks, runtime version provenance or null, overhead disclosures and test/job/step costs; missing required hosted evidence stays nonzero | escalated: baseline accepts dependency-off timing as primary suite cost |
| 252-06 Task 2 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics-comparison.test.sh` | Fixed 20 pairs/40 families and later 48 hours; [1..20] median 10.5, p95 19; both timing paths instrumented identically with measured/unknown overhead retained; no replacement; miss/unknown/insufficient outcomes | green |
| 252-06 Task 3 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-measure-report.test.sh` | Short source-linked report, actual-versus-pinned toolchain and both overhead disclosures, literal replay/local timing commands, separate populations/rankings/limitations and deterministic regeneration | escalated: report repeats incorrect ExUnit suite cost |

## Audit Results (2026-10-12)

- `node --test scripts/ci/ci-run-metrics-replay.test.mjs` — 1 passed after repairing the stale snapshot fixture with hash-checked rate-limit/rules inputs and a source-hashed workflow file.
- `bash scripts/ci/ci-run-metrics.test.sh` — 39 passed, including cutoff, guarded-request, interruption, artifact-provenance, replay and embedded comparison contracts.
- `node --test scripts/ci/ci-run-metrics-replay.test.mjs scripts/ci/ci-measure-workflow.test.mjs scripts/ci/ci-playwright-report.test.mjs` — 13 passed. Standalone comparison and report tests passed; focused ExUnit timing tests passed (2 tests); the ExUnit process harness passed with `complete: true`.
- Saved baseline verification returned `ready` with no diagnostics; the saved preflight shape is `ready`, with four requests and no missing capabilities.
- **Escalated:** In source bundle SHA-256 `169e5425870bd4486b0c7c6a07a4fd2c938c363fb7c156ffac27f4220f7426f0`, timing artifact 11773560061 for run 38307191464 is bound to producer job 115007133882 (`Library tests shard`, attempt 2). The complete ExUnit report has 65 passed tests and 2,639 excluded, matching the final `mix test --only threadline_guard --no-deps-check` child in `scripts/ci/sigra-dep-off.sh`. The `mix ci` alias runs that child after its primary test suite and inherits the same output path. Thus the stored 188,522µs is the dependency-off timing, not the primary suite timing. The baseline validator still returns ready and the rendered report repeats this value as full-suite cost. Keep Phase 252 validation partial until implementation preserves separate invocations and fresh hosted evidence proves the primary suite report.

## Wave 0 Requirements

No dependency or new testing framework is needed. Create meaningful contract fixtures with each producing slice, before accepting its behavior:

- Collector API pages/attempts/checks/workload, first-live-request budget guard, request ledger, interruption, redirect destination validation, invalid schema and hash/origin mismatch fixtures are created in 252-01/02 before their behavior is accepted.
- Formatter events and report-write/test-exit failure cases are created in 252-03; Playwright complete/partial/failed/skipped report and overhead disclosure fixtures are created in 252-04.
- Workflow integration checks and source-bound cache/actual runtime-version metadata checks are created in 252-05.
- Percentile fixture: values 1 through 20 yield median 10.5 and nearest-rank p95 19 (`ceil(0.95 * 20) = 19`).
- Comparison fixtures that retain failed/cancelled/non-comparable families and reject replacement or a favorable window extension are created in 252-06.

The discovery files can seed fixtures, but cannot satisfy current baseline acceptance.

## Manual-Only Verifications

None. Unavailable logs, timestamps, artifact origin or cache conditions are recorded as unknown and never accepted by human override. The ExUnit timing defect is an escalated implementation finding, not a manual-only requirement.

## Validation Sign-Off

- [x] Exact plan/task map finalized and checked by the independent plan checker
- [ ] Every task behavior is verified; primary-suite ExUnit timing remains blocked
- [x] Existing test targets and commands were exercised
- [x] No watch-mode tests or retry/sleep workaround
- [x] Source-bound baseline and offline replay were verified; the wrong ExUnit invocation scope is recorded above
- [ ] `nyquist_compliant: true` set only after the required validation is actually achieved

**Status:** Partial. Twelve task checks passed; three task outcomes are escalated for the same ExUnit artifact scope defect. Phase verification and requirement status remain pending.

## Validation Audit 2026-10-12

| Metric | Count |
|---|---|
| Gaps found | 2 |
| Resolved | 1 |
| Escalated | 1 |
