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


  @impl true
  def auth_error(conn, :org_mfa_required, opts) do
    enrollment_path = Keyword.get(opts, :enrollment_path, ~p"/users/settings/mfa")

    conn
    |> put_flash(
      :warning,
      "Your organization requires two-factor authentication. Set up MFA below to continue."
    )
    |> redirect(to: enrollment_path)
  end


  @impl true
  def auth_error(conn, :insufficient_scope, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_resp_content_type("text/html")
    |> send_resp(
      403,
      "Access denied. You do not have access to this admin scope."
    )
  end

  @impl true
  def auth_error(conn, :not_found, _opts) do
    conn
    |> put_status(:not_found)
    |> put_resp_content_type("text/html")
    |> send_resp(
      404,
      "Not found. This organization admin scope is unavailable."
    )
  end

end
