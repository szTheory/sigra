defmodule Sigra.Plug.ErrorHandler do
  @moduledoc """
  Behaviour for handling authentication errors in the HTTP pipeline.

  Implement this behaviour in your application to customize how authentication
  errors are presented to users. The generated `MyAppWeb.AuthErrorHandler`
  provides a default implementation.

  ## Error Types

    * `:unauthenticated` - No authenticated user found
    * `:stale_sudo` - Sudo window has expired, re-authentication required
    * `:rate_limited` - Request rate limit exceeded

  ## Example

      defmodule MyAppWeb.AuthErrorHandler do
        @behaviour Sigra.Plug.ErrorHandler

        @impl true
        def auth_error(conn, :unauthenticated, _opts) do
          conn
          |> Phoenix.Controller.put_flash(:error, "You must log in to access this page.")
          |> Phoenix.Controller.redirect(to: "/login")
        end

        @impl true
        def auth_error(conn, :stale_sudo, _opts) do
          conn
          |> Phoenix.Controller.put_flash(:error, "Please re-enter your password to continue.")
          |> Phoenix.Controller.redirect(to: "/users/sudo")
        end

        @impl true
        def auth_error(conn, :rate_limited, _opts) do
          conn
          |> Plug.Conn.put_resp_content_type("text/plain")
          |> Plug.Conn.send_resp(429, "Too many requests. Please try again later.")
        end
      end
  """

  @type error_type ::
          :unauthenticated
          | :stale_sudo
          | :rate_limited
          | :insufficient_scope
          | :token_expired
          | :token_revoked
          | :mfa_required

  @doc """
  Handle an authentication error.

  Called by `Sigra.Plug.RequireAuthenticated` and `Sigra.Plug.RequireSudo`
  when authentication requirements are not met.

  The `conn` has NOT been halted yet -- your implementation should send a
  response. The calling plug will halt the connection after this callback returns.
  """
  @doc since: "0.1.0"
  @callback auth_error(Plug.Conn.t(), error_type(), keyword()) :: Plug.Conn.t()
end
