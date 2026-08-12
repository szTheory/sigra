defmodule Sigra.Plug.FetchJWT do
  @moduledoc """
  Explicit JWT access-token authentication plug.

  A successful request verifies only a Bearer JWT, reloads the current host
  user, assigns the configured Scope, and stores bounded verifier-derived
  credential facts in `conn.private[:sigra_auth]`. Invalid credentials assign a
  nil Scope so downstream authentication gates own the response.
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

    if Keyword.get(config.jwt, :enabled, false) do
      fetch_enabled_jwt(conn, config, scope_module)
    else
      Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp fetch_enabled_jwt(conn, config, scope_module) do
    with {:ok, raw_jwt} <- extract_bearer_jwt(conn),
         {:ok, claims} <- Sigra.JWT.verify_access(config, raw_jwt),
         subject when is_binary(subject) and subject != "" <- claims["sub"],
         user when not is_nil(user) <- config.repo.get(config.user_schema, subject) do
      CredentialAuth.put_verified_scope(conn, scope_module, user, :jwt, %{
        id: claims["jti"],
        scopes: verified_scopes(claims),
        auth_method: :jwt,
        assurance: []
      })
    else
      _ -> Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp extract_bearer_jwt(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> jwt] -> {:ok, String.trim(jwt)}
      _ -> :error
    end
  end

  defp verified_scopes(%{"scopes" => scopes}) when is_list(scopes), do: scopes
  defp verified_scopes(_claims), do: []
end
