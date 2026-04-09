# Phase 08 — Account Lifecycle: Security Audit

**Auditor:** GSD Security Auditor
**Date:** 2026-04-08
**ASVS Level:** 1
**Block On:** critical

## Threat Verification

| Threat ID | Severity | Category | Disposition | Status | Evidence |
|-----------|----------|----------|-------------|--------|----------|
| T-8-01 | medium | Hook injection via runtime-supplied module/function | mitigate | CLOSED | `lib/sigra/config.ex` — NimbleOptions validates `{:tuple, [:atom, :atom]}` for hooks config (lines 524-540). Only compile-time `{module, function}` tuples accepted. |
| T-8-02 | low | Hook step leaks sensitive data in error tuples | mitigate | CLOSED | `lib/sigra/hooks.ex:61` — step named `:"on_#{operation}_hook"`. Error contains hook's returned reason only, not internal state. |
| T-8-03 | high | Account takeover via email change without re-auth | mitigate | CLOSED | `lib/sigra/account/email_change.ex` — confirm-then-switch pattern implemented (email stays active until new confirmed). Cancel via `cancel/3`. Sudo enforcement is upstream responsibility (generated auth context). `priv/templates/sigra.install/user_auth.ex:368-378` — `check_account_active` plug present. |
| T-8-04 | medium | Email enumeration via pending_email | mitigate | CLOSED | `lib/sigra/account/email_change.ex:50-51` — checks `email_taken?` via callback, returns `{:error, :email_taken}` (generic). `priv/templates/sigra.install/migration.exs:29` — unique index on pending_email `WHERE pending_email IS NOT NULL`. |
| T-8-05 | high | Session persistence after password change | mitigate | CLOSED | `lib/sigra/account/password_change.ex:160-175` — `maybe_invalidate_sessions/2` calls `session_store.delete_all_for_user` with `except_token` option. Configurable via `config.password.invalidate_sessions_on_change` (default: true). |
| T-8-06 | high | Grace period bypass for deleted account | mitigate | CLOSED | `lib/sigra/account/deletion.ex:48-49` — `deleted_at` check prevents re-scheduling. `lib/sigra/account/deletion.ex:197-204` — all sessions revoked on scheduling via `revoke_sessions/2`. `lib/sigra/account/deletion.ex:198` — tokens deleted via `Multi.delete_all(:tokens, ...)`. |
| T-8-07 | medium | Deletion request/cancel cycle abuse | mitigate | CLOSED | `lib/sigra/account/deletion.ex:166-169` — `within_cooldown?/2` checks elapsed hours since cancellation. Config default 24h cooldown. |
| T-8-08 | medium | Data remnants after anonymization | mitigate | CLOSED | `lib/sigra/account/deletion.ex:278-294` — anonymize strategy: email replaced with `deleted_#{user.id}@deleted.invalid`, `hashed_password: nil`, `pending_email: nil`, `original_email: nil`, `scheduled_deletion_at: nil`. |
| T-8-09 | medium | Bypass RequirePasswordChange | mitigate | CLOSED | `lib/sigra/plug/require_password_change.ex:32-43` — plug checks `must_change_password: true` and halts. `priv/templates/sigra.install/user_auth.ex:341-353` — `require_password_unchanged/2` redirects to settings page (settings exempt to avoid loop). |
| T-8-10 | low | Oban job module resolution injection | mitigate | CLOSED | `lib/sigra/workers/account_deletion.ex:33-35` — `Module.safe_concat/1` and `String.to_existing_atom/1` used for all module/atom resolution from Oban args. |
| T-8-11 | medium | Duplicate deletion jobs | mitigate | CLOSED | `lib/sigra/workers/account_deletion.ex:27` — `unique: [period: 300, keys: [:user_id]]`. `lib/sigra/workers/account_deletion.ex:42` — `Deletion.scheduled?/1` guard before execution. |
| T-8-12 | medium | Email change token valid too long | mitigate | CLOSED | `priv/templates/sigra.install/user_token.ex:11` — `@change_email_validity_in_days 1` (updated from 2 to 1 day / ~24h). |
| T-8-13 | medium | Deleted account email reuse blocked | mitigate | CLOSED | `priv/templates/sigra.install/migration.exs:27` — `create unique_index(..., where: "deleted_at IS NULL", name: ..._email_active_index)`. Partial index enforces uniqueness only for active users. |
| T-8-14 | medium | Pending email reservation bypass | mitigate | CLOSED | `priv/templates/sigra.install/migration.exs:29` — `create unique_index(...[:pending_email], where: "pending_email IS NOT NULL", ...)`. |
| T-8-15 | high | Deleted account accessing protected routes | mitigate | CLOSED | `priv/templates/sigra.install/user_auth.ex:368-378` — `check_account_active/2` checks `user.deleted_at` and redirects to `/users/reactivation`. |
| T-8-16 | medium | Password change form accessible despite RequirePasswordChange | mitigate | CLOSED | `priv/templates/sigra.install/user_auth.ex:341-353` — `require_password_unchanged/2` redirects to `/users/settings#password`, which is the settings page itself (exempt from the check). |
| T-8-17 | medium | CSRF on email change / deletion requests | mitigate | CLOSED | `priv/templates/sigra.install/settings_live.ex` — all state-changing operations use `phx-submit` (forms) or `phx-click` (buttons), both covered by Phoenix LiveView's built-in CSRF protection. |
| T-8-18 | medium | XSS via email display on settings page | mitigate | CLOSED | `priv/templates/sigra.install/settings_live.ex` — uses HEEx `~H` sigil with auto-escaping. Grep for `raw(` returns no matches. No raw user input rendering. |

## Unregistered Flags

None. No `## Threat Flags` section found in any SUMMARY.md file for Phase 08.

## Accepted Risks (from Plan Residual Risk sections)

1. **OAuth provider-side tokens not revoked on deletion (D-25).** Tokens expire naturally. Provider-side revocation adds complexity/fragility. Accepted by design.
2. **Hard delete relies on Sigra cascading its own tables only.** App-level foreign keys must use the `on_delete` hook (D-32). Documented but not enforced.
3. **Hook functions execute arbitrary developer code.** Developer is trusted (D-49). Contract documented.
4. **Oban worker args contain module names as strings.** Standard Oban pattern. `Module.safe_concat/1` validates at runtime.
5. **MySQL/SQLite lack partial indexes.** Application-level uniqueness enforcement used instead. Documented in migration template.
6. **Reactivation re-auth depends on correct plug ordering.** Generated code provides the check but flow depends on router configuration.
