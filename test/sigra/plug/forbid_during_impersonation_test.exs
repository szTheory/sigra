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

  test "falls back to default denial copy and audit action when caller does not override them" do
    scope = %{user: %{id: "user-7"}, impersonating_from: %{id: "admin-7"}}

    opts = ForbidDuringImpersonation.init(error_handler: TestErrorHandler)

    conn =
      conn(:post, "/users/settings/api_tokens")
      |> Plug.Conn.assign(:current_scope, scope)
      |> ForbidDuringImpersonation.call(opts)

    assert conn.halted
    assert conn.status == 403
    assert conn.assigns.error_opts[:message] == "You can't perform this action while impersonating."
    assert conn.assigns.error_opts[:audit][:action] == "admin.impersonation.denied"
    # Default metadata is an empty map so downstream audit logging stays deterministic.
    assert conn.assigns.error_opts[:audit][:metadata] == %{}
  end

  test "passes through when current_scope is missing entirely (not an impersonation session)" do
    opts = ForbidDuringImpersonation.init(error_handler: TestErrorHandler)

    conn =
      conn(:post, "/users/settings/mfa/passkeys")
      |> ForbidDuringImpersonation.call(opts)

    refute conn.halted
    refute conn.assigns[:error_type]
  end

  test "passes through when scope has no impersonating_from key at all" do
    opts = ForbidDuringImpersonation.init(error_handler: TestErrorHandler)

    conn =
      conn(:post, "/users/settings/mfa/passkeys")
      |> Plug.Conn.assign(:current_scope, %{user: %{id: "user-1"}})
      |> ForbidDuringImpersonation.call(opts)

    refute conn.halted
    refute conn.assigns[:error_type]
  end

  test "exposes denial audit on the conn assigns so downstream tests and middleware can observe it" do
    scope = %{user: %{id: "user-42"}, impersonating_from: %{id: "admin-42"}}

    opts =
      ForbidDuringImpersonation.init(
        error_handler: TestErrorHandler,
        audit_metadata: %{"reason" => "danger_zone"}
      )

    conn =
      conn(:delete, "/users/sessions")
      |> Plug.Conn.assign(:current_scope, scope)
      |> ForbidDuringImpersonation.call(opts)

    assert conn.halted
    denial = conn.assigns[:sigra_impersonation_denial_audit]

    assert denial.action == "admin.impersonation.denied"
    assert denial.scope.actor_id == "admin-42"
    assert denial.scope.effective_user_id == "user-42"
    assert denial.metadata == %{"reason" => "danger_zone"}
  end
end
