defmodule Sigra.Plug.FetchBearer do
  @moduledoc """
  Deprecated compatibility dispatcher for legacy bearer-token routes.

  Existing installations retain their historical deterministic dispatch:

  - a configured API-token prefix selects `Sigra.Plug.FetchAPIToken` first;
  - an enabled `eyJ` bearer selects `Sigra.Plug.FetchJWT`;
  - every other bearer selects `Sigra.Plug.FetchAPIToken`.

  New routes should select `Sigra.Plug.FetchAPIToken` or `Sigra.Plug.FetchJWT`
  explicitly. This dispatcher intentionally keeps the legacy classifier only;
  successful authentication is performed by the selected explicit credential
  pipeline, which assigns the normal host Scope and bounded credential facts.

  ## Options

    * `:config` - A `%Sigra.Config{}` struct (required)
    * `:scope_module` - The host application's Scope module (required)
  """

  @behaviour Plug

  @doc """
  Initializes the legacy compatibility dispatcher.

  New routes should initialize `Sigra.Plug.FetchAPIToken` or
  `Sigra.Plug.FetchJWT` directly.
  """
  @doc since: "0.7.0"
  @doc deprecated:
         "Use Sigra.Plug.FetchAPIToken or Sigra.Plug.FetchJWT explicitly. FetchBearer is a legacy compatibility dispatcher."
  @deprecated "Use Sigra.Plug.FetchAPIToken or Sigra.Plug.FetchJWT explicitly. FetchBearer is a legacy compatibility dispatcher."
  @impl Plug
  def init(opts), do: opts

  @doc """
  Dispatches legacy bearer routes to an explicit credential-kind Plug.

  Existing Scopes skip all work. New routes should call
  `Sigra.Plug.FetchAPIToken` or `Sigra.Plug.FetchJWT` directly.
  """
  @doc since: "0.7.0"
  @doc deprecated:
         "Use Sigra.Plug.FetchAPIToken or Sigra.Plug.FetchJWT explicitly. FetchBearer is a legacy compatibility dispatcher."
  @deprecated "Use Sigra.Plug.FetchAPIToken or Sigra.Plug.FetchJWT explicitly. FetchBearer is a legacy compatibility dispatcher."
  @impl Plug
  def call(conn, opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      dispatch(conn, opts)
    end
  end

  defp dispatch(conn, opts) do
    config = Keyword.fetch!(opts, :config)

    case extract_bearer_token(conn) do
      {:ok, raw_token} ->
        legacy_pipeline(config, raw_token).call(conn, opts)

      :error ->
        Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp legacy_pipeline(config, raw_token) do
    prefix = get_prefix(config)
    jwt_enabled = Keyword.get(config.jwt, :enabled, false)

    cond do
      prefix && String.starts_with?(raw_token, prefix) -> Sigra.Plug.FetchAPIToken
      jwt_enabled && String.starts_with?(raw_token, "eyJ") -> Sigra.Plug.FetchJWT
      true -> Sigra.Plug.FetchAPIToken
    end
  end

  defp get_prefix(config) do
    Keyword.get(config.api_token, :prefix) ||
      if config.otp_app, do: "#{config.otp_app}_sk_"
  end

  defp extract_bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      _ -> :error
    end
  end
end
