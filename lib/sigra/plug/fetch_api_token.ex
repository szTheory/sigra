defmodule Sigra.Plug.FetchAPIToken do
  @moduledoc """
  Explicit personal-access-token authentication plug.

  A successful request assigns the configured host Scope with the current user
  and stores bounded verifier-derived credential facts in `conn.private[:sigra_auth]`.
  Invalid credentials assign a nil Scope so downstream authentication gates own
  the response.
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
    config = Keyword.fetch!(opts, :config)
    scope_module = Keyword.fetch!(opts, :scope_module)

    with {:ok, raw_token} <- extract_bearer_token(conn),
         {:ok, token} <- Sigra.APIToken.verify(config, raw_token),
         user when not is_nil(user) <- config.repo.get(config.user_schema, token.user_id) do
      CredentialAuth.put_verified_scope(conn, scope_module, user, :personal_access_token, %{
        id: token.id,
        scopes: token.scopes,
        auth_method: :api_token,
        assurance: []
      })
    else
      _ -> Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp extract_bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      _ -> :error
    end
  end
end
