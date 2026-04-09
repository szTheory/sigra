# Phase 8: Account Lifecycle - Research

**Researched:** 2026-04-08
**Domain:** Account lifecycle operations (email change, password change, account deletion, profile hooks)
**Confidence:** HIGH

## Summary

Phase 8 implements four distinct account lifecycle features: email change with re-verification, password change with session invalidation, configurable account deletion (soft/hard/anonymize), and profile update hooks via Ecto.Multi integration. All sensitive operations are gated by sudo mode, which was already implemented in Phase 4.

The codebase is well-prepared for this phase. The existing `email_changeset/3`, `password_changeset/3`, `validate_current_password/2`, and `SessionStore.delete_all_for_user/2` functions provide the foundation. The `user_tokens` table already supports `"change:"` prefixed contexts with 2-day TTL (needs adjustment to 24h per D-03). The `Sigra.Plug.RequireSudo` plug provides the pattern for the new `RequirePasswordChange` plug. Email delivery via `Sigra.Delivery` and the `EmailTemplates` behaviour are established patterns to extend.

**Primary recommendation:** Build each feature as an independent module in the library (`Sigra.AccountLifecycle.EmailChange`, `Sigra.AccountLifecycle.PasswordChange`, `Sigra.AccountLifecycle.Deletion`) following the established pattern where the library module owns the security logic and the generated context module delegates to it. Profile hooks should be a thin `Sigra.Hooks` module that wraps Ecto.Multi step injection. The migration template from Phase 1 should be updated to include the 5 new user columns rather than creating a separate migration.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 to D-10:** Email change uses confirm-then-switch pattern. Old address gets notification with cancel link. 24h token TTL. One pending change at a time. New email reserved via `pending_email` field. Requires sudo mode. Three email templates. Link-only confirmation.
- **D-11 to D-33:** Account deletion with configurable strategy (soft_delete/hard_delete/anonymize). Grace period (14 days default). Oban job for finalization. Reactivation during grace period. Partial unique index on email. Three deletion email templates. Cooldown rate limiting. Data export behaviour.
- **D-34 to D-45:** Password change invalidates all sessions except current. No sudo required (current password IS re-auth). OAuth-only users see "Set a password" (requires sudo). Force password change via `must_change_password` flag. Notification email always sent.
- **D-46 to D-54:** Profile hooks via config-based `{module, function}` tuples. Ecto.Multi integration. Single hook per operation. Abort via Multi failure. Generated `MyApp.Auth.Hooks` stub module. `:on_email_change` fires at confirmation.
- **D-55 to D-61:** Single settings page at `/users/settings` with Email, Password, Deletion sections. Inline status indicators. Adaptive for OAuth-only users.

### Claude's Discretion
- Migration strategy: single migration template adding all 5 new columns to users table. Update Phase 1 migration template.
- Email change schema: `pending_email` (citext, nullable) with uniqueness index. Reuse existing `"change_email"` token context (adjust TTL to 24h).
- Cross-feature interactions: password change during pending email allowed, pending deletion blocks changes, force-password-change clears on any successful change.
- Flash messages, error wording, Oban job naming, queue config, additional telemetry events.

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ACCT-01 | Email change with re-verification (send to new address, keep old until confirmed) | D-01 to D-10: confirm-then-switch, `pending_email` field, 24h token, cancel link to old address, three email templates |
| ACCT-02 | Password change with current password verification | D-34 to D-45: verify current password, invalidate other sessions, notification email, OAuth "Set a password" flow, `must_change_password` flag |
| ACCT-03 | Account deletion with configurable handling (soft delete, hard delete, anonymization) | D-11 to D-33: three strategies, grace period, Oban finalization job, reactivation, partial index, data export behaviour |
| ACCT-04 | Profile management hooks (callbacks for app-specific profile updates) | D-46 to D-54: config-based `{module, function}` tuples, Ecto.Multi integration, generated stub module |
| SESS-09 | Sudo/re-authentication mode for sensitive operations | Already implemented in Phase 4 (D-20 to D-23). This phase USES it but does not build it. `Sigra.Plug.RequireSudo` exists. |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| ecto | ~> 3.12 | Ecto.Multi for transactional operations | Already a dep [VERIFIED: mix.exs] |
| oban | ~> 2.17 | Scheduled deletion job, email delivery | Already optional dep [VERIFIED: mix.exs] |
| swoosh | ~> 1.5 | Email delivery for change/deletion notifications | Already optional dep [VERIFIED: mix.exs] |
| nimble_options | ~> 1.1 | Config validation for `:deletion` and `:hooks` sections | Already a dep [VERIFIED: mix.exs] |
| hammer | ~> 7.3 | Cooldown rate limiting for deletion cancel/re-request | Already optional dep [VERIFIED: mix.exs] |

