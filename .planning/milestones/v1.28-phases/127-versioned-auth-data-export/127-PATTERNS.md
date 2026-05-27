# Phase 127: Versioned Auth Data Export - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 2
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/data_export.ex` | service | transform + CRUD query | `lib/sigra/data_export.ex` | exact |
| `test/sigra/data_export_test.exs` | test | request-response proof + transform proof | `test/sigra/data_export_test.exs` | exact |

## Pattern Assignments

### `lib/sigra/data_export.ex` (service, transform + CRUD query)

**Analog:** `lib/sigra/data_export.ex`

**Imports and public contract pattern** (lines 1-31):
```elixir
defmodule Sigra.DataExport do
  @moduledoc """
  Behaviour for exporting user data.

  Sigra provides a versioned export contract for Sigra-owned auth and
  account data. Application developers implement this behaviour to add
  host-app data alongside the Sigra-owned export.
  """

  @doc """
  Export all data associated with the given user.
  """
  @doc since: "0.8.0"
  @callback export_user_data(user :: struct()) :: {:ok, map()} | {:error, term()}
```

**Versioned payload assembly pattern** (lines 51-90):
```elixir
@spec export_auth_data(module(), struct(), keyword()) :: {:ok, map()}
def export_auth_data(repo, user, opts \\ []) do
  import Ecto.Query

  data = %{
    schema_version: 1,
    exported_at: DateTime.utc_now() |> DateTime.truncate(:second),
    account: %{
      id: user.id,
      email: user.email,
      confirmed_at: Map.get(user, :confirmed_at),
      inserted_at: user.inserted_at,
      deleted_at: Map.get(user, :deleted_at),
      scheduled_deletion_at: Map.get(user, :scheduled_deletion_at)
    },
    sessions: fetch_records(repo, Keyword.get(opts, :session_schema), user.id),
    identities: fetch_records(repo, Keyword.get(opts, :identity_schema), user.id),
    audit: fetch_audit_records(repo, Keyword.get(opts, :audit_schema), user.id),
    mfa: %{
      credentials: fetch_records(repo, Keyword.get(opts, :mfa_credential_schema), user.id),
      passkeys: fetch_records(repo, Keyword.get(opts, :user_passkey_schema), user.id),
      backup_codes: %{
        count: count_records(repo, Keyword.get(opts, :backup_code_schema), user.id),
        exported: false,
        reason: "Backup codes are stored hashed and cannot be exported in raw form."
      }
    },
    organizations: %{
      memberships: fetch_records(repo, Keyword.get(opts, :membership_schema), user.id)
    },
    enterprise: %{
      connections: [],
      exported: false,
      reason:
        "Enterprise connections are organization-scoped and are not included in the user export contract."
    },
    omissions: omissions(opts)
  }

  {:ok, data}
end
```

**Optional schema query guard pattern** (lines 93-117):
```elixir
defp fetch_records(nil, _schema, _user_id), do: []
defp fetch_records(_repo, nil, _user_id), do: []

defp fetch_records(repo, schema, user_id) do
  import Ecto.Query

  if function_exported?(schema, :__schema__, 1) and :user_id in schema.__schema__(:fields) do
    repo.all(from(r in schema, where: field(r, ^:user_id) == ^user_id))
  else
    []
  end
end

defp count_records(nil, _schema, _user_id), do: 0
defp count_records(_repo, nil, _user_id), do: 0

defp count_records(repo, schema, user_id) do
  import Ecto.Query

  if function_exported?(schema, :__schema__, 1) and :user_id in schema.__schema__(:fields) do
    repo.aggregate(from(r in schema, where: field(r, ^:user_id) == ^user_id), :count, :id)
  else
    0
  end
