---
phase: "246"
slug: "generated-confirmation-recovery"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-06"
---

# Phase 246 — Validation Strategy

> Validation contract for the generated confirmation journey. Task IDs below are provisional and must be reconciled with the final PLAN.md task breakdown before execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest; Playwright Test 1.62.1 |
| **Config file** | `mix.exs`; `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/auth_test.exs test/sigra/install/generator_email_test.exs test/sigra/install/generator_wiring_test.exs test/sigra/install/features/core_test.exs test/sigra/install/generated_confirmation_live_test.exs` |
| **Full suite command** | `mix ci` plus the required `install_smoke` lane and generated-host browser proof; runner duration varies and has not been measured for this phase |

## Sampling Rate

- **After every task commit:** Run the focused ExUnit files for the touched source seam.
- **After every plan wave:** Run `mix ci`; the required CI path must include the fresh-host confirmation probe and the Chromium confirmation scenario.
- **Before `$gsd-verify-work`:** Require green relevant CI and retained fresh-host browser/persistence evidence.
- **Max feedback latency:** Keep the local ExUnit command below 60 seconds; use bounded CI for host generation and browser checks.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 246-01-01 | 01 | 1 | CONF-01 | T-246-01, T-246-02 | Link GET leaves confirmation state unchanged; explicit submit confirms the token owner without creating or switching the visitor's session; persisted `confirmed_at` changes and token replay fails. | LiveView/integration + generated-host | `mix test test/sigra/install/generated_confirmation_live_test.exs`; `bash scripts/ci/install-smoke.sh` | ❌ Wave 0 coverage required | ⬜ pending |
| 246-01-02 | 01 | 1 | CONF-02 | T-246-03, T-246-04 | Exact email display spacing reaches the server; only allowed spacing is normalized; six ASCII digits are required; a code for account A cannot confirm account B; per-account rate limiting remains in place. | Unit/integration + browser | `mix test test/sigra/auth_test.exs test/sigra/install/generated_confirmation_live_test.exs`; from `test/example/priv/playwright`, `npx playwright test tests/generated-confirmation.spec.ts --project=generated-host-chromium` | ❌ Wave 0 coverage required | ⬜ pending |
| 246-01-03 | 01 | 1 | CONF-03 | — | Success and invalid-code text is visible, localized, exposed with status/alert semantics, and retry remains available without forced focus movement. | Template contract + LiveView + browser | `mix test test/sigra/install/auth_ui_contract_test.exs test/sigra/install/generator_email_test.exs`; generated-host Playwright scenario from `test/example/priv/playwright` | ❌ Wave 0 assertions required | ⬜ pending |

## Wave 0 Requirements

- [ ] Add focused LiveView coverage for anonymous and signed-in link confirmation, GET no-op, explicit submit, unchanged session identity, anonymous code/resend guidance, and safe handling of missing scope.
- [ ] Add an account-binding regression proving a valid code for account A cannot change account B's persisted confirmation state, while retaining the per-account rate limit.
- [ ] Update generator assertions for the complete spaced input, server-side normalization, and visible accessible feedback.
- [ ] Extend the fresh-host probe to assert persisted confirmation state, session identity, and single-use token behavior.
- [ ] Add one deterministic Chromium scenario that pastes the spaced email code into the fresh host and checks visible success/invalid-code feedback and retry.
- [ ] Wire browser setup, app readiness, teardown, and failure artifacts into the existing required CI aggregation, without fixed sleeps.

## Manual-Only Verifications

All Phase 246 behaviors have automated verification; no manual UAT is required.

## Validation Sign-Off

- [ ] Every final plan task has an automated `<verify>` or an explicit Wave 0 dependency.
- [ ] Sampling continuity has no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references above.
- [ ] Browser tests use stable accessible locators, deterministic LiveView readiness, and no sleeps.
- [ ] Required CI retains the fresh-host browser and persisted-state evidence.
- [ ] Set `nyquist_compliant: true` only after the full validation map and all Wave 0 checks are satisfied.

**Approval:** pending automated plan and execution evidence
