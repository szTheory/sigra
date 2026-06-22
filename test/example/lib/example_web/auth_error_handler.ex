defmodule ExampleWeb.AuthErrorHandler do
  @moduledoc """
  Default error handler for Sigra authentication errors.

  Implements `Sigra.Plug.ErrorHandler` to handle authentication
  failures with appropriate redirects and error messages.
  """

  @behaviour Sigra.Plug.ErrorHandler

  use ExampleWeb, :verified_routes

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
    # Send the user to the dedicated re-auth page (NOT /users/log_in — an already
    # authenticated user gets bounced straight back off the login page, so the
    # password prompt never appears). Carry the original path so SudoController
    # returns them where they were headed after confirming.
    conn
    |> put_flash(:error, "Please re-enter your password to continue.")
    |> redirect(to: ~p"/users/sudo?#{[return_to: conn.request_path]}")
  end

  @impl true
  def auth_error(conn, :rate_limited, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(429, "Too many requests. Please try again later.")
  end

  @impl true
  def auth_error(conn, :insufficient_scope, _opts) do
    # An authenticated user who simply lacks admin scope shouldn't dead-end on a
    # raw 403 — send them home to their Tasklane account hub with a clear message
    # (principle of least surprise). Keep the hard 403 for unauthenticated /
    # non-HTML callers, where there is no session to flash into or page to land on.
    case conn.assigns[:current_scope] do
      %{user: %{}} ->
        conn
        |> put_flash(:error, "You don't have access to that admin area.")
        |> redirect(to: ~p"/app")

      _ ->
        conn
        |> put_status(:forbidden)
        |> put_resp_content_type("text/html")
        |> send_resp(
          403,
          "Access denied. You do not have access to this admin scope."
        )
    end
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
