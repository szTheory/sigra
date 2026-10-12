---
phase: "252"
slug: "measure-current-ci"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-12"
---

# Phase 252 — Validation Strategy

This is an execution contract, not a claim that implementation or hosted measurements have passed. The exact plan/task map below names each new test target in its producing task's files list. The prior clean draft is recoverable at commit `dd38b5bbe6a979fc7b0ede8ce919ee196551df82` (SHA-256 `5f67bceacbacf8210834c73f516a6d1fe36e3ec6a7fbf41ecde8d24c44f2e43d`).

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

| Plan/task | Requirement | Automated verification | Coverage required |
|---|---|---|---|
| 252-01 Task 1 | CIMEAS-01, CIMEAS-02 | `jq -e '.status == "ready"' .planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT.json >/dev/null && bash scripts/ci/ci-run-metrics.test.sh` | Exact-source/API feasibility first; one saved PR family → required wait/runner sum → zero-network replay; five live rules and distinct equal-duration jobs |
| 252-01 Task 2 | CIMEAS-01 | `bash scripts/ci/ci-run-metrics.test.sh` | Changed rules, check/job binding, multi-revision family, literal outcomes and unknown timestamp rejection |
| 252-02 Task 1 | CIMEAS-01 | `bash scripts/ci/ci-run-metrics.test.sh` | Frozen cutoff; latest 100/event in 30 days; API totals/capped state; all attempts and source-backed PR workload |
| 252-02 Task 2 | CIMEAS-01 | `bash scripts/ci/ci-run-metrics.test.sh` | 600 requests/60 minutes; core ≤250; 403/429 hard stop; one counted transient retry; explicit GET; durable interruption ledger, lock and offline replay |
| 252-02 Task 3 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | Producing run/SHA/attempt and digest/hash, safe ZIP bounds, expired/missing diagnostics and secret-free ledger |
| 252-03 Task 1 | CIMEAS-02 | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/planning/ci_timing_formatter_test.exs` | Opt-in ExUnit completed-test microseconds, result/identity, suite totals/skips and ordinary scheduling/CLI output |
| 252-03 Task 2 | CIMEAS-02 | `bash scripts/ci/ci-exunit-timing.test.sh` | Partial/write failure and deliberate test failure preserve nonzero result; shared suite time differs from summed tests |
| 252-04 Task 1 | CIMEAS-02 | `node --test scripts/ci/ci-playwright-report.test.mjs` | Built-in JSON alongside list/HTML; unique invocation paths; five seams, one worker and zero retries |
| 252-04 Task 2 | CIMEAS-02 | `node --test scripts/ci/ci-playwright-report.test.mjs` | Project/seam/invocation/retry, millisecond unit, skips, missing/partial detection, distinct equal costs and stable tie order |
| 252-05 Task 1 | CIMEAS-02 | `node --test scripts/ci/ci-measure-workflow.test.mjs` | Single `mix ci` owner; exact five required names and browser seams; original exits, actual cache/toolchain/image metadata, always-upload diagnostics |
| 252-05 Task 2 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | Separate critical-path wait and summed runner rankings; measured setup/cache/compile/database/app/test stages; unknown fields stay unknown |
| 252-05 Task 3 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | At most four newest failed families/event, twelve total and three recurring signatures; no invented flake; unknown logs ≠ no flake |
| 252-06 Task 1 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json` | Fresh bounded hosted sources, producing PR, separate populations and workload, source checks, required endpoint and test/job/step costs |
| 252-06 Task 2 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-run-metrics.test.sh` | Fixed 20 pairs/40 families and later 48 hours; [1..20] median 10.5, p95 19; no replacement; miss/unknown/insufficient outcomes |
| 252-06 Task 3 | CIMEAS-01, CIMEAS-02 | `bash scripts/ci/ci-measure-report.test.sh` | Short source-linked report and literal replay/local timing commands; separate populations/rankings/limitations; deterministic regeneration |

## Wave 0 Requirements

No dependency or new testing framework is needed. Create meaningful contract fixtures with each producing slice, before accepting its behavior:

- Collector API pages/attempts/checks/workload, request ledger, interruption, invalid schema and hash/origin mismatch fixtures are created in 252-01/02 before their behavior is accepted.
- Formatter events and report-write/test-exit failure cases are created in 252-03; Playwright complete/partial/failed/skipped report fixtures are created in 252-04.
- Workflow integration checks and source-bound cache/runtime metadata checks are created in 252-05.
- Percentile fixture: values 1 through 20 yield median 10.5 and nearest-rank p95 19 (`ceil(0.95 * 20) = 19`).
- Comparison fixtures that retain failed/cancelled/non-comparable families and reject replacement or a favorable window extension are created in 252-06.

The discovery files can seed fixtures, but cannot satisfy current baseline acceptance.

## Manual-Only Verifications

None. All phase behaviors have automated verification. Unavailable logs, timestamps, artifact origin or cache conditions are recorded as unknown and never accepted by human override.

## Validation Sign-Off

- [ ] Exact plan/task map finalized and checked by the independent plan checker
- [ ] All tasks have automated verification and observable failure conditions
- [ ] New targets are created before their commands are required
- [ ] No watch-mode tests or retry/sleep workaround
- [ ] Source-bound current baseline and offline replay verified during execution
- [ ] `nyquist_compliant: true` set only after the required validation is actually achieved

**Approval:** Draft seeded from approved context and implementation research; execution pending.