end
```

**Audit multi-field ownership query pattern** (lines 122-144):
```elixir
defp fetch_audit_records(repo, schema, user_id) do
  import Ecto.Query

  fields = schema.__schema__(:fields)

  predicates =
    [:actor_id, :effective_user_id, :target_id]
    |> Enum.filter(&(&1 in fields))

  if predicates == [] do
    []
  else
    predicate =
      Enum.reduce(predicates, dynamic(false), fn field_name, acc ->
        dynamic([record], ^acc or field(record, ^field_name) == ^user_id)
      end)

    query =
      from(record in schema, where: ^predicate)
      |> maybe_order_audit_records(fields)

    repo.all(query)
  end
end
```

**Omission truth pattern to expand** (lines 162-179):
```elixir
defp omissions(opts) do
  []
  |> maybe_add_omission(
    is_nil(Keyword.get(opts, :audit_schema)),
    "Audit events are omitted because no audit schema was provided."
  )
  |> maybe_add_omission(
    is_nil(Keyword.get(opts, :membership_schema)),
    "Organization memberships are omitted because no membership schema was provided."
  )
  |> maybe_add_omission(
    is_nil(Keyword.get(opts, :mfa_credential_schema)),
    "MFA credential rows are omitted because no MFA credential schema was provided."
  )
end

defp maybe_add_omission(omissions, true, message), do: [message | omissions]
defp maybe_add_omission(omissions, false, _message), do: omissions
```

**Lifecycle status source to copy from:** `lib/sigra/account/deletion.ex`

**Derived lifecycle status pattern** (lines 139-152):
```elixir
@spec status(map()) :: {:scheduled, non_neg_integer()} | :not_scheduled | :deleted
def status(user) do
  cond do
    not is_nil(user.deleted_at) and not is_nil(user.scheduled_deletion_at) ->
      days = DateTime.diff(user.scheduled_deletion_at, DateTime.utc_now(), :day)
      {:scheduled, max(days, 0)}

    not is_nil(user.deleted_at) ->
      :deleted

    true ->
      :not_scheduled
  end
end
```

**Library-owned export orchestration analog:** `lib/sigra/admin/audit/export.ex`

**Config normalization + query + safe projection flow** (lines 29-63):
```elixir
defp export(config, %Scope{} = admin_scope, params, extra_filters) do
  params = stringify_map(params)
  filter_params = Map.drop(params, ["order_by", "order_direction", "return_to"])

  with {:ok, normalized} <- QueryParams.normalize(filter_params, admin_scope) do
    order_by = normalize_order_field(Map.get(params, "order_by"))
    order_direction = normalize_order_direction(Map.get(params, "order_direction"))
    limit = normalized.limit
    cursor = normalized.cursor
    filters = build_filters(normalized, admin_scope, extra_filters)
    audit_schema = audit_schema!(config)

    events =
      audit_schema
      |> Query.build(filters)
      |> apply_order(order_by, order_direction)
      |> apply_cursor(order_by, order_direction, cursor)
      |> limit(^limit)
      |> config.repo.all()

    users_by_id = load_users(config, events)
    orgs_by_id = load_organizations(config, events)
    csv_opts = csv_row_opts(admin_scope, extra_filters)

    rows =
      Enum.map(events, &CSVExport.row(&1, users_by_id, orgs_by_id, csv_opts))

    {:ok, CSVExport.dump(rows)}
  else
    {:error, {:organization, :out_of_scope}} ->
      {:ok, CSVExport.dump([])}

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Optional generated schema discovery pattern** (lines 150-170):
```elixir
defp organization_schema(config) do
  Map.get(config, :organization_schema) ||
    optional_schema(accounts_module(config), :Organization)
end

defp accounts_module(%{accounts_module: module}) when is_atom(module), do: module
defp accounts_module(%{accounts: module}) when is_atom(module), do: module

defp accounts_module(%{user_schema: module}) when is_atom(module) do
  module |> Module.split() |> Enum.drop(-1) |> Module.safe_concat()
rescue
  ArgumentError -> nil
end

defp accounts_module(_config), do: nil
defp optional_schema(nil, _name), do: nil

defp optional_schema(module, name) do
  schema = Module.concat(module, name)
  if Code.ensure_loaded?(schema), do: schema, else: nil
end
```

**Curated row serialization analog:** `lib/sigra/admin/audit/csv_export.ex`

