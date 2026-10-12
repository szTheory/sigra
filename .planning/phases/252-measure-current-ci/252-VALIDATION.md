---
phase: "252"
slug: "measure-current-ci"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-12"
---

# Phase 252 — Validation Strategy

This is an execution contract, not a claim that implementation or hosted measurements have passed. The planner must replace the responsibility rows below with exact plan/task IDs and keep every new test target in its producing task's files list.

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

| Responsibility (planner assigns task ID) | Requirement | Automated verification | Coverage required |
|---|---|---|---|
| First end-to-end collector/replay slice | CIMEAS-01 | `bash scripts/ci/ci-run-metrics.test.sh` | Saved source → validated family → required wait/runner cost → replay output; malformed/missing inputs rejected or unknown |
| Bounded event/attempt acquisition | CIMEAS-01 | Same hermetic suite with fake `gh` argv/request ledger | Fixed cutoff; 100/event; all attempts; 600 requests/60 minutes; core ≤250; 403/429; one transient retry; explicit GET; resumable diagnostics |
| Test timing and output completeness | CIMEAS-02 | Focused new ExUnit formatter contract; existing browser selections plus fixture contracts | Microsecond/millisecond units, identity/result/retry, suite vs shared setup, exclusions/skips, partial output and original exit status |
| Workflow/boot integration | CIMEAS-02 | New focused workflow contract and producing hosted CI records | Single `mix ci` owner; five browser seams; zero retries; useful selections; cache/toolchain/image metadata; always-retained diagnostics |
| Artifact validation and report replay | CIMEAS-01, CIMEAS-02 | Hermetic source/report fixtures | Producing run/SHA/attempt, digest/hash, safe extraction/size limits, no input-text execution or secret retention, unknown cache/timestamps |
| Current baseline/failure shortlist | CIMEAS-01, CIMEAS-02 | Offline replay and machine-readable acceptance checks against fresh bounded acquisition | Separate PR/main/nightly and docs-only/full; literal outcomes; at most 12 failed families and 3 signatures; no invented flake |
| Fixed later comparison contract | CIMEAS-01, CIMEAS-02 | Deterministic arithmetic/contract fixtures | 20 pairs/40 families; later 48-hour window; even median; nearest-rank p95; no replacement; miss/unknown/insufficient-data outcomes |

## Wave 0 Requirements

No dependency or new testing framework is needed. Create meaningful contract fixtures with each producing slice, before accepting its behavior:

- Collector API pages/attempts/checks/workload, request ledger, interruption, invalid schema and hash/origin mismatch fixtures.
- Formatter events and report-write/test-exit failure cases; Playwright complete/partial/failed/skipped report fixtures.
- Workflow integration checks and source-bound cache/runtime metadata checks.
- Percentile fixture: values 1 through 20 yield median 10.5 and nearest-rank p95 19 (`ceil(0.95 * 20) = 19`).
- Comparison fixtures that retain failed/cancelled/non-comparable families and reject replacement or a favorable window extension.

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
