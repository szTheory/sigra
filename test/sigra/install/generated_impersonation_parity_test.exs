defmodule Sigra.Install.GeneratedImpersonationParityTest do
  use ExUnit.Case, async: true

  @context_template "priv/templates/sigra.install/core/auth.ex"

  test "generated context denies every impersonation-sensitive operation" do
    source = File.read!(@context_template)

    for operation <- [
          "account.password_change",
          "mfa.disable",
          "mfa.regenerate_backup_codes",
          "passkey.register",
          "passkey.rename",
          "passkey.delete",
          "account.deletion_schedule",
          "account.deletion_cancel",
          "account.data_export"
        ] do
      assert source =~ ~s(forbid_sensitive_operation), "guard helper missing for #{operation}"
      assert source =~ ~s("#{operation}"), "generated context does not guard #{operation}"
    end

    assert source =~ ~s(Sigra.Audit.log_safe("admin.impersonation.denied")
    assert source =~ ~s(actor_id: impersonator.id)
    assert source =~ ~s(target_id: user.id)
    assert source =~ ~s(outcome: "failure")
  end

  test "generated UI and controllers propagate the current scope and handle typed denial" do
    settings = File.read!("priv/templates/sigra.install/core/settings_live.ex")
    mfa = File.read!("priv/templates/sigra.install/core/mfa_settings_live.ex")
    controller = File.read!("priv/templates/sigra.install/core/session_controller.ex")

    assert settings =~
             "Auth.change_password(user, current_password, attrs, scope: socket.assigns.current_scope)"

    assert settings =~ "Auth.schedule_deletion(user, scope: socket.assigns.current_scope)"
    assert settings =~ "Auth.cancel_deletion(user, scope: socket.assigns.current_scope)"
    assert mfa =~ "Auth.mfa_disable(user, code, scope: socket.assigns.current_scope)"
    assert mfa =~ "Auth.mfa_regenerate_backup_codes(user, {:totp, code}"
    assert controller =~ "scope: conn.assigns.current_scope"
    assert controller =~ "{:error, :impersonation_forbidden}"
  end

  test "API-token management keeps its separate typed denial contract" do
    source = File.read!("priv/templates/sigra.install/core/auth_api_token.ex")

    assert source =~ "forbid_api_token_operation"
    assert source =~ "You can't manage API tokens while impersonating."
    assert source =~ "{:error, :impersonation_forbidden, @impersonation_denial_message}"
  end
end
