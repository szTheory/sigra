# Phase 8: Account Lifecycle - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can change their email (with re-verification), change their password, delete their account, and manage profile updates through app-specific hooks. All sensitive operations are gated by sudo mode. The generated account settings page provides a unified interface for all lifecycle operations. Profile update hooks allow developers to extend auth operations with app-specific logic within the same transaction.

Note: Sudo mode (SESS-09) was already implemented in Phase 4 (D-20 through D-23). This phase uses it but does not build it.

</domain>

<decisions>
## Implementation Decisions

### Email Change Flow
- **D-01:** Confirm-then-switch: send verification to new address, old email stays active until confirmed. GitHub/GitLab pattern. No lockout risk.
- **D-02:** Old address receives notification with cancel link. Cancel deletes the pending change token and notifies the new address that the change was cancelled.
- **D-03:** Token TTL: 24 hours (configurable via `:email_change_ttl`). Shorter than account confirmation (48h) since user is already authenticated.
- **D-04:** One pending email change at a time. New request cancels any existing pending change.
- **D-05:** Reserve new email during pending state via `pending_email` field on user. Block registration with that email while pending. Prevents race condition.
- **D-06:** Expired token shows error page with "Request new email change" button. Same pattern as Phase 3 confirmation/reset expired flows.
- **D-07:** After successful email change, invalidate all sessions except current. Same pattern as password change.
- **D-08:** Requires sudo mode (re-authentication). OAuth-only users re-auth via OAuth provider (Phase 4 D-21).
- **D-09:** Three email templates: (1) confirmation to new address with verification link, (2) notification to old address with cancel link, (3) post-change confirmation to new address ("Your email has been updated").
- **D-10:** Link-only confirmation (no code fallback). Same pattern as password reset (Phase 3 D-31). Simpler flow since user initiated while authenticated.

