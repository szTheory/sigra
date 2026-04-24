defmodule Sigra.AccountAuditAtomicityTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Sigra.Account
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule AccountAuditUserToken do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "account_audit_user_tokens" do
      field(:token, :binary)
      field(:context, :string)
      field(:sent_to, :string)
      field(:user_id, :binary_id)
      timestamps(type: :utc_datetime_usec)
    end
  end

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

    for t <- ["account_audit_user_tokens", "account_audit_users_44", "audit_events"] do
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
      """
      CREATE TABLE account_audit_user_tokens (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id uuid NOT NULL,
        token bytea NOT NULL,
        context text NOT NULL,
        sent_to text,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "TRUNCATE TABLE account_audit_users_44, account_audit_user_tokens, audit_events RESTART IDENTITY CASCADE",
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

  defp email_change_opts(repo) do
    Keyword.merge(
      base_opts(repo),
      email_taken_fn: fn _r, _email -> false end,
      build_email_token_fn: fn user, context ->
        {encoded, hashed} = Sigra.Token.generate_hashed_token()

        tok = %AccountAuditUserToken{
          token: hashed,
          context: context,
          sent_to: user.email,
          user_id: user.id
        }

        {encoded, tok}
      end,
      token_query_fn: fn user, contexts ->
        from(t in AccountAuditUserToken,
          where: t.user_id == ^user.id and t.context in ^contexts
        )
      end,
      find_user_by_token_fn: fn repo, encoded ->
        case Base.url_decode64(encoded, padding: false) do
          {:ok, raw} ->
            h = Sigra.Token.hash_token(raw)

            q =
              from(u in AccountUser,
                join: t in AccountAuditUserToken,
                on: t.user_id == u.id,
                where: t.token == ^h
              )

            repo.one(q)

          :error ->
            nil
        end
      end
    )
  end

  test "change_password persists user update and account.password_change audit together", %{
    repo: repo
  } do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(
        AccountUser.changeset(%AccountUser{id: id}, %{
          email: "pw@example.com",
          hashed_password: "old-hash"
        })
      )

    assert {:ok, %AccountUser{} = updated} =
             Account.change_password(
               repo,
               user,
               "old-secret",
               %{password: "new-stored"},
               Keyword.merge(base_opts(repo),
                 validate_password_fn: fn u, cur ->
                   u.id == user.id and cur == "old-secret"
                 end
               )
             )

    assert updated.hashed_password == "new-stored"
    reloaded = repo.get!(AccountUser, id)
    assert reloaded.hashed_password == "new-stored"
    assert count_where(repo, "audit_events", "action = 'account.password_change'") == 1
  end

  test "rolls back change_password when audit insert is rejected by database guard", %{
    repo: repo
  } do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT account_audit_pw_change_guard CHECK (action <> 'account.password_change')
      """,
      []
    )

    try do
      id = Ecto.UUID.generate()

      {:ok, user} =
        repo.insert(
          AccountUser.changeset(%AccountUser{id: id}, %{
            email: "pw-guard@example.com",
            hashed_password: "before"
          })
        )

      assert_raise Ecto.ConstraintError, fn ->
        Account.change_password(
          repo,
          user,
          "secret",
          %{password: "after"},
          Keyword.merge(base_opts(repo),
            validate_password_fn: fn u, cur ->
              u.id == user.id and cur == "secret"
            end
          )
        )
      end

      reloaded = repo.get!(AccountUser, id)
      assert reloaded.hashed_password == "before"
      assert count(repo, "audit_events") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS account_audit_pw_change_guard",
        []
      )
    end
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

  test "clear_password_change_requirement persists must_change_password false and account.password_change audit together",
       %{repo: repo} do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(
        AccountUser.changeset(%AccountUser{id: id}, %{
          email: "forced-clear@example.com",
          hashed_password: "hash",
          must_change_password: true
        })
      )

    assert {:ok, %AccountUser{} = updated} =
             Account.clear_password_change_requirement(repo, user, base_opts(repo))

    assert updated.must_change_password == false
    reloaded = repo.get!(AccountUser, id)
    assert reloaded.must_change_password == false
    assert count_where(repo, "audit_events", "action = 'account.password_change'") == 1

    assert 1 ==
             count_where(
               repo,
               "audit_events",
               "action = 'account.password_change' AND (metadata->>'forced')::boolean IS TRUE"
             )
  end

  test "rolls back clear_password_change_requirement when audit insert is rejected by database guard",
       %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT account_audit_forced_clear_guard CHECK (action <> 'account.password_change')
      """,
      []
    )

    try do
      id = Ecto.UUID.generate()

      {:ok, user} =
        repo.insert(
          AccountUser.changeset(%AccountUser{id: id}, %{
            email: "forced-guard@example.com",
            hashed_password: "hash",
            must_change_password: true
          })
        )

      assert_raise Ecto.ConstraintError, fn ->
        Account.clear_password_change_requirement(repo, user, base_opts(repo))
      end

      reloaded = repo.get!(AccountUser, id)
      assert reloaded.must_change_password == true
      assert count(repo, "audit_events") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS account_audit_forced_clear_guard",
        []
      )
    end
  end

  test "clear_password_change_requirement without audit_schema skips audit insert", %{repo: repo} do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(
        AccountUser.changeset(%AccountUser{id: id}, %{
          email: "no-audit-forced@example.com",
          hashed_password: "hash",
          must_change_password: true
        })
      )

    opts = Keyword.drop(base_opts(repo), [:audit_schema])

    assert {:ok, %AccountUser{} = cleared} =
             Account.clear_password_change_requirement(repo, user, opts)

    assert cleared.must_change_password == false
    assert count(repo, "audit_events") == 0
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

  test "request_email_change persists pending email, token, and audit", %{repo: repo} do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(AccountUser.changeset(%AccountUser{id: id}, %{email: "req@example.com"}))

    assert {:ok, %AccountUser{} = updated, _encoded} =
             Account.request_email_change(
               repo,
               user,
               "new-req@example.com",
               email_change_opts(repo)
             )

    assert updated.pending_email == "new-req@example.com"
    reloaded = repo.get!(AccountUser, id)
    assert reloaded.pending_email == "new-req@example.com"
    assert count_where(repo, "audit_events", "action = 'account.email_change_request'") == 1
    assert token_count(repo) == 1
  end

  test "confirm_email_change switches email and writes audit", %{repo: repo} do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(
        AccountUser.changeset(%AccountUser{id: id}, %{email: "old-confirm@example.com"})
      )

    assert {:ok, pending_user, encoded} =
             Account.request_email_change(
               repo,
               user,
               "new-confirm@example.com",
               email_change_opts(repo)
             )

    assert pending_user.pending_email == "new-confirm@example.com"

    assert {:ok, %AccountUser{} = confirmed} =
             Account.confirm_email_change(repo, encoded, email_change_opts(repo))

    assert confirmed.email == "new-confirm@example.com"
    assert is_nil(confirmed.pending_email)
    reloaded = repo.get!(AccountUser, id)
    assert reloaded.email == "new-confirm@example.com"
    assert is_nil(reloaded.pending_email)
    assert count_where(repo, "audit_events", "action = 'account.email_change_request'") == 1
    assert count_where(repo, "audit_events", "action = 'account.email_change_confirm'") == 1
    assert token_count(repo) == 0
  end

  test "cancel_email_change clears pending and writes audit", %{repo: repo} do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(AccountUser.changeset(%AccountUser{id: id}, %{email: "cancel-old@example.com"}))

    assert {:ok, pending_user, _enc} =
             Account.request_email_change(
               repo,
               user,
               "cancel-new@example.com",
               email_change_opts(repo)
             )

    assert {:ok, %AccountUser{} = cleared} =
             Account.cancel_email_change(repo, pending_user, email_change_opts(repo))

    assert is_nil(cleared.pending_email)
    reloaded = repo.get!(AccountUser, id)
    assert is_nil(reloaded.pending_email)
    assert count_where(repo, "audit_events", "action = 'account.email_change_request'") == 1
    assert count_where(repo, "audit_events", "action = 'account.email_change_cancel'") == 1
    assert token_count(repo) == 0
  end

  test "rolls back request_email_change when audit insert is rejected by database guard", %{
    repo: repo
  } do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT account_audit_email_req_guard CHECK (action <> 'account.email_change_request')
      """,
      []
    )

    try do
      id = Ecto.UUID.generate()

      {:ok, user} =
        repo.insert(
          AccountUser.changeset(%AccountUser{id: id}, %{email: "req-guard@example.com"})
        )

      assert_raise Ecto.ConstraintError, fn ->
        Account.request_email_change(repo, user, "nope@example.com", email_change_opts(repo))
      end

      reloaded = repo.get!(AccountUser, id)
      assert is_nil(reloaded.pending_email)
      assert count(repo, "audit_events") == 0
      assert token_count(repo) == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS account_audit_email_req_guard",
        []
      )
    end
  end

  test "rolls back confirm_email_change when audit insert is rejected by database guard", %{
    repo: repo
  } do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(
        AccountUser.changeset(%AccountUser{id: id}, %{email: "confirm-guard@example.com"})
      )

    assert {:ok, _pending_user, encoded} =
             Account.request_email_change(
               repo,
               user,
               "confirm-new@example.com",
               email_change_opts(repo)
             )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT account_audit_email_confirm_guard CHECK (action <> 'account.email_change_confirm')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        Account.confirm_email_change(repo, encoded, email_change_opts(repo))
      end

      reloaded = repo.get!(AccountUser, id)
      assert reloaded.email == "confirm-guard@example.com"
      assert reloaded.pending_email == "confirm-new@example.com"
      assert count_where(repo, "audit_events", "action = 'account.email_change_confirm'") == 0
      assert token_count(repo) == 1
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS account_audit_email_confirm_guard",
        []
      )
    end
  end

  test "rolls back cancel_email_change when audit insert is rejected by database guard", %{
    repo: repo
  } do
    id = Ecto.UUID.generate()

    {:ok, user} =
      repo.insert(
        AccountUser.changeset(%AccountUser{id: id}, %{email: "cancel-guard@example.com"})
      )

    assert {:ok, pending_user, _enc} =
             Account.request_email_change(
               repo,
               user,
               "cancel-guard-new@example.com",
               email_change_opts(repo)
             )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT account_audit_email_cancel_guard CHECK (action <> 'account.email_change_cancel')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        Account.cancel_email_change(repo, pending_user, email_change_opts(repo))
      end

      reloaded = repo.get!(AccountUser, id)
      assert reloaded.pending_email == "cancel-guard-new@example.com"
      assert count_where(repo, "audit_events", "action = 'account.email_change_cancel'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS account_audit_email_cancel_guard",
        []
      )
    end
  end

  defp token_count(repo) do
    count(repo, "account_audit_user_tokens")
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
