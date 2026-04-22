defmodule Sigra.APITokenAuditAtomicTest do
  use ExUnit.Case, async: false

  alias Sigra.APIToken
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule ApiTokenRow do
    @moduledoc false
    use Ecto.Schema

    schema "user_api_tokens" do
      field(:user_id, :binary_id)
      field(:hashed_token, :binary)
      field(:prefix, :string)
      field(:name, :string)
      field(:scopes, {:array, :string})
      field(:expires_at, :utc_datetime)
      field(:revoked_at, :utc_datetime)
      field(:last_used_at, :utc_datetime)
      timestamps()
    end

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [
        :user_id,
        :hashed_token,
        :prefix,
        :name,
        :scopes,
        :expires_at
      ])
      |> Ecto.Changeset.validate_required([:user_id, :hashed_token, :prefix, :name, :scopes])
      |> Ecto.Changeset.validate_length(:name, max: 255)
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS user_api_tokens CASCADE", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE user_api_tokens (
        id bigserial PRIMARY KEY,
        user_id uuid NOT NULL,
        hashed_token bytea NOT NULL,
        prefix text NOT NULL,
        name text NOT NULL,
        scopes character varying(255)[] NOT NULL,
        expires_at timestamp,
        revoked_at timestamp,
        last_used_at timestamp,
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
      "TRUNCATE TABLE user_api_tokens, audit_events RESTART IDENTITY CASCADE",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE user_api_tokens DROP CONSTRAINT IF EXISTS audit_atomic_name_guard",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE user_api_tokens
      ADD CONSTRAINT audit_atomic_name_guard CHECK (name <> 'BAD_TOKEN_NAME')
      """,
      []
    )

    %{repo: repo}
  end

  defp sigra_config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: MyApp.User,
      otp_app: :my_app,
      audit: [audit_schema: AuditTestEvent],
      api_token: [api_token_schema: ApiTokenRow]
    )
  end

  test "persists token and api.token_create audit row in one transaction", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    cfg = sigra_config(repo)

    assert {:ok, raw, token} =
             APIToken.create(cfg, user, %{name: "atomic", scopes: ["profile:read"]})

    assert is_binary(raw)
    assert token.name == "atomic"

    assert count(repo, "user_api_tokens") == 1
    assert count_where(repo, "audit_events", "action = 'api.token_create'") == 1
  end

  test "database insert failure rolls back token and audit row", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    cfg = sigra_config(repo)

    assert_raise Ecto.ConstraintError, fn ->
      APIToken.create(cfg, user, %{name: "BAD_TOKEN_NAME", scopes: ["profile:read"]})
    end

    assert count(repo, "user_api_tokens") == 0
    assert count(repo, "audit_events") == 0
  end

  test "revoke sets revoked_at and writes api.token_revoke in one transaction", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    cfg = sigra_config(repo)

    assert {:ok, _raw, token} =
             APIToken.create(cfg, user, %{name: "to-revoke", scopes: ["profile:read"]})

    assert {:ok, revoked} = APIToken.revoke(cfg, token.id)
    assert revoked.revoked_at != nil

    assert count_where(repo, "audit_events", "action = 'api.token_revoke'") == 1
  end

  test "revoke rolls back token update when api.token_revoke audit insert is rejected", %{
    repo: repo
  } do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT api_token_revoke_audit_guard CHECK (action <> 'api.token_revoke')
      """,
      []
    )

    try do
      user = %{id: Ecto.UUID.generate()}
      cfg = sigra_config(repo)

      assert {:ok, _raw, token} =
               APIToken.create(cfg, user, %{name: "revoke-guard", scopes: ["profile:read"]})

      assert_raise Ecto.ConstraintError, fn ->
        APIToken.revoke(cfg, token.id)
      end

      reloaded = repo.get(ApiTokenRow, token.id)
      assert is_nil(reloaded.revoked_at)
      assert count_where(repo, "audit_events", "action = 'api.token_revoke'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS api_token_revoke_audit_guard",
        []
      )
    end
  end

  test "revoke_all updates rows and emits one api.token_revoke_all with count metadata", %{
    repo: repo
  } do
    user = %{id: Ecto.UUID.generate()}
    cfg = sigra_config(repo)

    assert {:ok, _, _} =
             APIToken.create(cfg, user, %{name: "a", scopes: ["profile:read"]})

    assert {:ok, _, _} =
             APIToken.create(cfg, user, %{name: "b", scopes: ["profile:read"]})

    assert {:ok, 2} = APIToken.revoke_all(cfg, user)

    assert count_where(repo, "audit_events", "action = 'api.token_revoke_all'") == 1

    %{rows: [[meta]]} =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT metadata FROM audit_events WHERE action = 'api.token_revoke_all' LIMIT 1",
        []
      )

    assert meta["count"] == 2
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
end
