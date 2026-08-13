defmodule Sigra.Plug.FetchAppSessionTest do
  use Sigra.Test.PostgresCase, async: false

  import ExUnit.CaptureLog
  import Plug.Test

  alias Sigra.AppSession
  alias Sigra.Plug.FetchAppSession
  alias Sigra.Test.AppSessionSchemas.{Family, Token, User}

  defmodule Scope do
    @moduledoc false
    defstruct [:user]
  end

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

      for statement <- [
            """
            CREATE TABLE IF NOT EXISTS sigra_app_session_users (
              id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
              email text NOT NULL,
              inserted_at timestamp NOT NULL DEFAULT now(),
              updated_at timestamp NOT NULL DEFAULT now()
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS sigra_app_session_families (
              id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
              user_id uuid NOT NULL REFERENCES sigra_app_session_users(id),
              client_ref varchar(255) NOT NULL,
              absolute_expires_at timestamp NOT NULL,
              revoked_at timestamp,
              inserted_at timestamp NOT NULL DEFAULT now(),
              updated_at timestamp NOT NULL DEFAULT now()
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS sigra_app_session_tokens (
              id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
              family_id uuid NOT NULL REFERENCES sigra_app_session_families(id),
              kind varchar(16) NOT NULL,
              digest bytea NOT NULL,
              expires_at timestamp NOT NULL,
              consumed_at timestamp,
              superseded_at timestamp,
              revoked_at timestamp,
              inserted_at timestamp NOT NULL DEFAULT now(),
              updated_at timestamp NOT NULL DEFAULT now()
            )
            """
          ] do
        Ecto.Adapters.SQL.query!(repo, statement, [])
      end

      Ecto.Adapters.SQL.query!(
        repo,
        "CREATE UNIQUE INDEX IF NOT EXISTS sigra_app_session_tokens_digest_idx ON sigra_app_session_tokens (digest)",
        []
      )
    end)

    :ok
  end

  setup %{repo: repo} do
    {:ok, user} = repo.insert(%User{email: "app-session-plug@example.com"})
    %{config: config(repo), repo: repo, user: user}
  end

  test "exports the Plug interface and retains forward-compatible host pipeline options" do
    opts = [config: config(Sigra.Test.PostgresRepo), scope_module: Scope]

    assert FetchAppSession.init(opts) == opts
    assert function_exported?(FetchAppSession, :init, 1)
    assert function_exported?(FetchAppSession, :call, 2)
  end

  test "authenticates one explicit access credential into a normal Scope with bounded facts", %{
    config: config,
    user: user
  } do
    assert {:ok, %{access_token: access, family_id: family_id}} =
             AppSession.issue(config, user, "ios-primary", [])

    parent = self()

    log =
      capture_log(fn ->
        send(parent, {:app_session_result, call_with_access(config, access)})
      end)

    assert_receive {:app_session_result, result}

    assert %Scope{user: %User{id: user_id}} = result.assigns.current_scope
    assert user_id == user.id

    assert result.private[:sigra_auth] == %{
             credential_kind: :app_session,
             credential_id: result.private[:sigra_auth].credential_id,
             family_id: family_id,
             scopes: [],
             auth_method: :app_session,
             assurance: []
           }

    assert is_binary(result.private[:sigra_auth].credential_id)
    refute inspect(result.assigns) =~ access
    refute inspect(result.private) =~ access
    refute inspect(result.assigns) =~ "ios-primary"
    refute inspect(result.private) =~ "ios-primary"
    refute log =~ access
    refute log =~ "Bearer " <> access
    refute log =~ "ios-primary"
  end

  test "missing, malformed, refresh-kind, expired, revoked, and deleted-user credentials fail closed",
       %{
         config: config,
         repo: repo,
         user: user
       } do
    for authorization <- [nil, "Basic nope", "Bearer "] do
      result = call_with_authorization(config, authorization)
      assert result.assigns.current_scope == nil
      refute Map.has_key?(result.private, :sigra_auth)
    end

    assert {:ok, %{access_token: access, refresh_token: refresh}} =
             AppSession.issue(config, user, "ios-primary", [])

    for raw_credential <- ["malformed", refresh] do
      result = call_with_access(config, raw_credential)
      assert result.assigns.current_scope == nil
      refute Map.has_key?(result.private, :sigra_auth)
      refute inspect(result.assigns) =~ raw_credential
      refute inspect(result.private) =~ raw_credential
    end

    {1, _} =
      repo.update_all(
        Ecto.Query.from(token in Token,
          where:
            token.digest == ^Sigra.Token.hash_token(Base.url_decode64!(access, padding: false))
        ),
        set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :second)]
      )

    assert_failed_without_facts(config, access)

    assert {:ok, %{access_token: revoked_access, family_id: revoked_family_id}} =
             AppSession.issue(config, user, "ios-secondary", [])

    {1, _} =
      repo.update_all(
        Ecto.Query.from(family in Family, where: family.id == ^revoked_family_id),
        set: [revoked_at: now()]
      )

    assert_failed_without_facts(config, access)
    assert_failed_without_facts(config, revoked_access)

    assert {:ok, %{access_token: deleted_access}} =
             AppSession.issue(config, user, "ios-tertiary", [])

    repo.delete_all(Token)
    repo.delete_all(Family)
    repo.delete!(user)
    assert_failed_without_facts(config, deleted_access)
  end

  test "returns an existing authenticated Scope unchanged without parsing the header", %{
    config: config
  } do
    existing_scope = %Scope{user: %{id: "user-1"}}

    result =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer should-not-be-inspected")
      |> Plug.Conn.assign(:current_scope, existing_scope)
      |> FetchAppSession.call(FetchAppSession.init(config: config, scope_module: Scope))

    assert result.assigns.current_scope == existing_scope
    refute Map.has_key?(result.private, :sigra_auth)
  end

  defp assert_failed_without_facts(config, credential) do
    result = call_with_access(config, credential)
    assert result.assigns.current_scope == nil
    refute Map.has_key?(result.private, :sigra_auth)
    refute inspect(result.assigns) =~ credential
    refute inspect(result.private) =~ credential
  end

  defp call_with_access(config, access), do: call_with_authorization(config, "Bearer " <> access)

  defp call_with_authorization(config, authorization) do
    conn = conn(:get, "/api/resource")

    conn =
      if authorization,
        do: Plug.Conn.put_req_header(conn, "authorization", authorization),
        else: conn

    FetchAppSession.call(conn, FetchAppSession.init(config: config, scope_module: Scope))
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      app_session: [family_schema: Family, token_schema: Token]
    )
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
