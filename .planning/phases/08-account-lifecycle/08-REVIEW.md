---
phase: 08-account-lifecycle
reviewed: 2026-04-08T12:00:00Z
depth: standard
files_reviewed: 29
files_reviewed_list:
  - lib/sigra/account.ex
  - lib/sigra/account/deletion.ex
  - lib/sigra/account/email_change.ex
  - lib/sigra/account/password_change.ex
  - lib/sigra/auth.ex
  - lib/sigra/hooks.ex
  - lib/sigra/install/injector.ex
  - lib/sigra/plug/require_password_change.ex
  - lib/sigra/telemetry.ex
  - lib/sigra/testing.ex
  - lib/sigra/workers/account_deletion.ex
  - priv/templates/sigra.install/auth.ex
  - priv/templates/sigra.install/auth_fixtures.ex
  - priv/templates/sigra.install/auth_hooks.ex
  - priv/templates/sigra.install/emails.ex
  - priv/templates/sigra.install/migration.exs
  - priv/templates/sigra.install/reactivation_live.ex
  - priv/templates/sigra.install/settings_live.ex
  - priv/templates/sigra.install/user.ex
  - priv/templates/sigra.install/user_auth.ex
  - priv/templates/sigra.install/user_token.ex
  - test/sigra/account/deletion_test.exs
  - test/sigra/account/email_change_test.exs
  - test/sigra/account/password_change_test.exs
  - test/sigra/install/injector_test.exs
  - test/sigra/plug/require_password_change_test.exs
  - test/sigra/templates/settings_live_test.exs
  - test/sigra/workers/account_deletion_test.exs
  - test/support/mock_repo_behaviour.ex
  - test/support/test_user.ex
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-04-08T12:00:00Z
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

Phase 8 adds account lifecycle features (email change, password change, account deletion with grace period, hooks engine, generated templates). The library-layer modules (`Sigra.Account.*`, `Sigra.Hooks`, `Sigra.Workers.AccountDeletion`) are well-structured with clear separation of concerns, proper telemetry integration, and good test coverage via Mox.

However, there are **3 critical integration bugs** in the `Sigra.Auth` orchestration layer where required callback functions are not passed through to the underlying `Sigra.Account.*` modules. These will cause `KeyError` crashes at runtime when the generated `Auth` context calls the library functions. There are also several warnings around missing error handling and a hook execution issue.

## Critical Issues

### CR-01: Missing `build_email_token_fn` and `token_query_fn` in email change request flow

**File:** `lib/sigra/auth.ex:1180-1194`
**Issue:** `Sigra.Auth.request_email_change/4` merges only `changeset_fn`, `user_token_schema`, `secret_key_base`, and `config` into opts before delegating to `Sigra.Account.request_email_change/4`. The downstream `Sigra.Account.EmailChange.request/4` calls `Keyword.fetch!(opts, :build_email_token_fn)` (line 143 of email_change.ex) and `Keyword.fetch!(opts, :token_query_fn)` (line 144), both of which will raise `KeyError` because they are never provided. The generated `auth.ex` template (line 566) only passes `changeset_fn` and `user_token_schema`.
**Fix:** `Sigra.Auth.request_email_change/4` must construct and inject the required callback functions from the config/opts, similar to how other auth operations build their callbacks:
```elixir
def request_email_change(config, user, new_email, opts \\ []) do
  repo = config.repo
  user_token_schema = Keyword.fetch!(opts, :user_token_schema)

  merged_opts =
    Keyword.merge(
      [
        changeset_fn: Keyword.fetch!(opts, :changeset_fn),
        user_token_schema: user_token_schema,
        secret_key_base: config.secret_key_base,
        config: config,
        build_email_token_fn: fn user, context ->
          user_token_schema.build_email_token(user, context)
        end,
        token_query_fn: fn user, contexts ->
          user_token_schema.by_user_and_contexts_query(user, contexts)
        end,
        email_taken_fn: fn repo, email ->
          repo.get_by(config.user_schema, email: email) != nil
        end
      ],
      opts
    )

  Sigra.Account.request_email_change(repo, user, new_email, merged_opts)
end
```

### CR-02: Missing `find_user_by_token_fn`, `changeset_fn`, and `token_query_fn` in email change confirm flow

