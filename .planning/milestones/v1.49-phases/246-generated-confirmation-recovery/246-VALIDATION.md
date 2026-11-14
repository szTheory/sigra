---
phase: "246"
slug: "generated-confirmation-recovery"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-06"
---

# Phase 246 — Validation Strategy

> Validation contract for the generated confirmation journey. The exact-source required CI receipt is now green for `90ec16f72a71d33224c0816ad77762e2e7262c76`; earlier local blocker diagnostics remain as historical context in `246-MIX-CI-BLOCKED.md` and `246-CI-EVIDENCE.json`.

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
| 246-03-01 | 03 | 3 | CONF-02, CONF-03 | T-246-08 | Chromium pastes the literal spaced email code in a fresh generated host, sees invalid alert, retries, and sees success status. | Real browser | `PLAYWRIGHT_BROWSERS_PATH=/tmp/sigra-playwright-browsers bash scripts/ci/admin-acceptance-smoke.sh --test confirmation` | ✅ Browser spec added in task | ✅ pass (confirmation segment of full acceptance smoke at `fd75cad25fd29d1fd59c79bbf937e0cdd8aaf57a`; existing admin timeout passed on one retained retry) |
| 246-03-02 | 03 | 3 | CONF-01, CONF-02, CONF-03 | T-246-09 | Required CI runs the generated confirmation target and retains actual result and source SHA. | CI contract + recurring run receipt | `MIX_ENV=test mix test test/sigra/install/generated_confirmation_ci_contract_test.exs`; `PLAYWRIGHT_BROWSERS_PATH=/tmp/sigra-playwright-browsers bash scripts/ci/admin-acceptance-smoke.sh --test all`; required CI | ✅ Contract/receipt added in task | ✅ Exact-source workflow `37676348766` passed `ci-gate`, `install_smoke`, and `generated_admin_playwright_smoke` at `90ec16f72a71d33224c0816ad77762e2e7262c76`; admin-eval and all five browser shards also passed |

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
- [x] Required CI retains the fresh-host browser and persisted-state evidence for the exact final source; see `246-CI-EVIDENCE.json`.
- [x] Full validation map and Wave 0 checks are satisfied; phase-level verifier sign-off is recorded separately in `246-VERIFICATION.md`.

**Execution evidence:** focused regression tests passed 48/0 on the final confirmation fix; fresh-host installation passed 8/0; the install golden/idempotency checks passed 4/0 after refreshing the generated fixture. Required workflow `37676348766` passed for exact source `90ec16f72a71d33224c0816ad77762e2e7262c76`, including the required gate, install smoke, generated-admin Playwright, five example Playwright shards, and admin-eval. The prior `mix ci` and `mix precommit` diagnostics are preserved as historical observations for their earlier source; they do not replace or contradict this later exact-source CI receipt.

## Validation Audit 2026-10-07

| Metric | Count |
|---|---|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
