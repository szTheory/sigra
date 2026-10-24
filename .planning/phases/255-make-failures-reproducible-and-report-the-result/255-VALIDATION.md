---
phase: "255"
slug: "make-failures-reproducible-and-report-the-result"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-24"
---

# Phase 255 — Validation Strategy

Planning contract only. The planner must replace this provisional map with exact task IDs and commands before plan checking. No Phase 255 behavior has been implemented or verified.

## Test Infrastructure

Existing Node node:test, Python unittest, Bash integration tests, ExUnit and locked Playwright 1.59.1. Configurations: `mix.exs` and `test/example/priv/playwright/playwright.config.ts`. No new dependency or test framework.

Quick existing command: `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs`.

Existing replay regression: `bash scripts/ci/ci-run-metrics-comparison.test.sh`.

Full phase checks are derived from the final plans: real receiver/process/browser checks, safe bundle checks and clean checkout offline replay. Measure runtime during execution; estimates are not evidence.

## Sampling Rate

Run the owning seam's deterministic tests after each task and changed-seam tests after each wave. Keep fast fixtures separate from application/browser boot. No watch flags or sleeps as readiness checks. Create new test files in their owning task before implementation.

## Per-Task Verification Map

| Behavior | Requirement | Test type | Required automated proof | State |
|----------|-------------|-----------|--------------------------|-------|
| Actual seven-leg Mix path | CIDX-01 | Real process/ExUnit | Observe ordinary/scaffold/dep-off receivers; exclusions, prerequisites and nonzero outcomes | Pending plan assignment |
| Five exact browser selections | CIDX-01 | Identity contract/live browser | PR/non-PR identities; owned dev DB/server; matching PORT and CI=true | Pending plan assignment |
| First failure and original exit | CIDX-02 | Real process/browser | Failing cleanup; startup/discovery; first trace retention; passing disposal; exact argv/seed | Pending plan assignment |
| Safe invocation-bound bundle | CIDX-02 | Archive fixtures | Finished bundle excludes planted secrets, auth storage, stale output and escaping symlinks | Pending plan assignment |
| Hosted delivery | CIDX-02 | Isolated non-publishing canary | New finite frozen budget; actual success/failure/cancellation; retrieve source/run/attempt-bound files | Pending plan assignment |
| Portable faithful replay | CIMEAS-03 | Clean checkout offline | Hash-pinned inputs/tools; corrupt/missing helper negatives; unchanged originals; insufficient_data/zero pairs/null statistics/2046 and 1589 costs | Pending plan assignment |
| Accurate final report | CIMEAS-03 | Semantic assertions | Distinct measured/analysis/later development identities; original method/limits; speed requirements remain open | Pending plan assignment |

## Wave 0 Requirements

Existing infrastructure suffices. Each plan creates new tests before its behavior and identifies every producing task for new command targets. The planner finalizes the map after assigning plans.

## Manual-Only Verifications

None planned. Missing hosted artifacts or inaccessible replay packages remain concrete blockers. Do not substitute manual approval or mark missing proof as passed. Execution requires the separate `$gsd-execute-phase 255` invocation.

## Validation Sign-Off

- [ ] Exact task map completed from final plans
- [ ] Each runnable command states its observable failure signal
- [ ] New test files are created before use
- [ ] Local/process/browser and hosted scopes are separate
- [ ] Requirement and decision coverage gates pass
- [ ] Execution evidence produced; nyquist_compliant stays false until validated
