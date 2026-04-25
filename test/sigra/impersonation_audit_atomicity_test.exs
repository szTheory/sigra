defmodule Sigra.ImpersonationAuditAtomicityTest do
  @moduledoc """
  Postgres integration coverage for impersonation session/audit co-fate.

  For the non-atomic fallback path that still uses `session.create` / `session.delete`
  plus `log_safe`, see `Sigra.ImpersonationTest`.
  """

  use ExUnit.Case, async: false

  alias Sigra.Admin.Scope, as: AdminScope
  alias Sigra.Config
  alias Sigra.Impersonation
  alias Sigra.Session
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule TestUser do
    defstruct [:id, :email, :organization_ids]
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defmodule ImpersonationSessionRecord do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "impersonation_audit_sessions" do
      field(:user_id, :binary_id)
      field(:hashed_token, :binary)
      field(:token, :binary, virtual: true)
      field(:type, :string, default: "standard")
      field(:ip, :string)
      field(:user_agent, :string)
      field(:geo_city, :string)
      field(:geo_country_code, :string)
      field(:active_organization_id, :binary_id)
      field(:last_active_at, :utc_datetime_usec)
      field(:sudo_at, :utc_datetime_usec)
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule LegacySessionStore do
    @moduledoc false

    def create(user_id, metadata, _opts) do
      send(self(), {:legacy_create, user_id, metadata})

      {:ok,
       %Sigra.Session{
         id: 4242,
         user_id: user_id,
         token: "impersonation-raw",
         hashed_token: "impersonation-hash",
         type: :standard,
         inserted_at: DateTime.utc_now(),
         last_active_at: DateTime.utc_now()
       }}
    end

    def delete(hashed_token, _opts) do
      send(self(), {:legacy_delete, hashed_token})
      :ok
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    for table <- ["impersonation_audit_sessions", "audit_events"] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{table} CASCADE", [])
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE impersonation_audit_sessions (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id uuid NOT NULL,
        hashed_token bytea NOT NULL,
        type varchar(32) NOT NULL DEFAULT 'standard',
        ip varchar(64),
        user_agent varchar(512),
        geo_city varchar(255),
        geo_country_code varchar(8),
        active_organization_id uuid,
        last_active_at timestamp,
        sudo_at timestamp,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE audit_events (
        id uuid PRIMARY KEY,
        occurred_at timestamp NOT NULL DEFAULT now(),
        action varchar(255) NOT NULL,
        outcome varchar(32) NOT NULL DEFAULT 'success',
        actor_id uuid,
        actor_type varchar(64) NOT NULL DEFAULT 'user',
        target_id uuid,
        target_type varchar(64),
        ip_address varchar(64),
        user_agent varchar(512),
        metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
        organization_id uuid,
        effective_user_id uuid,
        inserted_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(repo, "TRUNCATE TABLE impersonation_audit_sessions CASCADE", [])
    Ecto.Adapters.SQL.query!(repo, "TRUNCATE TABLE audit_events CASCADE", [])

    %{repo: repo}
  end

  defp admin_scope(mode, admin_user, organization_id \\ nil) do
    organization =
      case organization_id do
        nil -> nil
        id -> %{id: id, slug: "org-#{id}", name: "Org #{id}"}
      end

    %AdminScope{
      mode: mode,
      scope: %TestScope{
        user: admin_user,
        active_organization: nil,
        membership: nil,
        impersonating_from: nil
      },
      organization: organization,
      organization_id: organization_id,
      organization_slug: organization && organization.slug,
      platform_admin?: mode == :global,
      admin_org_ids: if(organization_id, do: [organization_id], else: [])
    }
  end

  defp session(user_id, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    struct(
      %Session{
        id: attrs[:id] || 1,
        user_id: user_id,
        token: attrs[:token],
        hashed_token: attrs[:hashed_token] || "hashed-session-token",
        type: attrs[:type] || :standard,
        last_active_at: Map.get(attrs, :last_active_at, now),
        inserted_at: Map.get(attrs, :inserted_at, now),
        active_organization_id: Map.get(attrs, :active_organization_id),
        sudo_at: Map.get(attrs, :sudo_at)
      },
      Map.drop(attrs, [
        :id,
        :token,
        :hashed_token,
        :type,
        :last_active_at,
        :inserted_at,
        :active_organization_id,
        :sudo_at
      ])
    )
  end

  defp base_config(repo, store, audit_schema \\ AuditTestEvent) do
    Config.new!(
      repo: repo,
      user_schema: TestUser,
      scope_module: TestScope,
      otp_app: :impersonation_audit_atomicity_test,
      secret_key_base: String.duplicate("k", 64),
      audit: [audit_schema: audit_schema],
      session: [
        store: store,
        session_schema: ImpersonationSessionRecord
      ]
    )
  end

  defp audit_count(repo, action) do
    %{rows: [[count]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM audit_events WHERE action = $1", [
        action
      ])

    count
  end

  defp session_count(repo) do
    %{rows: [[count]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM impersonation_audit_sessions", [])

    count
  end

  defp get_session_row(repo, hashed_token) do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT user_id, hashed_token, type FROM impersonation_audit_sessions WHERE hashed_token = $1",
        [hashed_token]
      )

    rows
  end

  test "default Ecto store co-fates impersonation start with its audit row", %{repo: repo} do
    cfg = base_config(repo, Sigra.SessionStores.Ecto)
    admin = %TestUser{id: Ecto.UUID.generate(), email: "admin@example.com"}
    target = %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"}
    admin_session = session(admin.id, %{id: 11, hashed_token: "admin-hash"})

    assert {:ok, %{session: result, restore: {:admin_session, "admin-token"}, mode: :impersonating}} =
             Impersonation.start(
               cfg,
               admin_scope(:global, admin),
               admin_session,
               target,
               admin_token: "admin-token"
             )

    assert result.user_id == target.id
    assert is_binary(result.token)
    assert session_count(repo) == 1
    assert audit_count(repo, "admin.impersonation.start") == 1
    assert audit_count(repo, "session.create") == 0
    assert length(get_session_row(repo, result.hashed_token)) == 1
  end

  test "audit-off parity still persists sessions without audit rows", %{repo: repo} do
    cfg = base_config(repo, Sigra.SessionStores.Ecto, nil)
    admin = %TestUser{id: Ecto.UUID.generate(), email: "admin@example.com"}
    target = %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"}
    admin_session = session(admin.id, %{id: 12, hashed_token: "admin-hash"})

    assert {:ok, %{session: session, mode: :impersonating}} =
             Impersonation.start(
               cfg,
               admin_scope(:global, admin),
               admin_session,
               target,
               admin_token: "admin-token"
             )

    assert session_count(repo) == 1
    assert audit_count(repo, "admin.impersonation.start") == 0

    assert {:ok, %{restore: {:admin_session, "admin-token"}, session_deleted?: true}} =
             Impersonation.stop(
               cfg,
               %TestScope{user: target, active_organization: nil, membership: nil, impersonating_from: admin},
               session,
               admin_token: "admin-token"
             )

    assert session_count(repo) == 0
    assert audit_count(repo, "admin.impersonation.stop") == 0
  end

  test "default Ecto store co-fates impersonation stop with its audit row", %{repo: repo} do
    cfg = base_config(repo, Sigra.SessionStores.Ecto)
    admin = %TestUser{id: Ecto.UUID.generate(), email: "admin@example.com"}
    target = %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"}

    {:ok, _} =
      repo.insert(%ImpersonationSessionRecord{
        user_id: target.id,
        hashed_token: "impersonation-hash",
        type: "standard"
      })

    impersonation_session =
      session(target.id, %{
        id: 22,
        hashed_token: "impersonation-hash",
        impersonator_user_id: admin.id
      })

    assert {:ok, %{restore: {:admin_session, "admin-token"}, session_deleted?: true}} =
             Impersonation.stop(
               cfg,
               %TestScope{user: target, active_organization: nil, membership: nil, impersonating_from: admin},
               impersonation_session,
               admin_token: "admin-token"
             )

    assert session_count(repo) == 0
    assert audit_count(repo, "admin.impersonation.stop") == 1
    assert audit_count(repo, "session.delete") == 0
  end

  test "audit insert failure rolls back both start and stop on the Ecto path", %{repo: repo} do
    cfg = base_config(repo, Sigra.SessionStores.Ecto)
    admin = %TestUser{id: Ecto.UUID.generate(), email: "admin@example.com"}
    target = %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"}
    admin_session = session(admin.id, %{id: 31, hashed_token: "admin-hash"})

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT impersonation_audit_guard CHECK (action NOT IN ('admin.impersonation.start', 'admin.impersonation.stop'))
      """,
      []
    )

    try do
      assert {:error, :impersonation_aborted} =
               Impersonation.start(
                 cfg,
                 admin_scope(:global, admin),
                 admin_session,
                 target,
                 admin_token: "admin-token"
               )

      assert session_count(repo) == 0
      assert audit_count(repo, "admin.impersonation.start") == 0

      {:ok, _} =
        repo.insert(%ImpersonationSessionRecord{
          user_id: target.id,
          hashed_token: "impersonation-hash",
          type: "standard"
        })

      impersonation_session =
        session(target.id, %{
          id: 32,
          hashed_token: "impersonation-hash",
          impersonator_user_id: admin.id
        })

      assert {:error, :impersonation_aborted} =
               Impersonation.stop(
                 cfg,
                 %TestScope{user: target, active_organization: nil, membership: nil, impersonating_from: admin},
                 impersonation_session,
                 admin_token: "admin-token"
               )

      assert session_count(repo) == 1
      assert audit_count(repo, "admin.impersonation.stop") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS impersonation_audit_guard",
        []
      )
    end
  end

  test "fallback store keeps the legacy create/delete plus log_safe path", %{repo: repo} do
    cfg = base_config(repo, LegacySessionStore)
    admin = %TestUser{id: Ecto.UUID.generate(), email: "admin@example.com"}
    target = %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"}
    target_id = target.id
    admin_session = session(admin.id, %{id: 41, hashed_token: "admin-hash"})

    assert {:ok, %{session: impersonation_session, mode: :impersonating}} =
             Impersonation.start(
               cfg,
               admin_scope(:global, admin),
               admin_session,
               target,
               admin_token: "admin-token"
             )

    assert_received {:legacy_create, ^target_id, metadata}
    assert metadata.impersonator_user_id == admin.id
    assert metadata.impersonator_session_id == admin_session.id
    assert impersonation_session.user_id == target.id
    assert impersonation_session.hashed_token == "impersonation-hash"

    assert {:ok, %{session_deleted?: true}} =
             Impersonation.stop(
               cfg,
               %TestScope{user: target, active_organization: nil, membership: nil, impersonating_from: admin},
               impersonation_session,
               admin_token: "admin-token"
             )

    assert_received {:legacy_delete, "impersonation-hash"}

    assert audit_count(repo, "session.create") == 1
    assert audit_count(repo, "admin.impersonation.start") == 1
    assert audit_count(repo, "session.delete") == 1
    assert audit_count(repo, "admin.impersonation.stop") == 1
  end
end
