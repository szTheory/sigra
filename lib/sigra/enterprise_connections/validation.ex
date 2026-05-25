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
         :ok <- require_string(oidc_settings.encrypted_client_secret, "Client secret is required."),
         :ok <- validate_scopes(oidc_settings.scopes),
         :ok <- validate_client_authentication_method(oidc_settings.client_authentication_method),
         {:ok, discovery_url} <- discovery_url(oidc_settings),
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

  defp validate_client_authentication_method(method) when method in @supported_client_authentication_methods,
    do: :ok

  defp validate_client_authentication_method(_method),
    do:
      {:error, :validation_failed,
       "Client authentication method must be client_secret_basic or client_secret_post."}

  defp discovery_url(%{discovery_document_uri: uri}) when is_binary(uri) do
    if byte_size(String.trim(uri)) > 0 do
      {:ok, uri}
    else
      {:error, :validation_failed, "Issuer is required."}
    end
  end

  defp discovery_url(%{issuer: issuer}) when is_binary(issuer) do
    issuer = String.trim_trailing(issuer, "/")
    {:ok, issuer <> "/.well-known/openid-configuration"}
  end

  defp fetch_discovery_document(config, url) do
    http_client = Map.get(config, :http_client, &default_http_get/1)

    case http_client.(url: url) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, :validation_failed, "OIDC discovery failed with HTTP #{status}."}

      {:error, _reason} ->
        {:error, :validation_failed, "OIDC discovery could not be fetched."}
    end
  end

  defp default_http_get(opts) do
    if Code.ensure_loaded?(Req) and function_exported?(Req, :get, 1) do
      apply(Req, :get, [opts])
    else
      {:error, :req_unavailable}
    end
  end

  defp validate_discovery_document(document, issuer) do
    with :ok <- matches_issuer(document["issuer"], issuer),
         :ok <- require_document_key(document, "authorization_endpoint"),
         :ok <- require_document_key(document, "token_endpoint"),
         :ok <- require_document_key(document, "jwks_uri") do
      :ok
    end
  end

  defp matches_issuer(value, issuer) when is_binary(value) and value == issuer, do: :ok
  defp matches_issuer(_value, _issuer), do: {:error, :validation_failed, "OIDC discovery issuer mismatch."}

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
