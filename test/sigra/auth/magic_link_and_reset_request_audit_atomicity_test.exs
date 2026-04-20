defmodule Sigra.Auth.MagicLinkAndResetRequestAuditAtomicityTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Ecto.Multi
  alias Sigra.Audit
  alias Sigra.Audit.Assertions
  alias Sigra.Auth
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule B2User do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "b2_audit_users_43" do
      field(:email, :string)
      field(:confirmed_at, :utc_datetime)
      timestamps(type: :utc_datetime)
    end

    def changeset(struct \\ %__MODULE__{}, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:email, :confirmed_at])
      |> Ecto.Changeset.validate_required([:email])
    end
  end

  defmodule B2Token do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "b2_audit_tokens_43" do
      field(:token, :binary)
      field(:context, :string)
      field(:sent_to, :string)
      field(:user_id, :binary_id)
      timestamps(type: :utc_datetime)
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS b2_audit_tokens_43 CASCADE", [])
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS b2_audit_users_43 CASCADE", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE b2_audit_users_43 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text NOT NULL,
        confirmed_at timestamp,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE b2_audit_tokens_43 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        token bytea NOT NULL,
        context text NOT NULL,
        sent_to text NOT NULL,
        user_id uuid NOT NULL REFERENCES b2_audit_users_43(id) ON DELETE CASCADE,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """
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
      """
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "TRUNCATE TABLE b2_audit_tokens_43, b2_audit_users_43, audit_events RESTART IDENTITY CASCADE",
      []
    )

    %{repo: repo}
  end

  defp insert_user!(repo, email) do
    {:ok, u} =
      %B2User{}
      |> B2User.changeset(%{email: email})
      |> repo.insert()

    u
  end

  defp audit_opts(repo) do
    [repo: repo, audit_schema: AuditTestEvent]
  end

  test "request_magic_link writes token and auth.magic_link_request audit atomically", %{
    repo: repo
  } do
    user = insert_user!(repo, "magic-b2@example.com")

    assert {:ok, {_raw, _url}} =
             Auth.request_magic_link(repo, user.email,
               user_schema: B2User,
               user_token_schema: B2Token,
               url_fun: fn _t -> "https://example.com/m" end,
               audit_schema: AuditTestEvent
             )

    assert repo.aggregate(B2Token, :count, :id) == 1

    Assertions.assert_audit_fields(repo, AuditTestEvent, %{
      action: "auth.magic_link_request",
      actor_id: user.id,
      target_id: user.id
    })
  end

  test "verify_magic_link writes auth.magic_link_verify.success when audit_schema enabled", %{
    repo: repo
  } do
    user = insert_user!(repo, "verify-b2@example.com")
    {raw, hashed} = Sigra.Token.generate_hashed_token()

    {:ok, _} =
      %B2Token{}
      |> Ecto.Changeset.change(%{
        token: hashed,
        context: "magic_link",
        sent_to: user.email,
        user_id: user.id
      })
      |> repo.insert()

    assert {:ok, %B2User{}} =
             Auth.verify_magic_link(repo, raw,
               user_schema: B2User,
               user_token_schema: B2Token,
               audit_schema: AuditTestEvent,
               magic_link_ttl: 600
             )

    assert repo.aggregate(B2Token, :count, :id) == 0

    Assertions.assert_audit_fields(repo, AuditTestEvent, %{
      action: "auth.magic_link_verify.success",
      actor_id: user.id,
      target_id: user.id
    })
  end

  test "request_password_reset writes token and auth.password_reset_request audit atomically", %{
    repo: repo
  } do
    user = insert_user!(repo, "reset-b2@example.com")
    secret = String.duplicate("a", 64)

    assert {:ok, {_signed, _url}} =
             Auth.request_password_reset(repo, user.email,
               user_schema: B2User,
               user_token_schema: B2Token,
               secret_key_base: secret,
               url_fun: fn _t -> "https://example.com/r" end,
               audit_schema: AuditTestEvent
             )

    assert repo.aggregate(B2Token, :count, :id) == 1

    Assertions.assert_audit_fields(repo, AuditTestEvent, %{
      action: "auth.password_reset_request",
      actor_id: user.id,
      target_id: user.id
    })
  end

  test "magic link request composition rolls back token and audit on forced Multi failure", %{
    repo: repo
  } do
    user = insert_user!(repo, "rollback-b2@example.com")
    {_raw, hashed} = Sigra.Token.generate_hashed_token()

    token_struct =
      struct!(B2Token, %{
        token: hashed,
        context: "magic_link",
        sent_to: user.email,
        user_id: user.id
      })

    audit_opts =
      audit_opts(repo)
      |> Keyword.merge(
        organization_id: nil,
        effective_user_id: user.id,
        actor_id: user.id
      )

    multi =
      Multi.new()
      |> Multi.insert(:magic_link_token, token_struct)
      |> Audit.log_multi_safe(
        "auth.magic_link_request",
        Keyword.merge(audit_opts,
          actor_resolver: fn %{magic_link_token: t} -> t.user_id end,
          target_resolver: fn %{magic_link_token: t} -> t.user_id end,
          metadata: %{}
        )
      )
      |> Multi.run(:register_audit_atomicity_forced_fail, fn _repo, _ ->
        {:error, :forced}
      end)

    assert {:error, :register_audit_atomicity_forced_fail, :forced, _} = repo.transact(multi)
    assert repo.aggregate(B2Token, :count, :id) == 0
    assert [] == repo.all(from(a in AuditTestEvent, where: a.action == "auth.magic_link_request"))
  end
end
