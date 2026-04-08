defmodule Sigra.Plug.FetchSession do
  @moduledoc """
  Fetches the current user session, enforces timeouts, and assigns `current_scope`.

  This plug reads the session token from the Plug session (key: `:user_token`),
  fetches the session from the configured session store, validates idle and
  absolute timeouts, throttles activity updates, and handles remember-me
  cookie rehydration.

  If no valid session is found, `current_scope` is assigned as `nil`.

  The session struct is stored in `conn.private[:sigra_session]` for downstream
  plugs (e.g., `RequireSudo`).

  ## Cookie Security Defaults

  Sets `HttpOnly: true`, `SameSite: Lax`, `Secure: true` by default.
  Override `:secure` to `false` in development via the `:cookie_opts` option.

  ## Options

    * `:config` - A `%Sigra.Config{}` struct (contains session store, timeouts, etc.).
    * `:scope_module` - Module used to construct the scope from the user.
      Must export `new/1`.
    * `:cookie_opts` - Override default cookie security options.
    * `:remember_me_cookie` - Name of the remember-me cookie. Default: `nil` (disabled).

  ## Example

      plug Sigra.Plug.FetchSession,
        config: @sigra_config,
        scope_module: MyApp.Auth.Scope

  """

  @behaviour Plug

  @default_cookie_opts [
    http_only: true,
    same_site: "Lax",
    secure: true
  ]

  @doc """
  Initialize the plug with the given options.

  Merges default cookie security options with any user-provided overrides.
  """
  @doc since: "0.4.0"
  @impl Plug
  def init(opts) do
    user_cookie_opts = Keyword.get(opts, :cookie_opts, [])
    merged_cookie_opts = Keyword.merge(@default_cookie_opts, user_cookie_opts)
    Keyword.put(opts, :cookie_opts, merged_cookie_opts)
  end

  @doc """
  Fetch the current user session, enforce timeouts, and assign `current_scope`.
  """
  @doc since: "0.4.0"
  @impl Plug
  def call(conn, opts) do
    config = Keyword.fetch!(opts, :config)
    scope_module = Keyword.fetch!(opts, :scope_module)
    session_config = config.session
    session_store = Keyword.fetch!(session_config, :store)
    store_opts = [repo: config.repo, session_schema: Keyword.get(session_config, :session_schema)]

    token = Plug.Conn.get_session(conn, :user_token)

    {token, conn} =
      if is_nil(token) do
        maybe_rehydrate_remember_me(conn, opts)
      else
        {token, conn}
      end

    case fetch_and_validate_session(token, session_store, session_config, store_opts) do
      {:ok, session} ->
        maybe_update_activity(session, session_store, session_config, store_opts)
        scope = scope_module.new(%{id: session.user_id})

        conn
        |> Plug.Conn.assign(:current_scope, scope)
        |> Plug.Conn.put_private(:sigra_session, session)

      :skip ->
        Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp maybe_rehydrate_remember_me(conn, opts) do
    case Keyword.get(opts, :remember_me_cookie) do
      nil ->
        {nil, conn}

      cookie_name ->
        conn = Plug.Conn.fetch_cookies(conn)

        case conn.cookies[cookie_name] do
          nil -> {nil, conn}
          token -> {token, conn}
        end
    end
  end

  defp fetch_and_validate_session(nil, _store, _config, _opts), do: :skip

  defp fetch_and_validate_session(token, session_store, session_config, opts) do
    case session_store.fetch(token, opts) do
      {:ok, session} ->
        if session_valid?(session, session_config) do
          {:ok, session}
        else
          :skip
        end

      {:error, _reason} ->
        :skip
    end
  end

  defp session_valid?(session, session_config) do
    now = DateTime.utc_now()

    {idle_limit, absolute_limit} =
      case session.type do
        :remember_me ->
          {nil, Keyword.get(session_config, :remember_me_max_age, 5_184_000)}

        _ ->
          {Keyword.get(session_config, :idle_timeout, 1_800),
           Keyword.get(session_config, :absolute_timeout, 86_400)}
      end

    absolute_ok = DateTime.diff(now, session.inserted_at, :second) < absolute_limit

    idle_ok =
      is_nil(idle_limit) or
        DateTime.diff(now, session.last_active_at, :second) < idle_limit

    absolute_ok and idle_ok
  end

  defp maybe_update_activity(session, session_store, session_config, opts) do
    threshold = Keyword.get(session_config, :activity_update_threshold, 300)
    elapsed = DateTime.diff(DateTime.utc_now(), session.last_active_at, :second)

    if elapsed >= threshold do
      session_store.update_activity(
        session.hashed_token,
        %{last_active_at: DateTime.utc_now()},
        opts
      )
    end
  end
end
