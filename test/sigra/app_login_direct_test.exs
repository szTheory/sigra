defmodule Sigra.AppLoginDirectTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.AppLogin
  alias Sigra.AppSession
  alias Sigra.Test.AppLoginSchemas.{Attempt, Challenge}
  alias Sigra.Test.AppSessionSchemas.{Family, Token, User}

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_login_challenges (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), kind varchar(32) NOT NULL,
          digest bytea NOT NULL UNIQUE, profile_id varchar(255) NOT NULL,
          user_id uuid NOT NULL REFERENCES sigra_app_session_users(id), client_ref varchar(255) NOT NULL,
          expires_at timestamp NOT NULL, consumed_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )
    end)

    :ok
  end

  setup %{repo: repo} do
    {:ok, user} = repo.insert(%User{email: "direct-login@example.com"})
    %{repo: repo, config: config(repo), user: user}
  end

  test "a password-allowed profile issues the hosted app-session credential contract", %{
    config: config,
    user: user
  } do
    assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
             AppLogin.start_direct(config, "android-primary", user.email, "correct-password",
               authenticate_user: fn email, "correct-password" when email == user.email ->
                 {:ok, user}
               end
             )

    assert is_binary(access) and is_binary(refresh)

    assert {:ok, %{family_id: ^family_id, user_id: user_id}} =
             AppSession.authenticate(config, access)

    assert user_id == user.id
  end

  test "browser-required policy returns before password authentication", %{config: config} do
    verifier = fn _email, _password -> flunk("browser-required must not verify a password") end

    assert {:error, :browser_required} =
             AppLogin.start_direct(config, "ios-primary", "any@example.com", "password",
               authenticate_user: verifier
             )
  end

  test "credential, account, policy, and verifier denials share one direct failure", %{
    config: config,
    user: user
  } do
    callbacks = [authenticate_user: fn _email, _password -> {:error, :invalid} end]

    results = [
      AppLogin.start_direct(config, "unknown", user.email, "password", callbacks),
      AppLogin.start_direct(config, "android-primary", user.email, "wrong", callbacks),
      AppLogin.start_direct(config, "android-primary", user.email, "password", []),
      AppLogin.start_direct(config, "android-primary", user.email, "password",
        authenticate_user: fn _email, _password -> raise "host verifier failed" end
      ),
      AppLogin.start_direct(config, "android-primary", nil, "password", callbacks)
    ]

    assert Enum.uniq(results) == [{:error, :invalid_credentials}]
  end

  test "MFA password success returns a digest-only five-minute challenge", %{
    repo: repo,
    config: config,
    user: user
  } do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert {:ok, %{mfa_challenge: challenge}} =
             AppLogin.start_direct(config, "android-primary", user.email, "correct-password",
               authenticate_user: fn _email, _password -> {:ok, user, %{mfa_required: true}} end,
               now: now
             )

    assert is_binary(challenge)
    assert Map.keys(%{mfa_challenge: challenge}) == [:mfa_challenge]
    persisted = repo.one!(Challenge)
    assert persisted.digest == challenge_digest(challenge)
    refute persisted.digest == challenge
    assert persisted.profile_id == "android-primary"
    assert persisted.user_id == user.id
    assert persisted.client_ref == "android-primary"
    assert DateTime.to_unix(persisted.expires_at) == DateTime.to_unix(now) + 300
  end

  test "valid TOTP and backup factors consume one challenge and issue app sessions", %{
    repo: repo,
    config: config,
    user: user
  } do
    for {factor, callback} <- [
          {:totp, :mfa_verify},
          {:backup_code, :mfa_verify_backup}
        ] do
      {:ok, %{mfa_challenge: challenge}} =
        AppLogin.start_direct(config, "android-primary", user.email, "correct-password",
          authenticate_user: fn _email, _password -> {:ok, user, %{mfa_required: true}} end
        )

      callback_result = if factor == :backup_code, do: {:ok, :consumed, 0}, else: {:ok, :verified}

      opts =
        [{callback, fn ^user, "correct-factor" -> callback_result end}, factor: factor]

      assert {:ok, %{access_token: access, family_id: family_id}} =
               AppLogin.complete_direct_mfa(config, challenge, "correct-factor", opts)

      assert %{consumed_at: consumed_at} =
               repo.get_by!(Challenge, digest: challenge_digest(challenge))

      assert not is_nil(consumed_at)
      assert {:ok, %{family_id: ^family_id}} = AppSession.authenticate(config, access)
    end
  end

  test "wrong MFA factors do not consume a challenge and every terminal MFA failure is uniform",
       %{
         repo: repo,
         config: config,
         user: user
       } do
    {:ok, %{mfa_challenge: challenge}} =
      AppLogin.start_direct(config, "android-primary", user.email, "correct-password",
        authenticate_user: fn _email, _password -> {:ok, user, %{mfa_required: true}} end
      )

    verify = fn _user, code ->
      if code == "correct-factor", do: {:ok, :verified}, else: {:error, :invalid}
    end

    assert {:error, :invalid_credentials} =
             AppLogin.complete_direct_mfa(config, challenge, "wrong-factor", mfa_verify: verify)

    assert %{consumed_at: nil} =
             repo.get_by!(Challenge, digest: challenge_digest(challenge))

    assert 0 = repo.aggregate(Family, :count)

    assert {:ok, _credentials} =
             AppLogin.complete_direct_mfa(config, challenge, "correct-factor", mfa_verify: verify)

    failures = [
      AppLogin.complete_direct_mfa(config, challenge, "correct-factor", mfa_verify: verify),
      AppLogin.complete_direct_mfa(config, "malformed", "correct-factor", mfa_verify: verify),
      AppLogin.complete_direct_mfa(config, nil, "correct-factor", mfa_verify: verify)
    ]

    assert Enum.uniq(failures) == [{:error, :invalid_credentials}]
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
          },
          %{
            id: "android-primary",
            client_ref: "android-primary",
            callback_uris: ["com.sigra.app:/login"],
            direct_login: :password_allowed
          }
        ]
      ]
    )
  end

  defp challenge_digest(challenge) do
    {:ok, decoded} = Base.url_decode64(challenge, padding: false)
    Sigra.Token.hash_token(decoded)
  end
end
