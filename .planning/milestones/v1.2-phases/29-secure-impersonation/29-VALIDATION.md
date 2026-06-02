---
phase: 29
slug: secure-impersonation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 29 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with ConnCase and Phoenix LiveViewTest |
| **Config file** | `test/test_helper.exs` and `test/example/test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/impersonation_test.exs test/sigra/scope/hydration_impersonation_test.exs test/sigra/plug/forbid_during_impersonation_test.exs --max-failures 1` |
| **Example-app command** | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/impersonation_controller_test.exs test/example_web/user_auth_test.exs test/example_web/admin_shell_test.exs --max-failures 1` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test && cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~10-20s targeted library/example slices, ~90-180s combined full suites with live Postgres |

---

## Sampling Rate

- **After every task commit:** Run the targeted command listed for that task row.
- **After every plan wave:** Run the full suite command for library plus example app.
- **Before `/gsd-verify-work`:** All Phase 29 targeted commands green, then both full suites green.
- **Max feedback latency:** Keep task-level commands under ~20 seconds where possible.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 29-01-01 | 01 | 1 | IMPR-01, IMPR-02, IMPR-03, IMPR-05 | T-29-01, T-29-04 | Runtime rejects out-of-scope or nested impersonation and returns explicit timeout/restore outcomes | unit | `mix test test/sigra/impersonation_test.exs test/sigra/admin/authorizer_test.exs test/sigra/audit/log_safe_scope_test.exs test/sigra/scope/hydration_impersonation_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 29-01-02 | 01 | 1 | IMPR-01, IMPR-02, IMPR-03, IMPR-05 | T-29-01..T-29-04 | Library runtime, hydration, and audit attribution pass the focused direct-path suite | unit | `mix test test/sigra/impersonation_test.exs test/sigra/admin/authorizer_test.exs test/sigra/audit/log_safe_scope_test.exs test/sigra/scope/hydration_impersonation_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 29-02-01 | 02 | 2 | IMPR-01, IMPR-02, IMPR-03, IMPR-05 | T-29-05..T-29-08 | Controller start/stop, sudo enforcement, safe local `return_to`, and non-admin stop-path reachability are pinned in tests | integration | `cd test/example && mix test test/example_web/controllers/impersonation_controller_test.exs test/example_web/user_auth_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 29-02-02 | 02 | 2 | IMPR-01, IMPR-02, IMPR-03, IMPR-05 | T-29-05..T-29-08 | Generated/example controller and `UserAuth` wiring rotate and restore tokens through the explicit impersonation route contract | integration | `cd test/example && mix test test/example_web/controllers/impersonation_controller_test.exs test/example_web/user_auth_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 29-03-01 | 03 | 3 | IMPR-01, IMPR-03, IMPR-05 | T-29-09..T-29-11 | User detail start entry and persistent banner copy are fixed in host-chrome tests | liveview/component | `cd test/example && mix test test/example_web/live/admin_user_show_live_test.exs test/example_web/admin_shell_test.exs --max-failures 1` | ✅ existing | ⬜ pending |
| 29-03-02 | 03 | 3 | IMPR-01, IMPR-03, IMPR-05 | T-29-09..T-29-11 | Generated/example detail and shell chrome keep impersonation visible and route stop through the always-available path | liveview/component | `cd test/example && mix test test/example_web/live/admin_user_show_live_test.exs test/example_web/admin_shell_test.exs --max-failures 1` | ✅ existing | ⬜ pending |
| 29-04-01 | 04 | 3 | IMPR-04 | T-29-12..T-29-14 | Plug, controller, LiveView, and direct-path non-API-token mutations are blocked with explicit denial messaging | unit + integration | `mix test test/sigra/plug/forbid_during_impersonation_test.exs --max-failures 1 && cd test/example && mix test test/example_web/impersonation_blocked_ops_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 29-04-02 | 04 | 3 | IMPR-04 | T-29-12..T-29-14 | Shared impersonation gate is wired into non-API-token password/MFA/passkey/reactivation surfaces | unit + integration | `mix test test/sigra/plug/forbid_during_impersonation_test.exs --max-failures 1 && cd test/example && mix test test/example_web/impersonation_blocked_ops_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 29-05-01 | 05 | 4 | IMPR-04 | T-29-15, T-29-16 | Generated API-token wrapper/controller mutations are pinned as blocked during impersonation | template + integration | `cd test/example && mix test test/example_web/impersonation_api_token_blocked_ops_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 29-05-02 | 05 | 4 | IMPR-04 | T-29-15, T-29-16 | API-token create/revoke/revoke-all paths fail closed through generated seams and any matching host wrapper | template + integration | `cd test/example && mix test test/example_web/impersonation_api_token_blocked_ops_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/impersonation_test.exs` — runtime orchestration, non-nesting, timeout policy, restore outcomes.
- [ ] `test/sigra/scope/hydration_impersonation_test.exs` — dedicated `Sigra.Scope.Hydration` impersonation parity tests.
- [ ] `test/sigra/plug/forbid_during_impersonation_test.exs` — shared gate denial behavior and audit expectations.
- [ ] `test/example/test/example_web/controllers/impersonation_controller_test.exs` — controller start/stop, safe `return_to`, and app-wide stop route.
- [ ] `test/example/test/example_web/impersonation_blocked_ops_test.exs` — password, MFA, passkey, deletion/reactivation blocked-operation coverage.
- [ ] `test/example/test/example_web/impersonation_api_token_blocked_ops_test.exs` — API-token create/revoke/revoke-all coverage for generated seams.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Banner prominence across admin and non-admin pages | IMPR-03 | Human review is still useful for copy prominence and persistent placement, even after ExUnit renders are green | Run the example app, start impersonation from user detail, then visit an app page and an admin page; confirm the banner remains visible and the single `End impersonation` action is obvious in both places |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency stays under the targeted slice budget
- [ ] `nyquist_compliant: true` set in frontmatter before execution closes

**Approval:** pending
