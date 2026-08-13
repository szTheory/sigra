defmodule Sigra.Plug.FetchAppSession do
  @moduledoc """
  Explicit opaque app-session authentication plug.

  A successful request verifies one access credential through
  `Sigra.AppSession`, reloads the live host user, and assigns the configured
  normal Scope. Only bounded server-derived credential facts enter
  `conn.private[:sigra_auth]`; app sessions never contribute request-selected
  authorization scopes.
  """

  @behaviour Plug

  alias Sigra.Plug.CredentialAuth

  @impl Plug
  def init(opts) do
    _ = Keyword.fetch!(opts, :config)
    _ = Keyword.fetch!(opts, :scope_module)
    opts
  end

  @impl Plug
  def call(conn, opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      fetch(conn, opts)
    end
  end

  defp fetch(conn, opts) do
    config = opts |> Keyword.fetch!(:config) |> resolve_config()
    scope_module = Keyword.fetch!(opts, :scope_module)

    with {:ok, raw_access_token} <- extract_bearer_token(conn),
         {:ok, session} <- Sigra.AppSession.authenticate(config, raw_access_token),
         user when not is_nil(user) <- config.repo.get(config.user_schema, session.user_id) do
      CredentialAuth.put_verified_scope(conn, scope_module, user, :app_session, %{
        id: session.token_id,
        family_id: session.family_id,
        scopes: [],
        auth_method: :app_session,
        assurance: []
      })
    else
      _ -> Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp extract_bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 -> {:ok, token}
      _ -> :error
    end
  end

  defp resolve_config(config) when is_function(config, 0), do: config.()
  defp resolve_config(config), do: config
end