### No New Dependencies
This phase requires no new library dependencies. All functionality builds on existing deps and Elixir/Erlang stdlib. [VERIFIED: codebase audit]

## Architecture Patterns

### Recommended Project Structure
```
lib/sigra/
├── account.ex                    # Account lifecycle orchestrator (email change, password change, deletion)
├── account/
│   ├── email_change.ex           # Email change logic (request, confirm, cancel)
│   ├── password_change.ex        # Password change + set password for OAuth users
│   └── deletion.ex               # Deletion scheduling, cancellation, execution
├── data_export.ex                # DataExport behaviour
├── hooks.ex                      # Hook execution engine (Multi integration)
├── plug/
│   └── require_password_change.ex # RequirePasswordChange plug (mirrors RequireSudo)
├── workers/
│   └── account_deletion.ex       # Oban worker for grace period execution

priv/templates/sigra.install/
├── user.ex                       # Extended with pending_email, deleted_at, etc.
├── migration.exs                 # Extended with 5 new columns
├── auth.ex                       # Extended with account lifecycle context functions
├── auth_hooks.ex                 # NEW: Generated hooks stub module
├── email_change_email.ex         # NEW: 3 email change templates
├── deletion_email.ex             # NEW: 3 deletion email templates
├── password_change_email.ex      # NEW: Password change notification template
├── settings_live.ex              # NEW: Account settings LiveView page
```

### Pattern 1: Library Module + Generated Context Delegation
**What:** Security logic in library modules, generated context delegates to them
**When to use:** All account lifecycle operations
**Example:**
```elixir
# Source: Existing pattern in lib/sigra/auth.ex and priv/templates/sigra.install/auth.ex
# Library module (lib/sigra/account.ex)
defmodule Sigra.Account do
  def request_email_change(repo, user, new_email, opts) do
    # Validate, create token, store pending_email -- all in library
  end
end

# Generated context (priv/templates/sigra.install/auth.ex)
def request_email_change(user, new_email) do
  Sigra.Account.request_email_change(Repo, user, new_email,
    user_token_schema: UserToken,
    changeset_fn: &User.pending_email_changeset/2,
    secret_key_base: Endpoint.config(:secret_key_base)
  )
end
```
[VERIFIED: pattern observed in auth.ex]

### Pattern 2: Ecto.Multi for Transactional Operations
**What:** All multi-step operations wrapped in Ecto.Multi for atomicity
**When to use:** Email change confirmation, password change, deletion scheduling/execution
**Example:**
```elixir
# Source: Existing pattern in generated auth.ex update_user_password/3
Ecto.Multi.new()
|> Ecto.Multi.update(:user, changeset)
|> Ecto.Multi.delete_all(:tokens, token_query)
|> maybe_run_hook(multi, :on_password_change, %{user: user})
|> Repo.transaction()
```
[VERIFIED: pattern in priv/templates/sigra.install/auth.ex lines 210-224]

### Pattern 3: Hook Injection via Ecto.Multi
**What:** Profile hooks receive `(multi, context_map)` and append steps
**When to use:** All lifecycle operations that support hooks (D-46 to D-54)
**Example:**
```elixir
# Library module (lib/sigra/hooks.ex)
defmodule Sigra.Hooks do
  def maybe_run_hook(multi, operation, context_map, config) do
    case get_hook(config, operation) do
      nil -> multi
      {mod, fun} ->
        case apply(mod, fun, [multi, context_map]) do
          {:ok, multi} -> multi
          {:error, reason} -> Ecto.Multi.run(multi, :hook_failed, fn _, _ -> {:error, reason} end)
        end
    end
  end
end
```
[ASSUMED: based on D-46 to D-49 design decisions]

