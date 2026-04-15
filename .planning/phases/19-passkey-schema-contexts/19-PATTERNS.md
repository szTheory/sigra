# Phase 19: Passkey Schema + Contexts — Pattern Map

**Mapped:** 2026-04-15
**Files analyzed:** 22 new/modified
**Analogs found:** 21 / 22 (1 has no exact analog — `Sigra.Passkeys.CoseKey`, see "No Analog Found")

This map keys every file that Phase 19 will create or modify to the closest existing analog in the Sigra codebase, with concrete excerpts the planner should embed in each plan's `<actions>` block. Phase 19's hybrid lib+generator architecture means almost every file has a sibling pattern in `Sigra.MFA` or `Sigra.OAuth` — those two modules are the dominant precedent and should be mirrored field-for-field, helper-for-helper.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match |
|-------------------|------|-----------|----------------|-------|
| `lib/sigra/passkeys.ex` | context (security-critical) | request-response + CRUD | `lib/sigra/mfa.ex` | exact |
| `lib/sigra/passkeys/credential.ex` | library struct | transform | `lib/sigra/mfa/credential.ex` | exact |
| `lib/sigra/passkeys/registration.ex` | ceremony primitive | request-response | `lib/sigra/oauth/callback.ex` (handle_callback flow) | role-match |
| `lib/sigra/passkeys/authentication.ex` | ceremony primitive + guard | request-response | `lib/sigra/mfa.ex` `verify/3` + `lib/sigra/oauth.ex` `handle_callback/4` | role-match |
| `lib/sigra/passkeys/sign_count_policy.ex` | policy machine | transform | `lib/sigra/mfa/lockout.ex` | role-match |
| `lib/sigra/passkeys/cose_key.ex` | utility (serialization) | transform | (no analog — see below) | none |
| `lib/sigra/install/features/passkeys.ex` | install feature | event-driven (template emission) | `lib/sigra/install/features/organizations.ex` | exact |
| `lib/sigra/config.ex` (modify) | config schema | transform | self — add `passkeys:` slot mirroring `mfa:`/`oauth:` | exact |
| `lib/sigra/application.ex` (modify) | boot guard | event-driven | n/a — small addition for D-15 | partial |
| `lib/mix/tasks/sigra.upgrade.ex` (modify) | upgrade task | event-driven | self — add vault-promotion step | exact |
| `lib/sigra/install/injector.ex` (reuse only) | supervision injector | transform | self — `inject_vault_child/2` already exists | reuse |
| `mix.exs` (modify) | dependency manifest | config | self — add `{:wax_, "~> 0.7"}` | n/a |
| `priv/templates/sigra.install/passkeys/user_passkey.ex` | generated host schema | CRUD | `priv/templates/sigra.install/core/user_mfa_credential.ex` | exact |
| `priv/templates/sigra.install/passkeys/create_user_passkeys.exs` | migration template | event-driven (DDL) | `priv/templates/sigra.install/core/migration.exs` (citext + adapter branches) | role-match |
| `priv/templates/sigra.install/core/vault.ex` | promoted vault template | config | `priv/templates/sigra.gen.oauth/vault.ex` | exact (relocate) |
| `priv/templates/sigra.install/core/encrypted_binary.ex` | promoted Cloak.Ecto.Binary | transform | `priv/templates/sigra.gen.oauth/encrypted_binary.ex` | exact (relocate) |
| `priv/templates/sigra.install/core/encrypted.ex` (modify, gated) | passthrough stub | transform | self — keep as fallback path | reuse |
| `test/sigra/passkeys_test.exs` | context unit tests | test (request-response) | `test/sigra/mfa_test.exs` | role-match |
| `test/sigra/passkeys/registration_test.exs` | unit test | test | `test/sigra/mfa/...` | role-match |
| `test/sigra/passkeys/authentication_test.exs` | unit test (incl. StrongKey guard) | test | `test/sigra/mfa_test.exs` | role-match |
| `test/sigra/passkeys/sign_count_policy_test.exs` | unit test (3 modes) | test | `test/sigra/mfa/lockout_test.exs` | role-match |
| `test/sigra/passkeys/wax_roundtrip_test.exs` | smoke (D-16 Task-1) | integration test | n/a — new pattern; mirror `test/sigra/oauth_test.exs` ceremony shape | partial |
| `test/sigra/passkeys/encrypted_roundtrip_test.exs` | integration test | test | `test/sigra/oauth/...` Cloak round-trip | role-match |
| `test/support/passkey_fixtures.ex` | test fixtures | test | `test/support/oauth_test_helpers.ex` | role-match |
| `test/sigra/install/features/passkeys_test.exs` | feature emission test | test | `test/sigra/install/features/organizations_test.exs` | exact |
| `test/sigra/install/vault_promotion_test.exs` | install integration | test | `test/sigra/install/...` (org install tests) | partial |

