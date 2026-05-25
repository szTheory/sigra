---
phase: 115
slug: last-passkey-safety-deletion-truth
status: passed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-24
updated: 2026-05-24
requirements: [PK-02]
backfilled_by: Phase 119
---

# Phase 115 — Validation Strategy

> Retroactive Nyquist map for the already-shipped PK-02 behavior.
> Phase 119 supplies the missing authoritative verification and validation wrapper; it does not introduce new runtime passkey behavior.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit, Phoenix.LiveViewTest, controller tests, Playwright, planning-file grep |
| Config file | `test/test_helper.exs`; `test/example/test/test_helper.exs`; `test/example/priv/playwright/playwright.config.ts` |
| Focused root proof | `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/passkeys_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'` |
| Focused example-host proof | `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs` |
| Served-route proof | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-options.spec.ts --project=chromium` |
| Documentation gate | `rg -n "^nyquist_compliant: true$|^wave_0_complete: true$|PK-02|passkeys_test\\.exs|generator_passkey_management_test\\.exs|passkey_settings_live_test\\.exs|passkey_session_controller_test\\.exs|passkey-options\\.spec\\.ts" .planning/phases/115-last-passkey-safety-deletion-truth/115-VALIDATION.md` |

## Sampling Rate

- After any PK-02 behavioral change: rerun the focused root proof and example-host proof before updating verification text.
- Before calling PK-02 fully replayable on served routes: rerun the Playwright lane with a real example host listening on `localhost:4000`.
- Before milestone closeout or re-audit: rerun the documentation gate and ensure `115-VERIFICATION.md` still matches the same proof seams.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 115-01-01 | 01 | 0 | PK-02 | library delete semantics distinguish last-passkey deletes from ordinary deletes without host-owned rule drift | ExUnit | `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/passkeys_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'` | `test/sigra/passkeys_test.exs` | ✅ green |
| 115-01-02 | 01 | 0 | PK-02 | generated-host templates keep delete warning and fallback posture aligned with the library-owned seam | ExUnit | `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'` | `test/sigra/install/generator_passkey_management_test.exs` | ✅ green |
| 115-01-03 | 01 | 0 | PK-02 | example-host LiveView and controller surfaces preserve truthful last-passkey warnings, stale-sudo rejection, and final-passkey success posture | ExUnit | `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs` | `test/example/test/example_web/live/passkey_settings_live_test.exs`, `test/example/test/example_web/controllers/passkey_session_controller_test.exs` | ✅ green |
| 115-01-04 | 01 | 0 | PK-02 | served routes prove the enrollment-to-delete lifecycle and truthful post-delete fallback posture in a real browser lane | Playwright | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-options.spec.ts --project=chromium` | `test/example/priv/playwright/tests/passkey-options.spec.ts` | ✅ green |

## Validation Notes

- `nyquist_compliant: true` and `wave_0_complete: true` are set because every PK-02 evidence seam is now mapped to a concrete proof command and authoritative artifact, replacing the former missing-file blocker.
- The browser lane is now green after repairing the example host runtime endpoint config and booting the host locally on `localhost:4000`.
- Every requirement-bearing row in the verification map is scoped to `PK-02` only.

## Validation Sign-Off

- [x] All PK-02 implementation seams now map to concrete proof commands
- [x] `passkeys_test.exs` is represented
- [x] `generator_passkey_management_test.exs` is represented
- [x] `passkey_settings_live_test.exs` is represented
- [x] `passkey_session_controller_test.exs` is represented
- [x] `passkey-options.spec.ts` is represented
- [x] No template placeholders or `MISSING` markers remain

Approval: approved as a truthful retroactive Nyquist map for PK-02 with all mapped proof seams now green.