### Pattern 4: RequirePasswordChange Plug (mirrors RequireSudo)
**What:** Redirect to password change form when `must_change_password` is true
**When to use:** Force password change after admin sets flag
**Example:**
```elixir
# Source: Modeled on lib/sigra/plug/require_sudo.ex
defmodule Sigra.Plug.RequirePasswordChange do
  @behaviour Plug

  def call(conn, opts) do
    user = conn.assigns[:current_scope] && conn.assigns[:current_scope].user
    if user && user.must_change_password do
      conn
      |> error_handler.auth_error(:must_change_password, opts)
      |> Plug.Conn.halt()
    else
      conn
    end
  end
end
```
[VERIFIED: RequireSudo pattern in lib/sigra/plug/require_sudo.ex]

### Anti-Patterns to Avoid
- **Checking `pending_email` without partial index:** PostgreSQL partial unique index on email `WHERE deleted_at IS NULL` is required to prevent conflicts. MySQL/SQLite need application-level enforcement. [VERIFIED: D-19]
- **Storing pending_email in tokens table:** The `pending_email` field belongs on the user record (not in tokens) to enable reservation (D-05). The token table holds the change verification token.
- **Running hooks outside the transaction:** Hooks MUST run inside the Ecto.Multi transaction so rollback works (D-49).
- **Sending emails inside the transaction:** Email delivery should happen AFTER successful transaction commit, not inside the Multi.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Grace period scheduling | Custom GenServer timer | Oban scheduled job (`scheduled_at:`) | Oban handles process crashes, node restarts, and provides observability [VERIFIED: D-17] |
| Token generation | Custom random string | `Sigra.Token.generate_hashed_token/0` | Already handles SHA-256 hashing, URL-safe encoding, constant-time comparison [VERIFIED: lib/sigra/token.ex] |
| Session invalidation | Manual delete queries | `SessionStore.delete_all_for_user/2` with `:except_token` | Already handles the "all except current" pattern [VERIFIED: lib/sigra/session_store.ex] |
| Email delivery | Direct Swoosh calls | `Sigra.Delivery.deliver/3` | Handles async/sync mode, Oban integration, telemetry [VERIFIED: lib/sigra/delivery.ex] |
| Sudo mode check | Custom timestamp comparison | `Sigra.Plug.RequireSudo` | Already implemented with configurable window [VERIFIED: lib/sigra/plug/require_sudo.ex] |
| Password hashing | Direct Argon2 calls | `Sigra.Crypto.hash_password/1` | Handles algorithm selection, hash migration [VERIFIED: CLAUDE.md] |

## Common Pitfalls

### Pitfall 1: Email Reservation Race Condition
**What goes wrong:** Two users simultaneously try to claim the same email via pending_email, or one tries to register while the other has it pending.
**Why it happens:** `pending_email` uniqueness must be enforced at the database level, not just application level.
**How to avoid:** Add a unique index on `pending_email` (partial: `WHERE pending_email IS NOT NULL` on PostgreSQL). Also check pending_email values during registration. [VERIFIED: D-05]
**Warning signs:** Duplicate email errors in production logs, or worse, two accounts with the same email.

### Pitfall 2: Email Change Token Sent-To Mismatch
**What goes wrong:** The existing `verify_email_token_query` checks `token.sent_to == user.email`, but for email change the token is sent to the NEW address while the user's current email is the OLD address.
**Why it happens:** The existing token verification pattern assumes the token is sent to the user's current email.
**How to avoid:** Use `"change:#{current_email}"` as the context (already coded in UserToken template line 138). The `sent_to` field should store the NEW email. The verification query must match on context, not on `sent_to == user.email`. [VERIFIED: priv/templates/sigra.install/user_token.ex line 138]
**Warning signs:** Email change tokens always fail verification.