---

## Pattern Assignments

### `lib/sigra/passkeys/credential.ex` (library struct, transform)

**Analog:** `lib/sigra/mfa/credential.ex` (118 lines, mirror field-for-field per D-04).

**Module/struct shape** (lib/sigra/mfa/credential.ex:1-53):
```elixir
defmodule Sigra.MFA.Credential do
  @moduledoc """
  Library struct representing an MFA credential (e.g., TOTP enrollment).

  Maps to and from the generated `UserMfaCredential` Ecto schema in the host app.
  ...
  """

  @type t :: %__MODULE__{
          id: term(),
          user_id: term(),
          type: String.t() | nil,
          encrypted_secret: binary() | nil,
          last_used_at: DateTime.t() | nil,
          last_verified_step: integer() | nil,
          failed_attempts: non_neg_integer(),
          locked_until: DateTime.t() | nil,
          enabled_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id, :user_id, :type, :encrypted_secret, :last_used_at,
    :last_verified_step, :locked_until, :enabled_at,
    :inserted_at, :updated_at,
    failed_attempts: 0
  ]

  @credential_fields [
    :id, :user_id, :type, :encrypted_secret, :last_used_at,
    :last_verified_step, :failed_attempts, :locked_until,
    :enabled_at, :inserted_at, :updated_at
  ]
```

**`from_schema/1` pattern** (lib/sigra/mfa/credential.ex:80-93) — copy verbatim, swap field list:
```elixir
@spec from_schema(map()) :: t()
def from_schema(schema) when is_map(schema) do
  fields =
    @credential_fields
    |> Enum.reduce([], fn field, acc ->
      case Map.fetch(schema, field) do
        {:ok, value} -> [{field, value} | acc]
        :error -> acc
      end
    end)

  struct(__MODULE__, fields)
end
```

**`to_params/1` pattern** (lib/sigra/mfa/credential.ex:108-117) — copy verbatim:
```elixir
@spec to_params(t()) :: map()
def to_params(%__MODULE__{} = credential) do
  credential
  |> Map.from_struct()
  |> Map.drop([:id, :inserted_at, :updated_at])
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  |> Map.new()
end
```

**Phase 19 fields** (per D-03): `:id, :user_id, :credential_id, :public_key, :sign_count, :aaguid, :nickname, :device_hint, :transports, :rp_id, :last_used_at, :inserted_at, :updated_at`. Default `transports: []`, default `sign_count: 0`.

---

### `lib/sigra/passkeys.ex` (context, request-response + CRUD)

**Analog:** `lib/sigra/mfa.ex` (high-level structure, audit helpers, `config` first-arg) + `lib/sigra/oauth.ex` (handle_callback Multi pattern for D-12).

**Module header + alias** (lib/sigra/mfa.ex:1-31):
```elixir
defmodule Sigra.MFA do
  @moduledoc """
  Core MFA orchestrator module.

  All security-critical MFA operations live here. The generated
  `MyApp.Auth` context delegates to these functions for ...

  ## Security Properties

  - TOTP secrets generated via NimbleTOTP (RFC 6238 compliant)
  - ...
  - TOTP secrets encrypted at rest via cloak_ecto (D-09)
  """

  alias Sigra.MFA.{BackupCodes, Credential, Lockout, Trust}
```

**Audit-opts helper to mirror** (lib/sigra/mfa.ex:45-52) — copy as `passkey_audit_opts/1`:
```elixir
defp mfa_audit_opts(%Sigra.Config{} = config) do
  audit_config = Map.get(config, :audit, [])

  [
    repo: config.repo,
    audit_schema: Keyword.get(audit_config, :audit_schema)
  ]
end
```

OAuth has the identical helper at `lib/sigra/oauth.ex:101-109` (`oauth_audit_opts/1`). The Phase 19 `passkey_audit_opts/1` is byte-identical except for the function name.

**`config` first-arg + Telemetry.span pattern** (lib/sigra/mfa.ex:79-98) — every public function follows this shape:
```elixir
@doc since: "0.6.0"
@spec enroll(Sigra.Config.t(), keyword()) :: {:ok, map()}
def enroll(%Sigra.Config{} = config, opts \\ []) do
  Sigra.Telemetry.span([:sigra, :mfa, :enroll], %{}, fn ->
    # ... body ...
    {:ok, result}
  end)
end
```

