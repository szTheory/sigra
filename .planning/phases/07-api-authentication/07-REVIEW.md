---
phase: 07-api-authentication
reviewed: 2026-04-08T12:00:00Z
depth: standard
files_reviewed: 40
files_reviewed_list:
  - lib/mix/tasks/sigra.install.ex
  - lib/sigra/api_token.ex
  - lib/sigra/api_token/scope_registry.ex
  - lib/sigra/auth.ex
  - lib/sigra/config.ex
  - lib/sigra/ecto/types/string_list.ex
  - lib/sigra/email_templates.ex
  - lib/sigra/error.ex
  - lib/sigra/install/injector.ex
  - lib/sigra/jwt.ex
  - lib/sigra/jwt/claims_builder.ex
  - lib/sigra/jwt/refresh_token.ex
  - lib/sigra/jwt/signer.ex
  - lib/sigra/plug/error_handler.ex
  - lib/sigra/plug/fetch_bearer.ex
  - lib/sigra/plug/require_scopes.ex
  - lib/sigra/telemetry.ex
  - lib/sigra/testing.ex
  - lib/sigra/workers/token_cleanup.ex
  - mix.exs
  - priv/templates/sigra.install/api_token_controller.ex
  - priv/templates/sigra.install/api_token_created_email.ex
  - priv/templates/sigra.install/api_token_migration.exs
  - priv/templates/sigra.install/auth_api_token.ex
  - priv/templates/sigra.install/token_controller.ex
  - priv/templates/sigra.install/user_api_token.ex
  - test/sigra/api_token/scope_registry_test.exs
  - test/sigra/api_token_test.exs
  - test/sigra/ecto/types/string_list_test.exs
  - test/sigra/install/api_token_generator_test.exs
  - test/sigra/jwt/refresh_token_test.exs
  - test/sigra/jwt/signer_test.exs
  - test/sigra/jwt_test.exs
  - test/sigra/plug/fetch_bearer_test.exs
  - test/sigra/plug/require_scopes_test.exs
  - test/sigra/testing_test.exs
  - test/sigra/workers/token_cleanup_test.exs
  - test/support/test_user.ex
  - test/support/test_user_token.ex
findings:
  critical: 3
  warning: 6
  info: 4
  total: 13
status: issues_found
---

# Phase 7: Code Review Report

**Reviewed:** 2026-04-08
**Depth:** standard
**Files Reviewed:** 40
**Status:** issues_found

## Summary

Phase 7 adds API token authentication (opaque tokens + JWT) to Sigra. The implementation is well-structured with good separation of concerns: `Sigra.APIToken` for opaque tokens, `Sigra.JWT` for JWT, `Sigra.Plug.FetchBearer` for auto-detection routing, and `Sigra.Plug.RequireScopes` for scope enforcement. Template generation, telemetry, cleanup workers, and testing helpers are all included.

Key concerns center around: (1) a SQL injection vector in the refresh token family revocation query, (2) missing authorization checks in the generated API token controller (any authenticated user can revoke any token by ID), and (3) the `api_token_timestamp` function can produce invalid timestamps due to a seconds overflow boundary condition. Several warnings around error handling and token hashing inconsistency are also flagged.

## Critical Issues

### CR-01: SQL Injection via LIKE pattern in revoke_family

**File:** `lib/sigra/jwt/refresh_token.ex:163`
**Issue:** The `revoke_family/3` function constructs a `LIKE` query by interpolating `family_id` directly into a pattern string: `like(t.sent_to, ^"%\"family_id\":\"#{family_id}\"%")`. While `family_id` is a UUID generated internally by `Ecto.UUID.generate()` (line 41), the function is public (`@doc` and `@spec` exported) and accepts arbitrary string input. If a caller passes a user-controlled string, the `%` and `_` wildcards in SQL LIKE are not escaped, and the string interpolation bypasses Ecto's parameterization for the pattern itself. More critically, this pattern-matching approach on JSON stored in a text field is fragile and could match unintended rows if the JSON structure changes.
**Fix:** Use a dedicated indexed column for `family_id` instead of querying JSON via LIKE. If schema changes are deferred, at minimum validate the family_id is a valid UUID before interpolation:

```elixir
# Immediate fix: validate UUID format
defp validate_uuid!(id) do
  case Ecto.UUID.cast(id) do
    {:ok, _} -> :ok
    :error -> raise ArgumentError, "invalid family_id: #{inspect(id)}"
  end
end

# In revoke_family:
validate_uuid!(family_id)
# Or better: store family_id as a proper column on the token schema
```

### CR-02: Missing authorization in generated APITokenController delete action

**File:** `priv/templates/sigra.install/api_token_controller.ex:71-78`
**Issue:** The `delete/2` action revokes a token by ID without verifying that the token belongs to the current user. Any authenticated API user can revoke any other user's token by guessing or enumerating token IDs (UUIDs, but still an authorization bypass). The `delete_all/2` action correctly scopes to the current user, but single-token deletion does not.
**Fix:** Add ownership verification before revocation:

