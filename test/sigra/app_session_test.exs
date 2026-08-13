defmodule Sigra.AppSessionTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.AppSession
  alias Sigra.Test.AppSessionSchemas.{Family, Token, User}

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_session_users (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
          email text NOT NULL,
          inserted_at timestamp NOT NULL DEFAULT now(),
          updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
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
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "CREATE INDEX IF NOT EXISTS sigra_app_session_families_user_id_idx ON sigra_app_session_families (user_id)",
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
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
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "CREATE UNIQUE INDEX IF NOT EXISTS sigra_app_session_tokens_digest_idx ON sigra_app_session_tokens (digest)",
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "CREATE INDEX IF NOT EXISTS sigra_app_session_tokens_family_kind_idx ON sigra_app_session_tokens (family_id, kind)",
        []
      )
    end)

    :ok
  end

  setup %{repo: repo} do
    {:ok, user} = repo.insert(%User{email: "app-session@example.com"})
    %{config: config(repo), user: user}
  end

  test "issues digest-only opaque credentials and authenticates access without sliding the family", %{
    repo: repo,
    config: config,
    user: user
  } do
    assert config.app_session[:access_ttl] == 900
    assert config.app_session[:refresh_idle_ttl] == 2_592_000
    assert config.app_session[:absolute_ttl] == 7_776_000

    assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
             AppSession.issue(config, user, "ios-primary", [])

    assert is_binary(access) and byte_size(access) > 0
    assert is_binary(refresh) and byte_size(refresh) > 0
    refute access == refresh

    family = repo.get!(Family, family_id)
    tokens = repo.all(Ecto.Query.from(t in Token, where: t.family_id == ^family_id))

    assert Enum.count(tokens) == 2
    assert Enum.sort(Enum.map(tokens, & &1.kind)) == [:access, :refresh]
    assert Enum.all?(tokens, &(byte_size(&1.digest) == 32))
    refute Enum.any?(tokens, &(&1.digest == access or &1.digest == refresh))
    refute inspect(tokens) =~ access
    refute inspect(tokens) =~ refresh
    refute inspect(tokens) =~ "ios-primary"
    assert DateTime.diff(family.absolute_expires_at, family.inserted_at, :second) in 7_776_000..7_776_001

    assert {:ok, %{user_id: user_id, family_id: ^family_id, token_id: token_id}} =
             AppSession.authenticate(config, access)

    assert user_id == user.id
    assert is_binary(token_id)
    assert repo.get!(Family, family_id).absolute_expires_at == family.absolute_expires_at
  end

  test "fails closed for malformed credentials and absent app-session schemas", %{config: config} do
    assert {:error, :invalid_token} = AppSession.authenticate(config, "malformed")

    missing_schemas = Sigra.Config.new!(repo: config.repo, user_schema: User)
    assert {:error, :app_session_not_configured} = AppSession.authenticate(missing_schemas, "opaque")
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      app_session: [family_schema: Family, token_schema: Token]
    )
  end
end
