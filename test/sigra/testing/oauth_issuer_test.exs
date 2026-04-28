defmodule Sigra.Testing.OAuthIssuerTest do
  use ExUnit.Case, async: true

  alias Sigra.Testing.OAuthIssuer

  describe "start_link/1 - provider :google" do
    test "returns an issuer handle with request-time state" do
      with_issuer([provider: :google], fn issuer ->
        assert is_binary(OAuthIssuer.url(issuer))
        assert String.starts_with?(OAuthIssuer.url(issuer), "http://127.0.0.1:")
        assert is_pid(issuer.state)
      end)
    end
  end

  describe "/.well-known/openid-configuration" do
    test "returns the discovery document" do
      with_issuer([], fn issuer ->
        response = get!(OAuthIssuer.url(issuer) <> "/.well-known/openid-configuration")
        assert response.status == 200

        assert response.body == %{
                 "issuer" => OAuthIssuer.url(issuer),
                 "authorization_endpoint" => OAuthIssuer.url(issuer) <> "/oauth2/v2/auth",
                 "token_endpoint" => OAuthIssuer.url(issuer) <> "/token",
                 "userinfo_endpoint" => OAuthIssuer.url(issuer) <> "/userinfo",
                 "jwks_uri" => OAuthIssuer.url(issuer) <> "/jwks",
                 "token_endpoint_auth_methods_supported" => [
                   "none",
                   "client_secret_post",
                   "client_secret_basic"
                 ]
               }
      end)
    end
  end

  describe "/oauth2/v2/auth -> 302 redirect" do
    test "redirects back with code and state" do
      with_issuer([], fn issuer ->
        response =
          get!(
            OAuthIssuer.url(issuer) <>
              "/oauth2/v2/auth?" <>
              URI.encode_query(%{
                "client_id" => "sigra-client",
                "redirect_uri" => "http://example.test/callback",
                "state" => "state-123",
                "code_challenge" => pkce_challenge("verifier-123"),
                "code_challenge_method" => "S256",
                "nonce" => "nonce-123"
              }),
            autoredirect: false
          )

        assert response.status == 302
        location = header!(response, "location")
        query = URI.parse(location).query |> URI.decode_query()

        assert URI.parse(location).path == "/callback"
        assert query["state"] == "state-123"
        assert is_binary(query["code"])
      end)
    end
  end

  describe "/token RS256 sign+verify roundtrip" do
    test "returns an RS256 id_token" do
      with_issuer([], fn issuer ->
        %{code: code} = authorize!(issuer)
        response = exchange_code!(issuer, code, "verifier-123")

        assert response.status == 200
        assert response.body["token_type"] == "Bearer"
        assert response.body["expires_in"] == 3600
        assert is_binary(response.body["access_token"])
        assert is_binary(response.body["refresh_token"])

        config = [
          client_id: "sigra-client",
          openid_configuration: OAuthIssuer.openid_config(issuer),
          session_params: %{nonce: "nonce-123"}
        ]

        assert {:ok, jwt} =
                 Assent.Strategy.OIDC.validate_id_token(config, response.body["id_token"])

        assert jwt.header["alg"] == "RS256"
        assert jwt.header["kid"] == "kid1"
        assert jwt.claims["iss"] == OAuthIssuer.url(issuer)
        assert jwt.claims["aud"] == "sigra-client"
        assert jwt.claims["nonce"] == "nonce-123"
        assert jwt.claims["email_verified"] == true
      end)
    end
  end

  describe "/token with bad code_verifier" do
    test "returns invalid_grant" do
      with_issuer([], fn issuer ->
        %{code: code} = authorize!(issuer)
        response = exchange_code!(issuer, code, "wrong-verifier")

        assert response.status == 400
        assert response.body["error"] == "invalid_grant"
        assert response.body["error_description"] == "invalid code_verifier"
      end)
    end
  end

  describe "/jwks" do
    test "exposes the configured key count" do
      with_issuer([kid_count: 2], fn issuer ->
        response = get!(OAuthIssuer.url(issuer) <> "/jwks")
        assert response.status == 200
        assert Enum.map(response.body["keys"], & &1["kid"]) == ["kid1", "kid2"]
      end)
    end
  end

  describe "configurable exp" do
    test "respects the requested expiration offset" do
      with_issuer([exp: 60], fn issuer ->
        %{code: code} = authorize!(issuer)
        response = exchange_code!(issuer, code, "verifier-123")
        claims = jwt_claims(response.body["id_token"])

        assert claims["exp"] - claims["iat"] == 60
      end)
    end
  end

  describe "refresh-token rotation toggle" do
    test "keeps refresh tokens stable when disabled" do
      with_issuer([refresh_rotation: false], fn issuer ->
        %{code: code} = authorize!(issuer)
        first = exchange_code!(issuer, code, "verifier-123")

        second =
          post_form!(OAuthIssuer.url(issuer) <> "/token", %{
            "grant_type" => "refresh_token",
            "refresh_token" => first.body["refresh_token"],
            "client_id" => "sigra-client"
          })

        assert second.status == 200
        assert second.body["refresh_token"] == first.body["refresh_token"]
      end)
    end
  end

  describe "email_verified boolean shape" do
    test "returns email_verified as a JSON boolean" do
      with_issuer([], fn issuer ->
        %{code: code} = authorize!(issuer)
        token_response = exchange_code!(issuer, code, "verifier-123")

        userinfo =
          get!(OAuthIssuer.url(issuer) <> "/userinfo",
            headers: [{"authorization", "Bearer " <> token_response.body["access_token"]}]
          )

        assert userinfo.status == 200
        assert userinfo.body["email_verified"] === true
        assert is_boolean(userinfo.body["email_verified"])
      end)
    end
  end

  defp authorize!(issuer) do
    response =
      get!(
        OAuthIssuer.url(issuer) <>
          "/oauth2/v2/auth?" <>
          URI.encode_query(%{
            "client_id" => "sigra-client",
            "redirect_uri" => "http://example.test/callback",
            "state" => "state-123",
            "code_challenge" => pkce_challenge("verifier-123"),
            "code_challenge_method" => "S256",
            "nonce" => "nonce-123"
          }),
        autoredirect: false
      )

    query =
      response
      |> header!("location")
      |> URI.parse()
      |> Map.fetch!(:query)
      |> URI.decode_query()

    %{code: query["code"], state: query["state"]}
  end

  defp exchange_code!(issuer, code, verifier) do
    post_form!(OAuthIssuer.url(issuer) <> "/token", %{
      "grant_type" => "authorization_code",
      "code" => code,
      "redirect_uri" => "http://example.test/callback",
      "client_id" => "sigra-client",
      "code_verifier" => verifier
    })
  end

  defp jwt_claims(token) do
    %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(token)
    claims
  end

  defp pkce_challenge(verifier) do
    verifier
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end

  defp get!(url, opts \\ []) do
    request!(:get, url, opts)
  end

  defp post_form!(url, form, opts \\ []) do
    request!(:post, url, Keyword.put(opts, :body, URI.encode_query(form)))
  end

  defp request!(method, url, opts) do
    headers =
      opts
      |> Keyword.get(:headers, [])
      |> Enum.map(fn {key, value} -> {String.to_charlist(key), String.to_charlist(value)} end)
      |> maybe_put_form_header(method, opts)

    request =
      case {method, Keyword.get(opts, :body)} do
        {:post, body} ->
          {String.to_charlist(url), headers, ~c"application/x-www-form-urlencoded", body}

        _other ->
          {String.to_charlist(url), headers}
      end

    http_opts =
      []
      |> maybe_put(:autoredirect, Keyword.get(opts, :autoredirect))

    assert {:ok, {{_, status, _}, raw_headers, raw_body}} =
             :httpc.request(method, request, http_opts, body_format: :binary)

    %{
      status: status,
      headers: Enum.map(raw_headers, fn {key, value} -> {to_string(key), to_string(value)} end),
      body: decode_body(raw_body)
    }
  end

  defp maybe_put_form_header(headers, :post, _opts) do
    [{~c"content-type", ~c"application/x-www-form-urlencoded"} | headers]
  end

  defp maybe_put_form_header(headers, _method, _opts), do: headers

  defp decode_body(""), do: ""

  defp decode_body(body) do
    case Jason.decode(body) do
      {:ok, json} -> json
      {:error, _reason} -> body
    end
  end

  defp header!(response, name) do
    response.headers
    |> Enum.find_value(fn {header, value} -> if header == name, do: value end)
    |> Kernel.||(flunk("missing header #{name} in #{inspect(response.headers)}"))
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)

  defp with_issuer(opts, fun) do
    {:ok, issuer} = OAuthIssuer.start_link(opts)

    try do
      fun.(issuer)
    after
      OAuthIssuer.stop(issuer)
    end
  end
end
