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

  test "issues digest-only opaque credentials and authenticates access without sliding the family",
       %{
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

    assert DateTime.diff(family.absolute_expires_at, family.inserted_at, :second) in 7_775_999..7_776_000

    assert {:ok, %{user_id: user_id, family_id: ^family_id, token_id: token_id}} =
             AppSession.authenticate(config, access)

    assert user_id == user.id
    assert is_binary(token_id)
    assert repo.get!(Family, family_id).absolute_expires_at == family.absolute_expires_at
  end

  test "fails closed for malformed credentials and absent app-session schemas", %{config: config} do
    assert {:error, :invalid_token} = AppSession.authenticate(config, "malformed")

    missing_schemas = Sigra.Config.new!(repo: config.repo, user_schema: User)

    assert {:error, :app_session_not_configured} =
             AppSession.authenticate(missing_schemas, "opaque")
  end

  test "refresh rotates one family without sliding its absolute deadline", %{
    repo: repo,
    config: config,
    user: user
  } do
    assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
             AppSession.issue(config, user, "ios-primary", [])

    family =
      repo.get!(Family, family_id)
      |> Ecto.Changeset.change(absolute_expires_at: DateTime.add(past(), 11, :second))
      |> repo.update!()

    original_tokens = tokens_for_family(repo, family_id)
    original_access = Enum.find(original_tokens, &(&1.kind == :access))
    original_refresh = Enum.find(original_tokens, &(&1.kind == :refresh))

    assert {:ok, %{access_token: new_access, refresh_token: new_refresh, family_id: ^family_id}} =
             AppSession.refresh(config, refresh)

    refute new_access in [access, refresh]
    refute new_refresh in [access, refresh, new_access]
    assert repo.get!(Family, family_id).absolute_expires_at == family.absolute_expires_at

    assert %{consumed_at: consumed_at} = repo.get!(Token, original_refresh.id)
    assert not is_nil(consumed_at)
    assert %{superseded_at: superseded_at} = repo.get!(Token, original_access.id)
    assert not is_nil(superseded_at)

    tokens = tokens_for_family(repo, family_id)
    assert Enum.count(tokens) == 4
    assert Enum.count(tokens, &(&1.kind == :access and is_nil(&1.superseded_at))) == 1
    assert Enum.count(tokens, &(&1.kind == :refresh and is_nil(&1.consumed_at))) == 1

    replacement_refresh = Enum.find(tokens, &(&1.kind == :refresh and is_nil(&1.consumed_at)))
    assert replacement_refresh.expires_at == family.absolute_expires_at
    assert {:error, :invalid_token} = AppSession.authenticate(config, access)
    assert {:ok, %{family_id: ^family_id}} = AppSession.authenticate(config, new_access)
  end

  test "refresh rejects idle and absolute expiry without replacement credentials", %{
    repo: repo,
    config: config,
    user: user
  } do
    assert {:ok, %{refresh_token: idle_refresh, family_id: idle_family_id}} =
             AppSession.issue(config, user, "ios-idle", [])

    idle_token = refresh_token_for_family(repo, idle_family_id)
    repo.update!(Ecto.Changeset.change(idle_token, expires_at: past()))

    assert {:error, :token_expired} = AppSession.refresh(config, idle_refresh)
    assert Enum.count(tokens_for_family(repo, idle_family_id)) == 2

    assert {:ok, %{refresh_token: absolute_refresh, family_id: absolute_family_id}} =
             AppSession.issue(config, user, "ios-absolute", [])

    absolute_family = repo.get!(Family, absolute_family_id)
    repo.update!(Ecto.Changeset.change(absolute_family, absolute_expires_at: past()))

    assert {:error, :token_expired} = AppSession.refresh(config, absolute_refresh)
    assert Enum.count(tokens_for_family(repo, absolute_family_id)) == 2
  end

  test "refresh reuse revokes only the consumed refresh family before returning", %{
    repo: repo,
    config: config,
    user: user
  } do
    assert {:ok, %{refresh_token: refresh, family_id: family_id}} =
             AppSession.issue(config, user, "ios-primary", [])

    assert {:ok, %{access_token: replacement_access}} = AppSession.refresh(config, refresh)
    assert {:error, :reuse_detected} = AppSession.refresh(config, refresh)

    assert not is_nil(repo.get!(Family, family_id).revoked_at)
    assert Enum.all?(tokens_for_family(repo, family_id), &(not is_nil(&1.revoked_at)))
    assert {:error, :invalid_token} = AppSession.authenticate(config, replacement_access)
  end

  test "refresh rejects malformed and wrong-kind inputs without cross-family mutation", %{
    repo: repo,
    config: config,
    user: user
  } do
    assert {:ok, %{access_token: access, family_id: first_family_id}} =
             AppSession.issue(config, user, "ios-first", [])

    assert {:ok, %{family_id: second_family_id}} =
             AppSession.issue(config, user, "ios-second", [])

    first_before = tokens_for_family(repo, first_family_id)
    second_before = tokens_for_family(repo, second_family_id)
    assert {:error, :invalid_token} = AppSession.refresh(config, "malformed")
    assert {:error, :invalid_token} = AppSession.refresh(config, access)

    assert tokens_for_family(repo, first_family_id) == first_before
    assert tokens_for_family(repo, second_family_id) == second_before
  end

  test "owner-bound family revoke immediately denies its access and refresh without leaking foreign selectors",
       %{repo: repo, config: config, user: user} do
    {:ok, other_user} = repo.insert(%User{email: "other-app-session@example.com"})

    assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
             AppSession.issue(config, user, "ios-owned", [])

    assert {:ok, %{access_token: other_access, family_id: other_family_id}} =
             AppSession.issue(config, other_user, "ios-other", [])

    assert {:error, :not_found} = Sigra.Auth.revoke_app_session(config, user, other_family_id)
    assert {:ok, %{family_id: ^other_family_id}} = AppSession.authenticate(config, other_access)

    assert {:ok, %{id: ^family_id}} = Sigra.Auth.revoke_app_session(config, user, family_id)
    assert {:error, :invalid_token} = AppSession.authenticate(config, access)
    assert {:error, :invalid_token} = AppSession.refresh(config, refresh)
    assert Enum.all?(tokens_for_family(repo, family_id), &(not is_nil(&1.revoked_at)))
    assert {:error, :not_found} = Sigra.Auth.revoke_app_session(config, user, family_id)
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      app_session: [family_schema: Family, token_schema: Token]
    )
  end

  defp tokens_for_family(repo, family_id) do
    repo.all(Ecto.Query.from(t in Token, where: t.family_id == ^family_id, order_by: t.id))
  end

  defp refresh_token_for_family(repo, family_id) do
    repo.one!(
      Ecto.Query.from(t in Token, where: t.family_id == ^family_id and t.kind == :refresh)
    )
  end

  defp past do
    DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.truncate(:microsecond)
  end
end