**File:** `lib/sigra/auth.ex:1206-1221`
**Issue:** `Sigra.Auth.confirm_email_change/3` passes `user_token_schema`, `user_schema`, `session_store`, and `config`, but `Sigra.Account.EmailChange.confirm/3` calls `Keyword.fetch!(opts, :find_user_by_token_fn)` (line 85 of email_change.ex), `Keyword.fetch!(opts, :changeset_fn)` (line 166), and `Keyword.fetch!(opts, :token_query_fn)` (line 167). All three will crash with `KeyError`.
**Fix:** Construct the required callbacks from the schema modules:
```elixir
def confirm_email_change(config, encoded_token, opts \\ []) do
  repo = config.repo
  user_token_schema = Keyword.fetch!(opts, :user_token_schema)

  merged_opts =
    Keyword.merge(
      [
        user_token_schema: user_token_schema,
        user_schema: config.user_schema,
        session_store: get_session_store(config),
        config: config,
        find_user_by_token_fn: fn repo, token ->
          # Look up user by email change token
          context_prefix = "change:"
          case user_token_schema.verify_email_token_query(token, context_prefix) do
            {:ok, query} -> repo.one(query)
            :error -> nil
          end
        end,
        changeset_fn: fn user, attrs ->
          Ecto.Changeset.change(user, attrs)
        end,
        token_query_fn: fn user, contexts ->
          user_token_schema.by_user_and_contexts_query(user, contexts)
        end
      ],
      opts
    )

  Sigra.Account.confirm_email_change(repo, encoded_token, merged_opts)
end
```

### CR-03: Missing `validate_password_fn` in password change flow

**File:** `lib/sigra/auth.ex:1255-1268`
**Issue:** `Sigra.Auth.change_password/5` merges `changeset_fn`, `session_store`, and `config`, but `Sigra.Account.PasswordChange.change/5` calls `Keyword.fetch!(opts, :validate_password_fn)` (line 46 of password_change.ex). This will crash with `KeyError`. The generated `auth.ex` template (line 606) also does not pass `validate_password_fn`.
**Fix:**
```elixir
def change_password(config, user, current_password, attrs, opts \\ []) do
  repo = config.repo

  merged_opts =
    Keyword.merge(
      [
        changeset_fn: Keyword.fetch!(opts, :changeset_fn),
        session_store: get_session_store(config),
        config: config,
        validate_password_fn: fn user, password ->
          config.user_schema.valid_password?(user, password)
        end
      ],
      opts
    )

  Sigra.Account.change_password(repo, user, current_password, attrs, merged_opts)
end
```

## Warnings

### WR-01: Hooks engine discards the Multi returned by hook functions

**File:** `lib/sigra/hooks.ex:63-68`
**Issue:** When a hook returns `{:ok, multi}`, the returned multi is discarded -- the code returns `{:ok, :hook_completed}` regardless. The hook's `multi` (which may contain additional DB operations) is never merged or executed. This makes the hook documentation misleading: it says hooks can "add steps" to a multi, but those steps are silently dropped.
**Fix:** Either execute the hook's multi within the `Multi.run` callback, or change the API to not accept multi from hooks:
```elixir
Multi.run(multi, step_name, fn repo, changes ->
  merged_context = Map.merge(context_map, %{changes: changes})

  case apply(mod, fun, [Multi.new(), merged_context]) do
    {:ok, hook_multi} ->
      # Execute the hook's multi within this transaction
      case repo.transaction(hook_multi) do
        {:ok, _} -> {:ok, :hook_completed}
        {:error, _step, reason, _} -> {:error, reason}
      end
    {:error, reason} -> {:error, reason}
  end
end)
```
Alternatively, if hooks should only signal success/failure without additional DB operations, simplify the callback contract to `(context_map) -> :ok | {:error, reason}` and update the documentation accordingly.

### WR-02: `cancel_email_change` deletes tokens using current email but pending email token may exist

**File:** `lib/sigra/account/email_change.ex:122`
**Issue:** The `cancel/3` function deletes tokens with context `"change:#{user.email}"`. However, the token was originally created in `do_request` (line 146) with context `"change:#{user.email}"` at request time. If the user's email was already changed by a different flow between request and cancel (unlikely but possible in concurrent scenarios), the token context would not match and orphaned tokens would remain.

This is a minor concern given the token has a TTL, but worth documenting or using a broader cleanup pattern.
**Fix:** Consider also cleaning up tokens with context matching `"change:%"` for the user, or document that TTL-based expiry handles orphaned tokens.

### WR-03: `deletion_changeset` in generated user.ex does not validate `must_change_password` or `email`

