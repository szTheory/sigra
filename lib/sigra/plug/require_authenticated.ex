defmodule Sigra.Plug.RequireAuthenticated do
  @moduledoc """
  Authentication gate plug that halts unauthenticated requests.

  This plug checks for `conn.assigns.current_scope`. If present, the request
  passes through unchanged. If absent (nil), the configured error handler is
  called with `:unauthenticated` and the connection is halted.

  ## Options

    * `:error_handler` - Module implementing `Sigra.Plug.ErrorHandler`.
      Required.

  ## Example

      plug Sigra.Plug.RequireAuthenticated,
        error_handler: MyAppWeb.AuthErrorHandler

  """

  @behaviour Plug

  @doc """
  Initialize the plug with the given options.
  """
  @doc since: "0.1.0"
  @impl Plug
  def init(opts), do: opts

  @doc """
  Check for authenticated user and halt if not present.
  """
  @doc since: "0.1.0"
  @impl Plug
  def call(conn, opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)

    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> error_handler.auth_error(:unauthenticated, opts)
      |> Plug.Conn.halt()
    end
  end
end
