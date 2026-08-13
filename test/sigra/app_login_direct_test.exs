defmodule Sigra.AppLoginDirectTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.AppLogin
  alias Sigra.AppSession
  alias Sigra.Test.AppLoginSchemas.{Attempt, Challenge}
  alias Sigra.Test.AppSessionSchemas.{Family, Token, User}

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
               authenticate_user: fn email, "correct-password" when email == user.email -> {:ok, user} end
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
end
