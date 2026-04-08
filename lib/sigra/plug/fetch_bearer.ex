defmodule Sigra.Plug.FetchBearer do
  @moduledoc """
  Extracts a bearer token from the Authorization header and assigns current_scope.

  Auto-detects token type by format:
  - Tokens starting with the configured API token prefix -> opaque API token (DB lookup)
  - Tokens starting with "eyJ" and JWT enabled -> JWT (signature verification)
  - All other tokens -> opaque API token path (DB lookup)

  Assigns `current_scope` with `token_scopes`, `auth_method`, and `token_id` fields.
  Skips if `current_scope` is already assigned.

  ## Options

    * `:config` - A `%Sigra.Config{}` struct (required)
    * `:scope_module` - The module to call `.new/1` on (the host app's Scope module)

  ## Example

      plug Sigra.Plug.FetchBearer,
        config: @sigra_config,
        scope_module: MyApp.Auth.Scope
  """

  @behaviour Plug

  @doc """
  Initialize the plug with the given options.
  """
  @doc since: "0.7.0"
  @impl Plug
  def init(opts), do: opts

  @doc """
  Extract bearer token from Authorization header and assign `current_scope`.

  Skips processing if `current_scope` is already assigned (D-53).
  """
  @doc since: "0.7.0"
  @impl Plug
  def call(conn, opts) do
    # D-53: skip if current_scope already assigned
    if conn.assigns[:current_scope] do
      conn
    else
      do_fetch(conn, opts)
    end
  end

  defp do_fetch(conn, opts) do
    config = Keyword.fetch!(opts, :config)
    scope_module = Keyword.fetch!(opts, :scope_module)

    case extract_bearer_token(conn) do
      {:ok, raw_token} ->
        case detect_and_verify(config, raw_token) do
          {:ok, :api_token, token} ->
            scope =
              build_scope(scope_module, token.user_id, %{
                token_scopes: token.scopes,
                auth_method: :api_token,
                token_id: token.id
              })

            Plug.Conn.assign(conn, :current_scope, scope)

          {:ok, :jwt, claims} ->
            scope =
              build_scope(scope_module, claims["sub"], %{
                token_scopes: claims["scopes"],
                auth_method: :jwt,
                token_id: claims["jti"]
              })

            Plug.Conn.assign(conn, :current_scope, scope)

          {:error, _reason} ->
            Plug.Conn.assign(conn, :current_scope, nil)
        end

      :error ->
        Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp detect_and_verify(config, raw_token) do
    prefix = get_prefix(config)
    jwt_enabled = Keyword.get(config.jwt, :enabled, false)

    cond do
      # Prefix match -> always opaque (checked first per D-38)
      prefix && String.starts_with?(raw_token, prefix) ->
        verify_opaque(config, raw_token)

      # eyJ prefix and JWT enabled -> JWT path
      jwt_enabled && String.starts_with?(raw_token, "eyJ") ->
        case Sigra.JWT.verify_access(config, raw_token) do
          {:ok, claims} -> {:ok, :jwt, claims}
          error -> error
        end

      # Default: try opaque
      true ->
        verify_opaque(config, raw_token)
    end
  end

  defp verify_opaque(config, raw_token) do
    case Sigra.APIToken.verify(config, raw_token) do
      {:ok, token} -> {:ok, :api_token, token}
      error -> error
    end
  end

  defp get_prefix(config) do
    Keyword.get(config.api_token, :prefix) ||
      if config.otp_app, do: "#{config.otp_app}_sk_"
  end

  defp build_scope(scope_module, user_id, extra) do
    scope_module.new(Map.merge(%{id: user_id}, extra))
  end

  defp extract_bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      _ -> :error
    end
  end
end