For Phase 19, every `Sigra.Passkeys.*/3..4` function wraps its body in `Sigra.Telemetry.span([:sigra, :passkeys, :register | :authenticate | :delete | :rename], %{user_id: user.id}, fn -> ... end)`.

**Atomic Multi + audit pattern for `register/3` (D-12)** — mirror `Sigra.OAuth.handle_callback/4`'s audit interleave (`lib/sigra/oauth.ex:131-200`). The relevant excerpt (lib/sigra/oauth.ex:158-167) shows the `audit_opts = oauth_audit_opts(config)` resolved once and merged into each event:
```elixir
audit_opts = oauth_audit_opts(config)

case result do
  {:ok, :registered, user, _session} ->
    Sigra.Audit.log_safe("oauth.callback.success", Sigra.Scope.from_config(config, user),
      Keyword.merge(audit_opts,
        actor_id: user.id,
        metadata: %{provider: to_string(provider), outcome: "registered"}
      )
    )
```

**`log_multi_safe/3` Multi-append pattern** (lib/sigra/audit.ex:213-237) — D-12 audit-inside-Multi rolls back on failure:
```elixir
@spec log_multi_safe(Ecto.Multi.t(), String.t(), opts()) :: Ecto.Multi.t()
def log_multi_safe(%Ecto.Multi{} = multi, action, opts)
    when is_binary(action) and is_list(opts) do
  case Keyword.get(opts, :audit_schema) do
    nil -> multi
    _ -> do_log_multi(multi, action, opts, true)
  end
end

defp do_log_multi(multi, action, opts, allow_reserved?) do
  audit_schema = Keyword.fetch!(opts, :audit_schema)
  resolver = Keyword.get(opts, :actor_resolver)
  cs_opts = changeset_opts(opts, allow_reserved?)

  Ecto.Multi.insert(multi, :audit, fn changes ->
    attrs = build_attrs(action, opts, resolver, changes)
    Changeset.changeset(struct(audit_schema), attrs, cs_opts)
  end)
end
```

**Note for planner (Open Question 2 in RESEARCH.md):** `build_attrs/4` is at `lib/sigra/audit.ex` ~line 240+. Read it before writing the audit call to confirm the metadata key name (`:metadata` vs `:data`). Don't guess.

**`Repo.transact/2` outer wrap (D-06/D-12)** — Sigra uses Ecto 3.13's `Repo.transact/2`, not the deprecated `Repo.transaction/2`. Sketch:
```elixir
config.repo.transact(fn ->
  with {:ok, count} <- count_for_user(config, user),
       :ok <- check_cap(count, max_per_user),
       {:ok, credential} <- insert_passkey(config, user, attrs),
       multi = Ecto.Multi.new() |> Sigra.Audit.log_multi_safe("passkey.register.success", passkey_audit_opts(config) ++ [actor_id: user.id, metadata: %{...}]),
       {:ok, _changes} <- config.repo.transaction(multi) do
    {:ok, Credential.from_schema(credential)}
  end
end)
```

(Planner picks the exact composition — both `Repo.transact/2`-only and `Multi.new() |> ... |> Repo.transaction/1` are idiomatic in Sigra; use whichever keeps the audit insert and the row insert in the same transaction. The MFA module mixes both styles.)

---

### `lib/sigra/passkeys/authentication.ex` (ceremony primitive + StrongKey guard)

**Analog:** mixed — D-07 guard pattern is novel; `Repo.get_by` pattern is universal in `lib/sigra/mfa.ex` and `lib/sigra/oauth.ex`.

**StrongKey guard shape (D-07, PK-07)** — must come BEFORE any `Wax.authenticate/6` call:
```elixir
# STEP 1: ownership pre-lookup (StrongKey CVE-2025-26788 defense)
case config.repo.get_by(user_passkey_schema, user_id: user.id, credential_id: credential_id) do
  nil ->
    {:error, :credential_not_owned}

  %{} = row ->
    # STEP 2: userHandle equality (W3C WebAuthn §7.2 step 6.3.2)
    if user_handle && user_handle != to_string(user.id) do
      {:error, :credential_not_owned}
    else
      # STEP 3: decrypt + deserialize (Cloak handles decrypt on load)
      cose_key = Sigra.Passkeys.CoseKey.deserialize(row.public_key)

      # STEP 4: build single-element allow_credentials
      credentials = [{row.credential_id, cose_key}]

      # STEP 5: call wax_
      case Wax.authenticate(credential_id, auth_data_bin, sig, client_data_json_raw, challenge, credentials) do
        {:ok, auth_data} -> handle_sign_count(config, row, auth_data, opts)
        {:error, _} = err -> err
      end
    end
end
```

