defmodule Sigra.Plug.RequirePasswordChange do
  @moduledoc """
  Plug that redirects users who must change their password.

  When a user has `must_change_password: true` set on their record
  (typically by an admin via `Sigra.Account.require_password_change/2`),
  this plug calls the error handler with `:must_change_password` and halts
  the connection, forcing them to the password change form.

  This mirrors the `Sigra.Plug.RequireSudo` pattern.

  ## Options

    * `:error_handler` - Required. Module implementing `Sigra.Plug.ErrorHandler`.

  ## Example

      plug Sigra.Plug.RequirePasswordChange,
        error_handler: MyAppWeb.AuthErrorHandler
  """

  @behaviour Plug

  @doc "Initialize plug options."
  @doc since: "0.8.0"
  @impl Plug
  def init(opts), do: opts

  @doc "Check if user must change password and halt if so."
  @doc since: "0.8.0"
  @impl Plug
  def call(conn, opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)

    case conn.assigns[:current_scope] do
      %{user: %{must_change_password: true}} ->
        conn
        |> error_handler.auth_error(:must_change_password, opts)
        |> Plug.Conn.halt()

      _ ->
        conn
    end
  end
end
