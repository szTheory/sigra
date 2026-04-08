defmodule <%= web_module %>.UserAuth do
  @moduledoc """
  Authentication helpers for the web layer.

  This module handles login, logout, session management, and
  provides plugs for authentication pipelines. Security-critical
  operations delegate to Sigra library plugs.
  """
  use <%= web_module %>, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias <%= context_module %>.Scope

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_<%= otp_app %>_user_remember_me"
  @remember_me_options [
    sign: true,
    max_age: @max_age,
    same_site: "Lax",
    http_only: true,
    secure: Mix.env() == :prod
  ]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renewal in
  `Plug.Session.COOKIE`.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = <%= context_module %>.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && <%= context_module %>.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      <%= web_module %>.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_scope(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && <%= context_module %>.get_user_by_session_token(user_token)
    scope = user && Scope.for_user(user)
    assign(conn, :current_scope, scope)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_scope` - Assigns current_scope
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_scope to socket assigns based
      on user_token. Redirects to login page if there's no
      logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_scope:

      defmodule <%= web_module %>.PageLive do
        use <%= web_module %>, :live_view

        on_mount {<%= web_module %>.UserAuth, :mount_current_scope}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{<%= web_module %>.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user =
        if user_token = session["user_token"] do
          <%= context_module %>.get_user_by_session_token(user_token)
        end

      user && Scope.for_user(user)
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.

  Delegates to `Sigra.Plug.RequireAuthenticated` for the core
  authentication check.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  @doc """
  Plug that handles unconfirmed users based on configuration.

  When `:unconfirmed_access` is `:allow_with_banner` (default):
    - Sets info flash reminding the user to confirm their email
    - Allows request to continue

  When `:unconfirmed_access` is `:block`:
    - Auto-resends confirmation email (D-04)
    - Sets error flash and redirects to confirmation page
    - Halts the connection

  ## Usage

  In your router:

      pipe_through [:browser, :require_authenticated_user, :require_confirmed_user]

  Or with explicit mode override:

      plug :require_confirmed_user, unconfirmed_access: :block

  """
  def require_confirmed_user(conn, opts \\ []) do
    user = conn.assigns[:current_scope] && conn.assigns.current_scope.user

    cond do
      is_nil(user) ->
        conn

      user.confirmed_at != nil ->
        conn

      unconfirmed_access_mode(opts) == :allow_with_banner ->
        conn
        |> put_flash(:info, dgettext("sigra", "Please confirm your email. Check your inbox or request a new confirmation email."))

      unconfirmed_access_mode(opts) == :block ->
        # D-04: auto-resend confirmation on blocked login attempt
        <%= context_module %>.deliver_user_confirmation_instructions(
          user,
          &url(conn, ~p"/users/confirm/#{&1}")
        )

        conn
        |> put_flash(:error, dgettext("sigra", "You must confirm your email before logging in. We've sent a new confirmation email."))
        |> redirect(to: ~p"/users/confirm")
        |> halt()
    end
  end

  defp unconfirmed_access_mode(opts) do
    Keyword.get(opts, :unconfirmed_access, :allow_with_banner)
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"
end
