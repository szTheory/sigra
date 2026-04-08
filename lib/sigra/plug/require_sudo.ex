defmodule Sigra.Plug.RequireSudo do
  @moduledoc """
  Sudo mode gate plug that requires recent re-authentication.

  This plug checks that the user is authenticated AND that the session's
  `sudo_at` timestamp (from `conn.private[:sigra_session]`) is within the
  configured sudo window. If the window has expired (or `sudo_at` is nil),
  the configured error handler is called with `:stale_sudo` and the
  connection is halted.

  ## Options

    * `:error_handler` - Module implementing `Sigra.Plug.ErrorHandler`.
      Required.
    * `:sudo_window` - Maximum age of sudo confirmation in seconds.
      Defaults to `300` (5 minutes).

  ## Example

      plug Sigra.Plug.RequireSudo,
        error_handler: MyAppWeb.AuthErrorHandler,
        sudo_window: 600

  """

  @behaviour Plug

  @default_sudo_window 300

  @doc """
  Initialize the plug with the given options.

  Sets the default `:sudo_window` to 300 seconds (5 minutes) if not provided.
  """
  @doc since: "0.1.0"
  @impl Plug
  def init(opts) do
    Keyword.put_new(opts, :sudo_window, @default_sudo_window)
  end

  @doc """
  Check sudo window freshness and halt if expired.

  Reads the session from `conn.private[:sigra_session]` and checks
  `session.sudo_at` against the configured sudo window.
  """
  @doc since: "0.4.0"
  @impl Plug
  def call(conn, opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)
    sudo_window = Keyword.fetch!(opts, :sudo_window)

    cond do
      is_nil(conn.assigns[:current_scope]) ->
        conn
        |> error_handler.auth_error(:unauthenticated, opts)
        |> Plug.Conn.halt()

      sudo_fresh?(conn, sudo_window) ->
        conn

      true ->
        conn
        |> error_handler.auth_error(:stale_sudo, opts)
        |> Plug.Conn.halt()
    end
  end

  defp sudo_fresh?(conn, sudo_window) do
    case conn.private[:sigra_session] do
      %Sigra.Session{sudo_at: %DateTime{} = sudo_at} ->
        DateTime.diff(DateTime.utc_now(), sudo_at, :second) <= sudo_window

      _ ->
        false
    end
  end
end
