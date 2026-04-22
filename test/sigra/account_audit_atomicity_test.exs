defmodule Sigra.AccountAuditAtomicityTest do
  use ExUnit.Case, async: false

  alias Sigra.Account
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule AccountUser do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "account_audit_users_44" do
      field(:email, :string)
      field(:hashed_password, :string)
      field(:pending_email, :string)
      field(:must_change_password, :boolean, default: false)
      field(:password_changed_at, :utc_datetime_usec)
      field(:deleted_at, :utc_datetime_usec)
      field(:scheduled_deletion_at, :utc_datetime_usec)
      field(:original_email, :string)
      field(:confirmed_at, :utc_datetime_usec)
      timestamps(type: :utc_datetime_usec)
    end

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [
        :email,
        :hashed_password,
        :pending_email,
        :must_change_password,
        :password_changed_at,
        :deleted_at,
        :scheduled_deletion_at,
        :original_email,
        :confirmed_at
      ])
      |> Ecto.Changeset.validate_required([:email])
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    for t <- ["account_audit_users_44", "audit_events"] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE account_audit_users_44 (
        id uuid PRIMARY KEY,
        email text NOT NULL,
        hashed_password text,
        pending_email text,
        must_change_password boolean NOT NULL DEFAULT false,
        password_changed_at timestamp,
        deleted_at timestamp,
        scheduled_deletion_at timestamp,
        original_email text,
        confirmed_at timestamp,
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
      "TRUNCATE TABLE account_audit_users_44, audit_events RESTART IDENTITY CASCADE",
      []
    )

    %{repo: repo}
  end

  defp base_opts(repo) do
    [
      repo: repo,
      audit_schema: AuditTestEvent,
      changeset_fn: fn user, attrs ->
        attrs =
          case {Map.get(attrs, :password), Map.get(attrs, "password")} do
            {nil, nil} ->
              attrs

            {pwd, _} when is_binary(pwd) ->
              attrs |> Map.delete(:password) |> Map.put(:hashed_password, pwd)

            {_, pwd} when is_binary(pwd) ->
              attrs |> Map.delete("password") |> Map.put(:hashed_password, pwd)
          end

        AccountUser.changeset(user, attrs)
      end,
      session_store: nil,
      config: []
    ]
  end

  test "set_password persists user update and account.password_change audit together", %{
    repo: repo
  } do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(
        AccountUser.changeset(%AccountUser{id: id}, %{
          email: "oauth@example.com",
          hashed_password: nil
        })
      )

    assert {:ok, %AccountUser{} = updated} =
             Account.set_password(repo, user, %{password: "stored"}, base_opts(repo))

    assert updated.hashed_password == "stored"
    reloaded = repo.get!(AccountUser, id)
    assert reloaded.hashed_password == "stored"
    assert count_where(repo, "audit_events", "action = 'account.password_change'") == 1
  end

  test "rolls back password set when audit insert is rejected by database guard", %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT account_audit_pw_guard CHECK (action <> 'account.password_change')
      """,
      []
    )

    try do
      id = Ecto.UUID.generate()

      {:ok, user} =
        repo.insert(
          AccountUser.changeset(%AccountUser{id: id}, %{
            email: "guard@example.com",
            hashed_password: nil
          })
        )

      assert_raise Ecto.ConstraintError, fn ->
        Account.set_password(repo, user, %{password: "nope"}, base_opts(repo))
      end

      reloaded = repo.get!(AccountUser, id)
      assert is_nil(reloaded.hashed_password)
      assert count(repo, "audit_events") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS account_audit_pw_guard",
        []
      )
    end
  end

  test "rolls back anonymize when account.deletion_execute audit is rejected", %{repo: repo} do
    id = Ecto.UUID.generate()
    deleted_at = DateTime.utc_now() |> DateTime.truncate(:second)
    scheduled_at = DateTime.add(deleted_at, 86_400, :second) |> DateTime.truncate(:second)

    {:ok, user} =
      repo.insert(
        AccountUser.changeset(%AccountUser{id: id}, %{
          email: "victim@example.com",
          hashed_password: "hash",
          deleted_at: deleted_at,
          scheduled_deletion_at: scheduled_at,
          original_email: "victim@example.com"
        })
      )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT account_audit_del_guard CHECK (action <> 'account.deletion_execute')
      """,
      []
    )

    try do
      opts =
        Keyword.merge(base_opts(repo), config: [deletion: [strategy: :anonymize]])

      assert_raise Ecto.ConstraintError, fn ->
        Account.execute_deletion(repo, user, opts)
      end

      reloaded = repo.get!(AccountUser, id)
      assert reloaded.email == "victim@example.com"
      assert count(repo, "audit_events") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS account_audit_del_guard",
        []
      )
    end
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
