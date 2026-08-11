defmodule <%= web_module %>.SettingsController do
  @moduledoc """
  Controller-mode account-security routes for `mix sigra.install --no-live`.

  These routes deliberately remain inside the generated authenticated and sudo
  pipelines. They provide a safe controller endpoint for account-security
  links emitted by the controller templates.
  """
  use <%= web_module %>, :controller

  alias <%= context_module %>, as: Auth

  def edit(conn, _params), do: redirect(conn, to: ~p"/users/settings/mfa")

  def reactivation(conn, _params), do: redirect(conn, to: ~p"/users/log_in")

  def mfa(conn, _params) do
    status = Auth.mfa_status(conn.assigns.current_scope.user)

    render(conn, :mfa_settings,
      mfa_enabled: status.enabled,
      backup_remaining: status.backup_codes_remaining,
      enrollment_step: nil,
      svg: nil,
      base32_secret: nil,
      backup_codes: [],
      show_disable: false
    )
  end

  def disable(conn, _params), do: unavailable(conn)
  def regenerate(conn, _params), do: unavailable(conn)
  def revoke_trust(conn, _params), do: unavailable(conn)
  def enroll(conn, _params), do: unavailable(conn)
  def confirm(conn, _params), do: unavailable(conn)
  def complete(conn, _params), do: unavailable(conn)

  defp unavailable(conn) do
    conn
    |> put_flash(:error, "This account-security action requires the LiveView settings UI.")
    |> redirect(to: ~p"/users/settings/mfa")
  end
end
