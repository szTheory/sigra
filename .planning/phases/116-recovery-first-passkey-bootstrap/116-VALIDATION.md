---
phase: 116
slug: recovery-first-passkey-bootstrap
status: passed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
updated: 2026-05-25
requirements: [PK-03]
backfilled_by: Phase 120
---

# Phase 116 — Validation Strategy

> Retroactive Nyquist map for the already-shipped `PK-03` behavior.
> Phase 120 supplies the missing authoritative verification and validation wrapper; it does not redefine the recovery-first bootstrap design.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit, Phoenix.LiveViewTest, controller tests, generator assertions, Playwright, planning-file grep |
| Config file | `test/test_helper.exs`; `test/example/test/test_helper.exs`; `test/example/priv/playwright/playwright.config.ts` |
| Focused root proof | `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/install/generator_passkey_primary_login_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'` |
| Focused example-host proof | `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/controllers/confirmation_controller_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs` |
| Served-route proof | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts --project=chromium` |
| Documentation gate | `rg -n "^nyquist_compliant: true$|^wave_0_complete: true$|PK-03|generator_passkey_primary_login_test\\.exs|generator_passkey_management_test\\.exs|confirmation_controller_test\\.exs|passkey_settings_live_test\\.exs|passkey_session_controller_test\\.exs|passkey_mfa_challenge_live_test\\.exs|passkey-login\\.spec\\.ts" .planning/phases/116-recovery-first-passkey-bootstrap/116-VALIDATION.md` |

## Sampling Rate

- After any `PK-03` behavioral or truth-surface change: rerun the focused root and example-host proofs before updating verification text.
- Before calling the served-route confirmation seam closed: rerun `passkey-login.spec.ts` against a local example host on `http://localhost:4000`.
- Before milestone re-audit: rerun the documentation gate and ensure `116-VERIFICATION.md` still reports the same proof seams and blocker state honestly.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 116-01-01 | 01 | 0 | PK-03 | generated-host login and management templates preserve signup follow-through, bootstrap banner, and explicit enrollment posture without hiding fallback methods | ExUnit | `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/install/generator_passkey_primary_login_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'` | `test/sigra/install/generator_passkey_primary_login_test.exs`, `test/sigra/install/generator_passkey_management_test.exs` | ✅ green |
| 116-01-02 | 01 | 0 | PK-03 | confirmation controller/routing, bootstrap LiveView state, passkey session fallback, and MFA challenge fallback stay aligned on the example host | ExUnit | `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/controllers/confirmation_controller_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs` | `test/example/test/example_web/controllers/confirmation_controller_test.exs`, `test/example/test/example_web/live/passkey_settings_live_test.exs`, `test/example/test/example_web/controllers/passkey_session_controller_test.exs`, `test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs` | ✅ green |
| 116-01-03 | 01 | 0 | PK-03 | the canonical served-route browser seam starts from confirmation intent, reaches the bootstrap banner, shows `Create passkey` / `Not now`, and completes passkey enrollment through the real POST endpoints | Playwright | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts --project=chromium` | `test/example/priv/playwright/tests/passkey-login.spec.ts` | ✅ green |

## Validation Notes

- `nyquist_compliant: true` and `wave_0_complete: true` are set because every `PK-03` implementation seam maps to a concrete proof command and each mapped seam is now green on current HEAD.
- The root generator fallback and the targeted example-host slice are green on current HEAD.
- The served-route Playwright seam is green and proves the confirmation -> sudo/bootstrap -> explicit enrollment lane on current HEAD.
- Every requirement-bearing row above is scoped to `PK-03`.

## Validation Sign-Off

- [x] All `PK-03` implementation seams now map to concrete proof commands
- [x] `generator_passkey_primary_login_test.exs` is represented
- [x] `generator_passkey_management_test.exs` is represented
- [x] `confirmation_controller_test.exs` is represented
- [x] `passkey_settings_live_test.exs` is represented
- [x] `passkey_session_controller_test.exs` is represented
- [x] `passkey_mfa_challenge_live_test.exs` is represented
- [x] `passkey-login.spec.ts` is represented
- [x] No placeholder `MISSING` or template tokens remain

Approval: passed as a truthful retroactive Nyquist map for `PK-03`; all mapped proof seams replay green on current HEAD.