```elixir
def delete(conn, %{"id" => id}) do
  user = conn.assigns.current_scope

  case Auth.revoke_api_token(id) do
    {:ok, token} ->
      # Verify ownership
      if to_string(token.user_id) == to_string(user.id) do
        json(conn, %{ok: true})
      else
        conn |> put_status(:not_found) |> json(%{error: "not_found"})
      end

    {:error, :not_found} ->
      conn |> put_status(:not_found) |> json(%{error: "not_found"})
  end
end
```

Alternatively, pass the user_id into `revoke_api_token` and scope the query.

### CR-03: Missing authorization in Sigra.APIToken.revoke -- no user scoping

**File:** `lib/sigra/api_token.ex:165-187`
**Issue:** `revoke/2` takes a `config` and `token_id` and revokes any token matching that ID, regardless of which user owns it. This is the library-level root cause of CR-02. The function should accept a user_id parameter and verify ownership, or the query should be scoped. Without this, even if the controller is fixed, other callers of this function could revoke tokens they do not own.
**Fix:** Add user scoping to the revoke function:

```elixir
@spec revoke(Sigra.Config.t(), term(), term()) :: {:ok, map()} | {:error, :not_found}
def revoke(config, token_id, user_id) do
  schema = Keyword.fetch!(config.api_token, :api_token_schema)

  case config.repo.get(schema, token_id) do
    nil -> {:error, :not_found}
    token when token.user_id != user_id -> {:error, :not_found}
    token ->
      # ... existing revocation logic
  end
end
```

## Warnings

### WR-01: api_token_timestamp can produce invalid timestamp at ss=59

**File:** `lib/mix/tasks/sigra.install.ex:566-568`
**Issue:** The `api_token_timestamp/0` function adds 1 second to the current time using `ss = min(ss + 1, 59)`. This works most of the time, but if `ss` is already 59, the timestamp stays at 59 rather than rolling over to the next minute. More importantly, if two users run `mix sigra.install --api` at the same second, they get the same timestamp, but this is a minor concern since the main migration has the same issue. The real problem is the logic assumes 1-second offset is sufficient but does not actually guarantee ordering relative to the main migration timestamp.
**Fix:** Use `:timer.sleep(1000)` before calling `:calendar.universal_time()`, or compute the offset from the main timestamp:

```elixir
defp api_token_timestamp do
  Process.sleep(1000)
  timestamp()
end
```

### WR-02: Unhandled crash in decode_cursor with malformed input

**File:** `lib/sigra/api_token.ex:354-358`
**Issue:** `decode_cursor/1` calls `Base.url_decode64!/2` (raises on invalid base64), `String.split/3` (could return fewer than 2 parts), `DateTime.from_iso8601/1` (pattern matches `{:ok, datetime, _}`), and `String.to_integer/1` (raises on non-numeric). Any malformed cursor from a client will crash the process with an unhandled exception rather than returning a clean error.
**Fix:** Wrap in a try/rescue or use non-bang functions:

```elixir
def decode_cursor(cursor) when is_binary(cursor) do
  with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
       [iso_string, id_string] <- String.split(decoded, "|", parts: 2),
       {:ok, datetime, _} <- DateTime.from_iso8601(iso_string),
       {id, ""} <- Integer.parse(id_string) do
    {datetime, id}
  else
    _ -> raise ArgumentError, "invalid cursor"
  end
end
```

### WR-03: Unsupervised Task.start for last_used_at update -- silent failures

**File:** `lib/sigra/api_token.ex:423-426`
**Issue:** `maybe_update_last_used/2` spawns an unsupervised `Task.start/1` to update the `last_used_at` timestamp. If the repo call fails (DB connection issue, etc.), the error is silently swallowed. While this is intentionally fire-and-forget for a non-critical update, the lack of any error logging means DB connection pool exhaustion or schema issues would be invisible.
**Fix:** Add minimal error logging:

```elixir
Task.start(fn ->
  try do
    changeset = Ecto.Changeset.change(token, last_used_at: DateTime.utc_now())
    config.repo.update(changeset)
  rescue
    e -> Logger.warning("Failed to update API token last_used_at: #{Exception.message(e)}")
  end
end)
```

### WR-04: Token hashing inconsistency between APIToken.create and Token.generate_hashed_token

