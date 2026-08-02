defmodule Sigra.EnterpriseConnections.Validation do
  @moduledoc """
  OIDC discovery and client-setting preflight validation for enterprise connections.
  """

  alias Assent.Strategy.OIDC

  @supported_client_authentication_methods ~w(client_secret_basic client_secret_post)

  @type diagnostics :: %{validated_at: DateTime.t()}

  @spec validate(map(), map()) :: {:ok, diagnostics()} | {:error, :validation_failed, String.t()}
  def validate(config, connection) do
    _ = Code.ensure_loaded(OIDC)

    with {:ok, oidc_settings} <- oidc_settings(connection),
         :ok <- require_string(oidc_settings.issuer, "Issuer is required."),
         :ok <- require_string(oidc_settings.client_id, "Client ID is required."),
         :ok <-
           require_string(oidc_settings.encrypted_client_secret, "Client secret is required."),
         :ok <- validate_scopes(oidc_settings.scopes),
         :ok <- validate_client_authentication_method(oidc_settings.client_authentication_method),
         {:ok, discovery_url} <- discovery_url(config, oidc_settings),
         {:ok, document} <- fetch_discovery_document(config, discovery_url),
         :ok <- validate_discovery_document(document, oidc_settings.issuer) do
      {:ok, %{validated_at: DateTime.utc_now() |> DateTime.truncate(:second)}}
    end
  end

  defp oidc_settings(%{oidc_settings: nil}),
    do: {:error, :validation_failed, "OIDC settings are required."}

  defp oidc_settings(%{oidc_settings: oidc_settings}), do: {:ok, oidc_settings}

  defp require_string(value, message) when is_binary(value) do
    if byte_size(String.trim(value)) > 0 do
      :ok
    else
      {:error, :validation_failed, message}
    end
  end

  defp require_string(_value, message), do: {:error, :validation_failed, message}

  defp validate_scopes(scopes) when is_list(scopes) do
    if "openid" in scopes do
      :ok
    else
      {:error, :validation_failed, "Scopes must include openid."}
    end
  end

  defp validate_scopes(_scopes), do: {:error, :validation_failed, "Scopes must include openid."}

  defp validate_client_authentication_method(method)
       when method in @supported_client_authentication_methods,
       do: :ok

  defp validate_client_authentication_method(_method),
    do:
      {:error, :validation_failed,
       "Client authentication method must be client_secret_basic or client_secret_post."}

  defp discovery_url(config, %{discovery_document_uri: uri}) when is_binary(uri) do
    if byte_size(String.trim(uri)) > 0 do
      validate_discovery_url(config, uri)
    else
      {:error, :validation_failed, "Issuer is required."}
    end
  end

  defp discovery_url(config, %{issuer: issuer}) when is_binary(issuer) do
    issuer = String.trim_trailing(issuer, "/")
    validate_discovery_url(config, issuer <> "/.well-known/openid-configuration")
  end

  defp fetch_discovery_document(config, url) do
    http_client = Map.get(config, :http_client, &default_http_get/1)

    # Redirects would otherwise create a second, unvalidated request target. Callers
    # that supply a custom HTTP client must preserve this option.
    case http_client.(url: url, redirect: false) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, :validation_failed, "OIDC discovery failed with HTTP #{status}."}

      {:error, _reason} ->
        {:error, :validation_failed, "OIDC discovery could not be fetched."}
    end
  end

  defp default_http_get(opts) do
    if Sigra.OptionalDeps.req_available?() and function_exported?(Req, :get, 1) do
      apply(Req, :get, [opts])
    else
      {:error, :req_unavailable}
    end
  end

  defp validate_discovery_url(config, url) do
    uri = URI.parse(String.trim(url))

    with :ok <- require_https(uri),
         :ok <- reject_userinfo(uri),
         :ok <- require_default_https_port(uri),
         :ok <- validate_host(config, uri.host) do
      {:ok, URI.to_string(uri)}
    end
  end

  defp require_https(%URI{scheme: "https", host: host}) when is_binary(host) and host != "", do: :ok

  defp require_https(_uri),
    do: {:error, :validation_failed, "OIDC discovery URL must use HTTPS."}

  defp reject_userinfo(%URI{userinfo: nil}), do: :ok

  defp reject_userinfo(_uri),
    do: {:error, :validation_failed, "OIDC discovery URL must not include user info."}

  defp require_default_https_port(%URI{port: nil}), do: :ok
  defp require_default_https_port(%URI{port: 443}), do: :ok

  defp require_default_https_port(_uri),
    do: {:error, :validation_failed, "OIDC discovery URL must use port 443."}

  defp validate_host(config, host) do
    with {:ok, addresses} <- resolve_host(config, host),
         true <- addresses != [] and Enum.all?(addresses, &public_address?/1) do
      :ok
    else
      false -> {:error, :validation_failed, "OIDC discovery host resolves to a private address."}
      {:error, _reason} -> {:error, :validation_failed, "OIDC discovery host could not be resolved."}
    end
  end

  defp resolve_host(config, host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} ->
        {:ok, [address]}

      {:error, _reason} ->
        resolver = Map.get(config, :dns_resolver, &default_dns_resolver/1)

        case resolver.(host) do
          {:ok, addresses} when is_list(addresses) -> {:ok, addresses}
          addresses when is_list(addresses) -> {:ok, addresses}
          {:error, _reason} = error -> error
          _other -> {:error, :invalid_dns_response}
        end
    end
  end

  defp default_dns_resolver(host) do
    host = String.to_charlist(host)

    with {:ok, ipv4} <- :inet.getaddrs(host, :inet),
         {:ok, ipv6} <- :inet.getaddrs(host, :inet6) do
      {:ok, ipv4 ++ ipv6}
    else
      {:error, :nxdomain} -> {:error, :nxdomain}
      {:error, _reason} ->
        # A hostname may legitimately publish only one address family.
        ipv4 = addresses_for(host, :inet)
        ipv6 = addresses_for(host, :inet6)

        if ipv4 ++ ipv6 == [], do: {:error, :unresolved}, else: {:ok, ipv4 ++ ipv6}
    end
  end

  defp addresses_for(host, family) do
    case :inet.getaddrs(host, family) do
      {:ok, addresses} -> addresses
      {:error, _reason} -> []
    end
  end

  defp public_address?({a, b, c, d}) do
    not (a == 0 or a == 10 or a == 127 or a >= 224 or
           (a == 100 and b in 64..127) or
           (a == 169 and b == 254) or
           (a == 172 and b in 16..31) or
           (a == 192 and b in [0, 168]) or
           (a == 192 and b == 0 and c == 2) or
           (a == 198 and b in [18, 19, 51]) or
           (a == 203 and b == 0 and c == 113))
  end

  defp public_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: false
  defp public_address?({0, 0, 0, 0, 0, 0, 0, 0}), do: false
  defp public_address?({0, 0, 0, 0, 0, 0xFFFF, a, b}),
    do: public_address?({div(a, 256), rem(a, 256), div(b, 256), rem(b, 256)})

  defp public_address?({first, second, _rest3, _rest4, _rest5, _rest6, _rest7, _rest8}),
    do: first not in 0xFC..0xFF and not (first == 0xFE and second in 0x80..0xBF)
  defp public_address?(_address), do: false

  defp validate_discovery_document(document, issuer) do
    with :ok <- matches_issuer(document["issuer"], issuer),
         :ok <- require_document_key(document, "authorization_endpoint"),
         :ok <- require_document_key(document, "token_endpoint"),
         :ok <- require_document_key(document, "jwks_uri") do
      :ok
    end
  end

  defp matches_issuer(value, issuer) when is_binary(value) and value == issuer, do: :ok

  defp matches_issuer(_value, _issuer),
    do: {:error, :validation_failed, "OIDC discovery issuer mismatch."}

  defp require_document_key(document, key) do
    case Map.get(document, key) do
      value when is_binary(value) ->
        if byte_size(String.trim(value)) > 0 do
          :ok
        else
          {:error, :validation_failed, "OIDC discovery is missing #{key}."}
        end

      _ ->
        {:error, :validation_failed, "OIDC discovery is missing #{key}."}
    end
  end
end
