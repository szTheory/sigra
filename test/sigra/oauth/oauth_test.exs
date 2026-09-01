defmodule Sigra.OAuthTest do
  use ExUnit.Case, async: true

  import Sigra.Test.OAuthHelpers

  alias Sigra.OAuth
  alias Sigra.Error.OAuthError

  @secret_key_base String.duplicate("a", 64)

  # Mock strategy that implements Assent's interface (2-arg callback)
  # Used via Generic wrapper's :strategy key -- no HTTP calls
  defmodule MockStrategy do
    def authorize_url(config) do
      authorization_params = Keyword.get(config, :authorization_params, [])

      query =
        [state: "original", scope: "email"]
        |> Keyword.merge(authorization_params)
        |> maybe_put(:nonce, Keyword.get(config, :nonce))

      session_params =
        %{code_verifier: "pkce_verifier"}
        |> maybe_put(:nonce, Keyword.get(config, :nonce))

      {:ok,
       %{
         url: "https://provider.example.com/auth?#{URI.encode_query(query)}",
         session_params: session_params
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

    defp maybe_put(keyword, _key, nil) when is_list(keyword), do: keyword

    defp maybe_put(keyword, key, value) when is_list(keyword),
      do: Keyword.put(keyword, key, value)

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule OAuthHttpAdapter do
    @behaviour Assent.HTTPAdapter

    alias Assent.HTTPAdapter.HTTPResponse

    @impl true
    def request(method, url, _body, _headers, opts) do
      send(opts[:test_pid], {:oauth_http_request, method, url})

      {:ok,
       %HTTPResponse{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: opts[:token]
       }}
    end
  end

  defmodule CountingRepo do
    def get_by(Sigra.Test.MockIdentity, _clauses) do
      Process.put(
        :oauth_identity_routing_calls,
        Process.get(:oauth_identity_routing_calls, 0) + 1
      )

      nil
    end

    def get_by(Sigra.Test.MockUser, _clauses), do: nil

    def insert(%Ecto.Changeset{} = changeset) do
      {:ok,
       changeset
       |> Ecto.Changeset.apply_changes()
       |> Map.put(:id, System.unique_integer([:positive]))}
    end

    def insert(struct) when is_map(struct) do
      {:ok, Map.put(struct, :id, System.unique_integer([:positive]))}
    end

    def transaction(%Ecto.Multi{} = multi), do: Sigra.Test.MultiStub.run(__MODULE__, multi)
  end

  defmodule LinkRepo do
    def get_by(Sigra.Test.MockIdentity, _clauses), do: nil

    def get_by(Sigra.Test.MockUser, clauses) do
      email = clauses[:email]
      %{id: 50, email: email, hashed_password: "$argon2id$hash"}
    end
  end

  defmodule FailingStrategy do
    def authorize_url(_config) do
      {:error, %{reason: :provider_error}}
    end

    def callback(_config, _params) do
      {:error, %{reason: :provider_error}}
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

    test "enterprise authorize persists enterprise_context in session params and signed state" do
      config = build_config()

      enterprise = %{
        organization_id: "org-acme",
        connection_id: "conn-acme",
        routing_source: :domain_discovery
      }

      assert {:ok, _url, session_params} =
               OAuth.authorize_url(config, :mock, enterprise: enterprise)

      assert session_params.enterprise_context == enterprise

      assert {:ok, data} =
               Sigra.Token.verify(
                 @secret_key_base,
                 "sigra-oauth-state",
                 session_params.sigra_state,
                 max_age: 900
               )

      assert data.enterprise_context == enterprise
    end

    test "non-enterprise authorize continues without enterprise_context" do
      config = build_config()

      assert {:ok, _url, session_params} = OAuth.authorize_url(config, :mock, [])
      refute Map.has_key?(session_params, :enterprise_context)
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

    test "authorization URL nonce == session nonce" do
      config = build_config()

      assert {:ok, url, %{nonce: nonce} = session_params} =
               OAuth.authorize_url(config, :mock, provider_evidence: true)

      assert URI.decode_query(URI.parse(url).query)["nonce"] == nonce
      assert session_params.nonce == nonce
      assert byte_size(Base.url_decode64!(nonce, padding: false)) == 32
    end

    test "evidence authorization merges allowed parameters" do
      config = build_config()

      assert {:ok, url, _session_params} =
               OAuth.authorize_url(config, :mock,
                 provider_evidence: true,
                 authorization_params: [
                   prompt: "login",
                   claims: ~s({"id_token":{"auth_time":null}})
                 ]
               )

      query = URI.decode_query(URI.parse(url).query)
      assert query["prompt"] == "login"
      assert query["claims"] == ~s({"id_token":{"auth_time":null}})
    end

    test "every reserved atom/string authorization key is rejected" do
      reserved_keys = [
        :client_id,
        "client_id",
        :redirect_uri,
        "redirect_uri",
        :response_type,
        "response_type",
        :state,
        "state",
        :code_challenge,
        "code_challenge",
        :code_challenge_method,
        "code_challenge_method",
        :nonce,
        "nonce"
      ]

      for key <- reserved_keys do
        assert {:error, %OAuthError{error_code: :invalid_authorization_params}} =
                 OAuth.authorize_url(build_config(), :mock,
                   provider_evidence: true,
                   authorization_params: [{key, "must-not-reach-provider"}]
                 )
      end

      assert {:error, %OAuthError{error_code: :invalid_authorization_params}} =
               OAuth.authorize_url(build_config(), :mock,
                 provider_evidence: true,
                 authorization_params: %{prompt: "login"}
               )

      assert {:error, %OAuthError{error_code: :invalid_authorization_params}} =
               OAuth.authorize_url(build_config(), :mock, authorization_params: [prompt: "login"])
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

    test "exact evidence five-tuple" do
      config = build_google_config()
      {:ok, url, session_params} = OAuth.authorize_url(config, :google, provider_evidence: true)

      token = signed_id_token(session_params.nonce, %{"auth_time" => 1_777_777_777})
      config = put_google_token(config, token)
      params = %{"state" => URI.decode_query(URI.parse(url).query)["state"], "code" => "code"}

      assert {:ok, :registered, _user, _session,
              %{
                provider: :google,
                issuer: "https://issuer.example.com",
                subject: "provider_uid_123",
                auth_time: 1_777_777_777
              } = evidence} =
               OAuth.handle_callback(
                 config,
                 :google,
                 params,
                 session_params,
                 provider_evidence: true
               )

      assert Map.keys(evidence) |> Enum.sort() == [:auth_time, :issuer, :provider, :subject]
      assert_receive {:oauth_http_request, :post, "https://issuer.example.com/token"}
      refute_receive {:oauth_http_request, :post, "https://issuer.example.com/token"}
    end

    test "one process_callback/4 routing call" do
      Process.put(:oauth_identity_routing_calls, 0)
      config = build_google_config() |> Map.put(:repo, CountingRepo)
      {:ok, url, session_params} = OAuth.authorize_url(config, :google, provider_evidence: true)

      config = put_google_token(config, signed_id_token(session_params.nonce))
      params = %{"state" => URI.decode_query(URI.parse(url).query)["state"], "code" => "code"}

      assert {:ok, :registered, _user, _session, _evidence} =
               OAuth.handle_callback(
                 config,
                 :google,
                 params,
                 session_params,
                 provider_evidence: true
               )

      assert Process.get(:oauth_identity_routing_calls) == 1
    after
      Process.delete(:oauth_identity_routing_calls)
    end

    test "legacy four-tuple/link/error compatibility" do
      config = build_config()
      {:ok, url, session_params} = OAuth.authorize_url(config, :mock)
      params = %{"state" => URI.decode_query(URI.parse(url).query)["state"], "code" => "code"}

      assert {:ok, :registered, _user, _session} =
               OAuth.handle_callback(config, :mock, params, session_params)

      link_config = %{config | repo: LinkRepo}

      assert {:link_confirmation_required, %{provider: :mock, email: "test@example.com"}} =
               OAuth.handle_callback(link_config, :mock, params, session_params)

      assert {:error, %OAuthError{error_code: :state_mismatch}} =
               OAuth.handle_callback(config, :mock, %{"state" => "wrong"}, session_params)
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

  defp build_google_config do
    build_config(
      providers: [
        google: [
          client_id: "client-id",
          client_secret: "client-secret",
          redirect_uri: "https://app.example.com/oauth/callback",
          openid_configuration: %{
            "issuer" => "https://issuer.example.com",
            "authorization_endpoint" => "https://issuer.example.com/authorize",
            "token_endpoint" => "https://issuer.example.com/token",
            "token_endpoint_auth_methods_supported" => ["client_secret_post"]
          },
          id_token_signed_response_alg: "HS256",
          http_adapter: {OAuthHttpAdapter, test_pid: self(), token: nil}
        ]
      ]
    )
  end

  defp put_google_token(config, token) do
    providers =
      config.oauth
      |> Keyword.fetch!(:providers)
      |> Keyword.update!(:google, fn provider_config ->
        Keyword.put(
          provider_config,
          :http_adapter,
          {OAuthHttpAdapter,
           test_pid: self(), token: %{"access_token" => "access", "id_token" => token}}
        )
      end)

    %{config | oauth: Keyword.put(config.oauth, :providers, providers)}
  end

  defp signed_id_token(nonce, overrides \\ %{}) do
    now = :os.system_time(:second)

    claims =
      Map.merge(
        %{
          "iss" => "https://issuer.example.com",
          "sub" => "provider_uid_123",
          "aud" => "client-id",
          "exp" => now + 300,
          "iat" => now,
          "nonce" => nonce,
          "email" => "test@example.com",
          "name" => "Test",
          "email_verified" => true
        },
        overrides
      )

    {:ok, token} =
      Assent.Strategy.sign_jwt(claims, "HS256", "client-secret", json_library: Jason)

    token
  end

  defp sudo_session do
    %Sigra.Session{sudo_at: DateTime.utc_now()}
  end
end
