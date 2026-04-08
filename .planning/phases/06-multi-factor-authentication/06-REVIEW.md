---
phase: 06-multi-factor-authentication
reviewed: 2026-04-08T14:30:00Z
depth: standard
files_reviewed: 44
files_reviewed_list:
  - lib/mix/tasks/sigra.install.ex
  - lib/sigra/auth.ex
  - lib/sigra/config.ex
  - lib/sigra/error.ex
  - lib/sigra/mfa.ex
  - lib/sigra/mfa/backup_codes.ex
  - lib/sigra/mfa/credential.ex
  - lib/sigra/mfa/lockout.ex
  - lib/sigra/mfa/trust.ex
  - lib/sigra/plug/fetch_session.ex
  - lib/sigra/plug/require_mfa.ex
  - lib/sigra/plug/require_mfa_enrolled.ex
  - lib/sigra/plug/require_sudo.ex
  - lib/sigra/session.ex
  - lib/sigra/telemetry.ex
  - lib/sigra/testing.ex
  - lib/sigra/workers/token_cleanup.ex
  - mix.exs
  - priv/templates/sigra.install/auth.ex
  - priv/templates/sigra.install/auth_fixtures.ex
  - priv/templates/sigra.install/emails.ex
  - priv/templates/sigra.install/mfa_challenge_controller.ex
  - priv/templates/sigra.install/mfa_challenge_html.ex
  - priv/templates/sigra.install/mfa_challenge_live.ex
  - priv/templates/sigra.install/mfa_settings_html.ex
  - priv/templates/sigra.install/mfa_settings_live.ex
  - priv/templates/sigra.install/migration.exs
  - priv/templates/sigra.install/user_auth.ex
  - priv/templates/sigra.install/user_backup_code.ex
  - priv/templates/sigra.install/user_mfa_credential.ex
  - test/sigra/auth_test.exs
  - test/sigra/install/generator_email_test.exs
  - test/sigra/install/generator_mfa_test.exs
  - test/sigra/mfa/backup_codes_test.exs
  - test/sigra/mfa/config_test.exs
  - test/sigra/mfa/credential_test.exs
  - test/sigra/mfa/error_test.exs
  - test/sigra/mfa/lockout_test.exs
  - test/sigra/mfa/trust_test.exs
  - test/sigra/mfa_test.exs
  - test/sigra/plug/require_mfa_enrolled_test.exs
  - test/sigra/plug/require_mfa_test.exs
  - test/sigra/telemetry_test.exs
  - test/sigra/testing_test.exs
findings:
  critical: 2
  warning: 6
  info: 5
  total: 13
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-04-08T14:30:00Z
**Depth:** standard
**Files Reviewed:** 44
**Status:** issues_found

## Summary

Phase 6 adds Multi-Factor Authentication (TOTP, backup codes, trust cookies, lockout, MFA pending sessions) to Sigra. The implementation is architecturally sound -- security-critical operations live in the library, generated templates handle UI, and the MFA lifecycle (enroll, verify, disable) is well-structured.

Two critical security issues were found: (1) the MFA credential stores the TOTP secret using `struct/2` + `Ecto.Changeset.change/1` which bypasses cloak_ecto encryption, meaning secrets are stored in plaintext, and (2) the backup code generation has a modulo bias that reduces the effective keyspace. Six warnings address missing transaction boundaries, a non-atomic lockout increment, incomplete MFA session gating in generated templates, and an undefined template binding. Five informational items cover dead code, incomplete feature wiring, and minor naming issues.

## Critical Issues

### CR-01: TOTP Secret Stored Unencrypted -- Bypasses cloak_ecto

**File:** `lib/sigra/mfa.ex:117-123`
**Issue:** In `confirm_enrollment/5`, the MFA credential is created by building a bare struct via `struct(mfa_credential_schema, credential_params)` followed by `Ecto.Changeset.change()`. This bypasses the `create_changeset/2` function defined in the generated `UserMFACredential` schema, which uses `cast/3` -- and more importantly, it bypasses cloak_ecto's transparent encryption. The `encrypted_secret` field is declared as `Encrypted.Binary` in the generated schema (line 22 of `user_mfa_credential.ex`), but cloak_ecto only encrypts values that go through Ecto's type casting pipeline. By using `struct/2` + `Ecto.Changeset.change/1`, the raw binary secret is written directly to the database without encryption.

