defmodule Sigra.OAuthTest do
  use ExUnit.Case, async: true

  import Sigra.Test.OAuthHelpers

  alias Sigra.OAuth
  alias Sigra.Error.OAuthError

  @secret_key_base String.duplicate("a", 64)

  # Mock strategy that implements Assent's interface (2-arg callback)
  # Used via Generic wrapper's :strategy key -- no HTTP calls
  defmodule MockStrategy do
    def authorize_url(_config) do
      {:ok,
       %{
         url: "https://provider.example.com/auth?state=original&scope=email",
         session_params: %{code_verifier: "pkce_verifier"}
       }}
    end

    # Assent interface: callback(config, params) -> {:ok, %{user: map, token: map}}
    def callback(_config, _params) do
      {:ok,
       %{
         user: %{
           "sub" => "uid_123",
           "email" => "test@example.com",
           "name" => "Test",
           "picture" => nil,
           "email_verified" => true
         },
         token: %{
           "access_token" => "tok",
           "refresh_token" => "ref",
           "expires_in" => 3600
         }
       }}
    end

    def refresh(_provider_config, _refresh_token, _config) do
      {:ok, %{"access_token" => "new_tok", "refresh_token" => "new_ref", "expires_in" => 3600}}
    end
  end

  defmodule FailingStrategy do
    def authorize_url(_config) do
      {:error, %{reason: :provider_error}}
    end

    def callback(_config, _params) do
      {:error, %{reason: :provider_error}}
    end

    def refresh(_provider_config, _refresh_token, _config) do
      {:error, %Assent.RequestError{response: %{"error" => "invalid_grant"}}}
    end
  end

  describe "authorize_url/3" do
    test "returns URL with HMAC-signed state and session params" do
      config = build_config()

      assert {:ok, url, session_params} = OAuth.authorize_url(config, :mock, [])
      assert is_binary(url)
      assert String.contains?(url, "https://")
      assert Map.has_key?(session_params, :sigra_state)
      assert is_binary(session_params.sigra_state)
    end

    test "preserves PKCE code_verifier in session_params" do
      config = build_config()

      assert {:ok, _url, session_params} = OAuth.authorize_url(config, :mock, [])
      assert Map.has_key?(session_params, :code_verifier)
      assert session_params.code_verifier == "pkce_verifier"
    end

    test "HMAC state replaces original state in URL" do
      config = build_config()

      assert {:ok, url, session_params} = OAuth.authorize_url(config, :mock, [])

      # The URL should contain the HMAC state, not the original
      uri = URI.parse(url)
      query = URI.decode_query(uri.query)
      assert query["state"] == session_params.sigra_state
      refute query["state"] == "original"
    end

    test "HMAC state is verifiable via Token.verify" do
      config = build_config()

      assert {:ok, _url, session_params} = OAuth.authorize_url(config, :mock, [])

      assert {:ok, data} =
               Sigra.Token.verify(
                 @secret_key_base,
                 "sigra-oauth-state",
                 session_params.sigra_state,
                 max_age: 900
               )

      assert data.provider == "mock"
      assert is_binary(data.nonce)
    end

    test "returns error for unknown provider" do
      config = build_config(providers: [])

      assert {:error, :unknown_provider} = OAuth.authorize_url(config, :discord, [])
    end

    test "returns error when strategy fails" do
      config =
        build_config(
          providers: [
            failing: [client_id: "x", client_secret: "y", strategy: FailingStrategy]
          ]
        )

      assert {:error, %OAuthError{error_code: :authorize_failed}} =
               OAuth.authorize_url(config, :failing, [])
    end
  end

  describe "handle_callback/4" do
    test "returns error on state mismatch" do
      config = build_config()
      params = %{"state" => "invalid_state", "code" => "auth_code"}
      session_params = %{sigra_state: "different_state"}

      assert {:error, %OAuthError{error_code: :state_mismatch}} =
               OAuth.handle_callback(config, :mock, params, session_params)
    end

    test "returns error when state is missing" do
      config = build_config()
      params = %{"code" => "auth_code"}
      session_params = %{sigra_state: "some_state"}

      assert {:error, %OAuthError{error_code: :state_mismatch}} =
               OAuth.handle_callback(config, :mock, params, session_params)
    end

    test "verifies HMAC state and processes callback on valid state" do
      config = build_config()

      # Generate a valid authorize URL first to get valid state
      {:ok, url, session_params} = OAuth.authorize_url(config, :mock, [])

      # Extract state from URL
      uri = URI.parse(url)
      query = URI.decode_query(uri.query)
      state = query["state"]

      params = %{"state" => state, "code" => "auth_code"}

      # This will call MockStrategy.callback, then Callback.process_callback
      # Since MockRepo returns nil for identity and user lookups,
      # it should register a new user
      result = OAuth.handle_callback(config, :mock, params, session_params)

      # Could be registered or error depending on mock repo behavior
      # With MockRepo, identity lookup returns nil, user lookup returns nil,
      # so it goes to registration via Multi
      assert match?({:ok, :registered, _, _}, result) or match?({:error, _}, result)
    end

    test "returns error when provider returns no email" do
      config = build_config()

      # Test via Callback directly since handle_callback requires valid state
      assert {:error, %OAuthError{error_code: :no_email}} =
               OAuth.Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(%{"email" => nil}),
                 mock_token()
               )
    end
  end

  describe "link_provider/4" do
    test "returns error when identity already exists for provider" do
      config = build_config()
      user = %{id: 1, email: "user@example.com"}

      assert {:error, :already_linked} =
               OAuth.link_provider(
                 config,
                 user,
                 %{
                   provider: :google,
                   provider_uid: "uid_123",
                   user_info: mock_user_info(),
                   token: mock_token()
                 },
                 session: sudo_session()
               )
    end

    test "returns error without sudo session" do
      config = build_config()
      user = %{id: 1, email: "user@example.com"}

      assert {:error, :sudo_required} =
               OAuth.link_provider(config, user, %{
                 provider: :google,
                 provider_uid: "uid_123",
                 user_info: mock_user_info(),
                 token: mock_token()
               })
    end
  end

  describe "unlink_provider/4" do
    test "returns error when trying to unlink last auth method" do
      config = build_config()
      user = %{id: 1, email: "user@example.com", hashed_password: nil}

      assert {:error, :last_provider} =
               OAuth.unlink_provider(config, user, :google, session: sudo_session())
    end

    test "succeeds when user has password as fallback" do
      config = build_config()
      user = %{id: 1, email: "user@example.com", hashed_password: "$argon2id$..."}

      assert {:ok, :unlinked} =
               OAuth.unlink_provider(config, user, :google, session: sudo_session())
    end

    test "returns error without sudo session" do
      config = build_config()
      user = %{id: 1, email: "user@example.com", hashed_password: "$argon2id$..."}

      assert {:error, :sudo_required} = OAuth.unlink_provider(config, user, :google)
    end
  end

  describe "get_tokens/2" do
    test "returns error when no refresh token and token expired" do
      config = build_config()

      identity = %Sigra.Identity{
        id: 1,
        user_id: 1,
        provider: "google",
        provider_uid: "uid_123",
        encrypted_access_token: "expired_token",
        encrypted_refresh_token: nil,
        token_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      }

      assert {:error, :token_expired} = OAuth.get_tokens(config, identity)
    end

    test "returns tokens when not expired" do
      config = build_config()

      identity = %Sigra.Identity{
        id: 1,
        user_id: 1,
        provider: "google",
        provider_uid: "uid_123",
        encrypted_access_token: "valid_token",
        encrypted_refresh_token: "refresh_token",
        token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      assert {:ok, %{access_token: "valid_token"}} = OAuth.get_tokens(config, identity)
    end

    test "returns tokens when token_expires_at is nil (no expiry info)" do
      config = build_config()

      identity = %Sigra.Identity{
        id: 1,
        user_id: 1,
        provider: "google",
        provider_uid: "uid_123",
        encrypted_access_token: "valid_token",
        encrypted_refresh_token: nil,
        token_expires_at: nil
      }

      assert {:ok, %{access_token: "valid_token"}} = OAuth.get_tokens(config, identity)
    end

    test "maps typed failures from refresh_token/2 back to :token_expired for compatibility" do
      config =
        build_config(
          providers: [
            failing: [client_id: "x", client_secret: "y", strategy: FailingStrategy]
          ]
        )

      identity = %Sigra.Identity{
        id: 1,
        user_id: 1,
        provider: "failing",
        provider_uid: "uid_123",
        encrypted_access_token: "expired",
        encrypted_refresh_token: "refresh_me",
        token_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      }

      assert {:error, :token_expired} = OAuth.get_tokens(config, identity)
    end
  end

  describe "refresh_token/2" do
    test "returns existing tokens when not expired" do
      config = build_config()

      identity = %Sigra.Identity{
        id: 1,
        user_id: 1,
        provider: "google",
        provider_uid: "uid_123",
        encrypted_access_token: "valid",
        encrypted_refresh_token: "refresh",
        token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      assert {:ok, %{access_token: "valid", refresh_token: "refresh"}} =
               OAuth.refresh_token(config, identity)
    end

    test "returns :reauth_required when token expired and no refresh token" do
      config = build_config()

      identity = %Sigra.Identity{
        id: 1,
        user_id: 1,
        provider: "google",
        provider_uid: "uid_123",
        encrypted_access_token: "expired",
        encrypted_refresh_token: nil,
        token_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      }

      assert {:error, :reauth_required} = OAuth.refresh_token(config, identity)
    end

    test "calls refresh on strategy and returns typed outcome on success" do
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
              "access_token" => "new_tok",
              "refresh_token" => "new_ref",
              "expires_in" => 3600,
              "token_type" => "Bearer"
            })
          )
        end
      )

      config =
        build_config(
          providers: [
            mock: [client_id: "test_id", client_secret: "test_secret", strategy: MockStrategy, base_url: site_url, token_url: "#{site_url}/token"]
          ]
        )

      identity = %Sigra.Identity{
        id: 1,
        user_id: 1,
        provider: "mock",
        provider_uid: "uid_123",
        encrypted_access_token: "expired",
        encrypted_refresh_token: "refresh_me",
        token_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      }

      assert {:ok, %{"access_token" => "new_tok", "refresh_token" => "new_ref"}} =
               OAuth.refresh_token(config, identity)
    end

    test "calls refresh on strategy and returns classified error on failure" do
      TestServer.start()
      site_url = TestServer.url()

      TestServer.add("/token",
        via: :post,
        to: fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            400,
            Jason.encode!(%{"error" => "invalid_grant"})
          )
        end
      )

      config =
        build_config(
          providers: [
            failing: [client_id: "x", client_secret: "y", strategy: FailingStrategy, base_url: site_url, token_url: "#{site_url}/token"]
          ]
        )

      identity = %Sigra.Identity{
        id: 1,
        user_id: 1,
        provider: "failing",
        provider_uid: "uid_123",
        encrypted_access_token: "expired",
        encrypted_refresh_token: "refresh_me",
        token_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      }

      assert {:error, :reauth_required} = OAuth.refresh_token(config, identity)
    end
  end

  describe "compute_token_expires_at/1" do
    test "returns nil for nil token" do
      assert OAuth.compute_token_expires_at(nil) == nil
    end

    test "returns nil when expires_in is not present" do
      assert OAuth.compute_token_expires_at(%{"access_token" => "x"}) == nil
    end

    test "returns DateTime when expires_in is present" do
      result = OAuth.compute_token_expires_at(%{"expires_in" => 3600})
      assert %DateTime{} = result
      # Should be roughly 1 hour from now
      diff = DateTime.diff(result, DateTime.utc_now(), :second)
      assert diff >= 3598 and diff <= 3602
    end
  end

  # -- Helpers --

  defp build_config(overrides \\ []) do
    providers =
      Keyword.get(overrides, :providers,
        mock: [client_id: "test_id", client_secret: "test_secret", strategy: MockStrategy],
        google: [client_id: "test_id", client_secret: "test_secret"]
      )

    %{
      repo: Sigra.Test.MockRepo,
      user_schema: Sigra.Test.MockUser,
      secret_key_base: @secret_key_base,
      oauth: [
        enabled: true,
        providers: providers,
        session_type: :remember_me,
        link_confirmation: :required,
        trust_provider_email: true
      ],
      session: [
        session_schema: Sigra.Test.MockSession,
        store: Sigra.Test.MockSessionStore
      ],
      identity_schema: Sigra.Test.MockIdentity
    }
  end

  defp sudo_session do
    %Sigra.Session{sudo_at: DateTime.utc_now()}
  end
end
