defmodule Sigra.ServiceAccountsAuditAtomicityTest do
  @moduledoc """
  D-AUD-08 / D-93-22 co-fated rollback proof for all five Phase 93
  service-account mutations.

  Mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs` (Phase 82) line
  for line, swapping the JWT refresh-flow schemas/calls for service-account
  schemas/calls. Per D-AUD-07, every fault path is its own named `test`
  block — no loops, no parametrized fixtures.

  Postgres-only (CLAUDE.md prereq: localhost:5432 postgres/postgres).
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  # --- Schemas ---------------------------------------------------------------
  # Minimal Ecto schemas for service_accounts and service_account_credentials.
  # These are test-only schema modules backed by the real Postgres test repo.

  defmodule SATestUser do
    @moduledoc false
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sa_atomicity_test_users" do
      field(:email, :string)
    end
  end

  defmodule SATestServiceAccount do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sa_atomicity_service_accounts" do
      field(:organization_id, :binary_id)
      field(:name, :string)
      field(:scopes, {:array, :string}, default: [])
      field(:role, :string)
      field(:token_epoch, :integer, default: 0)
      field(:revoked_at, :utc_datetime)
      field(:last_used_at, :utc_datetime)
      field(:created_by_user_id, :binary_id)
      timestamps(type: :utc_datetime)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :organization_id,
        :name,
        :scopes,
        :role,
        :token_epoch,
        :revoked_at,
        :last_used_at,
        :created_by_user_id
      ])
      |> validate_required([:organization_id, :name])
    end
  end

  defmodule SATestCredential do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sa_atomicity_service_account_credentials" do
      field(:service_account_id, :binary_id)
      field(:client_id, :string)
      field(:hashed_client_secret, :binary)
      field(:expires_at, :utc_datetime)
      field(:last_used_at, :utc_datetime)
      field(:revoked_at, :utc_datetime)
      timestamps(type: :utc_datetime)
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :service_account_id,
        :client_id,
        :hashed_client_secret,
        :expires_at,
        :last_used_at,
        :revoked_at
      ])
      |> validate_required([:service_account_id, :client_id, :hashed_client_secret])
      |> unique_constraint(:client_id)
    end
  end

  # --- Telemetry handler -----------------------------------------------------
  defmodule TelemetryHandler do
    @moduledoc false
    def handle_event(event, measurements, metadata, parent) do
      send(parent, {:telemetry, event, measurements, metadata})
    end
  end

  # --- Setup -----------------------------------------------------------------
  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp"|, [])

    # Drop and recreate tables owned by this test module.
    for t <- [
          "sa_atomicity_service_account_credentials",
          "sa_atomicity_service_accounts",
          "sa_atomicity_test_users",
          "audit_events"
        ] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE sa_atomicity_test_users (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE sa_atomicity_service_accounts (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        organization_id uuid NOT NULL,
        name text NOT NULL,
        scopes text[] NOT NULL DEFAULT '{}',
        role text,
        token_epoch integer NOT NULL DEFAULT 0,
        revoked_at timestamp,
        last_used_at timestamp,
        created_by_user_id uuid,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE sa_atomicity_service_account_credentials (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        service_account_id uuid NOT NULL
          REFERENCES sa_atomicity_service_accounts(id) ON DELETE CASCADE,
        client_id text NOT NULL UNIQUE,
        hashed_client_secret bytea NOT NULL,
        expires_at timestamp,
        last_used_at timestamp,
        revoked_at timestamp,
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

    Ecto.Adapters.SQL.query!(
      repo,
      "TRUNCATE TABLE sa_atomicity_service_accounts, sa_atomicity_service_account_credentials, audit_events RESTART IDENTITY CASCADE",
      []
    )

    %{repo: repo}
  end

  # --- Helpers ---------------------------------------------------------------

  defp count_rows(repo, table) do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM #{table}", [])

    n
  end

  # Mirror the `Sigra.Config.new!/1` idiom from
  # `test/sigra/jwt_refresh_audit_cofate_test.exs` lines 136 and 155 so
  # NimbleOptions defaults run and the config struct is identical to what
  # production callers see — never `%Sigra.Config{}` literal here.
  defp sigra_config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: SATestUser,
      otp_app: :sa_atomicity_test,
      secret_key_base: String.duplicate("k", 64),
      service_accounts: [
        service_account_schema: SATestServiceAccount,
        service_account_credential_schema: SATestCredential,
        client_id_byte_size: 24
      ],
      audit: [audit_schema: AuditTestEvent],
      jwt: [
        enabled: true,
        algorithm: "HS256",
        issuer: "sa_atomicity_test",
        access_ttl: 900,
        client_credentials_access_ttl: 3600,
        refresh: false,
        verify_epoch: false
      ]
    )
  end

  defp make_scope do
    %{
      user: %{id: Ecto.UUID.generate()},
      active_organization: %{id: Ecto.UUID.generate()}
    }
  end

  defp seed_sa!(repo, scope) do
    org_id = get_in(scope, [:active_organization, :id])

    %{rows: [[id_bytes]]} =
      Ecto.Adapters.SQL.query!(
        repo,
        """
        INSERT INTO sa_atomicity_service_accounts
          (organization_id, name, scopes, token_epoch)
        VALUES ($1, $2, ARRAY['deploy:write']::text[], 0)
        RETURNING id
        """,
        [Ecto.UUID.dump!(org_id), "ci-bot"]
      )

    {:ok, id_str} = Ecto.UUID.cast(id_bytes)
    repo.get(SATestServiceAccount, id_str)
  end

  defp attach_telemetry_to_self(name) do
    :telemetry.attach(
      {__MODULE__, name},
      [:sigra, :audit, :log_safe_error],
      &TelemetryHandler.handle_event/4,
      self()
    )
  end

  # --- The five fault-injection tests ----------------------------------------

  test "create: audit CHECK rejects service_account.create -> :service_account_aborted, no partial SA row",
       %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT sa_create_cofate_guard CHECK (action <> 'service_account.create')",
      []
    )

    try do
      scope = make_scope()
      org_id = get_in(scope, [:active_organization, :id])
      before_count = count_rows(repo, "sa_atomicity_service_accounts")
      attach_telemetry_to_self(:create)

      assert {:error, :service_account_aborted} =
               Sigra.ServiceAccounts.create(sigra_config(repo), scope, %{
                 organization_id: org_id,
                 name: "ci-bot",
                 scopes: ["deploy:write"]
               })

      assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                      %{action: "service_account.create", reason: :constraint_violation}},
                     1000

      assert count_rows(repo, "sa_atomicity_service_accounts") == before_count
      assert count_rows(repo, "audit_events") == 0
    after
      :telemetry.detach({__MODULE__, :create})

      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS sa_create_cofate_guard",
        []
      )
    end
  end

  test "revoke: audit CHECK rejects service_account.revoke -> :service_account_aborted, SA stays unrevoked",
       %{repo: repo} do
    scope = make_scope()
    sa = seed_sa!(repo, scope)
    original_epoch = sa.token_epoch

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT sa_revoke_cofate_guard CHECK (action <> 'service_account.revoke')",
      []
    )

    try do
      attach_telemetry_to_self(:revoke)

      assert {:error, :service_account_aborted} =
               Sigra.ServiceAccounts.revoke(sigra_config(repo), scope, sa)

      assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                      %{action: "service_account.revoke", reason: :constraint_violation}},
                     1000

      reread = repo.get(SATestServiceAccount, sa.id)
      assert is_nil(reread.revoked_at), "revoked_at must be nil — SA row must have rolled back"
      assert reread.token_epoch == original_epoch, "token_epoch must not advance under rollback"
    after
      :telemetry.detach({__MODULE__, :revoke})

      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS sa_revoke_cofate_guard",
        []
      )
    end
  end

  test "credential_create: audit CHECK rejects service_account.credential_create -> :service_account_credential_aborted, no partial credential row",
       %{repo: repo} do
    scope = make_scope()
    sa = seed_sa!(repo, scope)

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT sa_cred_create_cofate_guard CHECK (action <> 'service_account.credential_create')",
      []
    )

    try do
      before_creds = count_rows(repo, "sa_atomicity_service_account_credentials")
      attach_telemetry_to_self(:cred_create)

      assert {:error, :service_account_credential_aborted} =
               Sigra.ServiceAccounts.create_credential(sigra_config(repo), scope, sa, %{})

      assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                      %{
                        action: "service_account.credential_create",
                        reason: :constraint_violation
                      }},
                     1000

      assert count_rows(repo, "sa_atomicity_service_account_credentials") == before_creds,
             "credential row count must be unchanged — credential insert rolled back"
    after
      :telemetry.detach({__MODULE__, :cred_create})

      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS sa_cred_create_cofate_guard",
        []
      )
    end
  end

  test "credential_revoke: audit CHECK rejects service_account.credential_revoke -> :service_account_credential_aborted, credential stays unrevoked",
       %{repo: repo} do
    scope = make_scope()
    sa = seed_sa!(repo, scope)
    cfg = sigra_config(repo)

    # Create a real credential so we have one to revoke.
    {:ok, cred, _secret} = Sigra.ServiceAccounts.create_credential(cfg, scope, sa, %{})

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT sa_cred_revoke_cofate_guard CHECK (action <> 'service_account.credential_revoke')",
      []
    )

    try do
      attach_telemetry_to_self(:cred_revoke)

      assert {:error, :service_account_credential_aborted} =
               Sigra.ServiceAccounts.revoke_credential(cfg, scope, cred)

      assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                      %{
                        action: "service_account.credential_revoke",
                        reason: :constraint_violation
                      }},
                     1000

      reread = repo.get(SATestCredential, cred.id)

      assert is_nil(reread.revoked_at),
             "revoked_at must remain nil — credential update rolled back"
    after
      :telemetry.detach({__MODULE__, :cred_revoke})

      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS sa_cred_revoke_cofate_guard",
        []
      )
    end
  end

  test "token_issued: audit CHECK rejects service_account.token_issued -> :service_account_token_issuance_aborted, credential.last_used_at unchanged",
       %{repo: repo} do
    scope = make_scope()
    sa = seed_sa!(repo, scope)
    cfg = sigra_config(repo)

    {:ok, cred, _secret} = Sigra.ServiceAccounts.create_credential(cfg, scope, sa, %{})

    before_last_used = repo.get(SATestCredential, cred.id).last_used_at

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT sa_token_issued_cofate_guard CHECK (action <> 'service_account.token_issued')",
      []
    )

    try do
      attach_telemetry_to_self(:token_issued)

      # Per `lib/sigra/service_accounts.ex:199`, the multi-failure tuple is
      # normalized to `{:error, :service_account_token_issuance_aborted}`.
      assert {:error, :service_account_token_issuance_aborted} =
               Sigra.ServiceAccounts.issue_token(cfg, sa, cred, [])

      assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                      %{action: "service_account.token_issued", reason: :constraint_violation}},
                     1000

      reread = repo.get(SATestCredential, cred.id)

      assert reread.last_used_at == before_last_used,
             "credential.last_used_at must NOT advance when token_issued audit rolls back"
    after
      :telemetry.detach({__MODULE__, :token_issued})

      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS sa_token_issued_cofate_guard",
        []
      )
    end
  end
end
