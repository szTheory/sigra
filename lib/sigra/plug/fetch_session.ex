defmodule Sigra.Plug.FetchSession do
  @moduledoc """
  Fetches the current user from the session token and assigns `current_scope`.

  This plug reads the session token from the Plug session (key: `:user_token`),
  looks up the associated user via the configured session store, and assigns
  the resulting scope to `conn.assigns.current_scope`.

  If no token is present or the session store returns an error, `current_scope`
  is assigned as `nil`.

  ## Options

    * `:session_store` - Module implementing the session store interface
      (must export `fetch/2`). Defaults to `Sigra.SessionStores.Ecto`.
    * `:scope_module` - Module used to construct the scope from the user.
      Must export `new/1`.

  ## Example

      plug Sigra.Plug.FetchSession,
        session_store: MyApp.SessionStore,
        scope_module: MyApp.Auth.Scope

  """

  @behaviour Plug

  @doc """
  Initialize the plug with the given options.
  """
  @doc since: "0.1.0"
  @impl Plug
  def init(opts), do: opts

  @doc """
  Fetch the current user from session and assign `current_scope`.
  """
  @doc since: "0.1.0"
  @impl Plug
  def call(conn, opts) do
    session_store = Keyword.fetch!(opts, :session_store)
    scope_module = Keyword.fetch!(opts, :scope_module)

    token = Plug.Conn.get_session(conn, :user_token)

    case fetch_scope(token, session_store, scope_module, opts) do
      {:ok, scope} ->
        Plug.Conn.assign(conn, :current_scope, scope)

      :skip ->
        Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp fetch_scope(nil, _store, _scope_module, _opts), do: :skip

  defp fetch_scope(token, session_store, scope_module, opts) do
    case session_store.fetch(token, opts) do
      {:ok, user} -> {:ok, scope_module.new(user)}
      {:error, _reason} -> :skip
    end
  end
end
