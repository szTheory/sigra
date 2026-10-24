---
phase: "255"
slug: "make-failures-reproducible-and-report-the-result"
status: remediation_required
nyquist_compliant: false
wave_0_complete: true
created: "2026-10-24"
---

# Phase 255 — Validation Strategy

Execution coverage audit: all 14 tasks across seven plans have automated tests and source-bound execution records. Requirements await the separate phase goal verifier. Existing hosted/distribution allowances are closed; their commands must not be replayed to repeat this audit.

## Test Infrastructure

Existing Node node:test, Python unittest, Bash integration tests, ExUnit and locked Playwright 1.59.1. Configurations: `mix.exs` and `test/example/priv/playwright/playwright.config.ts`. No new dependency or test framework.

Quick existing command: `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs`.

Existing replay regression: `bash scripts/ci/ci-run-metrics-comparison.test.sh`.

Full phase checks are derived from the final plans: real receiver/process/browser checks, safe bundle checks and clean checkout offline replay. Measure runtime during execution; estimates are not evidence.

## Sampling Rate

Run the owning seam's deterministic tests after each task and changed-seam tests after each wave. Keep fast fixtures separate from application/browser boot. No watch flags or sleeps as readiness checks. Create new test files in their owning task before implementation.

## Per-Task Verification Map