The same pattern appears in `Sigra.Testing.setup_totp/2` at `lib/sigra/testing.ex:252-256`.

**Fix:**
```elixir
# In lib/sigra/mfa.ex, confirm_enrollment/5 (line ~117-123):
# Replace struct + change with proper changeset that triggers cloak_ecto:
{:ok, db_credential} =
  mfa_credential_schema.create_changeset(%{
    user_id: user.id,
    type: "totp",
    encrypted_secret: raw_secret,
    last_verified_step: step,
    failed_attempts: 0,
    locked_until: nil,
    enabled_at: now
  })
  |> repo.insert()
```

Alternatively, use `Ecto.Changeset.cast/3` with the schema struct so the `Encrypted.Binary` type's `dump/1` callback is invoked.

### CR-02: Backup Code Generation Has Modulo Bias

**File:** `lib/sigra/mfa/backup_codes.ex:41-48`
**Issue:** The backup code is generated as `:crypto.strong_rand_bytes(4) |> :binary.decode_unsigned() |> rem(100_000_000)`. A 4-byte unsigned integer has a max value of 4,294,967,295. Since 4,294,967,296 mod 100,000,000 = 94,967,296, the first ~95 million values (0-94,967,295) are slightly more likely than the remaining ~5 million. This creates a ~2.2% bias toward certain codes. While not catastrophic, for a security library this violates the principle of uniform random generation.

The same pattern exists in `lib/sigra/auth.ex:311-314` for confirmation code generation.

**Fix:**
```elixir
# Use rejection sampling to eliminate modulo bias:
defp uniform_random(range) do
  bytes = :crypto.strong_rand_bytes(4)
  n = :binary.decode_unsigned(bytes)
  # Reject values that would cause bias
  if n >= div(4_294_967_296, range) * range do
    uniform_random(range)
  else
    rem(n, range)
  end
end

# Then in generate/1:
raw_int = uniform_random(100_000_000)
```

## Warnings

### WR-01: MFA Enrollment Not Wrapped in Transaction -- Partial State on Failure

**File:** `lib/sigra/mfa.ex:118-138`
**Issue:** In `confirm_enrollment/5`, the MFA credential insert and backup code insert_all are separate operations without a wrapping `Ecto.Multi` or `Repo.transaction`. If the credential insert succeeds but the backup code insert fails, the user ends up with MFA enabled but no backup codes. This is a data integrity issue. The `disable/4` function faces the same issue in `cleanup_mfa/5` (lines 499-512) where backup code deletion and credential deletion are separate non-transactional operations.

**Fix:**
```elixir
# Wrap in Ecto.Multi:
multi =
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:credential, credential_changeset)
  |> Ecto.Multi.insert_all(:backup_codes, backup_code_schema, entries)

case repo.transaction(multi) do
  {:ok, %{credential: db_credential}} -> ...
  {:error, step, reason, _} -> {:error, reason}
end
```

### WR-02: MFA Lockout Increment + Lock Is Non-Atomic (TOCTOU Race)

**File:** `lib/sigra/mfa/lockout.ex:69-96`
**Issue:** The `increment/4` function performs two separate database operations: (1) atomic increment of `failed_attempts` via `update_all`, then (2) a second `update_all` to set `locked_until` if the threshold is reached. Between these two operations, a concurrent request could also increment, resulting in both seeing threshold reached and both setting `locked_until` (harmless duplication), or more problematically, the returned `new_count` being stale if another increment landed between the two queries.

The comment on line 77 states "The returned value is the value AFTER increment" -- this is correct for PostgreSQL but should be verified for MySQL/SQLite adapters which Sigra targets.

**Fix:**
```elixir
# Combine into a single update_all with conditional locked_until:
# For PostgreSQL, use a raw SQL fragment:
from(c in mfa_credential_schema,
  where: c.id == ^credential_id,
  update: [
    inc: [failed_attempts: 1],
    set: [
      locked_until: fragment(
        "CASE WHEN failed_attempts + 1 >= ? THEN ? ELSE locked_until END",
        ^threshold,
        ^locked_until
      )
    ]
  ],
  select: %{failed_attempts: c.failed_attempts}
)
```

