---
phase: 8
slug: account-lifecycle
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-08
validated: 2026-04-08
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/account/ test/sigra/hooks_test.exs test/sigra/data_export_test.exs test/sigra/plug/require_password_change_test.exs test/sigra/workers/account_deletion_test.exs test/sigra/templates/settings_live_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds |
| **Current test count** | 1112 tests, 0 failures |

---

## Sampling Rate

- **After every task commit:** Run Phase 8 quick run command
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 8-01-01 | 01 | 1 | ACCT-01 | T-8-03 / T-8-04 | Email change requires re-verification; token lifecycle; session invalidation | unit | `mix test test/sigra/account/email_change_test.exs` | test/sigra/account/email_change_test.exs | green |
| 8-01-02 | 01 | 1 | ACCT-02 | T-8-05 | Password change validates current password; invalidates sessions; force change flag | unit | `mix test test/sigra/account/password_change_test.exs` | test/sigra/account/password_change_test.exs | green |
| 8-01-03 | 01 | 1 | ACCT-03 | T-8-06 / T-8-07 / T-8-08 | Account deletion configurable strategy (soft/hard/anonymize); grace period; cooldown | unit | `mix test test/sigra/account/deletion_test.exs` | test/sigra/account/deletion_test.exs | green |
| 8-01-04 | 01 | 1 | ACCT-04 | T-8-01 / T-8-02 | Profile hooks run in Ecto.Multi; abort on failure; nil no-op | unit | `mix test test/sigra/hooks_test.exs` | test/sigra/hooks_test.exs | green |
| 8-01-05 | 01 | 1 | SESS-09 | T-8-09 | RequirePasswordChange plug halts for must_change_password=true; passes through otherwise | unit | `mix test test/sigra/plug/require_password_change_test.exs` | test/sigra/plug/require_password_change_test.exs | green |
| 8-01-06 | 01 | 1 | Config | T-8-01 | Config validates deletion strategy enum, hooks tuples, email_change TTL, password options | unit | `mix test test/sigra/config_test.exs` | test/sigra/config_test.exs | green |
| 8-01-07 | 01 | 1 | DataExport | — | DataExport behaviour defines callback; export_auth_data returns expected structure | unit | `mix test test/sigra/data_export_test.exs` | test/sigra/data_export_test.exs | green |
| 8-01-08 | 03 | 3 | ACCT-03 | T-8-10 / T-8-11 | Oban worker handles grace period expiry with safety checks; Module.safe_concat | unit | `mix test test/sigra/workers/account_deletion_test.exs` | test/sigra/workers/account_deletion_test.exs | green |
| 8-01-09 | 05 | 5 | Generator | T-8-15 / T-8-16 | Injector injects lifecycle routes, Oban queue, template files; idempotent | unit | `mix test test/sigra/install/injector_test.exs` | test/sigra/install/injector_test.exs | green |
| 8-01-10 | 05 | 5 | UI Templates | T-8-17 / T-8-18 | Settings LiveView has email/password/deletion sections; reactivation page; user_auth plugs; fixtures | unit | `mix test test/sigra/templates/settings_live_test.exs` | test/sigra/templates/settings_live_test.exs | green |

*Status: pending · green · red · flaky*

---

## Wave 0 Requirements

- [x] `test/sigra/account/email_change_test.exs` — 7 tests for ACCT-01 (request/confirm/cancel)
- [x] `test/sigra/account/password_change_test.exs` — 8 tests for ACCT-02 (change/set/force)
- [x] `test/sigra/account/deletion_test.exs` — 16 tests for ACCT-03 (schedule/cancel/execute x3 strategies)
- [x] `test/sigra/hooks_test.exs` — 9 tests for ACCT-04 (hooks nil/success/abort + get_hook)
- [x] `test/sigra/plug/require_password_change_test.exs` — 7 tests for SESS-09 (plug enforcement)
- [x] `test/sigra/config_test.exs` — Phase 8 config section tests (deletion, hooks, TTL, password options)
- [x] `test/sigra/data_export_test.exs` — 4 tests for DataExport behaviour + export_auth_data
- [x] `test/sigra/workers/account_deletion_test.exs` — 9 tests for Oban worker
- [x] `test/sigra/install/injector_test.exs` — Phase 8 injector tests (routes, queue, files)
- [x] `test/sigra/templates/settings_live_test.exs` — 30+ tests for LiveView templates + user_auth plugs + fixtures

*Existing infrastructure covers test framework — ExUnit is built-in.*

---

## Coverage Notes

### File Name Deviations from Original Draft

The original draft expected `test/sigra/account/profile_hooks_test.exs` and `test/sigra/account/sudo_test.exs`. Actual implementation:

- **ACCT-04 hooks**: Covered by `test/sigra/hooks_test.exs` (the hooks engine is a library module, not an account sub-module)
- **SESS-09 sudo/re-auth**: The Phase 8 portion (RequirePasswordChange plug) is covered by `test/sigra/plug/require_password_change_test.exs`. Sudo mode itself was implemented in Phase 4.

### Test Count by Requirement

| Requirement | Test Count | Test Files |
|-------------|-----------|------------|
| ACCT-01 | 7 | email_change_test.exs |
| ACCT-02 | 15 | password_change_test.exs (8), require_password_change_test.exs (7) |
| ACCT-03 | 25 | deletion_test.exs (16), account_deletion_test.exs (9) |
| ACCT-04 | 9 | hooks_test.exs |
| SESS-09 | 7 | require_password_change_test.exs |
| Config | 12 | config_test.exs (Phase 8 subset) |
| DataExport | 4 | data_export_test.exs |
| Generator | 10 | injector_test.exs (Phase 8 subset) |
| UI Templates | 30+ | settings_live_test.exs |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Email delivery content | ACCT-01 | Email body rendering requires visual inspection | Send test email, verify both confirmation and notification emails contain correct links |
| Settings page visual layout | UI | CSS/Tailwind class rendering cannot be verified without a browser | Check 3 sections visible, danger zone red border, OAuth-only variant |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated (2026-04-08)
**Test run:** 167 Phase 8 tests, 0 failures (from 1112 total suite)
