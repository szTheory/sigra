defmodule ExampleWeb.OAuthControllerTest do
  use ExampleWeb.ConnCase, async: false

  alias Sigra.Testing.OAuthIssuer

  @moduletag :example_app

  setup do
    on_exit(fn ->
      Application.delete_env(:sigra, :oauth_provider_overrides)
    end)

    :ok
  end

  describe "GET /auth/google/callback" do
    test "rejects state mismatch with the safe flash", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{sigra_oauth_state: valid_state_token()})
        |> Plug.Conn.assign(:sigra_config, Example.Accounts.sigra_config())

      conn =
        conn
        |> recycle()
        |> init_test_session(%{sigra_oauth_state: valid_state_token()})
        |> Plug.Conn.assign(:sigra_config, Example.Accounts.sigra_config())
        |> get(~p"/auth/google/callback", %{"state" => "bad-state", "code" => "bad-code"})

      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Authentication expired. Please try again."
    end

    test "surfaces provider error with the generated flash", %{conn: conn} do
      oauth_state = valid_state_token()

      Application.put_env(:sigra, :oauth_provider_overrides,
        google: [
          openid_configuration: %{
            "issuer" => "http://127.0.0.1:4009",
            "authorization_endpoint" => "http://127.0.0.1:4009/oauth2/v2/auth",
            "token_endpoint" => "http://127.0.0.1:4009/token",
            "userinfo_endpoint" => "http://127.0.0.1:4009/userinfo",
            "jwks_uri" => "http://127.0.0.1:4009/jwks"
          }
        ]
      )

      conn =
        conn
        |> init_test_session(%{
          sigra_oauth_state: oauth_state,
          sigra_oauth_code_verifier: "unused-verifier"
        })
        |> Plug.Conn.assign(:sigra_config, Example.Accounts.sigra_config())
        |> get(~p"/auth/google/callback", %{
          "state" => oauth_state,
          "error" => "access_denied"
        })

      assert redirected_to(conn) == ~p"/users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Could not sign in with google. Please try again or use another method."
    end

    test "shows the no-email flash when the provider omits email", %{conn: conn} do
      {conn, authorize_url, issuer} =
        begin_google_oauth(conn, %{email: "", sub: "no-email-sub"}, pkce_required: false)

      oauth_state = get_session(conn, :sigra_oauth_state)
      code_verifier = get_session(conn, :sigra_oauth_code_verifier)
      callback_params = authorize_callback_params!(authorize_url)

      conn =
        conn
        |> recycle()
        |> init_test_session(%{
          sigra_oauth_state: oauth_state,
          sigra_oauth_code_verifier: code_verifier
        })
        |> Plug.Conn.assign(:sigra_config, Example.Accounts.sigra_config())
        |> get(~p"/auth/google/callback", callback_params)

      assert redirected_to(conn) == ~p"/users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "We need your email to create an account. Please grant email permission and try again."

      OAuthIssuer.stop(issuer)
    end
  end

  defp begin_google_oauth(conn, user_claims, issuer_opts) do
    issuer = start_google_issuer!(user_claims, issuer_opts)

    conn =
      conn
      |> init_test_session(%{})
      |> Plug.Conn.assign(:sigra_config, Example.Accounts.sigra_config())
      |> get(~p"/auth/google")

    authorize_url = redirected_to(conn, 302)

    on_exit(fn ->
      OAuthIssuer.stop(issuer)
    end)

    {conn, authorize_url, issuer}
  end

  defp start_google_issuer!(user_claims, issuer_opts) do
    {:ok, issuer} =
      OAuthIssuer.start_link(
        Keyword.merge([provider: :google, user: user_claims], issuer_opts)
      )

    Application.put_env(:sigra, :oauth_provider_overrides,
      google: [
        client_id: "google-client-id",
        client_secret: "google-client-secret",
        base_url: OAuthIssuer.url(issuer),
        openid_configuration: OAuthIssuer.openid_config(issuer)
      ]
    )

    issuer
  end

  defp authorize_callback_params!(authorize_url) do
    :inets.start()
    :ssl.start()

    request = {String.to_charlist(authorize_url), []}

    {:ok, {{_version, 302, _reason}, headers, _body}} =
      :httpc.request(:get, request, [{:autoredirect, false}], [])

    location =
      headers
      |> Enum.find_value(fn
        {~c"location", value} -> List.to_string(value)
        {"location", value} -> value
        _other -> nil
      end)

    location
    |> URI.parse()
    |> Map.fetch!(:query)
    |> URI.decode_query()
  end

  defp valid_state_token do
    Sigra.Token.generate(
      Example.Accounts.sigra_config().secret_key_base,
      "sigra-oauth-state",
      %{provider: "google", nonce: "controller-test"},
      max_age: 900
    )
  end
end
