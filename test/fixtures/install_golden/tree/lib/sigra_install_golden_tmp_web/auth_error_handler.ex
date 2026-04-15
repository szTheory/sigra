defmodule SigraInstallGoldenTmpWeb.AuthErrorHandler do
  @moduledoc """
  Default error handler for Sigra authentication errors.

  Implements `Sigra.Plug.ErrorHandler` to handle authentication
  failures with appropriate redirects and error messages.

  Clauses for `:no_active_org` and `:insufficient_role` are generated
  by Sigra for organization-aware routes. Edit the redirect target or
  message to match your product's tone.
  """

  @behaviour Sigra.Plug.ErrorHandler

  use SigraInstallGoldenTmpWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  @impl true
  def auth_error(conn, :unauthenticated, _opts) do
    conn
    |> put_flash(:error, "You must log in to access this page.")
    |> redirect(to: ~p"/users/log_in")
  end

  @impl true
  def auth_error(conn, :stale_sudo, _opts) do
    conn
    |> put_flash(:error, "Please re-enter your password to continue.")
    |> redirect(to: ~p"/users/log_in")
  end

  @impl true
  def auth_error(conn, :rate_limited, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(429, "Too many requests. Please try again later.")
  end


  @impl true
  def auth_error(conn, :no_active_org, _opts) do
    conn
    |> put_flash(:info, "Pick or create an organization to continue.")
    |> redirect(to: ~p"/organizations")
  end


  @impl true
  def auth_error(conn, :insufficient_role, _opts) do
    conn
    |> put_flash(:error, "You don't have permission to access this page in the current organization.")
    |> put_status(:forbidden)
    |> put_view(SigraInstallGoldenTmpWeb.ErrorHTML)
    |> render(:"403")
    |> halt()
  end
end
