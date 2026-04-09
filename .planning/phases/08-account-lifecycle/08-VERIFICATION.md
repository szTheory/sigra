---
phase: 08-account-lifecycle
verified: 2026-04-08T23:45:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Verify settings LiveView renders all 3 sections correctly in a running Phoenix app"
    expected: "Email section with change form and pending status, password section with change/set variants, deletion danger zone with red border and confirmation"
    why_human: "LiveView template is EEx -- cannot verify rendered HTML without a running Phoenix app and browser"
  - test: "Verify sudo mode gates sensitive settings operations"
    expected: "Changing email, deleting account, and setting password for OAuth-only users should prompt for re-authentication if sudo window has expired"
    why_human: "Sudo enforcement depends on router plug pipeline ordering which varies per host app configuration"
  - test: "Verify reactivation page appears for deleted users during grace period login"
    expected: "User with scheduled deletion logging in sees reactivation page with cancel option"
    why_human: "Requires full login flow integration test with session management"
  - test: "Verify email templates render correctly with proper styling"
    expected: "7 new emails render with correct copywriting, CTA buttons, and security footer per UI-SPEC"
    why_human: "Email HTML rendering quality requires visual inspection in an email client or preview tool"
---

# Phase 8: Account Lifecycle Verification Report

**Phase Goal:** Users can change email (with re-verification), change password, delete their account, and perform sensitive operations only after re-authenticating in sudo mode; profile update hooks integrate cleanly with app-specific schemas
**Verified:** 2026-04-08T23:45:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can request an email change; new address receives confirmation, old address receives notification with cancel link; change only takes effect after confirmation | VERIFIED | `EmailChange.request/4` creates token + sets pending_email, `confirm/3` switches email atomically, `cancel/3` clears state. 3 email templates exist: `email_change_confirmation_email`, `email_change_notification_email`, `email_changed_email`. Session invalidation on confirm via `session_store.delete_all_for_user`. |
| 2 | User can change password with current password verification; all other sessions invalidated | VERIFIED | `PasswordChange.change/4` verifies current password via changeset, calls `session_store.delete_all_for_user` with `except_token` to preserve current session. Configurable via `invalidate_sessions_on_change` config. `password_changed_email` template exists. |
| 3 | User can delete account; deletion behavior (soft/hard/anonymize) is configurable | VERIFIED | `Deletion.schedule/cancel/execute` implement full lifecycle. Config accepts `:strategy` with `:soft_delete`, `:hard_delete`, `:anonymize` options. Grace period with Oban worker (`AccountDeletion`). Anonymize replaces email with `deleted_{id}@deleted.invalid`, clears password. 3 deletion email templates exist. |
| 4 | Sensitive operations prompt for re-authentication when sudo window expired; sudo window is configurable | VERIFIED | `Sigra.Plug.RequireSudo` exists from Phase 4 with configurable `sudo_window`. Generated `sudo_controller.ex` and `sudo_html.ex` handle re-auth flow. Auth context documents "Requires sudo mode" for sensitive operations. Settings LiveView operations are in authenticated scope that can be gated by RequireSudo at router level. |
| 5 | Application developers can register profile update callbacks that run within the same transaction | VERIFIED | `Sigra.Hooks.maybe_run_hook/4` injects steps into Ecto.Multi. Wired into all 3 sub-modules: `email_change`, `password_change`, `deletion`. Config accepts `{module, function}` tuples. Generated `auth_hooks.ex` stub with 4 documented operations. `with_hook/3` testing helper exists. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/hooks.ex` | Hook execution engine | VERIFIED | 95 lines, `maybe_run_hook/4`, `get_hook/2`, Ecto.Multi integration |
| `lib/sigra/data_export.ex` | DataExport behaviour | VERIFIED | 73 lines, `@callback export_user_data/1`, `export_auth_data/3` helper |
| `lib/sigra/account.ex` | Account orchestrator | VERIFIED | 91 lines, 12 `defdelegate` functions to sub-modules |
| `lib/sigra/account/email_change.ex` | Email change logic | VERIFIED | 204 lines, `request/4`, `confirm/3`, `cancel/3`, Telemetry spans, Hooks integration |
| `lib/sigra/account/password_change.ex` | Password change logic | VERIFIED | 176 lines, `change/4`, `set_for_oauth_user/3`, `force_change_required?/1`, session invalidation |
| `lib/sigra/account/deletion.ex` | Account deletion logic | VERIFIED | 307 lines, `schedule/3`, `cancel/3`, `execute/3`, 3 strategies, `scheduled?/1`, `status/1` |
| `lib/sigra/plug/require_password_change.ex` | RequirePasswordChange plug | VERIFIED | 45 lines, checks `must_change_password: true`, calls error_handler, halts |
| `lib/sigra/workers/account_deletion.ex` | Oban worker for grace period | VERIFIED | 82 lines, `perform/1`, `Deletion.execute`, safety checks, `sigra_lifecycle` queue |
| `priv/templates/sigra.install/migration.exs` | Migration with 5 new columns | VERIFIED | `pending_email`, `deleted_at`, `scheduled_deletion_at`, `original_email`, `must_change_password` across all 3 adapter branches. Partial indexes for Postgres. |
| `priv/templates/sigra.install/user.ex` | User schema with lifecycle fields | VERIFIED | 5 lifecycle fields, `pending_email_changeset`, `deletion_changeset`, `force_password_changeset` |
| `priv/templates/sigra.install/user_token.ex` | Updated token TTL | VERIFIED | `@change_email_validity_in_days 1` (was 2) |
| `priv/templates/sigra.install/auth.ex` | Auth context with lifecycle delegation | VERIFIED | 11 lifecycle functions delegating to `Sigra.Auth` and `Sigra.Account` |
| `priv/templates/sigra.install/auth_hooks.ex` | Hooks stub module | VERIFIED | 4 operations (`on_register`, `on_email_change`, `on_password_change`, `on_delete`) documented and commented |
| `priv/templates/sigra.install/emails.ex` | 7 new email templates | VERIFIED | All 7 callbacks implemented: `email_change_confirmation_email`, `email_change_notification_email`, `email_changed_email`, `deletion_scheduled_email`, `deletion_cancelled_email`, `deletion_finalized_email`, `password_changed_email` |
| `priv/templates/sigra.install/settings_live.ex` | Account settings LiveView | VERIFIED | 3 sections (email `id="email"`, password `id="password"`, deletion `id="delete"`), OAuth-only "Set a password" variant, pending email display, danger zone border styling, force password change banner |
| `priv/templates/sigra.install/reactivation_live.ex` | Grace period reactivation page | VERIFIED | Cancel deletion button, sign-out link, scheduled deletion date display |
| `priv/templates/sigra.install/user_auth.ex` | Updated plug pipeline | VERIFIED | `require_password_unchanged/2` and `check_account_active/2` plugs added |
| `lib/sigra/install/injector.ex` | Generator with Phase 8 routes | VERIFIED | `inject_lifecycle_routes/2`, `inject_oban_lifecycle_queue/1`, `lifecycle_template_files/0` |
| `lib/sigra/testing.ex` | Testing helpers | VERIFIED | 10 lifecycle helpers: `scheduled_deletion_fixture`, `force_password_change_fixture`, `with_hook`, `assert_deletion_scheduled`, `assert_password_changed`, etc. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `account/email_change.ex` | `Sigra.Hooks` | `Hooks.maybe_run_hook` | WIRED | Called in confirm flow |
| `account/password_change.ex` | `Sigra.Hooks` | `Hooks.maybe_run_hook` | WIRED | Called in change flow |
| `account/deletion.ex` | `Sigra.Hooks` | `Hooks.maybe_run_hook` | WIRED | Called in schedule flow |
| `account/email_change.ex` | `session_store` | `delete_all_for_user` | WIRED | Called after confirm |
| `account/password_change.ex` | `session_store` | `delete_all_for_user` | WIRED | Called after change (configurable) |
| `auth.ex` (lib) | `Sigra.Account` | delegation | WIRED | 8 functions delegate to Account |
| `auth.ex` (template) | `Sigra.Auth` | delegation | WIRED | 11 functions delegate to Sigra.Auth/Account |
| `workers/account_deletion.ex` | `Deletion.execute` | function call | WIRED | Calls `Deletion.execute/3` and `Deletion.scheduled?/1` |
| `plug/require_password_change.ex` | `conn.assigns` | `must_change_password` field | WIRED | Pattern matches on user struct field |
| `user_auth.ex` (template) | `RequirePasswordChange` | plug reference | WIRED | `require_password_unchanged/2` delegates to plug pattern |
| `injector.ex` | settings routes | route injection | WIRED | `inject_lifecycle_routes/2` adds 3 routes |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `settings_live.ex` | `pending_email_change?` | `user.pending_email` | From DB via scope | FLOWING |
| `settings_live.ex` | `deletion_status` | `Auth.deletion_status(user)` | Computed from `user.deleted_at` and `user.scheduled_deletion_at` | FLOWING |
| `settings_live.ex` | `has_password?` | `user.hashed_password` | From DB | FLOWING |
| `reactivation_live.ex` | `scheduled_deletion_date` | `user.scheduled_deletion_at` | From DB | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Phase 8 tests pass | `mix test test/sigra/account/ ...` | 60 tests, 0 failures | PASS |
| Full suite passes | `mix test` | 1112 tests, 0 failures | PASS |
| Compilation clean | `mix compile --warnings-as-errors` | Exit 0 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| ACCT-01 | 02, 04, 05 | Email change with re-verification | SATISFIED | EmailChange module, email templates, settings LiveView, auth context delegation |
| ACCT-02 | 02, 03, 04, 05 | Password change with current password verification | SATISFIED | PasswordChange module, RequirePasswordChange plug, auth context delegation, settings LiveView |
| ACCT-03 | 02, 03, 04, 05 | Account deletion with configurable handling | SATISFIED | Deletion module (3 strategies), AccountDeletion Oban worker, auth context delegation, settings LiveView, reactivation page |
| ACCT-04 | 01, 04 | Profile management hooks | SATISFIED | Hooks engine, config section, auth_hooks.ex stub, DataExport behaviour |
| SESS-09 | 03, 05 | Sudo/re-authentication for sensitive operations | SATISFIED | RequireSudo plug (Phase 4), RequirePasswordChange plug, check_account_active plug, sudo controller/templates exist |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | - | - | - | - |

No TODOs, FIXMEs, placeholders, or stub implementations found in Phase 8 library code.

### Human Verification Required

### 1. Settings LiveView Visual Correctness

**Test:** Open `/users/settings` in a browser with a running Phoenix app
**Expected:** 3 sections visible (email, password, deletion). Deletion section has red left border. OAuth-only user sees "Set a password" instead of "Change password". Pending email change shows status indicator with cancel button. Force password change shows yellow banner.
**Why human:** LiveView EEx template cannot be verified for rendered HTML without a running app

### 2. Sudo Mode Gates Sensitive Operations

**Test:** Let sudo window expire, then attempt to change email, delete account, or set password for OAuth user
**Expected:** User is redirected to re-authentication page before the operation proceeds
**Why human:** Sudo enforcement depends on router plug pipeline ordering which is configured per host app

### 3. Reactivation Flow During Grace Period

**Test:** Schedule account deletion, log out, log back in during grace period
**Expected:** User sees reactivation page with option to cancel deletion or sign out
**Why human:** Requires full login flow integration test with session management

### 4. Email Template Rendering

**Test:** Trigger all 7 new email types and inspect in email preview tool
**Expected:** Correct copy per UI-SPEC, CTA buttons rendered, security footer on security-related emails, standard footer on others
**Why human:** Email HTML rendering quality requires visual inspection

### Gaps Summary

No gaps found. All 5 roadmap success criteria are met by the implementation. All required library modules, generated templates, plugs, workers, testing helpers, and generator wiring are in place and substantive.

The only outstanding items are human verification of visual rendering (settings LiveView, email templates) and integration flow testing (sudo gating, reactivation flow) which cannot be verified programmatically.

---

_Verified: 2026-04-08T23:45:00Z_
_Verifier: Claude (gsd-verifier)_
