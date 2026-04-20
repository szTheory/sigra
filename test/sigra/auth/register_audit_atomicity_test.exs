defmodule Sigra.Auth.RegisterAuditAtomicityTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Sigra.Audit.Assertions
  alias Sigra.Auth
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule RegUser do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "reg_audit_users_43" do
      field(:email, :string)
      field(:hashed_password, :string)
      timestamps()
    end

    def changeset(struct \\ %__MODULE__{}, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:email, :hashed_password])
      |> Ecto.Changeset.validate_required([:email, :hashed_password])
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS reg_audit_users_43 CASCADE", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE reg_audit_users_43 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text NOT NULL,
        hashed_password text NOT NULL,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now(),
        CONSTRAINT reg_audit_users_43_email_key UNIQUE (email)
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
      "TRUNCATE TABLE reg_audit_users_43, audit_events RESTART IDENTITY CASCADE",
      []
    )

    %{repo: repo}
  end

  defp register_opts(repo) do
    [
      changeset_fn: fn attrs -> RegUser.changeset(%RegUser{}, attrs) end,
      audit_schema: AuditTestEvent,
      repo: repo
    ]
  end

  test "persists auth.register.success in same transaction as user insert", %{repo: repo} do
    attrs = %{"email" => "reg-ok@example.com", "hashed_password" => "hash"}

    assert {:ok, user} =
             Auth.register(repo, attrs, register_opts(repo))

    assert user.email == "reg-ok@example.com"

    Assertions.assert_audit_fields(repo, AuditTestEvent, %{
      action: "auth.register.success",
      actor_id: user.id,
      target_id: user.id,
      metadata: %{"method" => "password"}
    })
  end

  test "rolls back user and audit when a post-user Multi step fails", %{repo: repo} do
    attrs = %{"email" => "reg-roll@example.com", "hashed_password" => "hash"}

    multi =
      Auth.register_user_multi(attrs, register_opts(repo))
      |> Ecto.Multi.run(:register_audit_atomicity_forced_fail, fn _repo, _ ->
        {:error, :forced}
      end)

    assert {:error, :register_audit_atomicity_forced_fail, :forced, _} =
             repo.transact(multi)

    assert [] == repo.all(RegUser)
    assert [] == repo.all(from(a in AuditTestEvent, where: a.action == "auth.register.success"))
  end
end
