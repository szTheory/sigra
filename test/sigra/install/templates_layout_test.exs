defmodule Sigra.Install.TemplatesLayoutTest do
  @moduledoc """
  Asserts the physical layout of `priv/templates/sigra.install/`.

  Phase 11-03 (Wave 2) relocated all v1.0 templates from the flat
  `priv/templates/sigra.install/*.{ex,exs}` path into
  `priv/templates/sigra.install/core/*.{ex,exs}`. These tests are the
  structural barrier that keeps the layout locked down so Wave 3
  (`Features.Core.files/1`) can rely on the `core/` prefix.
  """

  use ExUnit.Case, async: true

  @manifest_post_move ~w(
    add_active_organization_id_to_user_sessions.exs
    alter_audit_events_add_org_columns.exs
    api_token_controller.ex
    api_token_created_email.ex
    api_token_migration.exs
    audit_event.ex
    auth.ex
    auth_api_token.ex
    auth_fixtures.ex
    auth_hooks.ex
    auth_mailer.ex
    confirmation_controller.ex
    confirmation_html.ex
    confirmation_live.ex
    conn_case_helpers.ex
    create_audit_events.exs
    emails.ex
    encrypted.ex
    encrypted_binary.ex
    error_handler.ex
    login_html.ex
    mailer.ex
    mfa_challenge_controller.ex
    mfa_challenge_html.ex
    mfa_challenge_live.ex
    mfa_settings_html.ex
    mfa_settings_live.ex
    migration.exs
    reactivation_live.ex
    registration_html.ex
    registration_live.ex
    reset_password_controller.ex
    reset_password_html.ex
    reset_password_live.ex
    scope.ex
    session_controller.ex
    session_live.ex
    settings_live.ex
    sigra_authz.ex
    sudo_controller.ex
    sudo_html.ex
    token_controller.ex
    user.ex
    user_api_token.ex
    user_auth.ex
    user_backup_code.ex
    user_mfa_credential.ex
    user_session.ex
    user_token.ex
    vault.ex
  )

  @core_dir "priv/templates/sigra.install/core"
  @top_dir "priv/templates/sigra.install"

  test "templates have been relocated under core/ subdirectory" do
    # Phase 92 / Plan 92-02: +1 (core/sigra_authz.ex). The host-owned
    # `Sigra.Authz` starter sits beside admin/policy.ex (admin feature)
    # and lives under core/ because the Authz seam itself is core-scoped.
    core_files = @core_dir |> File.ls!() |> Enum.sort()
    assert length(core_files) == 50
    assert core_files == Enum.sort(@manifest_post_move)
  end

  test "old flat template directory holds no files directly" do
    top_level_files =
      @top_dir
      |> File.ls!()
      |> Enum.reject(&File.dir?(Path.join(@top_dir, &1)))

    assert top_level_files == []
  end
end