### WR-03: Generated MFA Challenge Controller Uses Session-Based State Check Instead of Plug-Based

**File:** `priv/templates/sigra.install/mfa_challenge_controller.ex:23`
**Issue:** The controller checks `get_session(conn, :mfa_pending) != true` to determine if the user is in MFA pending state. However, the library-level MFA gating (`Sigra.Plug.RequireMFA`) checks `conn.private[:sigra_session].type == :mfa_pending`. These are two different mechanisms. The controller uses a Plug session key (`:mfa_pending`) while the library uses the session store's type field. If `Sigra.Plug.RequireMFA` is used (as auto-injected into the router), the Plug session key may never be set, causing the controller to incorrectly redirect away from the MFA challenge page.

The same inconsistency exists in the LiveView template at `mfa_challenge_live.ex:19` which checks `session["mfa_pending"]`.

**Fix:** The generated controller should check the session type from `conn.private[:sigra_session]` instead of a session key, or the `user_auth.ex` template's `require_mfa` plug (line 314) should set the `:mfa_pending` session key when it detects an `mfa_pending` session type. The most robust approach:

```elixir
# In mfa_challenge_controller.ex new/1:
session = conn.private[:sigra_session]
if is_nil(session) or session.type != :mfa_pending do
  conn |> redirect(to: ~p"/") |> halt()
else
  # render challenge page
end
```

### WR-04: Undefined Template Binding `settings_url` in emails.ex

**File:** `priv/templates/sigra.install/emails.ex:302`
**Issue:** The `mfa_disabled_email/2` function references `<%= settings_url %>` but this binding is not included in the generator's binding list in `sigra.install.ex`. The binding list (lines 83-99) includes `log_in_url` and `reset_password_url` but not `settings_url`. This will cause an `UndefinedFunctionError` or `KeyError` when the template is rendered by the installer.

**Fix:**
```elixir
# In lib/mix/tasks/sigra.install.ex, add to the binding list (~line 92):
settings_url: "\#{#{inspect(web_module)}.Endpoint.url()}/users/settings"
```

### WR-05: `mfa_user_fixture` in auth_fixtures.ex Passes Wrong Options to setup_totp

**File:** `priv/templates/sigra.install/auth_fixtures.ex:96`
**Issue:** The `mfa_user_fixture/1` function calls `Sigra.Testing.setup_totp(user, repo: Repo)` but `setup_totp/2` requires `:config`, `:mfa_credential_schema`, and `:backup_code_schema` options (see `lib/sigra/testing.ex:233-237`). Passing only `:repo` will cause a `KeyError` at runtime when `Keyword.fetch!(opts, :config)` is called. The `mfa_locked_fixture/1` has the same issue calling `simulate_mfa_lockout(user, repo: Repo)` which requires `:config` and `:mfa_credential_schema`.

**Fix:**
```elixir
# In auth_fixtures.ex, mfa_user_fixture:
def mfa_user_fixture(attrs \\ %{}) do
  user = user_fixture(attrs)
  config = Auth.sigra_config()
  %{secret: secret, credential: _cred, backup_codes: codes} =
    Sigra.Testing.setup_totp(user,
      config: config,
      mfa_credential_schema: UserMFACredential,
      backup_code_schema: UserBackupCode
    )
  %{user: user, totp_secret: secret, backup_codes: codes}
end
```

### WR-06: RequireMFA Plug Path Comparison Does Not Account for Query Strings or Trailing Slashes

**File:** `lib/sigra/plug/require_mfa.ex:58`
**Issue:** The check `conn.request_path in [mfa_path, logout_path]` uses exact string matching. If the MFA challenge page is accessed with a query string (e.g., `/users/mfa?tab=backup`) or a trailing slash (`/users/mfa/`), the check will fail and the plug will redirect, creating an infinite redirect loop. While `request_path` strips query strings in Plug, trailing slashes are preserved.