**Telemetry wrap for the whole ceremony** — mirror `Sigra.Telemetry.span([:sigra, :passkeys, :authenticate], %{user_id: user.id}, fn -> ... end)` pattern from `lib/sigra/mfa.ex:80`.

---

### `lib/sigra/passkeys/sign_count_policy.ex` (policy machine, transform)

**Analog:** `lib/sigra/mfa/lockout.ex` (small, focused, pure-function policy module). Same shape: small set of `defp`s, one public entry function, returns tagged tuples the caller pattern-matches on.

**Phase 19 skeleton (RESEARCH.md §Code Examples lines 539-551):**
```elixir
defmodule Sigra.Passkeys.SignCountPolicy do
  @moduledoc """
  Sign-count regression policy machine (D-05, PK-08).

  Implements three modes — `:warn`, `:require_reauth`, `:revoke` — with
  the W3C-spec-mandated zero-zero carve-out (PITFALLS.md §P-4) for sync'd
  passkeys (Apple iCloud Keychain, Google Password Manager) that legitimately
  return sign_count = 0 on every assertion.
  """

  @type policy :: :warn | :require_reauth | :revoke

  @spec evaluate(non_neg_integer(), non_neg_integer(), policy()) ::
          :ok | {:regression, policy()}
  def evaluate(stored, presented, policy) do
    cond do
      stored == 0 and presented == 0 -> :ok                       # P-4 carve-out
      presented > stored              -> :ok                       # normal monotonic
      true                            -> {:regression, policy}
    end
  end
end
```

The caller (`Sigra.Passkeys.Authentication.handle_sign_count/4`) pattern-matches on `{:regression, policy}` and dispatches:
- `:warn` → emit `passkey.sign_count_regression` audit (D-10) + return `{:ok, _}` continue auth
- `:require_reauth` → emit audit + return `{:error, :sign_count_regression}`
- `:revoke` → emit audit + delete row in same Multi + return `{:error, :sign_count_regression}`

---

### `lib/sigra/install/features/passkeys.ex` (install feature)

**Analog:** `lib/sigra/install/features/organizations.ex` (exact match — Phase 13/16 pattern).

**Module header + behaviour declaration** (lib/sigra/install/features/organizations.ex:1-37):
```elixir
defmodule Sigra.Install.Features.Organizations do
  @moduledoc """
  `Sigra.Install.Feature` implementation for the organizations feature: ...

  Owns every template under `priv/templates/sigra.install/organizations/`
  and the single migration that creates the ... tables.

  `enabled?/1` checks `Keyword.get(opts, :organizations, true)` ...
  ...
  ## Isolation invariant (Pitfall X-3)

  This module contains ZERO references to `Features.Core`,
  `Features.Passkeys`, or `Features.Admin`. ...
  """

  @behaviour Sigra.Install.Feature

  alias Sigra.Install.Injection

  @impl true
  def enabled?(opts), do: Keyword.get(opts, :organizations, true)
```

**`files/1` pattern** (lib/sigra/install/features/organizations.ex:40-145) — list of `{:eex, source, target_path}` tuples. For Phase 19, the list will be:
```elixir
@impl true
def files(binding) do
  otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
  ctx = binding |> Keyword.get(:context_alias, "Accounts") |> Macro.underscore()

  [
    # Generated host UserPasskey schema
    {:eex, "passkeys/user_passkey.ex",
     Path.join(["lib", otp_app, ctx, "user_passkey.ex"])}
  ]
end
```

**`migrations/1` pattern** (lib/sigra/install/features/organizations.ex:165-175):
```elixir
@impl true
def migrations(_binding) do
  [
    {:user_passkeys, "passkeys/create_user_passkeys.exs", "create_user_passkeys.exs"}
  ]
end
```

**`enabled?/1` for Phase 19:**
```elixir
@impl true
def enabled?(opts), do: Keyword.get(opts, :passkeys, false)
# Default false — passkeys are opt-in for v1.1, not v1.0 baseline.
```

