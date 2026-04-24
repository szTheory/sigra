defmodule Sigra.JWTRefreshAuditCofateTest do
  @moduledoc """
  Postgres integration tests for JWT refresh **persistence + audit co-fate**.

  For **audit-only** `Sigra.APIToken.audit_jwt_refresh/2` and
  `audit_jwt_refresh_reuse/2` (Phase **81**), see
  `test/sigra/api_token_audit_atomic_test.exs`.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias Sigra.JWT
  alias Sigra.JWT.RefreshToken
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule VerifyFailureTelemetryHandler do
    @moduledoc false
    def handle_event(event, measurements, metadata, parent) do
      send(parent, {:telemetry, event, measurements, metadata})
    end
  end

  defmodule CofateUser do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "jwt_refresh_cofate_users" do
      field(:email, :string)
      field(:token_epoch, :integer, default: 0)
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule CofateUserToken do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "jwt_refresh_cofate_user_tokens" do
      field(:token, :binary)
      field(:context, :string)
      field(:sent_to, :string)
      field(:user_id, :binary_id)
      timestamps(type: :utc_datetime_usec)
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    for t <- ["jwt_refresh_cofate_user_tokens", "jwt_refresh_cofate_users"] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE jwt_refresh_cofate_users (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text,
        token_epoch integer NOT NULL DEFAULT 0,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE jwt_refresh_cofate_user_tokens (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        token bytea NOT NULL,
        context varchar(255) NOT NULL,
        sent_to text NOT NULL,
        user_id uuid NOT NULL,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE IF NOT EXISTS audit_events (
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
      "TRUNCATE TABLE jwt_refresh_cofate_user_tokens RESTART IDENTITY CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "TRUNCATE TABLE jwt_refresh_cofate_users RESTART IDENTITY CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(repo, "TRUNCATE TABLE audit_events RESTART IDENTITY CASCADE", [])

    %{repo: repo}
  end

  defp token_opts do
    [user_token_schema: CofateUserToken]
  end

  defp sigra_config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: CofateUser,
      otp_app: :jwt_cofate_test,
      secret_key_base: String.duplicate("k", 64),
      audit: [audit_schema: AuditTestEvent],
      jwt: [
        enabled: true,
        algorithm: "HS256",
        issuer: "jwt_cofate",
        access_ttl: 900,
        refresh_ttl: 86_400,
        refresh: true,
        verify_epoch: false
      ]
    )
  end

  defp sigra_config_no_audit(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: CofateUser,
      otp_app: :jwt_cofate_test,
      secret_key_base: String.duplicate("k", 64),
      audit: [],
      jwt: [
        enabled: true,
        algorithm: "HS256",
        issuer: "jwt_cofate",
        access_ttl: 900,
        refresh_ttl: 86_400,
        refresh: true,
        verify_epoch: false
      ]
    )
  end

  defp count(repo, table) do
    %{rows: [[n]]} = Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM #{table}", [])
    n
  end

  defp count_where(repo, table, where) do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM #{table} WHERE #{where}", [])

    n
  end

  defp insert_user!(repo) do
    {:ok, u} = repo.insert(%CofateUser{email: "jwt-cofate@example.com"})
    u
  end

  test "happy path: audit on persists rotation and one api.jwt_refresh row", %{repo: repo} do
    user = insert_user!(repo)
    cfg = sigra_config(repo)
    opts = token_opts()
    {raw_refresh, _} = RefreshToken.create(cfg, user, ["profile:read"], opts)

    assert count(repo, "jwt_refresh_cofate_user_tokens") == 1

    assert {:ok, new_tokens} = JWT.refresh(cfg, raw_refresh, opts)
    assert is_binary(new_tokens.access_token)
    assert new_tokens.refresh_token != raw_refresh

    assert count(repo, "jwt_refresh_cofate_user_tokens") == 2
    assert count_where(repo, "audit_events", "action = 'api.jwt_refresh'") == 1
  end

  test "audit off: refresh succeeds with zero api.jwt_refresh rows", %{repo: repo} do
    user = insert_user!(repo)
    cfg = sigra_config_no_audit(repo)
    opts = token_opts()
    {raw_refresh, _} = RefreshToken.create(cfg, user, ["profile:read"], opts)

    assert {:ok, _} = JWT.refresh(cfg, raw_refresh, opts)
    assert count_where(repo, "audit_events", "action = 'api.jwt_refresh'") == 0
  end

  test "happy path fault injection: audit CHECK rejects api.jwt_refresh → jwt_refresh_aborted, no partial rotation",
       %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT jwt_refresh_cofate_happy_guard CHECK (action <> 'api.jwt_refresh')
      """,
      []
    )

    try do
      user = insert_user!(repo)
      cfg = sigra_config(repo)
      opts = token_opts()
      {raw_refresh, _} = RefreshToken.create(cfg, user, ["profile:read"], opts)

      before_tokens = count(repo, "jwt_refresh_cofate_user_tokens")

      ref =
        :telemetry.attach(
          {__MODULE__, :jwt_cofate_happy_guard},
          [:sigra, :audit, :log_safe_error],
          &VerifyFailureTelemetryHandler.handle_event/4,
          self()
        )

      try do
        assert {:error, :jwt_refresh_aborted} = JWT.refresh(cfg, raw_refresh, opts)

        assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                        %{action: "api.jwt_refresh", reason: :constraint_violation}}
      after
        :telemetry.detach(ref)
      end

      assert count(repo, "jwt_refresh_cofate_user_tokens") == before_tokens
      assert count_where(repo, "audit_events", "action = 'api.jwt_refresh'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS jwt_refresh_cofate_happy_guard",
        []
      )
    end
  end

  test "reuse + audit on: api.jwt_refresh_reuse row and {:error, :reuse_detected} after commit",
       %{
         repo: repo
       } do
    user = insert_user!(repo)
    cfg = sigra_config(repo)
    opts = token_opts()
    {raw1, _} = RefreshToken.create(cfg, user, ["profile:read"], opts)

    assert {:ok, %{refresh_token: raw2}} = JWT.refresh(cfg, raw1, opts)
    assert {:error, :reuse_detected} = JWT.refresh(cfg, raw1, opts)

    assert count_where(repo, "audit_events", "action = 'api.jwt_refresh_reuse'") == 1
    assert raw2 != raw1
  end

  test "reuse audit fault injection: reject api.jwt_refresh_reuse → jwt_refresh_aborted (revoke rolled back)",
       %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT jwt_refresh_cofate_reuse_guard CHECK (action <> 'api.jwt_refresh_reuse')
      """,
      []
    )

    try do
      user = insert_user!(repo)
      cfg = sigra_config(repo)
      opts = token_opts()
      {raw1, _} = RefreshToken.create(cfg, user, ["profile:read"], opts)
      assert {:ok, %{refresh_token: raw2}} = JWT.refresh(cfg, raw1, opts)

      before_reuse_audits =
        count_where(repo, "audit_events", "action = 'api.jwt_refresh_reuse'")

      ref =
        :telemetry.attach(
          {__MODULE__, :jwt_cofate_reuse_guard},
          [:sigra, :audit, :log_safe_error],
          &VerifyFailureTelemetryHandler.handle_event/4,
          self()
        )

      try do
        assert {:error, :jwt_refresh_aborted} = JWT.refresh(cfg, raw1, opts)

        assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                        %{action: "api.jwt_refresh_reuse", reason: :constraint_violation}}
      after
        :telemetry.detach(ref)
      end

      assert before_reuse_audits ==
               count_where(repo, "audit_events", "action = 'api.jwt_refresh_reuse'")

      # Legitimate rotated token still usable when reuse audit could not commit
      assert {:ok, _} = JWT.refresh(cfg, raw2, opts)
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS jwt_refresh_cofate_reuse_guard",
        []
      )
    end
  end
end