**Fix:**
```elixir
# Use String.starts_with? or normalize paths:
allowed_paths = [mfa_path, logout_path]
if Enum.any?(allowed_paths, &(conn.request_path == &1 or conn.request_path == &1 <> "/")) do
  conn
else
  # redirect
end
```

## Info

### IN-01: Duplicate MFA Config Schema Definition

**File:** `lib/sigra/config.ex:463-544` and `lib/sigra/config.ex:487-544`
**Issue:** The `@schema` module attribute defines the `mfa` key with all its nested options. The same options are also duplicated verbatim in the `@moduledoc` NimbleOptions.docs call (lines 371-427). While the moduledoc version is for documentation generation, having two copies of the same schema creates a maintenance burden -- if one is updated, the other must be updated too.

**Fix:** Extract the MFA schema into a module attribute and reference it in both places, or generate docs from the single `@schema` definition.

### IN-02: MFA Settings LiveView Regenerate Codes Has TODO

**File:** `priv/templates/sigra.install/mfa_settings_live.ex:549`
**Issue:** The `regenerate_codes` event handler has a `# TODO: Wire to Auth.mfa_regenerate_backup_codes/2 when available` comment. The TOTP code is verified but backup codes are not actually regenerated -- the handler just refreshes the status from the database. The `BackupCodes.regenerate/4` function exists in the library but is not wired into the generated context.

**Fix:** Wire the regeneration through the generated auth context by adding a `mfa_regenerate_backup_codes/2` function that calls `Sigra.MFA.BackupCodes.regenerate/4` and expose it in the generated `auth.ex` template.

### IN-03: `Sigra.MFA.enabled?/2` Spec Says It Takes a Struct But Reads Schema From Config

**File:** `lib/sigra/mfa.ex:365-383`
**Issue:** The `@spec` for `enabled?/2` says it takes `(Sigra.Config.t(), struct())` and the function reads `mfa_credential_schema` from `config.mfa` keyword list. However, the generated `auth.ex` context (line 549) calls `Sigra.MFA.enabled?(sigra_config(), user)` but `sigra_config()` does not include `:mfa_credential_schema` in its MFA config. This means `enabled?/2` will always return `false` in the generated app unless the host app manually adds the schema to config.

**Fix:** Either add `mfa_credential_schema: UserMFACredential` to the generated `sigra_config/0` function's MFA options, or change `enabled?/2` to accept it as an option parameter like the other MFA functions do.

### IN-04: `mfa_pending_timeout` Config Key Inconsistency

**File:** `lib/sigra/plug/fetch_session.ex:133`
**Issue:** The `session_valid?/2` function reads `Keyword.get(session_config, :mfa_pending_timeout, 300)` but the config schema defines this as `mfa.pending_timeout` (in the MFA config block, not the session config block). The session config does not define an `:mfa_pending_timeout` key. This means the `FetchSession` plug will always use the default 300 seconds and ignore any custom `pending_timeout` configured by the user.

**Fix:** Read from the MFA config instead of session config, or add the pending_timeout to the session config schema. The cleanest fix is to pass the full `Sigra.Config` to `FetchSession` and read from `config.mfa[:pending_timeout]`.

### IN-05: Generated Migration Backup Codes Table Missing `updated_at` in timestamps

**File:** `priv/templates/sigra.install/migration.exs:79`
**Issue:** The `user_backup_codes` table uses `timestamps(type: :utc_datetime_usec, updated_at: false)` which is correct and intentional (backup codes are write-once, consume via `used_at`). However, the `BackupCodes.regenerate/4` function (line 147 of `backup_codes.ex`) inserts entries with `updated_at: now` which would fail at the database level since the column does not exist. The `confirm_enrollment/5` function in `mfa.ex:135` has the same issue.

**Fix:** Remove `updated_at: now` from the entries map in both `BackupCodes.regenerate/4` and `MFA.confirm_enrollment/5`, since the migration creates the table without an `updated_at` column:
```elixir
%{
  user_id: user_id,
  hashed_code: hashed,
  used_at: nil,
  inserted_at: now
  # Do NOT include updated_at
}
```

---

_Reviewed: 2026-04-08T14:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