**Stable allowlisted row map pattern** (lines 34-72):
```elixir
@spec row(struct(), map(), map(), keyword()) :: map()
def row(event, users_by_id, orgs_by_id, opts \\ []) do
  actor = Map.get(users_by_id, event.actor_id)
  effective_user = Map.get(users_by_id, event.effective_user_id)
  scope_org = Keyword.get(opts, :scope_organization)

  organization =
    if is_binary(event.organization_id) do
      Map.get(orgs_by_id, event.organization_id)
    else
      if is_map(scope_org), do: scope_org, else: nil
    end

  %{
    "occurred_at" => iso8601(event.occurred_at || event.inserted_at),
    "event_id" => event.id,
    "action" => event.action,
    "outcome" => event.outcome || "success",
    "actor_id" => event.actor_id,
    "actor_label" => user_label(actor, event.actor_id),
    "effective_user_id" => event.effective_user_id,
    "effective_user_label" => user_label(effective_user, event.effective_user_id),
    "target_id" => event.target_id,
    "target_type" => event.target_type,
    "organization_id" => organization_id_cell,
    "organization_label" => organization_label(organization, event.organization_id),
    "impersonation_state" => impersonation_state(event)
  }
end
```

**Generated-host thin adapter boundary:** `priv/templates/sigra.install/admin/audit_export_controller.ex`

**Thin generated controller seam pattern** (lines 10-27):
```elixir
def index(conn, %{"id" => user_id} = params) do
  case Sigra.Admin.Audit.Export.subject_csv(export_config(), conn.assigns.admin_scope, user_id, params) do
    {:ok, csv} ->
      send_csv(conn, csv)

    {:error, _reason} ->
      send_resp(conn, 400, "Invalid audit export filters")
  end
end

def index(conn, params) do
  case Sigra.Admin.Audit.Export.csv(export_config(), conn.assigns.admin_scope, params) do
    {:ok, csv} ->
      send_csv(conn, csv)

    {:error, _reason} ->
      send_resp(conn, 400, "Invalid audit export filters")
  end
end
```

**Secret-field inventory from generated schemas:**

| Section | Source | Safe implication |
|---------|--------|------------------|
| account | `priv/templates/sigra.install/core/user.ex` lines 8-24 | Include lifecycle fields; never include `:hashed_password`. |
| sessions | `priv/templates/sigra.install/core/user_session.ex` lines 21-35 | Exclude `:hashed_token`; export metadata such as type, IP, user agent, timestamps, active org. |
| identities | `priv/templates/sigra.gen.oauth/user_identity.ex` lines 18-33 | Exclude `:encrypted_access_token` and `:encrypted_refresh_token`; export provider/profile metadata. |
| audit | `priv/templates/sigra.install/core/audit_event.ex` lines 24-39 | Export action/outcome/actor/target/org/timestamps/metadata as Sigra-owned audit truth. |
| MFA credentials | `priv/templates/sigra.install/core/user_mfa_credential.ex` lines 18-29 | Exclude `:encrypted_secret`; export type, lockout, enabled, and last-used metadata. |
| backup codes | `priv/templates/sigra.install/core/user_backup_code.ex` lines 18-24 | Exclude `:hashed_code`; count only and keep non-export reason. |
| passkeys | `priv/templates/sigra.install/passkeys/user_passkey.ex` lines 19-32 | Exclude `:credential_id` and `:public_key`; export nickname/device/rp/sign-count metadata. |
| memberships | `priv/templates/sigra.install/organizations/organization_membership.ex` lines 19-26 | Export role, organization id, user id, timestamps. |

---

### `test/sigra/data_export_test.exs` (test, request-response proof + transform proof)

**Analog:** `test/sigra/data_export_test.exs`

**Test module and alias pattern** (lines 1-6):
```elixir
defmodule Sigra.DataExportTest do
  use ExUnit.Case, async: true

  alias Sigra.DataExport

  describe "export_auth_data/3" do
```

