---
phase: 21
slug: passkey-liveviews-post-auth-controller
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-15
revised: 2026-04-15
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for library/generator/example app, Node-stub JS tests for generated hooks, Playwright browser smoke for generated passkey login binding, example app precommit gate |
| **Config file** | `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/AGENTS.md` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_passkey_management_test.exs test/sigra/install/generator_passkey_mfa_challenge_test.exs test/sigra/install/generator_passkey_primary_login_test.exs test/sigra/install/features/passkeys_js_test.exs --max-failures 1` |
| **Example app command** | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/confirmation_controller_test.exs test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/registration_live_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs --max-failures 1` |
| **Config regression command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys/config_test.exs --max-failures 1` |
| **Playwright smoke command** | `bash -lc 'set -euo pipefail; cd test/example; MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.setup; MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix phx.server > /tmp/sigra-example-playwright.log 2>&1 & server_pid=$!; cleanup(){ kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; }; trap cleanup EXIT; for i in {1..60}; do if curl -fsS http://localhost:4000/users/log_in >/dev/null; then break; fi; if ! kill -0 "$server_pid" 2>/dev/null; then cat /tmp/sigra-example-playwright.log; exit 1; fi; sleep 1; done; curl -fsS http://localhost:4000/users/log_in >/dev/null; cd priv/playwright; SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts'` |
| **Final precommit command** | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix precommit` |
| **Estimated runtime** | ~240 seconds for focused gates; example `mix precommit` may exceed quick feedback latency and is final-gate only |

---

## Sampling Rate

- **After every task commit:** Run the task-local `<automated>` command from its PLAN.md. Task-local checks use ExUnit/Node-stub feedback only; Playwright is reserved for the final Phase 21 gate.
- **After every plan wave:** Run the generator quick run command above.
- **Before `$gsd-verify-work`:** Run config regression command, generator quick run, example app command, self-contained Playwright smoke command, `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix compile --warnings-as-errors`, and example `mix precommit`.
- **Max feedback latency:** 240 seconds for task and wave gates; final precommit is allowed to run longer because it is the project guideline gate from `test/example/AGENTS.md`.

---

## Per-Plan Verification Map