**File:** `lib/sigra/api_token.ex:81-83`
**Issue:** In `do_create/4`, the code calls `Token.generate_hashed_token()` to get `{raw_random, _hash_of_random}`, then constructs `raw_key = prefix <> raw_random`, then calls `Token.hash_token(raw_key)` to hash the full prefixed key. This means the hash stored in the DB is the hash of the full key (prefix + random), which is correct for verification. However, the first hash (`_hash_of_random`) from `generate_hashed_token()` is generated and immediately discarded. This is wasteful but not incorrect. The concern is that `Token.generate_hashed_token()` likely uses `Base.url_encode64(:crypto.strong_rand_bytes(32))` and hashes that, while `Token.hash_token/1` hashes the prefixed string. If `Token.hash_token/1` uses a different algorithm than what `generate_hashed_token/0` uses internally, future maintenance could introduce bugs. The API could be cleaner.
**Fix:** Consider using `:crypto.strong_rand_bytes/1` directly instead of calling `generate_hashed_token()` and discarding half the result:

```elixir
raw_random = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
raw_key = prefix <> raw_random
hashed_token = Token.hash_token(raw_key)
```

### WR-05: Generated controller has unused `config` variable

**File:** `priv/templates/sigra.install/api_token_controller.ex:25`
**Issue:** The `index/2` action assigns `config = Auth.sigra_config()` but never uses the `config` variable. It uses `Auth.list_api_tokens/2` instead, which internally calls `sigra_config()` again. Same pattern in `create/2` at line 43.
**Fix:** Remove the unused variable:

```elixir
def index(conn, params) do
  user = conn.assigns.current_scope
  # ... rest without config
```

### WR-06: JWT generate_tokens does not pass user_token_schema opts through to RefreshToken.create

**File:** `lib/sigra/jwt.ex:86-88`
**Issue:** `generate_tokens/4` accepts `opts` and passes them to `RefreshToken.create/4`, which calls `Keyword.fetch!(opts, :user_token_schema)`. But the generated `auth_api_token.ex` template's `generate_jwt_tokens/2` (line 33-34) calls `Sigra.Auth.generate_jwt_tokens(sigra_config(), user, scopes)` without passing `user_token_schema` in opts. `Sigra.Auth.generate_jwt_tokens/3` (line 1134) calls `Sigra.JWT.generate_tokens(config, user, scopes)` also without opts. When refresh tokens are enabled (default), `RefreshToken.create` will raise `KeyError` because `:user_token_schema` is missing.
**Fix:** Either pass the user_token_schema through the call chain, or resolve it from config. The cleanest fix is to have `generate_tokens` pull it from config:

```elixir
# In Sigra.JWT.generate_tokens:
user_token_schema = Keyword.get(opts, :user_token_schema) ||
  Keyword.get(config.api_token, :user_token_schema) ||
  raise "user_token_schema required for refresh tokens"
```

## Info

### IN-01: Scope format regex does not support numeric characters in resource/action

**File:** `lib/sigra/api_token/scope_registry.ex:39`
**Issue:** The scope format regex `~r/^[a-z_]+:[a-z_]+$/` only allows lowercase letters and underscores. Scopes like `"v2_api:read"` would work, but `"api2:read"` would not because digits are not allowed. This is a design choice but may surprise users.
**Fix:** Consider expanding to `~r/^[a-z][a-z0-9_]*:[a-z][a-z0-9_]*$/` to allow digits.

### IN-02: UserAPIToken schema missing changeset function

**File:** `priv/templates/sigra.install/user_api_token.ex`
**Issue:** The generated `UserAPIToken` schema does not define a `changeset/2` function. `Sigra.APIToken.do_create/4` (line 88) calls `schema.changeset(struct(schema), attrs)`. This will raise `UndefinedFunctionError` at runtime. The test mock (`MockAPITokenSchema`) in `api_token_test.exs` does define `changeset/2`, which is why tests pass.
**Fix:** Add a changeset function to the generated schema template:

```elixir
def changeset(token, attrs) do
  token
  |> Ecto.Changeset.cast(attrs, [:user_id, :hashed_token, :prefix, :name, :scopes, :expires_at])
  |> Ecto.Changeset.validate_required([:user_id, :hashed_token, :name, :scopes])
  |> Ecto.Changeset.validate_length(:name, max: 255)
end
```

### IN-03: priv/templates not included in package files

**File:** `mix.exs:66`
**Issue:** The `package/0` function lists `files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)` but does not include `priv/`. The templates in `priv/templates/sigra.install/` are required by the `mix sigra.install` task. Without them, the published hex package will not be able to generate files.
**Fix:** Add `priv` to the files list:

```elixir
files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
```

### IN-04: Duplicate config schema definition

**File:** `lib/sigra/config.ex`
**Issue:** The NimbleOptions schema is defined twice: once in the `@moduledoc` (lines 18-498) for documentation, and again as `@schema` (lines 501-1065). These two copies must be kept in sync manually. Any change to one that is not reflected in the other creates documentation drift.
**Fix:** Define the schema once and reference it in the moduledoc:

```elixir
@schema [...]

@moduledoc """
...
## Options

#{NimbleOptions.docs(@schema)}
"""
```

---

_Reviewed: 2026-04-08_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