**Versioned section proof pattern** (lines 7-28):
```elixir
test "returns {:ok, map} with versioned export sections" do
  user = %{
    id: 1,
    email: "test@example.com",
    confirmed_at: ~U[2026-01-01 00:00:00Z],
    inserted_at: ~U[2026-01-01 00:00:00Z]
  }

  assert {:ok, data} = DataExport.export_auth_data(nil, user, [])

  assert data.schema_version == 1
  assert %DateTime{} = data.exported_at
  assert Map.has_key?(data, :account)
  assert Map.has_key?(data, :sessions)
  assert Map.has_key?(data, :identities)
  assert Map.has_key?(data, :audit)
  assert Map.has_key?(data, :mfa)
  assert Map.has_key?(data, :organizations)
  assert Map.has_key?(data, :enterprise)
  assert Map.has_key?(data, :omissions)
end
```

**Lifecycle field proof pattern to extend with `lifecycle_status`** (lines 30-48):
```elixir
test "account map contains lifecycle fields" do
  user = %{
    id: 42,
    email: "user@example.com",
    confirmed_at: nil,
    inserted_at: ~U[2026-03-15 12:00:00Z],
    deleted_at: ~U[2026-03-16 12:00:00Z],
    scheduled_deletion_at: ~U[2026-03-20 12:00:00Z]
  }

  {:ok, data} = DataExport.export_auth_data(nil, user, [])

  assert data.account.id == 42
  assert data.account.email == "user@example.com"
  assert data.account.confirmed_at == nil
  assert data.account.inserted_at == ~U[2026-03-15 12:00:00Z]
  assert data.account.deleted_at == ~U[2026-03-16 12:00:00Z]
  assert data.account.scheduled_deletion_at == ~U[2026-03-20 12:00:00Z]
end
```

**Optional degradation proof pattern to expand** (lines 50-69):
```elixir
test "optional sections degrade honestly without schemas" do
  user = %{
    id: 1,
    email: "test@example.com",
    confirmed_at: nil,
    inserted_at: ~U[2026-01-01 00:00:00Z]
  }

  {:ok, data} = DataExport.export_auth_data(nil, user, [])

  assert data.sessions == []
  assert data.identities == []
  assert data.audit == []
  assert data.mfa.credentials == []
  assert data.mfa.passkeys == []
  assert data.mfa.backup_codes.count == 0
  assert data.organizations.memberships == []
  assert data.enterprise.exported == false
  assert Enum.any?(data.omissions, &String.contains?(&1, "Audit events are omitted"))
end
```

**In-test schema fixture pattern:** `test/sigra/enterprise_routing/discovery_test.exs`

**Local Ecto schema modules** (lines 4-23):
```elixir
defmodule TestOrganization do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "organizations" do
    field :name, :string
    field :slug, :string
  end
end

defmodule TestConnection do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "enterprise_connections" do
    field :organization_id, :binary_id
    field :status, Ecto.Enum, values: [:draft, :validation_failed, :active, :disabled]
    field :display_name, :string
    field :login_hint_domains, {:array, :string}, default: []
  end
end
```

**Fake repo query harness** (lines 26-91):
```elixir
defmodule DiscoveryRepo do
  alias Sigra.EnterpriseRouting.DiscoveryTest.{TestConnection, TestOrganization}

  @connections [
    %TestConnection{
      id: "conn-acme",
      organization_id: "org-acme",
      status: :active,
      display_name: "Acme Workforce",
      login_hint_domains: ["acme.example"]
    }
  ]

  def all(%Ecto.Query{wheres: wheres}) do
    Enum.filter(@connections, fn connection ->
      Enum.all?(wheres, fn where -> matches_expr?(where.expr, where.params, connection) end)
    end)
  end

  def get(TestOrganization, id), do: Map.get(@organizations, id)
end
```

**Simpler stub repo pattern:** `test/sigra/audit_test.exs`

**Repo minimal surface for unit tests** (lines 15-29):
```elixir
defmodule StubRepo do
  @moduledoc false
  def insert(changeset) do
    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  def all(_query), do: []
  def stream(_query), do: Stream.map([], & &1)
  def aggregate(_q, :count, _f), do: 0
  def transaction(fun) when is_function(fun, 0), do: {:ok, fun.()}
end
```

