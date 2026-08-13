defmodule Sigra.AppSessionSecurityEventTest do
  use Sigra.Test.PostgresCase, async: false

  import Mox

  alias Sigra.{AppSession, Auth, Token}
  alias Sigra.Test.AppSessionSchemas.Family
  alias Sigra.Test.AppSessionSchemas.Token, as: AppToken
  alias Sigra.Test.AuditEvent

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_app_session_users" do
      field :email, :string
      field :hashed_password, :string
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule UserToken do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_security_event_user_tokens" do
      field :token, :binary
      field :context, :string
      field :sent_to, :string
      field :user_id, :binary_id
      timestamps(type: :utc_datetime_usec)
    end
  end

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE sigra_app_session_users ADD COLUMN IF NOT EXISTS hashed_password text",
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_security_event_user_tokens (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), token bytea NOT NULL,
          context varchar(255) NOT NULL, sent_to varchar(255), user_id uuid NOT NULL,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      :ok
    end)
  end

  setup %{repo: repo} do
    {:ok, user} =
      repo.insert(%User{
        email: "security-event-#{System.unique_integer([:positive])}@example.com",
        hashed_password: "old"
      })

    %{repo: repo, user: user}
  end

  test "password reset revokes app credentials in its transaction and leaves no secret in audit metadata",
       %{repo: repo, user: user} do
    config = config(repo)

    assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
             AppSession.issue(config, user, "reset-client")

    {encoded, reset_token} = reset_token(user)
    {:ok, _} = repo.insert(reset_token)

    assert {:ok, %{hashed_password: "new"}} =
             Auth.reset_password(repo, encoded, %{"password" => "new"}, reset_opts(config))

    assert {:error, :invalid_token} = AppSession.authenticate(config, access)
    assert {:error, :invalid_token} = AppSession.refresh(config, refresh)
    assert not is_nil(repo.get!(Family, family_id).revoked_at)

    assert repo.aggregate(
             Ecto.Query.from(t in UserToken, where: t.user_id == ^user.id),
             :count,
             :id
           ) == 0

    [event] =
      repo.all(
        Ecto.Query.from(e in AuditEvent, where: e.action == "auth.password_reset_complete")
      )

    refute inspect(event.metadata) =~ access
    refute inspect(event.metadata) =~ refresh
  end

  test "password-reset audit rejection rolls back password, reset token, and app-family revocation",
       %{repo: repo, user: user} do
    config = config(repo)
    assert {:ok, %{family_id: family_id}} = AppSession.issue(config, user, "rollback-client")
    {encoded, reset_token} = reset_token(user)
    {:ok, token_record} = repo.insert(reset_token)

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT security_event_reset_audit CHECK (action <> 'auth.password_reset_complete')",
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        Auth.reset_password(repo, encoded, %{"password" => "new"}, reset_opts(config))
      end

      assert repo.get!(User, user.id).hashed_password == "old"
      assert repo.get!(UserToken, token_record.id).id == token_record.id
      assert is_nil(repo.get!(Family, family_id).revoked_at)
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS security_event_reset_audit",
        []
      )
    end
  end

  test "sign-out-all revokes only the target user's app credentials even when retaining a browser token",
       %{repo: repo, user: user} do
    config = config(repo)

    {:ok, other} =
      repo.insert(%User{
        email: "other-#{System.unique_integer([:positive])}@example.com",
        hashed_password: "old"
      })

    assert {:ok, %{access_token: access}} = AppSession.issue(config, user, "signout-client")
    assert {:ok, %{access_token: other_access}} = AppSession.issue(config, other, "other-client")
    user_id = user.id

    Sigra.MockSessionStore
    |> expect(:list_by_user, fn ^user_id, _opts -> [] end)
    |> expect(:delete_all_for_user, fn ^user_id, opts ->
      assert opts[:except_token] == "current-browser"
      {0, nil}
    end)

    assert {0, nil} =
             Auth.delete_all_sessions(
               %{config | session: [store: Sigra.MockSessionStore, session_schema: User]},
               user.id,
               except_token: "current-browser"
             )

    assert {:error, :invalid_token} = AppSession.authenticate(config, access)
    assert {:ok, _} = AppSession.authenticate(config, other_access)
  end

  defp config(repo),
    do:
      Sigra.Config.new!(
        repo: repo,
        user_schema: User,
        app_session: [family_schema: Family, token_schema: AppToken]
      )

  defp reset_opts(config),
    do: [
      secret_key_base: "security-event-secret",
      user_token_schema: UserToken,
      user_schema: User,
      changeset_fn: fn user, attrs ->
        Ecto.Changeset.change(user, hashed_password: attrs["password"])
      end,
      app_session_config: config,
      audit_schema: AuditEvent
    ]

  defp reset_token(user) do
    {raw, _digest} = Token.generate_hashed_token()
    signed = Plug.Crypto.sign("security-event-secret", "sigra-reset-token", raw)

    {Base.url_encode64(signed, padding: false),
     %UserToken{
       token: Token.hash_token(raw),
       context: "reset_password",
       sent_to: user.email,
       user_id: user.id
     }}
  end
end