| Task ID | Wave | Requirement | Test type | Exact automated commands | State |
|---|---|---|---|---|---|
| 255-01-01 | 1 | CIMEAS-03 | Native/process/integration | `python3 -B scripts/ci/ci-comparison-replay.test.py`<br>`python3 -B scripts/ci/ci-comparison-replay.py preflight --root . --output .planning/execution/255-replay/PREFLIGHT.json && python3 -B scripts/ci/ci-comparison-replay.py replay --from-evidence --output .planning/execution/255-replay/RESULT.json` | PASS — `255-01-SUMMARY.md` and scoped records below |
| 255-01-02 | 1 | CIMEAS-03 | Contract/semantic | `python3 -B scripts/ci/ci-comparison-replay.test.py && bash scripts/ci/ci-run-metrics-comparison.test.sh && python3 -B scripts/ci/ci-metrics-security.test.py`<br>`python3 -B scripts/ci/ci-comparison-replay.py pack --output .planning/execution/255-replay/input-package.tar.gz && python3 -B scripts/ci/ci-comparison-replay.py replay --package .planning/execution/255-replay/input-package.tar.gz --output .planning/execution/255-replay/RESULT.json` | PASS — `255-01-SUMMARY.md` and scoped records below |
| 255-02-01 | 2 | CIDX-02 | Native/process/integration | `python3 -B scripts/ci/ci-command-record.test.py` | PASS — `255-02-SUMMARY.md` and scoped records below |
| 255-02-02 | 2 | CIDX-02 | Contract/semantic | `python3 -B scripts/ci/ci-diagnostic-bundle.test.py && python3 -B scripts/ci/ci-command-record.test.py && python3 -B scripts/ci/ci-metrics-security.test.py` | PASS — `255-02-SUMMARY.md` and scoped records below |
| 255-03-01 | 3 | CIDX-01, CIDX-02 | Native/process/integration | `python3 -B scripts/ci/ci-mix-receivers.test.py && node --test scripts/ci/ci-prep-semantics.test.mjs`<br>`MIX_ENV=test python3 -B scripts/ci/ci-mix-receivers.test.py --native --output .planning/execution/255-local/MIX-RECEIVERS.json` | PASS — `255-03-SUMMARY.md` and scoped records below |
| 255-03-02 | 3 | CIDX-01, CIDX-02 | Native/process/integration | `MIX_ENV=test mix test test/sigra/planning/ci_timing_formatter_test.exs && bash scripts/ci/test-sigra-dep-off.sh && python3 -B scripts/ci/ci-mix-receivers.test.py` | PASS — `255-03-SUMMARY.md` and scoped records below |
| 255-04-01 | 3 | CIDX-01, CIDX-02 | Native/process/integration | `node --test scripts/ci/ci-browser-command.test.mjs scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs`<br>`node scripts/ci/ci-browser-command.mjs list --seam demo_showcase --event pull_request --output-root /tmp/sigra255-selection` | PASS — `255-04-SUMMARY.md` and scoped records below |
| 255-04-02 | 3 | CIDX-01, CIDX-02 | Native/process/integration | `python3 -B scripts/ci/ci-browser-local.test.py && node --test scripts/ci/ci-browser-command.test.mjs scripts/ci/ci-measure-workflow.test.mjs scripts/ci/ci-prep-semantics.test.mjs`<br>`python3 -B scripts/ci/ci-browser-local.test.py --native` | PASS — `255-04-SUMMARY.md` and scoped records below |
| 255-05-01 | 4 | CIDX-02 | Native/process/integration | `node --test scripts/ci/ci-browser-diagnostics.test.mjs && node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` | PASS — `255-05-SUMMARY.md` and scoped records below |
| 255-05-02 | 4 | CIDX-02 | Contract/semantic | `node --test scripts/ci/ci-browser-diagnostics.test.mjs && python3 -B scripts/ci/ci-diagnostic-bundle.test.py && python3 -B scripts/ci/ci-command-record.test.py`<br>`node scripts/ci/ci-browser-diagnostics.test.mjs --native --output .planning/execution/255-local/BROWSER-DIAGNOSTICS.json` | PASS — `255-05-SUMMARY.md` and scoped records below |
| 255-06-01 | 5 | CIDX-01, CIDX-02 | Native/process/integration | `python3 -B scripts/ci/ci-diagnostics-canary.test.py && node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs scripts/ci/ci-measure-workflow.test.mjs && python3 -B scripts/ci/ci-hosted-gate-verify.test.py && bash scripts/ci/honest-skip-verdict.test.sh`<br>`python3 -B scripts/ci/ci-diagnostics-canary.py run --freeze .planning/execution/255-diagnostics-canary/FREEZE.json --scenario success` | PASS — `255-06-SUMMARY.md` and scoped records below |
| 255-06-02 | 5 | CIDX-01, CIDX-02 | Native/process/integration | `node scripts/ci/ci-browser-diagnostics.test.mjs --measure-overhead --pairs 3 --output .planning/execution/255-local/TRACE-OVERHEAD.json`<br>`python3 -B scripts/ci/ci-diagnostics-canary.py run --freeze .planning/execution/255-diagnostics-canary/FREEZE.json --scenario failure && python3 -B scripts/ci/ci-diagnostics-canary.py run --freeze .planning/execution/255-diagnostics-canary/FREEZE.json --scenario cancellation && python3 -B scripts/ci/ci-diagnostics-canary.py verify --freeze .planning/execution/255-diagnostics-canary/FREEZE.json --output .planning/execution/255-diagnostics-canary/RESULT.json` | PASS — `255-06-SUMMARY.md` and scoped records below |
| 255-07-01 | 6 | CIDX-01, CIDX-02, CIMEAS-03 | Native/process/integration | `python3 -B scripts/ci/ci-comparison-replay.test.py && python3 -B scripts/ci/ci-comparison-replay.py distribute --remote origin --output .planning/execution/255-replay/DISTRIBUTION.json && python3 -B scripts/ci/ci-comparison-replay.py verify-distribution --record .planning/execution/255-replay/DISTRIBUTION.json` | PASS — `255-07-SUMMARY.md` and scoped records below |
| 255-07-02 | 6 | CIDX-01, CIDX-02, CIMEAS-03 | Contract/semantic | `python3 -B scripts/ci/ci-comparison-report.test.py && python3 -B scripts/ci/ci-comparison-replay.test.py && node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs && python3 -B scripts/ci/ci-hosted-gate-verify.test.py && bash scripts/ci/ci-run-metrics-comparison.test.sh && python3 -B scripts/ci/ci-metrics-security.test.py && node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` | PASS — `255-07-SUMMARY.md` and scoped records below |

## Wave 0 Requirements

Existing infrastructure suffices. Each task creates its new test targets before implementing their behavior. New commands in the map are execution deliverables, not commands claimed to exist or pass during planning. The first execution artifact is255-01-01's ready/blocked source preflight; dependent work stops when blocked.

