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

  describe "Phase 96 rate-limit wire proof" do
    defmodule TestHammer do
      use Hammer, backend: :ets
    end

    setup do
      Application.put_env(:sigra, :hammer_module, TestHammer)
      start_supervised!({TestHammer, clean_period: :timer.minutes(1)})
      :ok
    end

    test "POST /users/log_in returns allow and deny rate-limit headers", %{conn: conn} do
      # 1st request (Allowed)
      # Get the page to generate a session and CSRF token
      conn_get = get(conn, ~p"/users/log_in")
      
      valid_csrf = Plug.CSRFProtection.get_csrf_token()

      conn_1 =
        conn_get
        |> recycle()
        |> put_req_header("x-csrf-token", valid_csrf)
        |> put_req_header("x-forwarded-for", "203.0.113.1")
        |> post(~p"/users/log_in", %{"user" => %{"email" => "test@example.com", "password" => "wrong"}})

      IO.inspect(conn_1.status, label: "conn_1 status")
      IO.inspect(conn_1.resp_headers, label: "conn_1 headers")

      assert [limit] = Plug.Conn.get_resp_header(conn_1, "x-ratelimit-limit")
      assert [remaining] = Plug.Conn.get_resp_header(conn_1, "x-ratelimit-remaining")
      assert [reset] = Plug.Conn.get_resp_header(conn_1, "x-ratelimit-reset")
      
      assert limit == "10"
      assert String.to_integer(remaining) == 9
      assert String.to_integer(reset) > 0

      # Burn remaining requests to hit the limit
      conn_burn = Enum.reduce(1..9, conn_1, fn _, current_conn ->
        current_conn
        |> recycle()
        |> put_req_header("x-forwarded-for", "203.0.113.1")
        |> put_req_header("x-csrf-token", valid_csrf)
        |> post(~p"/users/log_in", %{"user" => %{"email" => "test@example.com", "password" => "wrong"}})
      end)

      # 11th request (Denied)
      conn_deny =
        conn_burn
        |> recycle()
        |> put_req_header("x-forwarded-for", "203.0.113.1")
        |> put_req_header("x-csrf-token", valid_csrf)
        |> post(~p"/users/log_in", %{"user" => %{"email" => "test@example.com", "password" => "wrong"}})

      assert conn_deny.status == 429
      assert Plug.Conn.get_resp_header(conn_deny, "x-ratelimit-limit") == ["10"]
      assert Plug.Conn.get_resp_header(conn_deny, "x-ratelimit-remaining") == ["0"]
      assert [retry_after] = Plug.Conn.get_resp_header(conn_deny, "retry-after")
      assert String.to_integer(retry_after) > 0
    end
  end

  describe "Phase 96 OAuth refresh wire proof" do
    test "Sigra.OAuth.get_tokens/3 refreshes an expired token using Assent TestServer", %{conn: _conn} do
      # Using our TestServer to mock the token refresh endpoint
      TestServer.start()
      site_url = TestServer.url()

      TestServer.add("/token",
        via: :post,
        to: fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "access_token" => "refreshed_access",
              "refresh_token" => "refreshed_refresh",
              "expires_in" => 3600,
              "token_type" => "Bearer"
            })
          )
        end
      )

      # Add a test provider override
      Application.put_env(:sigra, :oauth_provider_overrides,
        github: [
          client_id: "github-client",
          client_secret: "github-secret",
          base_url: site_url,
          token_url: "#{site_url}/token"
        ]
      )

      user = Example.Repo.insert!(%Example.Accounts.User{email: "refresh@example.com"})

      identity =
        Example.Repo.insert!(%Example.Accounts.UserIdentity{
          user_id: user.id,
          provider: "github",
          provider_uid: "refresh_uid",
          encrypted_access_token: "expired_access",
          encrypted_refresh_token: "refresh_me",
          token_expires_at: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -3600, :second),
          last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      # Calling get_oauth_tokens should detect expiration and trigger the refresh flow
      assert {:ok, %{access_token: "refreshed_access"}} =
               Sigra.OAuth.get_tokens(Example.Accounts.sigra_config(), Sigra.Identity.from_schema(identity))
               
      # Verify the DB was updated
      updated = Example.Repo.get!(Example.Accounts.UserIdentity, identity.id)
      assert updated.encrypted_access_token == "refreshed_access"
      assert updated.encrypted_refresh_token == "refreshed_refresh"
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