### Pitfall 3: Deletion During Grace Period - Session State
**What goes wrong:** User's sessions are revoked at deletion request (D-13) but grace period login shows reactivation option (D-15). If session revocation is incomplete, user might access the app during deletion.
**Why it happens:** Multiple tables need cleanup (sessions, tokens, API keys) and any missed cleanup creates a window.
**How to avoid:** Use Ecto.Multi to atomically: (1) set `deleted_at` and `scheduled_deletion_at`, (2) revoke all sessions, (3) delete all tokens, (4) revoke API keys. Wrap in a single transaction. [VERIFIED: D-13]
**Warning signs:** Users access protected pages after requesting deletion.

### Pitfall 4: Partial Index Portability
**What goes wrong:** `WHERE deleted_at IS NULL` partial index works on PostgreSQL but not MySQL or SQLite.
**Why it happens:** MySQL does not support partial/filtered indexes.
**How to avoid:** Conditional migration generation per adapter (established pattern in existing migration template). For MySQL/SQLite, use a composite index on `(email, deleted_at)` with application-level uniqueness enforcement for active users. [VERIFIED: D-19, existing migration.exs has adapter-specific branches]
**Warning signs:** Unique constraint errors on MySQL when trying to create the partial index.

### Pitfall 5: Hook Errors Masking Auth Errors
**What goes wrong:** When a hook fails, the error returned is generic `{:error, :hook_failed, changeset}` (D-50) which doesn't tell the user what went wrong with the auth operation.
**Why it happens:** The hook runs after the auth operation's Multi step, so if the hook fails, the auth operation was "successful" but rolled back.
**How to avoid:** The Multi should name the hook step distinctly (e.g., `:on_password_change_hook`) so the error tuple from `Repo.transaction/1` identifies the source. Return the hook's error changeset, not a generic one. [VERIFIED: D-50]
**Warning signs:** Vague error messages on settings page after operations that trigger hooks.

### Pitfall 6: Token TTL Mismatch
**What goes wrong:** The existing `@change_email_validity_in_days 2` in `user_token.ex` (line 10) conflicts with D-03's 24-hour TTL decision.
**Why it happens:** The template was generated with a default 2-day TTL. CONTEXT.md explicitly decides 24h.
**How to avoid:** Update the constant to `@change_email_validity_in_hours 24` or make it configurable via the `:email_change_ttl` config key. [VERIFIED: priv/templates/sigra.install/user_token.ex line 10 vs D-03]
**Warning signs:** Email change tokens remain valid longer than intended.

## Code Examples

### Email Change Request (Library Module)
```elixir
# Source: Pattern from existing auth.ex + D-01 to D-10 decisions
def request_email_change(repo, user, new_email, opts) do
  changeset_fn = Keyword.fetch!(opts, :changeset_fn)
  user_token_schema = Keyword.fetch!(opts, :user_token_schema)
  secret_key_base = Keyword.fetch!(opts, :secret_key_base)

  Telemetry.span([:sigra, :email_change, :request], %{user_id: user.id}, fn ->
    changeset = changeset_fn.(user, %{pending_email: new_email})

    with {:ok, _} <- validate_not_current_email(user, new_email),
         {:ok, _} <- validate_email_not_taken(repo, new_email, opts) do
      {encoded_token, token_struct} =
        user_token_schema.build_email_token(user, "change:#{user.email}")

      Ecto.Multi.new()
      |> Ecto.Multi.update(:user, changeset)
      |> Ecto.Multi.delete_all(:old_tokens,
           user_token_schema.by_user_and_contexts_query(user, ["change:#{user.email}"]))
      |> Ecto.Multi.insert(:token, %{token_struct | sent_to: new_email})
      |> repo.transaction()
      |> case do
        {:ok, %{user: user}} -> {:ok, user, encoded_token}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    end
  end)
end
```
[ASSUMED: synthesized from existing patterns]

