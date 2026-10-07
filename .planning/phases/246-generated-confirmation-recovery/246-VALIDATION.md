---
phase: "246"
slug: "generated-confirmation-recovery"
status: passed
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-06"
---

# Phase 246 — Validation Strategy

> Validation contract for the generated confirmation journey. Required CI passed
> for exact source SHA `2232272d77a4ebfccafe43ddec877bf3ad6195a7` in
> [run 37558299754](https://github.com/szTheory/sigra/actions/runs/37558299754).
> The original local contract failures are documented as resolved in
> `246-MIX-CI-BLOCKED.md`; the local managed-sandbox limitation is not counted
> as passing evidence.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest; Playwright Test 1.59.1 (committed lockfile) |
| **Config file** | `mix.exs`; `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/auth_test.exs test/sigra/install/generator_email_test.exs test/sigra/install/generator_wiring_test.exs test/sigra/install/features/core_test.exs test/sigra/install/auth_ui_contract_test.exs test/sigra/install/generated_confirmation_ci_contract_test.exs` |
| **Fresh-host commands** | `bash scripts/ci/install-smoke.sh`; `bash scripts/ci/admin-acceptance-smoke.sh --test confirmation` |
| **Full suite command** | `mix ci` plus the required `install_smoke` and `generated_admin_playwright_smoke` CI lanes; runner duration varies and has not been measured for this phase |

## Sampling Rate

- **After every task commit:** Run the focused ExUnit files for the touched source seam.
- **After every plan wave:** Run `mix ci`; the required CI path must include the fresh-host confirmation probe and the Chromium confirmation scenario.
- **Before `$gsd-verify-work`:** Require green relevant CI and retained fresh-host browser/persistence evidence.
- **Max feedback latency:** Keep the local ExUnit command below 60 seconds; use bounded CI for host generation and browser checks.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 246-01-01 | 01 | 1 | CONF-01, CONF-03 | T-246-01, T-246-02 | Anonymous link GET is read-only; explicit submit changes persisted `confirmed_at`, keeps the visitor anonymous, consumes the token, and displays success. | Fresh-host LiveView/DB | `bash scripts/ci/install-smoke.sh` | ✅ Probe source added in task | ✅ pass (7 fresh-host tests; Plan 01 summary) |
| 246-01-02 | 01 | 1 | CONF-01 | T-246-02, T-246-03 | Signed-in B can submit A's link without changing B's session; anonymous code/resend show guidance. | Fresh-host LiveView/DB + route contract | `mix test test/sigra/install/features/core_test.exs test/sigra/install/generator_wiring_test.exs`; `bash scripts/ci/install-smoke.sh` | ✅ Probe cases added in task | ✅ pass (Plan 01 summary) |
| 246-02-01 | 02 | 2 | CONF-02 | T-246-04, T-246-05, T-246-06 | Spaced code normalizes narrowly and confirms only its current account; malformed input and A-code/B-scope cannot mutate state; limiter remains per account. | Library ExUnit + fresh-host LiveView/DB | `mix test test/sigra/auth_test.exs`; `bash scripts/ci/install-smoke.sh` | ✅ Regression cases added in task | ✅ pass (71 unit; 8 fresh-host tests; Plan 02 summary) |
| 246-02-02 | 02 | 2 | CONF-03 | T-246-07 | Localized success/invalid results are visible with status/alert semantics, and invalid entry is retryable. | Template contract + fresh-host LiveView | `mix test test/sigra/install/generator_email_test.exs test/sigra/install/auth_ui_contract_test.exs`; `bash scripts/ci/install-smoke.sh` | ✅ Contract file and probe cases added in task | ✅ pass (47 template/UI tests; Plan 02 summary) |
| 246-03-01 | 03 | 3 | CONF-02, CONF-03 | T-246-08 | Chromium pastes the literal spaced email code in a fresh generated host, sees invalid alert, retries, and sees success status. | Real browser | `PLAYWRIGHT_BROWSERS_PATH=/tmp/sigra-playwright-browsers bash scripts/ci/admin-acceptance-smoke.sh --test confirmation` | ✅ Browser spec added in task | ✅ pass in `generated_admin_playwright_smoke` at `2232272d77a4ebfccafe43ddec877bf3ad6195a7` (run 37558299754) |
| 246-03-02 | 03 | 3 | CONF-01, CONF-02, CONF-03 | T-246-09 | Required CI runs the generated confirmation target and retains actual result and source SHA. | CI contract + recurring run receipt | `MIX_ENV=test mix test test/sigra/install/generated_confirmation_ci_contract_test.exs`; `PLAYWRIGHT_BROWSERS_PATH=/tmp/sigra-playwright-browsers bash scripts/ci/admin-acceptance-smoke.sh --test all`; required CI | ✅ Contract/receipt added in task | ✅ pass: `ci-gate`, `install_smoke`, and `generated_admin_playwright_smoke` succeeded on run 37558299754 for the same SHA; all five example browser shards and the full aggregate also passed |

## Wave 0 Requirements

- [x] Add the tracked `scripts/ci/generated-confirmation-probe.exs` and execute its generated-host LiveView cases for anonymous and signed-in link confirmation, GET no-op, explicit submit, unchanged session identity, anonymous code/resend guidance, and safe handling of missing scope.
- [x] Add an account-binding regression proving a valid code for account A cannot change account B's persisted confirmation state, while retaining the per-account rate limit.
- [x] Update generator assertions for the complete spaced input, server-side normalization, and visible accessible feedback.
- [x] Extend the fresh-host probe to assert persisted confirmation state, session identity, and single-use token behavior.
- [x] Add one deterministic Chromium scenario that pastes the spaced email code into the host generated by `admin-acceptance-smoke.sh` and checks visible success/invalid-code feedback and retry.
- [x] Wire the confirmation target into the existing `generated_admin_playwright_smoke` required CI job and its running generated-host server, with deterministic readiness and retained failure artifacts; keep `install_smoke` for persisted-state proof.

## Manual-Only Verifications

All Phase 246 behaviors have automated verification paths; no manual UAT is required. The required workflow result is still missing.

## Validation Sign-Off

- [x] Every final plan task has an automated `<verify>` or an explicit Wave 0 dependency.
- [x] Sampling continuity has no three consecutive tasks without automated verification.
- [x] Wave 0 covers all missing references above.
- [x] Browser tests use stable accessible locators, deterministic LiveView readiness, and no sleeps.
- [x] Required CI retains the fresh-host browser and persisted-state evidence for one exact committed source SHA.
- [x] `nyquist_compliant: true`: all validation-map and Wave 0 checks are satisfied by the exact-source receipt.

**Execution evidence:** required CI run [37558299754](https://github.com/szTheory/sigra/actions/runs/37558299754) passed for source `2232272d77a4ebfccafe43ddec877bf3ad6195a7`. The required `ci-gate`, fresh-host `install_smoke`, generated-host `generated_admin_playwright_smoke`, all five example Playwright shards, their full aggregate, and admin-eval render/probe succeeded. The original four contract failures were repaired before this run. A later local `mix ci` invocation remains environment-limited by nested macOS sandbox denial and cold Threadline output; its result is retained as a limitation, not as passing proof. See `246-CI-EVIDENCE.json`, `246-MIX-CI-FAILURES.json`, and `246-MIX-CI-BLOCKED.md` for receipts and diagnostics.
