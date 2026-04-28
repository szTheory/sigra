defmodule Sigra.Testing.OAuthIssuer do
  @moduledoc """
  In-process OIDC issuer for testing Sigra's OAuth ceremony end-to-end.

  Mirrors Assent's own OIDC test-server precedent with RS256 ID tokens,
  JWKS exposure, real PKCE verification, `email_verified` boolean shape,
  configurable expiration, and kid rotation.

  This module lives under test/support and is not exported as adopter
  public API in v0.x. It complements `Sigra.Testing.mock_oauth_callback/1`
  rather than replacing it.
  """

  @typedoc "Issuer handle returned by start_link/1"
  @type t :: %__MODULE__{
          base_url: String.t(),
          state: pid()
        }

  @fixture_dir Path.expand("fixtures", __DIR__)
  @kid1_private_path Path.join(@fixture_dir, "oauth_issuer_rsa_kid1_private.pem")
  @kid1_public_path Path.join(@fixture_dir, "oauth_issuer_rsa_kid1_public.pem")
  @kid2_private_path Path.join(@fixture_dir, "oauth_issuer_rsa_kid2_private.pem")
  @kid2_public_path Path.join(@fixture_dir, "oauth_issuer_rsa_kid2_public.pem")

  @external_resource @kid1_private_path
  @external_resource @kid1_public_path
  @external_resource @kid2_private_path
  @external_resource @kid2_public_path

  @default_user %{
    sub: "provider_123",
    email: "oauth@example.com",
    email_verified: true,
    name: "OAuth User",
    picture: "https://example.com/avatar.jpg"
  }

  @discovery_path "/.well-known/openid-configuration"
  @authorize_path "/oauth2/v2/auth"
  @token_path "/token"
  @userinfo_path "/userinfo"
  @jwks_path "/jwks"

  defstruct [:base_url, :state]

  @spec start_link(keyword()) :: {:ok, t()} | {:error, term()}
  def start_link(opts \\ []) do
    provider = Keyword.get(opts, :provider, :google)
    user_claims = normalize_user_claims(Keyword.get(opts, :user, @default_user))
    kid_count = Keyword.get(opts, :kid_count, 1)
    exp_offset = normalize_exp(Keyword.get(opts, :exp, 3600))
    refresh_rotation = Keyword.get(opts, :refresh_rotation, true)
    pkce_required = Keyword.get(opts, :pkce_required, true)

    with :ok <- validate_provider(provider),
         :ok <- validate_kid_count(kid_count),
         {:ok, instance} <- TestServer.start(),
         {:ok, registrar} <- start_registrar(),
         base_url = base_url(instance),
         {:ok, state} <-
           Agent.start_link(fn ->
             %{
               instance: instance,
               registrar: registrar,
               base_url: base_url,
               provider: provider,
               user_claims: user_claims,
               kid_count: kid_count,
               exp_offset: exp_offset,
               refresh_rotation?: refresh_rotation,
               pkce_required?: pkce_required,
               codes: %{},
               access_tokens: %{},
               refresh_tokens: %{}
             }
           end),
         :ok <- register_routes(instance, registrar, state) do
      {:ok, %__MODULE__{base_url: base_url, state: state}}
    end
  end

  @spec set_user(t(), map()) :: :ok
  def set_user(%__MODULE__{state: state}, user_claims) do
    Agent.update(state, &Map.put(&1, :user_claims, normalize_user_claims(user_claims)))
  end

  @spec set_kid_count(t(), 1 | 2) :: :ok
  def set_kid_count(%__MODULE__{state: state}, kid_count) when kid_count in [1, 2] do
    Agent.update(state, &Map.put(&1, :kid_count, kid_count))
  end

  @spec url(t()) :: String.t()
  def url(%__MODULE__{base_url: base_url}), do: base_url

  @spec openid_config(t()) :: map()
  def openid_config(%__MODULE__{base_url: base_url}) do
    %{
      "issuer" => base_url,
      "authorization_endpoint" => base_url <> @authorize_path,
      "token_endpoint" => base_url <> @token_path,
      "userinfo_endpoint" => base_url <> @userinfo_path,
      "jwks_uri" => base_url <> @jwks_path,
      "token_endpoint_auth_methods_supported" => [
        "none",
        "client_secret_post",
        "client_secret_basic"
      ]
    }
  end

  @spec stop(t()) :: :ok
  def stop(%__MODULE__{state: state}) do
    if Process.alive?(state) do
      %{instance: instance, registrar: registrar} =
        Agent.get(state, &Map.take(&1, [:instance, :registrar]))

      if Process.alive?(registrar), do: send(registrar, :stop)
      TestServer.stop(instance)
      Agent.stop(state)
    end

    :ok
  end

  defp register_routes(instance, registrar, state) do
    route_specs = [
      {@discovery_path, [via: :get], &handle_discovery(&1, state)},
      {@authorize_path, [via: :get], &handle_authorize(&1, state)},
      {@token_path, [via: :post], &handle_token(&1, state)},
      {@userinfo_path, [via: :get], &handle_userinfo(&1, state)},
      {@jwks_path, [via: :get], &handle_jwks(&1, state)}
    ]

    Enum.each(route_specs, fn {path, opts, handler} ->
      add_persistent_route(instance, registrar, path, opts, handler)
    end)

    :ok
  end

  defp add_persistent_route(instance, registrar, path, opts, handler) do
    TestServer.add(
      instance,
      path,
      Keyword.put(opts, :to, fn conn ->
        send(registrar, {:rearm, instance, path, opts, handler})
        handler.(conn)
      end)
    )
  end

  defp handle_discovery(conn, state) do
    conn
    |> json(200, state |> agent_issuer() |> openid_config())
  end

  defp handle_authorize(conn, state) do
    params = Plug.Conn.fetch_query_params(conn).params

    with {:ok, redirect_uri} <- fetch_required(params, "redirect_uri"),
         {:ok, oauth_state} <- fetch_required(params, "state"),
         :ok <- validate_pkce_request(params, state) do
      code = random_token("code")

      stored_code = %{
        code_challenge: Map.get(params, "code_challenge"),
        code_challenge_method: Map.get(params, "code_challenge_method"),
        client_id: Map.get(params, "client_id", "sigra-client"),
        nonce: Map.get(params, "nonce"),
        redirect_uri: redirect_uri
      }

      Agent.update(state, &put_in(&1, [:codes, code], stored_code))

      conn
      |> Plug.Conn.put_resp_header(
        "location",
        redirect_with_code(redirect_uri, code, oauth_state)
      )
      |> Plug.Conn.send_resp(302, "")
    else
      {:error, message} -> json(conn, 400, %{error: message})
    end
  end

  defp handle_token(conn, state) do
    params = read_form_body(conn)

    case params["grant_type"] || "authorization_code" do
      "authorization_code" -> exchange_code(conn, state, params)
      "refresh_token" -> exchange_refresh_token(conn, state, params)
      other -> json(conn, 400, %{error: "unsupported_grant_type", grant_type: other})
    end
  end

  defp exchange_code(conn, state, params) do
    with {:ok, code} <- fetch_required(params, "code"),
         {:ok, code_data} <- fetch_code(state, code),
         :ok <- validate_redirect_uri(code_data, params),
         :ok <- validate_code_verifier(state, code_data, params) do
      token_payload = issue_tokens(state, code_data)
      Agent.update(state, &update_in(&1.codes, fn codes -> Map.delete(codes, code) end))
      json(conn, 200, token_payload)
    else
      {:error, reason} ->
        json(conn, 400, %{error: "invalid_grant", error_description: reason})
    end
  end

  defp exchange_refresh_token(conn, state, params) do
    with {:ok, refresh_token} <- fetch_required(params, "refresh_token"),
         {:ok, refresh_data} <- fetch_refresh_token(state, refresh_token) do
      {refresh_token, state_update} =
        if refresh_data.refresh_rotation? do
          new_token = random_token("refresh")

          {new_token,
           fn current_state ->
             current_state
             |> update_in([:refresh_tokens], fn tokens ->
               tokens
               |> Map.delete(refresh_token)
               |> Map.put(new_token, %{refresh_data | refresh_token: new_token})
             end)
           end}
        else
          {refresh_token, fn current_state -> current_state end}
        end

      Agent.update(state, state_update)
      token_payload = issue_tokens_from_refresh(state, refresh_data, refresh_token)
      json(conn, 200, token_payload)
    else
      {:error, reason} ->
        json(conn, 400, %{error: "invalid_grant", error_description: reason})
    end
  end

  defp handle_userinfo(conn, state) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, user_claims} <- fetch_access_token(state, token) do
      json(conn, 200, stringify_claims(user_claims))
    else
      {:error, _reason} ->
        json(conn, 401, %{error: "invalid_token"})
    end
  end

  defp handle_jwks(conn, state) do
    keys =
      state
      |> Agent.get(& &1.kid_count)
      |> public_jwks()

    json(conn, 200, %{"keys" => keys})
  end

  defp validate_provider(:google), do: :ok
  defp validate_provider(provider), do: {:error, {:unsupported_provider, provider}}

  defp validate_kid_count(kid_count) when kid_count in [1, 2], do: :ok
  defp validate_kid_count(kid_count), do: {:error, {:invalid_kid_count, kid_count}}

  defp validate_pkce_request(params, state) do
    if Agent.get(state, & &1.pkce_required?) do
      with {:ok, _challenge} <- fetch_required(params, "code_challenge"),
           {:ok, "S256"} <- fetch_required(params, "code_challenge_method") do
        :ok
      else
        {:error, _reason} -> {:error, "missing_pkce"}
      end
    else
      :ok
    end
  end

  defp validate_redirect_uri(%{redirect_uri: redirect_uri}, %{"redirect_uri" => redirect_uri}),
    do: :ok

  defp validate_redirect_uri(%{redirect_uri: _redirect_uri}, _params),
    do: {:error, "redirect_uri mismatch"}

  defp validate_code_verifier(state, code_data, params) do
    if Agent.get(state, & &1.pkce_required?) do
      with {:ok, verifier} <- fetch_required(params, "code_verifier"),
           true <- code_data.code_challenge == pkce_challenge(verifier) do
        :ok
      else
        _any -> {:error, "invalid code_verifier"}
      end
    else
      :ok
    end
  end

  defp fetch_code(state, code) do
    case Agent.get(state, &get_in(&1, [:codes, code])) do
      nil -> {:error, "unknown code"}
      code_data -> {:ok, code_data}
    end
  end

  defp fetch_access_token(state, token) do
    case Agent.get(state, &get_in(&1, [:access_tokens, token])) do
      nil -> {:error, :invalid_token}
      claims -> {:ok, claims}
    end
  end

  defp fetch_refresh_token(state, refresh_token) do
    case Agent.get(state, &get_in(&1, [:refresh_tokens, refresh_token])) do
      nil -> {:error, "unknown refresh_token"}
      data -> {:ok, data}
    end
  end

  defp issue_tokens(state, code_data) do
    base_state = Agent.get(state, & &1)
    refresh_token = random_token("refresh")

    claims = build_id_token_claims(base_state, code_data.client_id, code_data.nonce)
    id_token = sign_id_token(claims, current_kid(base_state))
    access_token = random_token("access")

    Agent.update(state, fn current_state ->
      current_state
      |> put_in([:access_tokens, access_token], current_state.user_claims)
      |> put_in([:refresh_tokens, refresh_token], %{
        client_id: code_data.client_id,
        nonce: code_data.nonce,
        refresh_rotation?: current_state.refresh_rotation?
      })
    end)

    %{
      "access_token" => access_token,
      "refresh_token" => refresh_token,
      "id_token" => id_token,
      "token_type" => "Bearer",
      "expires_in" => base_state.exp_offset
    }
  end

  defp issue_tokens_from_refresh(state, refresh_data, refresh_token) do
    base_state = Agent.get(state, & &1)
    claims = build_id_token_claims(base_state, refresh_data.client_id, refresh_data.nonce)
    id_token = sign_id_token(claims, current_kid(base_state))
    access_token = random_token("access")

    Agent.update(state, &put_in(&1, [:access_tokens, access_token], &1.user_claims))

    %{
      "access_token" => access_token,
      "refresh_token" => refresh_token,
      "id_token" => id_token,
      "token_type" => "Bearer",
      "expires_in" => base_state.exp_offset
    }
  end

  defp build_id_token_claims(base_state, client_id, nonce) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    exp = now + base_state.exp_offset

    base_state.user_claims
    |> stringify_claims()
    |> Map.merge(%{
      "iss" => base_state.base_url,
      "aud" => client_id,
      "iat" => now,
      "exp" => exp
    })
    |> maybe_put("nonce", nonce)
  end

  defp sign_id_token(claims, kid) do
    private_jwk =
      kid
      |> private_key_path()
      |> File.read!()
      |> JOSE.JWK.from_pem()

    {_, token} =
      private_jwk
      |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => kid}, claims)
      |> JOSE.JWS.compact()

    token
  end

  defp public_jwks(kid_count) do
    1..kid_count
    |> Enum.map(fn index ->
      kid = "kid#{index}"

      public_key_path(kid)
      |> File.read!()
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_public()
      |> JOSE.JWK.to_map()
      |> elem(1)
      |> Map.merge(%{"kid" => kid, "alg" => "RS256", "use" => "sig"})
    end)
  end

  defp current_kid(%{kid_count: 1}), do: "kid1"
  defp current_kid(%{kid_count: 2}), do: "kid2"

  defp agent_issuer(state) do
    base_url = Agent.get(state, & &1.base_url)
    %__MODULE__{base_url: base_url, state: state}
  end

  defp read_form_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    _ = conn
    URI.decode_query(body)
  end

  defp bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _other -> {:error, :missing_bearer}
    end
  end

  defp redirect_with_code(redirect_uri, code, oauth_state) do
    uri = URI.parse(redirect_uri)

    query =
      URI.decode_query(uri.query || "") |> Map.merge(%{"code" => code, "state" => oauth_state})

    %{uri | query: URI.encode_query(query)} |> URI.to_string()
  end

  defp fetch_required(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when value not in [nil, ""] -> {:ok, value}
      _other -> {:error, "#{key} missing"}
    end
  end

  defp pkce_challenge(verifier) do
    verifier
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end

  defp json(conn, status, payload) do
    body = Jason.encode!(payload)

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, body)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp stringify_claims(user_claims) do
    Map.new(user_claims, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_user_claims(user_claims) when is_map(user_claims) do
    user_claims
    |> Enum.reduce(%{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, key, value)
      {key, value}, acc when is_binary(key) -> Map.put(acc, String.to_existing_atom(key), value)
    end)
    |> then(&Map.merge(@default_user, &1))
    |> Map.update!(:email_verified, &(&1 == true))
  rescue
    ArgumentError ->
      @default_user
  end

  defp normalize_exp(%DateTime{} = exp) do
    diff = DateTime.diff(exp, DateTime.utc_now(), :second)
    if diff > 0, do: diff, else: 0
  end

  defp normalize_exp(exp) when is_integer(exp) and exp >= 0, do: exp
  defp normalize_exp(_exp), do: 3600

  defp private_key_path("kid1"), do: @kid1_private_path
  defp private_key_path("kid2"), do: @kid2_private_path
  defp public_key_path("kid1"), do: @kid1_public_path
  defp public_key_path("kid2"), do: @kid2_public_path

  defp random_token(prefix) do
    encoded = :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
    prefix <> "_" <> encoded
  end

  defp base_url(instance), do: TestServer.url(instance, "", host: "127.0.0.1")

  defp start_registrar do
    pid =
      spawn_link(fn ->
        registrar_loop()
      end)

    {:ok, pid}
  end

  defp registrar_loop do
    receive do
      {:rearm, instance, path, opts, handler} ->
        add_persistent_route(instance, self(), path, opts, handler)
        registrar_loop()

      :stop ->
        :ok
    end
  end
end