## Unresolved Edges and Hosted Bounds

CIDX-01, CIDX-02 and CIMEAS-03 now have automated coverage and actual native/hosted/replay records; final requirement completion awaits phase verification. CIDX-01 is tested by255-03/04 native receivers/selections and255-07 guidance assertions; CIDX-02 by255-02/05 real failures/safe bundles and255-06 actual hosted delivery; CIMEAS-03 by255-01 semantic replay and255-07 remote clean-checkout retrieval/report assertions. This audit maps observed tests and records; it does not substitute for the phase goal verdict. Automatically recalled prohibitions retain descriptor-less unresolved projections; explicit forbidden behaviors additionally have executable acceptance tests.

Plan 06 has a new frozen allowance:4 hosted fixture invocations maximum including at most 1 diagnosed infrastructure retry,120 controller HTTP requests including polling/retrieval/retries,60 minutes total elapsed,2 scoped Git pushes,6 minutes per fixture job and0 test retries. One 60-second watcher per run; core<=250 or403/429 stops requests until reset. Success, deliberate failure and actual GitHub fixture cancellation are distinct outcomes. Partial/missing cancellation uploads remain partial/missing.

Final-source trace overhead uses exactly 6 local passing invocations (3 off/3 on) and adds 0 comparison acceptance samples. Plan 07 distribution permits 1 successful create-only scoped evidence push, at most 1 transient retry after reading remote state and 2 retrieval attempts; no hosted dispatch or release publication.

## Manual-Only Verifications

None planned. Missing hosted artifacts or inaccessible replay packages remain concrete blockers. Do not substitute manual approval or mark missing proof as passed. Execution requires the separate `$gsd-execute-phase 255` invocation.

## Validation Sign-Off

- [x] Exact task map completed from final plans
- [x] Each runnable command states its observable failure signal
- [x] New test files are created before use
- [x] Local/process/browser and hosted scopes are separate
- [x] Requirement and decision coverage gates pass
- [x] Execution evidence produced and audited; no manual-only approval substitutes for missing records

## Execution Audit References

Audited source: `04b16705abfabb90b6d06f8f09eb9631e812dc58`. Current fast checks: 89 Python cases in `FAST-TESTS.json` passed; its original Node failure remains preserved. Preparation guard repair passed all 84 Node tests in `FAST-TESTS-AFTER-PREP-REPAIR.json`; the eight Mix observer tests passed after wiring the exact planned test entry point.

- Mix native identities and seeds: `.planning/execution/255-local/MIX-RECEIVERS.json`; final exact-entry-point regression will be recorded separately under `255-verification/`.
- Local ownership/browser native gate: `255-04-NATIVE.json` (exit 0).
- Seven native failure cases and three inspected traces: `.planning/execution/255-local/BROWSER-DIAGNOSTICS.json`; original native source and evidence-writer source are separately named.
- Hosted success/failure/cancellation: `.planning/execution/255-diagnostics-canary/RESULT.json`, independently verified, 37 requests / 3 invocations / 1 push / no retries. Cancellation's two final files remain missing. The first rate-read receipt/time gap is explicit and conservatively charged.
- Six passing overhead observations: `.planning/execution/255-local/TRACE-OVERHEAD.json`; noisy/inconclusive, no acceptance samples.
- Real remote fetch/offline replay: `.planning/execution/255-replay/DISTRIBUTION.json`, 191 members, zero network commands, unchanged inputs; first failed retrieval preserved, second passed. Published helper and corrected controller are distinct.
- Report semantics: `scripts/ci/ci-comparison-report.test.py`, six tests.

No test infrastructure gap or human-only check was found. Historical Phase 254 speed requirements remain open and are outside this phase's completion claim.

## Review Coverage Gaps

CR-01 needs real outer-runner SIGTERM cleanup; CR-02 child SIGKILL propagation; CR-03 concurrent process budget contention; CR-04 archive-level URL-userinfo/camel-case secret redaction; WR-01 retained missing-file metadata. Existing passing tests remain recorded, but coverage is incomplete until these focused regressions and repairs pass.
