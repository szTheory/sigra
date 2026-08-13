defmodule Sigra.AppLogin.ConcurrencyTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.AppLogin
  alias Sigra.Test.AppLoginSchemas.{Attempt, Challenge}
  alias Sigra.Test.AppSessionSchemas.{Family, Token, User}

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_session_users (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), email text NOT NULL,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_session_families (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
          user_id uuid NOT NULL REFERENCES sigra_app_session_users(id), client_ref varchar(255) NOT NULL,
          absolute_expires_at timestamp NOT NULL, revoked_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_session_tokens (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
          family_id uuid NOT NULL REFERENCES sigra_app_session_families(id), kind varchar(16) NOT NULL,
          digest bytea NOT NULL, expires_at timestamp NOT NULL, consumed_at timestamp,
          superseded_at timestamp, revoked_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
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
        """
        CREATE TABLE IF NOT EXISTS sigra_app_login_attempts (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), digest bytea NOT NULL UNIQUE,
          verifier_digest bytea NOT NULL, profile_id varchar(255) NOT NULL, callback text NOT NULL,
          user_id uuid NOT NULL REFERENCES sigra_app_session_users(id), client_ref varchar(255) NOT NULL,
          expires_at timestamp NOT NULL, consumed_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      :ok
    end)
  end

  test "two barrier-released callers consume one hosted code and issue one session", %{repo: repo} do
    parent = self()
    config = config(repo)
    profile = %{id: "ios-primary", client_ref: "ios-primary"}
    callback = "com.sigra.app:/login"
    code = "hosted-concurrent-code"
    verifier = String.duplicate("v", 43)
    {:ok, user} = repo.insert(%User{email: "hosted-concurrency@example.com"})
    attempt = insert_attempt(repo, user, code, verifier, profile, callback)

    callers =
      for _ <- 1..2 do
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(repo, parent, self())
          send(parent, {:hosted_exchange_ready, self()})

          receive do
            :go -> AppLogin.exchange_hosted(config, code, verifier, profile, callback)
          end
        end)
      end

    for _ <- callers do
      assert_receive {:hosted_exchange_ready, caller}
      send(caller, :go)
    end

    results = Enum.map(callers, &Task.await(&1, 5_000))

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, :invalid_code}, &1)) == 1
    assert %{consumed_at: consumed_at} = repo.get!(Attempt, attempt.id)
    assert not is_nil(consumed_at)
    assert repo.aggregate(Family, :count) == 1
    assert repo.aggregate(Token, :count) == 2
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      app_session: [
        family_schema: Family,
        token_schema: Token,
        app_login_code_schema: Attempt,
        app_login_challenge_schema: Challenge,
        first_party_profiles: [
          %{
            id: "ios-primary",
            client_ref: "ios-primary",
            callback_uris: ["com.sigra.app:/login"],
            direct_login: :browser_required
          }
        ]
      ]
    )
  end

  defp insert_attempt(repo, user, code, verifier, profile, callback) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    repo.insert!(%Attempt{
      digest: Sigra.Token.hash_token(code),
      verifier_digest: verifier |> Sigra.AppLogin.PKCE.challenge() |> Sigra.Token.hash_token(),
      profile_id: profile.id,
      callback: callback,
      user_id: user.id,
      client_ref: profile.client_ref,
      expires_at: DateTime.add(now, 60, :second)
    })
  end
end
