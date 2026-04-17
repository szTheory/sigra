defmodule Sigra.Plug.ForbidDuringImpersonationTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias Sigra.Plug.ForbidDuringImpersonation

  defmodule TestErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, opts) do
      conn
      |> Plug.Conn.assign(:error_type, type)
      |> Plug.Conn.assign(:error_opts, opts)
      |> Plug.Conn.send_resp(403, "blocked")
    end
  end

  test "passes through when not impersonating" do
    opts = ForbidDuringImpersonation.init(error_handler: TestErrorHandler)

    conn =
      conn(:post, "/users/settings/mfa/passkeys")
      |> Plug.Conn.assign(:current_scope, %{user: %{id: "user-1"}, impersonating_from: nil})
      |> ForbidDuringImpersonation.call(opts)

    refute conn.halted
    refute conn.assigns[:error_type]
  end

  test "halts impersonating requests with explicit denial copy and audit context" do
    scope = %{user: %{id: "user-1"}, impersonating_from: %{id: "admin-1"}}

    opts =
      ForbidDuringImpersonation.init(
        error_handler: TestErrorHandler,
        message: "You can't change account security settings while impersonating.",
        audit_action: "impersonation_sensitive_operation_denied"
      )

    conn =
      conn(:post, "/users/settings/mfa/passkeys")
      |> Plug.Conn.assign(:current_scope, scope)
      |> ForbidDuringImpersonation.call(opts)

    assert conn.halted
    assert conn.status == 403
    assert conn.resp_body == "blocked"
    assert conn.assigns.error_type == :insufficient_scope
    assert conn.assigns.error_opts[:message] ==
             "You can't change account security settings while impersonating."

    assert conn.assigns.error_opts[:audit][:action] ==
             "impersonation_sensitive_operation_denied"

    assert conn.assigns.error_opts[:audit][:scope][:effective_user_id] == "user-1"
    assert conn.assigns.error_opts[:audit][:scope][:actor_id] == "admin-1"
  end
end