**Postgres-backed test repo available when query compilation matters:** `test/support/postgres_test_repo.ex`

**Opt-in real repo pattern** (lines 1-35):
```elixir
if Code.ensure_loaded?(Postgrex) do
  defmodule Sigra.Test.PostgresRepo do
    @moduledoc """
    Minimal Postgres-backed Ecto.Repo used exclusively by the opt-in
    `:postgres` tagged tests.
    """

    use Ecto.Repo, otp_app: :sigra, adapter: Ecto.Adapters.Postgres

    @doc false
    def default_config do
      [
        hostname: System.get_env("SIGRA_TEST_PG_HOSTNAME", "localhost"),
        username: System.get_env("SIGRA_TEST_PG_USERNAME", "postgres"),
        password: System.get_env("SIGRA_TEST_PG_PASSWORD", "postgres"),
        database: System.get_env("SIGRA_TEST_PG_DATABASE", "sigra_test"),
        pool_size: 2,
        log: false
      ]
    end
  end
end
```

## Shared Patterns

### Library-Owned Contract, Generated-Host Thin Adapter

**Source:** `lib/sigra/data_export.ex` lines 33-51 and `priv/templates/sigra.install/admin/audit_export_controller.ex` lines 10-39

**Apply to:** `lib/sigra/data_export.ex`; any later generated wrapper in Phase 129.

Keep payload ownership in `Sigra.DataExport.export_auth_data/3`. Generated code should pass schemas/config and call the library, like the audit export controller calls `Sigra.Admin.Audit.Export`.

### Stable Versioned Export Envelope

**Source:** `lib/sigra/data_export.ex` lines 55-90

**Apply to:** `lib/sigra/data_export.ex`, `test/sigra/data_export_test.exs`

Keep these top-level keys present: `:schema_version`, `:exported_at`, `:account`, `:sessions`, `:identities`, `:audit`, `:mfa`, `:organizations`, `:enterprise`, `:omissions`.

### Lifecycle Truth

**Source:** `lib/sigra/account/deletion.ex` lines 139-152

**Apply to:** account section in `lib/sigra/data_export.ex`; lifecycle assertions in `test/sigra/data_export_test.exs`.

Call `Sigra.Account.Deletion.status/1` rather than reimplementing scheduled/deleted/not-scheduled logic.

### Optional Schema Degradation

**Source:** `lib/sigra/data_export.ex` lines 93-117 and 162-179

**Apply to:** all optional sections in `lib/sigra/data_export.ex`.

Missing schemas should return present empty values and omission notes. Expand omission coverage from the current three schemas to all optional Sigra-owned schemas: `:session_schema`, `:identity_schema`, `:audit_schema`, `:mfa_credential_schema`, `:user_passkey_schema`, `:backup_code_schema`, and `:membership_schema`.

### Curated Safe Serialization

**Source:** `lib/sigra/admin/audit/csv_export.ex` lines 34-72 and generated schema templates listed above.

**Apply to:** session, identity, audit, MFA credential, passkey, backup-code, and membership serializers in `lib/sigra/data_export.ex`.

Use explicit allowlists per section. Do not return raw structs from generated auth schemas.

### Test Style

**Source:** `test/sigra/data_export_test.exs` lines 1-78; `test/sigra/enterprise_routing/discovery_test.exs` lines 4-91; `test/sigra/audit_test.exs` lines 15-29.

**Apply to:** `test/sigra/data_export_test.exs`.

Keep tests flat and self-contained. Define local schema modules and a small repo stub in the test file when configured-schema behavior needs rows.

## No Analog Found

All identified files have close analogs.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|

## Metadata

**Analog search scope:** `lib/`, `test/`, `priv/templates/`, `.planning/phases/127-versioned-auth-data-export/`
**Files scanned:** 240+ paths from `rg --files lib test priv/templates`
**Pattern extraction date:** 2026-05-27