| Plan | Wave | Requirements | Threat Refs | Secure Behavior | Test Type | Automated Command | Status |
|------|------|--------------|-------------|-----------------|-----------|-------------------|--------|
| 21-01 | 1 | PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-06, PK-UX-07, PK-UX-09, PK-UX-11 | T-21-01-01..08 | Generated Auth wrappers use bundled AAGUID registry labels, registration email, duplicate remap, sudo routes, POST completion, and recovery-aware passkey-primary controller seams | generator + unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_mfa_test.exs --max-failures 1` | ⬜ pending |
| 21-02 | 2 | PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-09, PK-UX-10, PK-UX-12 | T-21-02-01..06 | `/users/settings/mfa` owns enrollment/list/rename/delete UX, uses `PasskeyRegister`, hides raw credential metadata, maps duplicate/abort states, and renders delete as a row-local controller POST form rather than a LiveView mutation | generator | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkey_management_test.exs --max-failures 1` | ⬜ pending |
| 21-03 | 2 | PK-UX-05, PK-UX-10, PK-UX-11, PK-UX-12 | T-21-03-01..06 | MFA challenge is passkey-first for passkey users, never auto-triggers, keeps TOTP/backup fallback visible, and posts success to controller completion | generator | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkey_mfa_challenge_test.exs test/sigra/install/generator_mfa_test.exs --max-failures 1` | ⬜ pending |
| 21-04 | 2 | PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-11 | T-21-04-01..07 | Passkey-primary login stays identifier-first, signup enrollment is config-gated, unconfirmed users cannot use passkey-primary, magic-link recovery remains mandatory, and login completion remains controller POST-owned | generator | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkey_primary_login_test.exs test/sigra/install/generator_wiring_test.exs --max-failures 1` | ⬜ pending |
| 21-07 | 3 | PK-UX-08, PK-UX-10, PK-UX-12 | T-21-07-01..05 | Conditional UI/autofill JS ships as progressive enhancement, `attachPasskeyLogin({ enableConditionalUI: true })` binds controller pages on DOMContentLoaded, supported browsers fetch conditional options without email, hooks preserve controller POST completion, and abort/timeout/unsupported states use safe copy | generator + JS | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/passkeys_js_test.exs --max-failures 1` | ⬜ pending |
| 21-05 | 4 | PK-UX-01..PK-UX-12 | T-21-05-01..05 | Example app mirrors generated Phase 21 source into concrete Phoenix server/controller/context and UI/assets files, exposes the passkey ceremony seam, and compiles with warnings as errors after each mirror task | example source mirror + compile | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix compile --warnings-as-errors` | ⬜ pending |
| 21-06 | 5 | PK-UX-01..PK-UX-12 | T-21-06-01..06 | Example app integration tests prove passkey-primary login success, MFA passkey success, sudo enrollment notification success, stale-sudo delete rejection, invalid/error paths, signup/confirmation handoff, fallback UI, and Playwright smoke coverage for controller-page passkey login binding | example integration + Playwright + precommit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_passkey_management_test.exs test/sigra/install/generator_passkey_mfa_challenge_test.exs test/sigra/install/generator_passkey_primary_login_test.exs test/sigra/install/features/passkeys_js_test.exs --max-failures 1 && (cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/confirmation_controller_test.exs test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/registration_live_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs --max-failures 1) && (cd test/example/priv/playwright && npx playwright test tests/passkey-login.spec.ts) && (cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix compile --warnings-as-errors) && (cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix precommit)` | ⬜ pending |
| 21-08 | 6 | PK-UX-01..PK-UX-12 | T-21-08-01..05 | Gap closure foundation adds `passkey_primary_enabled` to `Sigra.Config`, proves it with focused config tests, then gives the example app real passkey routes, runtime passkey config, concrete `Example.Accounts.UserPasskey`, and `user_passkeys` migration | config regression + example compile/routes/migration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys/config_test.exs --max-failures 1 && (cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.reset) && (cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix compile --warnings-as-errors) && (cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix phx.routes \| rg "passkey") && (cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix run -e 'Sigra.Passkeys.reset_cached_config(); IO.inspect(Sigra.Passkeys.config().passkeys)')` | ⬜ pending |
| 21-09 | 7 | PK-UX-01..PK-UX-12 | T-21-09-01..05 | Gap closure tests remove fixture-local passkey schema/table bootstrap, replace source-contract assertions with real route/session/database assertions, and make Playwright fail unless the real example server and `/users/log_in` page are running | example integration + self-contained Playwright | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs --max-failures 1 && cd ../.. && ! rg -n "source\\(|File\\.read!|router_source|controller =~|fixtures =~|setContent|gotoLoginOrFixture|ERR_CONNECTION_REFUSED|CREATE TABLE IF NOT EXISTS user_passkeys|Module\\.create" test/example/test/example_web/controllers/passkey_session_controller_test.exs test/example/test/example_web/live/passkey_settings_live_test.exs test/example/test/support/fixtures/auth_fixtures.ex test/example/priv/playwright/tests/passkey-login.spec.ts && bash -lc 'set -euo pipefail; cd test/example; MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.setup; MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix phx.server > /tmp/sigra-example-playwright.log 2>&1 & server_pid=$!; cleanup(){ kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; }; trap cleanup EXIT; for i in {1..60}; do if curl -fsS http://localhost:4000/users/log_in >/dev/null; then break; fi; if ! kill -0 "$server_pid" 2>/dev/null; then cat /tmp/sigra-example-playwright.log; exit 1; fi; sleep 1; done; curl -fsS http://localhost:4000/users/log_in >/dev/null; cd priv/playwright; SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts'` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Nyquist Coverage

All implementation tasks in the nine PLAN.md files include `<verify><automated>...`.

Wave 0 test scaffolding is folded into the plans themselves:

- Plan 21-01 creates `test/sigra/install/generator_passkeys_foundation_test.exs`.
- Plan 21-02 creates `test/sigra/install/generator_passkey_management_test.exs`.
- Plan 21-03 creates `test/sigra/install/generator_passkey_mfa_challenge_test.exs`.
- Plan 21-04 creates/extends `test/sigra/install/generator_passkey_primary_login_test.exs`.
- Plan 21-07 creates/extends `test/sigra/install/features/passkeys_js_test.exs`.
- Plan 21-05 mirrors generated source into the example app in two tasks (server/controller/context, then UI/assets) and compiles after each task.
- Plan 21-06 creates example integration tests under `test/example/test/example_web/...` and passkey fixture/stub helpers under `test/example/test/support/fixtures/auth_fixtures.ex`.
- Plan 21-06 creates `test/example/priv/playwright/tests/passkey-login.spec.ts` for focused browser smoke coverage of `attachPasskeyLogin()`, conditional mediation feature detection, visible identifier/fallback UI, and unsupported/abort recovery.
- Plan 21-08 creates focused config regression coverage in `test/sigra/passkeys/config_test.exs` before adding `passkey_primary_enabled` to the `Sigra.Config` passkeys schema, then adds route/config/schema/migration foundation in the example app.
- Plan 21-09 rewrites example passkey tests so verification crosses real router/session/database boundaries and runs Playwright against a server started by the verification command itself.

No separate Wave 0 plan is required because every missing test file is created before or within the task that relies on it, and each task has an automated verification command.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Last-passkey delete warning strength | PK-UX-04, PK-UX-07 | Copy severity and account-recovery posture need human judgment beyond string presence | Seed a user with one passkey in passkey-primary mode, enter the delete flow after sudo, and confirm the warning explicitly calls out remaining recovery methods |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 coverage is embedded in task-local test creation
- [x] No watch-mode flags
- [x] Feedback latency target documented
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ready for execution