(Planner: confirm the default before locking — CONTEXT.md doesn't lock the default-on/default-off bit explicitly, but the phase scope frames passkeys as opt-in via `--passkeys`.)

**Vault co-emission (D-13)** — `Sigra.Install.Features.Passkeys.files/1` (or alternatively `Sigra.Install.Features.Core.files/1` under a feature-OR gate) must emit `core/vault.ex` and `core/encrypted_binary.ex` when ANY of `--passkeys`/`--mfa`/`--oauth` is set. The current `Features.Core.files/1` at `lib/sigra/install/features/core.ex:232-233` emits the stub:
```elixir
# Phase 10.1: Encrypted.Binary passthrough stub
{:eex, "core/encrypted.ex", Path.join(["lib", otp_app, ctx, "encrypted.ex"])},
```
Plan 19-04 replaces this with a feature-gated branch:
```elixir
if encrypts_anything?(binding) do
  [{:eex, "core/vault.ex", Path.join(["lib", otp_app, "vault.ex"])},
   {:eex, "core/encrypted_binary.ex", Path.join(["lib", otp_app, ctx, "encrypted", "binary.ex"])}]
else
  [{:eex, "core/encrypted.ex", Path.join(["lib", otp_app, ctx, "encrypted.ex"])}]
end
```

---

### `priv/templates/sigra.install/passkeys/user_passkey.ex` (generated host schema, CRUD)

**Analog:** `priv/templates/sigra.install/core/user_mfa_credential.ex` (verbatim shape).

**Full template shape to mirror:**
```elixir
defmodule <%= context_module %>.UserMFACredential do
  @moduledoc """
  Ecto schema for MFA credentials (e.g., TOTP enrollment).

  Stores encrypted TOTP secrets, lockout tracking, and replay prevention.
  Maps to and from `Sigra.MFA.Credential` library struct.

  Generated by `mix sigra.install`. Customize freely -- this module
  is owned by your application.
  """

  use Ecto.Schema
  import Ecto.Changeset
<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
<% end %>
  schema "user_mfa_credentials" do
    belongs_to :user, <%= context_module %>.<%= schema_alias %>
    field :type, :string
    field :encrypted_secret, <%= context_module %>.Encrypted.Binary
    field :last_used_at, :utc_datetime_usec
    field :last_verified_step, :integer
    field :failed_attempts, :integer, default: 0
    field :locked_until, :utc_datetime_usec
    field :enabled_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Changeset for creating a new MFA credential."
  def create_changeset(credential \\ %__MODULE__{}, attrs) do
    credential
    |> cast(attrs, [:user_id, :type, :encrypted_secret, :enabled_at])
    |> validate_required([:user_id, :type, :encrypted_secret])
    |> unique_constraint([:user_id, :type])
    |> foreign_key_constraint(:user_id)
  end

  @doc "Changeset for updating MFA credential fields ..."
  def update_changeset(credential, attrs) do
    credential
    |> cast(attrs, [:last_used_at, :last_verified_step, :failed_attempts, :locked_until, :enabled_at])
  end
end
```

**Phase 19 differences (per D-01/D-02/D-03/D-13):**
- Schema table: `"user_passkeys"`
- `field :credential_id, :binary` (NOT encrypted, indexed unique)
- `field :public_key, <%= app_module %>.Encrypted.Binary` (note: `app_module`, not `context_module` — D-13 unifies onto the `app_module` namespace)
- `field :sign_count, :integer, default: 0`
- `field :aaguid, Ecto.UUID` (D-01, nullable)
- `field :nickname, :string`
- `field :device_hint, :string`
- `field :transports, {:array, :string}, default: []`
- `field :rp_id, :string`
- `field :last_used_at, :utc_datetime_usec`
- `create_changeset/2` validates `[:user_id, :credential_id, :public_key, :sign_count, :rp_id]`, `unique_constraint([:credential_id])`, `validate_length(:transports, max: 8)`, `update_change(:transports, &Enum.uniq/1)` (D-02)
- `update_changeset/2` casts `[:sign_count, :last_used_at, :nickname]`

---

### `priv/templates/sigra.install/passkeys/create_user_passkeys.exs` (migration template)

**Analog:** `priv/templates/sigra.install/core/migration.exs` (adapter-branched DDL).

**Adapter-branch + binary_id pattern** (priv/templates/sigra.install/core/migration.exs:1-30):
```elixir
defmodule <%= repo_module %>.Migrations.CreateSigraAuthTables do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    create table(:<%= table_name %><%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :email, :citext, null: false
      ...
      timestamps(type: :utc_datetime)
    end

    create unique_index(:<%= table_name %>, [:email], where: "deleted_at IS NULL", ...)
```

**For Phase 19**, mirror this exact `<%= if adapter == :postgres do %>` / `<% else %>` branch structure. Postgres branch emits `add :aaguid, :uuid` (D-01) and `add :public_key, :binary`. MySQL/SQLite branch emits `add :aaguid, :binary, size: 16` fallback. Indexes: `create index(:user_passkeys, [:user_id])`, `create unique_index(:user_passkeys, [:credential_id])`.

---

### `priv/templates/sigra.install/core/vault.ex` (D-13 promotion)

**Analog:** `priv/templates/sigra.gen.oauth/vault.ex` (40 lines, verbatim relocation).

**Source (verbatim — copy unchanged):**
```elixir
defmodule <%= app_module %>.Vault do
  @moduledoc """
  Cloak vault for encrypting sensitive fields at rest.

  Uses AES-256-GCM encryption with a key derived from the `CLOAK_KEY`
  environment variable. ...

  ## Generating a key

      32 |> :crypto.strong_rand_bytes() |> Base.encode64()
  ...
  """

  use Cloak.Vault, otp_app: <%= inspect(otp_app) %>

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: decode_env!("CLOAK_KEY"),
          iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    var |> System.fetch_env!() |> Base.decode64!()
  end
end
```

Update the `@moduledoc` "Generated by `mix sigra.gen.oauth`" line → "Generated by `mix sigra.install` (any of `--passkeys`/`--mfa`/`--oauth`)".

---

### `priv/templates/sigra.install/core/encrypted_binary.ex` (D-13 promotion)

**Analog:** `priv/templates/sigra.gen.oauth/encrypted_binary.ex` (12 lines).

```elixir
defmodule <%= app_module %>.Encrypted.Binary do
  @moduledoc """
  Ecto type for transparently encrypting binary fields via Cloak.

  Used by `UserIdentity` for OAuth access and refresh tokens.

  Generated by `mix sigra.gen.oauth`. ...
  """

  use Cloak.Ecto.Binary, vault: <%= app_module %>.Vault
end
```

Update the @moduledoc to mention `UserPasskey.public_key` and `UserMFACredential.encrypted_secret` as the consumers.

---

### `lib/mix/tasks/sigra.upgrade.ex` (modify, D-14)

**Analog:** `lib/sigra/install/injector.ex:380-412` — `inject_vault_child/2` is already implemented and reusable. D-14 reuses it verbatim.

**Existing injector to call** (lib/sigra/install/injector.ex:389-412):
```elixir
@spec inject_vault_child(String.t(), String.t()) ::
        {:ok, String.t()} | {:already_injected, String.t()}
def inject_vault_child(file_contents, app_module) do
  vault_module = "#{app_module}.Vault"

  if String.contains?(file_contents, @vault_marker) do
    {:already_injected, file_contents}
  else
    case Regex.run(~r/children\s*=\s*\[/m, file_contents, return: :index) do
      [{pos, len}] ->
        insert_at = pos + len
        vault_child = "\n      {#{vault_module}, []},"
        {before, rest} = String.split_at(file_contents, insert_at)
        {:ok, before <> vault_child <> rest}

      _ ->
        {:ok, file_contents <> "\n# Add #{vault_module} to your application supervision tree:\n# {#{vault_module}, []}\n"}
    end
  end
end
```

D-14's `mix sigra.upgrade` step:
1. Detect `<context_module>.Encrypted.Binary` is the stub (grep `priv/templates/sigra.install/core/encrypted.ex` signature in host source).
2. Detect any of `--passkeys`/`--mfa`/`--oauth` is configured.
3. Render and write `<app>/vault.ex` from `priv/templates/sigra.install/core/vault.ex`.
4. Render and overwrite `<app>/<ctx>/encrypted/binary.ex` from `priv/templates/sigra.install/core/encrypted_binary.ex` (or move it to the new path if relocating).
5. Read host `application.ex`, call `Sigra.Install.Injector.inject_vault_child/2`, write back.
6. Print the `CLOAK_KEY` generation banner (`32 |> :crypto.strong_rand_bytes() |> Base.encode64()`).

---

### `lib/sigra/config.ex` (modify — add `passkeys:` slot)

**Analog:** self — `mfa:` slot at lines 391-447, `oauth:` slot at lines 448-479. D-05/D-06 add a parallel `passkeys:` slot.

**Pattern (mfa: slot, lines 391-447):**
```elixir
mfa: [
  type: :keyword_list,
  default: [],
  doc: "Multi-factor authentication options.",
  keys: [
    enabled: [
      type: :boolean,
      default: true,
      doc: "Enable MFA support. Default: true."
    ],
    totp_drift_steps: [
      type: :non_neg_integer,
      default: 1,
      doc: "TOTP drift window in 30-second steps. Default: 1."
    ],
    lockout_threshold: [
      type: :pos_integer,
      default: 5,
      doc: "Failed MFA attempts before lockout. Default: 5."
    ],
    ...
  ]
],
```

**Phase 19 addition (RESEARCH.md §Code Examples lines 614-643):**
```elixir
passkeys: [
  type: :keyword_list,
  default: [],
  doc: "Passkey (WebAuthn) options.",
  keys: [
    enabled: [type: :boolean, default: true, doc: "Enable passkey support. Default: true."],
    sign_count_policy: [
      type: {:in, [:warn, :require_reauth, :revoke]},
      default: :warn,
      doc: "Sign-count regression policy. Default: :warn (P-4; matches Apple iCloud sync)."
    ],
    max_per_user: [type: :pos_integer, default: 10, doc: "Soft cap on passkeys per user. Default: 10."],
    rp_id: [type: {:or, [:string, nil]}, default: nil, doc: "RP ID. Phase 20 owns the loader."],
    origin: [type: {:or, [:string, nil]}, default: nil, doc: "RP origin. Phase 20."],
    attestation: [type: {:in, [:none, :indirect, :direct]}, default: :none, doc: "Phase 20."],
    user_verification: [type: {:in, [:preferred, :required, :discouraged]}, default: :preferred, doc: "Phase 20."],
    timeout_ms: [type: :pos_integer, default: 60_000, doc: "Phase 20."]
  ]
]
```

**Also modify** `audit:` `reserved_prefixes` default at `lib/sigra/config.ex:543`:
```elixir
# BEFORE
reserved_prefixes: [type: {:list, :string}, default: ~w(auth. session. mfa. oauth. api. account. sigra.), ...]
# AFTER
reserved_prefixes: [type: {:list, :string}, default: ~w(auth. session. mfa. oauth. api. account. sigra. passkey.), ...]
```

---

### `mix.exs` (modify — add wax_)

**Pattern:** existing `deps/0` block in `mix.exs`. Single-line addition:
```elixir
{:wax_, "~> 0.7"}
```

Run `mix hex.info wax_` first (per A2 in research Assumptions Log) to confirm 0.7.0 is still current.

---

## Shared Patterns

### Audit-opts helper (cross-cutting)

**Source:** `lib/sigra/mfa.ex:45-52` and `lib/sigra/oauth.ex:101-109` (identical shape).
**Apply to:** `Sigra.Passkeys` (`passkey_audit_opts/1`).

```elixir
defp passkey_audit_opts(%Sigra.Config{} = config) do
  audit_config = Map.get(config, :audit, [])

  [
    repo: config.repo,
    audit_schema: Keyword.get(audit_config, :audit_schema)
  ]
end
```

### `config` first-arg + Telemetry.span body wrap

**Source:** `lib/sigra/mfa.ex:79-98`, `lib/sigra/oauth.ex:131-155`.
**Apply to:** every public function on `Sigra.Passkeys` (D-08 surface).

```elixir
@spec register(Sigra.Config.t(), User.t(), map(), keyword()) :: ...
def register(%Sigra.Config{} = config, user, attestation, opts \\ []) do
  Sigra.Telemetry.span([:sigra, :passkeys, :register], %{user_id: user.id}, fn ->
    # ... body ...
  end)
end
```

### NimbleOptions per-call validation

**Source:** Pervasive across Sigra (`lib/sigra/organizations.ex:234`, `lib/sigra/upgrade/backfill.ex:76`, `lib/sigra/config.ex` itself).
**Apply to:** `register/4` and `authenticate/4` opts validation.

Pattern:
```elixir
@register_opts_schema [
  max_per_user: [type: :pos_integer, required: false]
]

defp validated_opts(opts, schema) do
  NimbleOptions.validate!(opts, schema)
end
```

### `log_multi_safe/3` audit-inside-Multi

**Source:** `lib/sigra/audit.ex:213-237` (definition); used by `lib/sigra/oauth.ex` and Phase 9 callers.
**Apply to:** `Sigra.Passkeys.register/3` (D-12) and the sign-count regression branch in `authenticate/3` (D-10).

```elixir
multi
|> Ecto.Multi.insert(:passkey, passkey_changeset)
|> Sigra.Audit.log_multi_safe(
  "passkey.register.success",
  passkey_audit_opts(config) ++ [
    actor_id: user.id,
    metadata: %{credential_id: Base.url_encode64(credential_id), rp_id: config.passkeys[:rp_id]}
  ]
)
|> config.repo.transaction()
```

### Cloak vault encrypted field

**Source:** `priv/templates/sigra.gen.oauth/encrypted_binary.ex` (12 lines).
**Apply to:** `UserPasskey.public_key`. Use `<%= app_module %>.Encrypted.Binary` in the schema field declaration. After D-13, this is the unified namespace.

### Hybrid lib+generator boundary

**Source:** Architecture invariant — every persistent domain object follows this. `Sigra.MFA.Credential` ↔ `<context_module>.UserMFACredential` is the canonical pair.
**Apply to:** `Sigra.Passkeys.Credential` ↔ `<context_module>.UserPasskey`. The library context module never references the host schema by module name — it accepts the schema module via `opts[:user_passkey_schema]` or `config.passkeys[:user_passkey_schema]`. See `lib/sigra/mfa.ex:117-123` (`mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)`).

### Test fixtures pattern

**Source:** `test/support/oauth_test_helpers.ex` (mirror — fixed test vectors + builder functions).
**Apply to:** `test/support/passkey_fixtures.ex` — house wax_ test vectors (raw `attestation_object`, `client_data_json`, `credential_id`, `cose_key` map, `aaguid`) so unit tests don't recompute them per test.

---

## No Analog Found

| File | Role | Data Flow | Reason | Recommendation |
|------|------|-----------|--------|----------------|
| `lib/sigra/passkeys/cose_key.ex` | utility (serialization) | transform | No COSE/CBOR/integer-keyed-map serialization helper exists in Sigra today. The closest precedent is `Sigra.Token` (HMAC + binary encoding) but the operation is fundamentally different. | Lock per RESEARCH.md Open Question 1 + Plan 19-01 D-17: `:erlang.term_to_binary/1` + `:erlang.binary_to_term(bin, [:safe])` (the `[:safe]` flag is mandatory — atom-creation DoS guard). Module is ~20 lines: `serialize/1`, `deserialize/1`, `@moduledoc` explaining the choice and citing the smoke-test (`test/sigra/passkeys/wax_roundtrip_test.exs`) as the empirical validation per Assumption A1. |
| `test/sigra/passkeys/wax_roundtrip_test.exs` | smoke (D-16 Task-1) | integration test | First time Sigra round-trips a 3rd-party crypto library against fixtures. The shape of the test is novel because wax_ is the first WebAuthn dep. | Use `test/sigra/oauth_test.exs` (mock callback round-trip) as a structural reference — same 3-step shape: `register → store → authenticate`. The 10-line smoke assertion (D-16) goes in this file as the FIRST test in Plan 19-01, before any unit tests. It exists to empirically validate Assumption A1 (COSE key round-trip preserves integer keys through encrypt/decrypt). |
| `lib/sigra/application.ex` boot-check (D-15) | partial — small modification | n/a | Sigra has no precedent for boot-time module-resolution guards. Closest precedent: `lib/sigra/install/injector.ex` config-time guards, which run in mix tasks not at boot. | Add a `@spec verify_vault!/1`-style helper that checks if `<app_module>.Encrypted.Binary` is the stub by inspecting its `__info__(:functions)` output (the stub is `use Ecto.Type`, the real one is `use Cloak.Ecto.Binary` which adds different callbacks). Raise with a remediation message pointing at `mix sigra.upgrade`. Plan 19-04 owns this. |

---

## Metadata

**Analog search scope:**
- `lib/sigra/` (full tree)
- `lib/sigra/install/` (features + injector)
- `lib/sigra/mfa/`, `lib/sigra/oauth/`, `lib/sigra/organizations/`
- `priv/templates/sigra.install/core/`, `priv/templates/sigra.gen.oauth/`
- `test/support/`, `test/sigra/mfa*`, `test/sigra/oauth*`

**Files scanned:** ~40 (precedent files identified by RESEARCH.md + ad-hoc directory listings)

**Pattern extraction date:** 2026-04-15

**Phase:** 19-passkey-schema-contexts

**Confidence:** HIGH for every analog except the three "No Analog Found" entries, which are all called out with clear forward-references to either Plan 19-01 (CoseKey, smoke test) or Plan 19-04 (boot-check).
