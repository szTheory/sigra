defmodule Sigra.OAuth.AssentOidcContractTest do
  @moduledoc """
  SEED-4 / OIDC stub path: Assent ships `Assent.Strategy.OIDC` so host apps can
  wire a local or dockerized OIDC issuer (Keycloak, Zitadel, etc.) without Google.
  """
  use ExUnit.Case, async: true

  alias Sigra.OAuth.Strategies.{Apple, Google}

  defmodule HTTPAdapter do
    @behaviour Assent.HTTPAdapter

    alias Assent.HTTPAdapter.HTTPResponse

    @impl true
    def request(method, url, _body, _headers, opts) do
      send(opts[:test_pid], {:oidc_http_request, method, url})

      {:ok,
       %HTTPResponse{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: opts[:token]
       }}
    end
  end

  test "Assent.Strategy.OIDC is present for stand-in IdP configuration" do
    assert {:module, Assent.Strategy.OIDC} = Code.ensure_loaded(Assent.Strategy.OIDC)
    assert function_exported?(Assent.Strategy.OIDC, :authorize_url, 1)
    assert function_exported?(Assent.Strategy.OIDC, :validate_id_token, 2)
  end

  test "matching token nonce" do
    nonce = "matching-nonce"

    assert {:ok, user, token,
            %{
              provider: :google,
              issuer: "https://issuer.example.com",
              subject: "subject-123",
              auth_time: 1_777_777_777
            } = evidence} =
             evidence_callback(
               signed_id_token(%{"nonce" => nonce, "auth_time" => 1_777_777_777}),
               nonce
             )

    assert user["sub"] == "subject-123"
    assert is_binary(token["id_token"])
    assert Map.keys(evidence) |> Enum.sort() == [:auth_time, :issuer, :provider, :subject]
    refute Map.has_key?(evidence, :claims)
    refute Map.has_key?(evidence, :token)
    refute Map.has_key?(evidence, :config)
  end

  test "missing token nonce" do
    token = signed_id_token(%{}, drop: ["nonce"])

    assert {:error, _reason} = evidence_callback(token, "session-nonce")
  end

  test "wrong token nonce" do
    token = signed_id_token(%{"nonce" => "wrong-nonce"})

    assert {:error, _reason} = evidence_callback(token, "session-nonce")
  end

  test "signature failure" do
    token = signed_id_token(%{"nonce" => "nonce"}, secret: "wrong-secret")

    assert {:error, _reason} = evidence_callback(token, "nonce")
  end

  test "issuer failure" do
    token = signed_id_token(%{"nonce" => "nonce", "iss" => "https://attacker.example.com"})

    assert {:error, _reason} = evidence_callback(token, "nonce")
  end

  test "audience failure" do
    token = signed_id_token(%{"nonce" => "nonce", "aud" => "another-client"})

    assert {:error, _reason} = evidence_callback(token, "nonce")
  end

  test "expiry failure" do
    token = signed_id_token(%{"nonce" => "nonce", "exp" => :os.system_time(:second) - 1})

    assert {:error, _reason} = evidence_callback(token, "nonce")
  end

  test "issued-at failure" do
    token = signed_id_token(%{"nonce" => "nonce", "iat" => :os.system_time(:second) - 120})

    assert {:error, _reason} =
             evidence_callback(token, "nonce", id_token_ttl_seconds: 60)
  end

  test "iat failure" do
    token = signed_id_token(%{"nonce" => "nonce"}, drop: ["iat"])

    assert {:error, _reason} = evidence_callback(token, "nonce")
  end

  test "one authorization-code exchange" do
    nonce = "one-exchange"

    assert {:ok, _user, _token, _evidence} =
             evidence_callback(signed_id_token(%{"nonce" => nonce}), nonce)

    assert_receive {:oidc_http_request, :post, "https://issuer.example.com/token"}
    refute_receive {:oidc_http_request, :post, "https://issuer.example.com/token"}
  end

  test "missing/non-integer auth_time is nil/unavailable" do
    for {auth_time_overrides, expected} <- [{%{}, nil}, {%{"auth_time" => "recent"}, nil}] do
      nonce = "auth-time-#{inspect(auth_time_overrides)}"
      token = signed_id_token(Map.put(auth_time_overrides, "nonce", nonce))

      assert {:ok, _user, _token, %{auth_time: ^expected}} = evidence_callback(token, nonce)
    end
  end

  test "token/nonce validation errors fail the callback" do
    assert {:error, _reason} = evidence_callback("not-a-jwt", "nonce")

    assert {:error, _reason} =
             evidence_callback(signed_id_token(%{"nonce" => "token-nonce"}), "session-nonce")
  end

  test "Google and Apple expose legacy and evidence wrapper contracts" do
    assert {:module, Google} = Code.ensure_loaded(Google)
    assert {:module, Apple} = Code.ensure_loaded(Apple)
    assert function_exported?(Google, :callback, 3)
    assert function_exported?(Google, :callback, 4)
    assert function_exported?(Apple, :callback, 3)
    assert function_exported?(Apple, :callback, 4)

    nonce = "legacy-nonce"

    assert {:ok, _normalized_user, _token} =
             legacy_callback(signed_id_token(%{"nonce" => nonce}), nonce)
  end

  defp evidence_callback(token, nonce, config_overrides \\ []) do
    Google.callback(
      provider_config(token, config_overrides),
      %{"state" => "provider-state", "code" => "authorization-code"},
      %{state: "provider-state", nonce: nonce},
      provider_evidence: true
    )
  end

  defp legacy_callback(token, nonce) do
    Google.callback(
      provider_config(token),
      %{"state" => "provider-state", "code" => "authorization-code"},
      %{state: "provider-state", nonce: nonce}
    )
  end

  defp provider_config(token, overrides \\ []) do
    [
      client_id: "client-id",
      client_secret: "client-secret",
      redirect_uri: "https://app.example.com/oauth/callback",
      nonce: "provider-nonce",
      openid_configuration: %{
        "issuer" => "https://issuer.example.com",
        "authorization_endpoint" => "https://issuer.example.com/authorize",
        "token_endpoint" => "https://issuer.example.com/token",
        "token_endpoint_auth_methods_supported" => ["client_secret_post"]
      },
      id_token_signed_response_alg: "HS256",
      http_adapter:
        {HTTPAdapter,
         test_pid: self(), token: %{"access_token" => "access-token", "id_token" => token}}
    ]
    |> Keyword.merge(overrides)
  end

  defp signed_id_token(overrides, opts \\ []) do
    now = :os.system_time(:second)

    claims =
      %{
        "iss" => "https://issuer.example.com",
        "sub" => "subject-123",
        "aud" => "client-id",
        "exp" => now + 300,
        "iat" => now,
        "nonce" => "nonce",
        "email" => "person@example.com",
        "name" => "Person",
        "email_verified" => true
      }
      |> Map.merge(overrides)
      |> Map.drop(Keyword.get(opts, :drop, []))

    {:ok, token} =
      Assent.Strategy.sign_jwt(
        claims,
        "HS256",
        Keyword.get(opts, :secret, "client-secret"),
        json_library: Jason
      )

    token
  end
end
