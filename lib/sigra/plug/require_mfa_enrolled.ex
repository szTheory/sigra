defmodule Sigra.Plug.RequireMFAEnrolled do
  @moduledoc """
  Plug that requires the current user to have MFA enrolled.

  Redirects unenrolled users to the MFA enrollment page. Used for routes
  that require MFA as a policy (e.g., admin routes).

  ## Options

    * `:enrollment_path` - Path to MFA enrollment. Default: `"/users/settings"`.
    * `:mfa_check_fn` - Function `(user -> boolean)` to check MFA enrollment.
      Required. Typically `&Sigra.MFA.enabled?(&1, config)`.

  ## Example

      plug Sigra.Plug.RequireMFAEnrolled,
        enrollment_path: "/users/settings",
        mfa_check_fn: &MyApp.Auth.mfa_enabled?/1

  """

  @behaviour Plug

  @doc """
  Initialize the plug with the given options.
  """
  @doc since: "0.6.0"
  @impl Plug
  def init(opts), do: opts

  @doc """
  Check MFA enrollment and redirect if user is not enrolled.

  Reads `conn.assigns[:current_scope]` for the current user, then calls
  the configured `:mfa_check_fn`. If the function returns `false` (or user
  is nil), redirects to `:enrollment_path` with a flash message and halts.
  """
  @doc since: "0.6.0"
  @impl Plug
  def call(conn, opts) do
    enrollment_path = Keyword.get(opts, :enrollment_path, "/users/settings")
    check_fn = Keyword.fetch!(opts, :mfa_check_fn)
    user = conn.assigns[:current_scope]

    if user && check_fn.(user) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Two-factor authentication enrollment is required.")
      |> Phoenix.Controller.redirect(to: enrollment_path)
      |> Plug.Conn.halt()
    end
  end
end