**File:** `priv/templates/sigra.install/user.ex:159-162`
**Issue:** The `deletion_changeset/2` casts `deleted_at`, `scheduled_deletion_at`, `original_email`, and `pending_email` but does not include `email` or `hashed_password`, which the anonymize strategy tries to set (see `deletion.ex:283-289`). When the anonymize strategy calls `changeset_fn.(user, %{email: anonymized_email, hashed_password: nil, ...})`, the `email` and `hashed_password` changes will be silently dropped by `cast/3`.
**Fix:** Either expand `deletion_changeset` to include `email` and `hashed_password`:
```elixir
def deletion_changeset(user, attrs) do
  user
  |> cast(attrs, [:deleted_at, :scheduled_deletion_at, :original_email, :pending_email, :email, :hashed_password])
end
```
Or use a separate changeset for the anonymize strategy that includes these fields.

### WR-04: `schedule_deletion` passes `config` as keyword list but `get_strategy` expects nested map access

**File:** `lib/sigra/account/deletion.ex:199`
**Issue:** `Hooks.maybe_run_hook(:delete, %{...}, config)` is called where `config` is the keyword list from `opts[:config]` (line 177). In `do_schedule`, `get_strategy(config)` at line 199 calls `get_in(config, [:deletion, :strategy])`. `get_in/2` works on keyword lists with atom keys, so `config[:deletion]` would return a keyword list, but then `get_in` tries to access `:strategy` on that result. If `config[:deletion]` is a keyword list (e.g., `[strategy: :soft_delete, ...]`), then `get_in(config, [:deletion, :strategy])` works. However, looking at the Oban worker (line 43), `config` is passed as `%{deletion: %{strategy: strategy}}` -- a map with map values. The inconsistency between keyword list configs (from normal flow) and map configs (from worker) means one path might silently return `nil` and default to `:soft_delete`.

This is not a crash but could lead to the wrong deletion strategy being applied if the config shape assumption changes.
**Fix:** Normalize config access or use a consistent data structure. Consider using `Keyword.get(config[:deletion] || [], :strategy, :soft_delete)` for explicit keyword-list handling, or validate config shape at entry points.

## Info

### IN-01: `@type` attribute should be `@type` not `@type` in Hooks module

**File:** `lib/sigra/hooks.ex:28-29`
**Issue:** Lines 28-29 use `@type hook :: ...` and `@type context_map :: ...`. In Elixir, module-level type attributes should use `@type` (which they do), but these are not used in `@spec` definitions. The `hook()` and `context_map()` types are defined but the specs on line 52 use inline types instead.
**Fix:** Either reference the types in the specs or keep them as documentation-only (current state is fine, but using the defined types in specs would be more consistent):
```elixir
@spec maybe_run_hook(Multi.t(), atom(), context_map(), keyword() | map()) :: Multi.t()
```

### IN-02: Duplicate `@doc since` annotations on delegated functions

**File:** `lib/sigra/account.ex:38-40`
**Issue:** Functions using `defdelegate` have both `@doc "..."` and `@doc since: "0.8.0"` on separate lines. The second `@doc` attribute overwrites the first in Elixir's documentation system. The doc string is lost and only the `since` metadata remains.
**Fix:** Combine into a single `@doc` attribute:
```elixir
@doc since: "0.8.0"
@doc "Request an email change. Sends verification to new address."
```
Or use the `@doc` attribute with metadata:
```elixir
@doc """
Request an email change. Sends verification to new address.
"""
@doc since: "0.8.0"
```
Note: In Elixir 1.18+, the second `@doc` with `since:` merges metadata with the preceding `@doc` string, so this may work correctly depending on Elixir version. Verify with `mix docs`.

### IN-03: Settings LiveView `confirm_delete` event does not refresh user assigns

**File:** `priv/templates/sigra.install/settings_live.ex:270-293`
**Issue:** After `Auth.schedule_deletion(user)` succeeds, the `deletion_status` is re-fetched using `Auth.deletion_status(user)` with the *original* user struct (line 279), not the updated one. Since the original user still has `deleted_at: nil`, the status will show `:not_scheduled` instead of `{:scheduled, days}`. The `scheduled_deletion_date` is correctly set from the return value, but the `deletion_status` assign will be stale.
**Fix:**
```elixir
{:ok, updated_user, scheduled_date} ->
  {:noreply,
   socket
   |> put_flash(:info, "Your account is scheduled for deletion on #{scheduled_date}.")
   |> assign(
     deletion_status: Auth.deletion_status(updated_user),
     scheduled_deletion_date: to_string(scheduled_date)
   )}
```

---

_Reviewed: 2026-04-08T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