### Deletion Scheduling (Library Module)
```elixir
# Source: Pattern from D-11 to D-17 decisions
def schedule_deletion(repo, user, opts) do
  grace_days = Keyword.get(opts, :grace_period_days, 14)
  scheduled_at = DateTime.add(DateTime.utc_now(), grace_days * 86400, :second)

  Ecto.Multi.new()
  |> Ecto.Multi.update(:user, Ecto.Changeset.change(user, %{
       deleted_at: DateTime.utc_now() |> DateTime.truncate(:second),
       scheduled_deletion_at: scheduled_at |> DateTime.truncate(:second),
       original_email: user.email
     }))
  |> Ecto.Multi.run(:revoke_sessions, fn _repo, _ ->
       session_store.delete_all_for_user(user.id, opts)
       {:ok, :revoked}
     end)
  |> Ecto.Multi.delete_all(:tokens, token_query)
  |> Ecto.Multi.run(:cancel_pending_email, fn repo, _ ->
       # D-24: Cancel any pending email change
       repo.update_all(
         from(u in user.__struct__, where: u.id == ^user.id),
         set: [pending_email: nil]
       )
       {:ok, :cancelled}
     end)
  |> maybe_schedule_oban_job(scheduled_at, user, opts)
  |> Hooks.maybe_run_hook(:on_delete, %{user: user}, opts)
  |> repo.transaction()
end
```
[ASSUMED: synthesized from D-11 to D-17 and existing Multi patterns]

### Oban Deletion Worker
```elixir
# Source: Pattern from lib/sigra/workers/token_cleanup.ex
defmodule Sigra.Workers.AccountDeletion do
  use Oban.Worker,
    queue: :sigra_lifecycle,
    max_attempts: 3,
    unique: [period: 300, keys: [:user_id]]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "strategy" => strategy}}) do
    # Fetch user, verify still scheduled, execute strategy
  end
end
```
[ASSUMED: modeled on existing Oban worker pattern]

### RequirePasswordChange Plug
```elixir
# Source: Modeled on lib/sigra/plug/require_sudo.ex
defmodule Sigra.Plug.RequirePasswordChange do
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)

    case conn.assigns[:current_scope] do
      %{user: %{must_change_password: true}} ->
        conn
        |> error_handler.auth_error(:must_change_password, opts)
        |> Plug.Conn.halt()
      _ ->
        conn
    end
  end
end
```
[VERIFIED: mirrors RequireSudo pattern from lib/sigra/plug/require_sudo.ex]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Immediate hard delete | Grace period + configurable strategy | Industry standard (GitHub, Heroku) | Prevents accidental data loss, enables recovery |
| Password change without notification | Always notify on password change | OWASP recommendation | Detects compromised accounts faster |
| Email change via direct update | Confirm-then-switch with dual notification | Industry standard (GitHub, GitLab) | Prevents account takeover via email change |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Ecto.Multi step naming allows distinguishing hook failures from auth operation failures in transaction error tuples | Architecture Patterns / Pattern 3 | Hook errors would be indistinguishable from auth errors, making debugging harder |
| A2 | Oban `unique` option with `keys: [:user_id]` prevents duplicate deletion jobs | Code Examples | Could schedule multiple deletion jobs for same user |
| A3 | `pending_email` partial unique index (`WHERE pending_email IS NOT NULL`) works correctly on PostgreSQL | Pitfalls | Email reservation race condition not prevented |

## Open Questions

1. **Oban queue naming for deletion jobs**
   - What we know: Existing workers use `queue: :sigra_mailer` for email. Deletion is a different concern.
   - What's unclear: Whether to use a separate queue (`:sigra_lifecycle`) or share the mailer queue.
   - Recommendation: Use `:sigra_lifecycle` -- separate concern, different retry semantics, easier to configure independently. Claude's discretion per CONTEXT.md.

2. **`pending_email` type on MySQL/SQLite**
   - What we know: PostgreSQL uses `citext` for case-insensitive email. MySQL uses `:string` with size 160.
   - What's unclear: Whether MySQL's `pending_email` column needs explicit case-insensitive collation.
   - Recommendation: Follow existing migration pattern -- `:string` with size 160 on MySQL, `:string` with `collate: :nocase` on SQLite. Application-level normalization via `Sigra.Email.normalize/1` handles case. [VERIFIED: existing migration.exs adapter branches]

3. **Data export format**
   - What we know: D-27 defines `Sigra.DataExport` behaviour with `export_user_data/1`.
   - What's unclear: What format the export should return (map, JSON string, file path).
   - Recommendation: Return a map -- callers can serialize to JSON/CSV as needed. Most flexible. Claude's discretion.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All | Yes | 1.19.5 | -- |