### Account Deletion
- **D-11:** Default strategy: soft delete. Configurable via `:deletion` config — `:soft_delete` | `:hard_delete` | `:anonymize`.
- **D-12:** Requires sudo mode. Success criteria #4 explicitly lists delete account as sudo-gated.
- **D-13:** Full cleanup on deletion request: revoke all sessions, delete all tokens, delete all OAuth identities, revoke all API keys. PubSub broadcast for LiveView disconnect. MFA data (TOTP secrets, passkeys) cleared at finalization only (preserved during grace period for seamless cancel).
- **D-14:** Configurable grace period: 14 days default. Account deactivated immediately (can't log in) but data not removed until grace period expires. GitHub/Heroku pattern.
- **D-15:** Login during grace period shows reactivation option: "Your account is scheduled for deletion on [date]. Want to cancel?" Re-authentication required to cancel.
- **D-16:** Full restore on cancel: clear deleted_at and scheduled_deletion_at, restore email from `original_email` field, send cancellation email. Sessions already revoked — user logs in fresh.
- **D-17:** Oban scheduled job for grace period execution. Job fires at scheduled_deletion_at, applies configured strategy. If Oban absent, developer runs cleanup task manually (documented).
- **D-18:** Anonymization: replace email with `deleted_{user_id}@deleted.invalid`, clear hashed_password, null optional fields. Keep user_id for referential integrity.
- **D-19:** Partial unique index on email: `WHERE deleted_at IS NULL` (PostgreSQL). Only enforces uniqueness on active users. MySQL/SQLite: application-level check or composite index.
- **D-20:** Three schema columns: `deleted_at` (utc_datetime, nullable), `scheduled_deletion_at` (utc_datetime, nullable), `original_email` (string, nullable).
- **D-21:** Three email templates: (1) deletion requested with cancel link and date, (2) deletion cancelled confirmation, (3) deletion finalized notification (sent to original_email before anonymization).
- **D-22:** Sudo + 24h cooldown rate limiting: after cancelling deletion, user can't re-request for 24 hours. Prevents abuse of request/cancel cycle.
- **D-23:** Re-registration allowed after finalization. Email becomes free in all strategies (hard delete removes row, soft delete/anonymize clears email).
- **D-24:** Pending email change auto-cancelled when deletion is requested. The change is moot if account is being deleted.
- **D-25:** OAuth-only users: standard deletion flow, OAuth re-auth for sudo, no provider-side token revocation (tokens expire naturally).
- **D-26:** Deletion audit: telemetry events `[:sigra, :account, :deletion_scheduled]` and `[:sigra, :account, :deleted]`. Phase 9 audit log captures these. No separate deletion_log table.
- **D-27:** Data export: `Sigra.DataExport` behaviour with `export_user_data/1` callback. Sigra exports its own auth data. Developer implements for app-specific data. Not tied to deletion — available anytime.
- **D-28:** Context API: `schedule_deletion/2`, `cancel_deletion/1`, `execute_deletion/1`, `deletion_scheduled?/1`, `deletion_status/1` (returns `{:scheduled, days_remaining}` | `:not_scheduled` | `:deleted`).
- **D-29:** Testing helpers: `scheduled_deletion_fixture/1`, `deleted_user_fixture/1`, `assert_deletion_scheduled/1`, `assert_deletion_cancelled/1`, `assert_account_deleted/1`, `simulate_grace_period_expiry/1`.
- **D-30:** Generated LiveView: account settings page with deletion section (danger zone styling), confirmation modal with sudo, cancel button, reactivation page for grace-period login.
- **D-31:** Config surface — `:deletion` section: `strategy` (default: `:soft_delete`), `grace_period_days` (default: 14), `cooldown_hours` (default: 24), `notify` (default: true). NimbleOptions validated. Note: `:before_delete` was merged into `:hooks` config as `:on_delete`.
- **D-32:** Hard delete: Sigra cascades its own tables (sessions, tokens, identities, API keys, TOTP, passkeys). Developer handles app FKs via `on_delete` hook.
- **D-33:** Anonymize-only strategy: same as soft delete but no grace period — executes immediately. PII stripped, row preserved for referential integrity.

### Password Change
- **D-34:** After successful password change, invalidate all sessions except current. Same pattern as password reset (Phase 3 D-29).
- **D-35:** No sudo required for password change — entering the current password IS the re-authentication. Adding sudo would mean entering password twice.
- **D-36:** OAuth-only users see "Set a password" (no current password field). Requires sudo (OAuth re-auth) since there's no current password to verify. Enables hybrid auth.
- **D-37:** Password change notification email always sent. Includes timestamp, IP, approximate location (if GeoIP), browser/OS (from UA). "If this wasn't you, reset your password immediately." Same pattern as suspicious login email (Phase 4 D-46).
- **D-38:** Force password change: `must_change_password` boolean on user. When true, `Sigra.Plug.RequirePasswordChange` redirects to password change form (same pattern as RequireSudo). Admin sets via context API. Flag cleared after successful change.
- **D-39:** Same validation rules as registration (Phase 2). Reuse `password_changeset/3`. No password history/reuse prevention (Phase 3 D-33). Real-time strength feedback.
- **D-40:** Context API: `change_password/3` (verify current, update hash, set password_changed_at, invalidate sessions), `set_password/2` (OAuth-only, requires sudo), `must_change_password?/1`, `require_password_change/1` (admin API to set flag).
- **D-41:** Schema: add `must_change_password` boolean (default: false) to users table.
- **D-42:** Config: extend existing `:password` section with `notify_on_change` (default: true) and `invalidate_sessions_on_change` (default: true).
- **D-43:** Telemetry: `[:sigra, :password, :change, :start/:stop]`, `[:sigra, :password, :set, :start/:stop]`, `[:sigra, :password, :force_change, :start/:stop]`, `[:sigra, :password, :force_change_completed, :stop]`.
- **D-44:** Testing helpers: `force_password_change_fixture/1`, `assert_password_changed/1`, `assert_sessions_invalidated/1`, `change_password/3`.
- **D-45:** Generated LiveView: password change form in settings. "Change password" for password users, "Set a password" for OAuth-only. Real-time strength feedback.

### Profile Update Hooks
- **D-46:** Config-based callbacks: `{module, function}` tuples in `:hooks` config section. Operations: `:on_register`, `:on_email_change`, `:on_password_change`, `:on_delete`. Each defaults to nil (no-op).
- **D-47:** Ecto.Multi integration: hook function receives `(multi, context_map)` where context_map includes user and operation-specific data. Returns `{:ok, multi}` with optional additional Multi steps. Runs AFTER the auth operation's Multi step (hook has persisted user with ID).
- **D-48:** Single hook per operation. Developer composes multiple actions inside their hook function. Predictable execution order.
- **D-49:** Abort via Multi failure: if hook step returns `{:error, ...}`, the entire auth transaction rolls back. Explicit contract — hooks can veto operations.
- **D-50:** Error reporting: auth operation returns `{:error, :hook_failed, changeset}`. Telemetry event `[:sigra, :hook, :failed]` with metadata (operation, module, error).
- **D-51:** Generator creates `MyApp.Auth.Hooks` with all hook functions stubbed and commented. Config points to generated module. Developer uncomments what they need.
- **D-52:** `:on_email_change` fires at confirmation (when email actually switches), not at request time.
- **D-53:** Testing helper: `Sigra.Testing.with_hook/3` temporarily overrides a hook for a test block via config swap. No Mox needed.
- **D-54:** `:before_delete` from deletion config merged into `:on_delete` in hooks config. One place for all lifecycle hooks.

### Account Settings Page
- **D-55:** Single page at `/users/settings` with vertically separated sections: Email, Password, Account Deletion. Each section is a self-contained form.
- **D-56:** Extend Phase 4's existing settings infrastructure. Link to sessions page (already generated). Incremental — doesn't replace what's there.
- **D-57:** Deletion section at bottom with red border/warning styling (danger zone). GitHub-style destructive section treatment.
- **D-58:** Inline status indicators: pending email change shown with cancel button, scheduled deletion shown with cancel button, force-password-change shown as banner.
- **D-59:** Email section: current email as read-only label. If pending, show "Changing to: new@example.com (awaiting confirmation)" with cancel. If no pending, show change form. Sudo on submit.
- **D-60:** Adaptive for OAuth-only users: password section shows "Set a password" instead of "Change password", no current password field. Linked accounts section references Phase 5 OAuth management page.
- **D-61:** Single URL with anchor links: `/users/settings#email`, `/users/settings#password`, `/users/settings#delete`. Email change confirmation: `/users/settings/confirm-email/:token`.

### Claude's Discretion
- Migration strategy: single migration template adding all 5 new columns (pending_email, deleted_at, scheduled_deletion_at, original_email, must_change_password) to users table. Update Phase 1 migration template (phases haven't shipped).
- Email change schema: `pending_email` (citext, nullable) with uniqueness index. Email change tokens use existing user_tokens with context "change_email" (already coded with 2-day TTL — adjust to 24h).
- Cross-feature interactions: password change during pending email change is allowed (doesn't affect pending change). Pending deletion blocks email/password changes (account deactivated). Force-password-change flag clears on any successful password change regardless of flow.
- Flash messages and specific error wording for settings page operations.
- Exact Oban job module naming and queue configuration for deletion.
- Additional telemetry events beyond those specified.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Dependencies
- `.planning/phases/03-email-flows-and-transactional-email/03-CONTEXT.md` — Email template patterns, token security (HMAC + SHA-256), Oban async delivery, confirmation/reset flow patterns
- `.planning/phases/04-session-management-and-security-baseline/04-CONTEXT.md` — Sudo mode (D-20 to D-23), session invalidation, rate limiting, suspicious login detection, cookie security, telemetry patterns

### Existing Implementation
- `lib/sigra/session_store.ex` — SessionStore behaviour with `delete_all_for_user/2` for session invalidation
- `lib/sigra/session_stores/ecto.ex` — Ecto implementation of session store
- `lib/sigra/plug/require_sudo.ex` — RequireSudo plug pattern (model for RequirePasswordChange)
- `lib/sigra/token.ex` — Signed token generation and verification
- `lib/sigra/email.ex` — Email normalization (trim, downcase, NFKC)
- `lib/sigra/email_templates.ex` — EmailTemplates behaviour (needs email change + deletion templates)
- `priv/templates/sigra.install/user.ex` — User schema with email_changeset, password_changeset, validate_current_password
- `priv/templates/sigra.install/user_token.ex` — UserToken schema, already has "change_email" context

### Requirements
- `.planning/REQUIREMENTS.md` — ACCT-01, ACCT-02, ACCT-03, ACCT-04, SESS-09 (already implemented)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SessionStore.delete_all_for_user/2` with `:except_token` option — reuse for session invalidation on email/password change
- `email_changeset/3` and `password_changeset/3` on User schema — extend for pending_email and must_change_password
- `validate_current_password/2` — reuse for password change verification
- Password reset flow in reset_password_controller — pattern for session invalidation + password_changed_at update
- EmailTemplates behaviour — extend with email change + deletion template callbacks
- `Sigra.Workers.EmailDelivery` — reuse for all new email types
- `Sigra.Workers.TokenCleanup` — extend for email change token cleanup
- `Sigra.Plug.RequireSudo` — model for `RequirePasswordChange` plug pattern
- User tokens with "change_email" context already defined with 2-day validity

### Established Patterns
- Hybrid lib+generator architecture: security logic in library, customizable code generated into host app
- Behaviour + config pattern for optional features (SessionStore, RateLimiter, GeoIP, EmailTemplates)
- Ecto.Multi for transactional operations
- Telemetry events with start/stop pattern for operations, one-shot for security events
- NimbleOptions for config validation
- Generated LiveView pages with "own your code" philosophy

### Integration Points
- Phase 1 migration template: add 5 new columns to users table
- Generated UserAuth module: add RequirePasswordChange plug
- Generated router: add email change confirmation route, settings routes
- Oban config: add deletion job queue
- Config: extend `:password` section, add `:deletion` and `:hooks` sections

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-account-lifecycle*
*Context gathered: 2026-04-08*