| Erlang/OTP | All | Yes | 28 | -- |
| PostgreSQL | Partial indexes | Not checked locally | -- | MySQL/SQLite with app-level check |

**Missing dependencies with no fallback:** None
**Missing dependencies with fallback:** None -- all deps already in mix.exs

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in, Elixir 1.19.5) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/sigra/account_test.exs --trace` |
| Full suite command | `mix test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ACCT-01 | Email change request, confirm, cancel | unit | `mix test test/sigra/account/email_change_test.exs -x` | No -- Wave 0 |
| ACCT-02 | Password change with current verification | unit | `mix test test/sigra/account/password_change_test.exs -x` | No -- Wave 0 |
| ACCT-03 | Account deletion schedule/cancel/execute | unit | `mix test test/sigra/account/deletion_test.exs -x` | No -- Wave 0 |
| ACCT-04 | Profile hooks via Multi integration | unit | `mix test test/sigra/hooks_test.exs -x` | No -- Wave 0 |
| SESS-09 | Sudo mode (already implemented) | unit | `mix test test/sigra/plug/require_sudo_test.exs -x` | Yes |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/account/ --trace`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/account/email_change_test.exs` -- covers ACCT-01
- [ ] `test/sigra/account/password_change_test.exs` -- covers ACCT-02
- [ ] `test/sigra/account/deletion_test.exs` -- covers ACCT-03
- [ ] `test/sigra/hooks_test.exs` -- covers ACCT-04
- [ ] `test/sigra/plug/require_password_change_test.exs` -- covers D-38
- [ ] `test/sigra/workers/account_deletion_test.exs` -- covers D-17

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Re-authentication via sudo mode for email change and deletion; current password for password change |
| V3 Session Management | yes | Session invalidation on password/email change via `SessionStore.delete_all_for_user/2` |
| V4 Access Control | yes | `RequirePasswordChange` plug gates access until password changed |
| V5 Input Validation | yes | Email validation via `Sigra.Email.normalize/1` + Ecto changeset; password via `Sigra.PasswordPolicy` |
| V6 Cryptography | no | No new crypto -- reuses existing `Sigra.Token` and `Sigra.Crypto` |

### Known Threat Patterns for Account Lifecycle

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Account takeover via email change | Spoofing | Confirm-then-switch: old email stays active until new confirmed (D-01). Sudo required (D-08). Cancel link to old address (D-02). |
| Email enumeration via pending_email | Information Disclosure | Do not reveal whether an email is already pending. Use generic error messages. |
| Deletion abuse (request/cancel cycle) | Denial of Service | 24h cooldown after cancelling deletion before re-requesting (D-22) |
| Session persistence after password change | Elevation of Privilege | Invalidate all sessions except current on password change (D-34) |
| Hook injection / arbitrary code execution | Tampering | Hooks are config-time `{module, function}` tuples, not runtime strings. Developer controls what code runs. |
| Grace period bypass | Tampering | `deleted_at` check in auth flow prevents login. Reactivation requires re-authentication (D-15). |

## Sources

### Primary (HIGH confidence)
- Codebase audit: `lib/sigra/session_store.ex`, `lib/sigra/token.ex`, `lib/sigra/auth.ex`, `lib/sigra/plug/require_sudo.ex`, `lib/sigra/delivery.ex`, `lib/sigra/workers/token_cleanup.ex`
- Template audit: `priv/templates/sigra.install/user.ex`, `priv/templates/sigra.install/user_token.ex`, `priv/templates/sigra.install/auth.ex`, `priv/templates/sigra.install/migration.exs`
- CONTEXT.md: 61 locked decisions (D-01 to D-61)
- mix.exs: dependency verification

### Secondary (MEDIUM confidence)
- CLAUDE.md: Technology stack recommendations and version constraints
- REQUIREMENTS.md: ACCT-01 to ACCT-04, SESS-09

### Tertiary (LOW confidence)
None -- all claims verified against codebase or cited from project docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new deps, all verified in mix.exs
- Architecture: HIGH -- follows established patterns verified in codebase
- Pitfalls: HIGH -- identified from codebase analysis (token TTL mismatch, partial index portability)

**Research date:** 2026-04-08
**Valid until:** 2026-05-08 (stable -- internal codebase, no external API changes)
