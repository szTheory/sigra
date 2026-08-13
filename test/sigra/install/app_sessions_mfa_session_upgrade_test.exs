defmodule Sigra.Install.AppSessionsMFASessionUpgradeTest do
  use ExUnit.Case, async: true

  @template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  @binding [
    context_module: "MyApp.Auth",
    schema_module: "MyApp.Auth.User",
    schema_alias: "User",
    table_name: "users",
    web_module: "MyAppWeb",
    otp_app: :my_app,
    repo_module: "MyApp.Repo",
    app_module: "MyApp",
    app_name: "MyApp",
    from_email: "noreply@example.com",
    log_in_url: "/users/log_in",
    binary_id: false,
    adapter: :postgres,
    organizations?: false,
    passkeys?: true
  ]

  @tag :controller
  test "controller MFA success upgrades the persisted pending session before hosted continuation" do
    controller = render_template("mfa_challenge_controller.ex", app_sessions: true)

    assert controller =~ "old_session = conn.private[:sigra_session]"
    assert controller =~ "%{type: :mfa_pending} <- old_session"

    assert controller =~
             "Auth.complete_mfa_verification(user, old_session, remember_me: remember_me)"

    assert controller =~ "UserAuth.put_user_session_token(conn, upgraded_session.token)"
    assert controller =~ "delete_session(:mfa_pending)"
    assert controller =~ ~s(~p"/users/app-login/continue")
  end

  @tag :controller
  test "controller MFA failure does not upgrade a browser session or resume approval" do
    controller = render_template("mfa_challenge_controller.ex", app_sessions: true)

    assert controller =~ "defp complete_mfa_session(conn, user, old_session, remember_me)"
    assert controller =~ "_ -> {:error, :session_upgrade_failed}"
    refute controller =~ "Auth.complete_mfa_verification(user, nil"
  end

  @tag :live
  test "LiveView TOTP and backup completion cross the controller-owned session seam" do
    live = render_template("mfa_challenge_live.ex", app_sessions: true)
    controller = render_template("mfa_challenge_controller.ex", app_sessions: true)

    assert live =~ ~s(id="mfa_totp_form")
    assert live =~ ~s(id="mfa_backup_form")
    assert live =~ ~s(action={~p"/users/mfa"})
    assert live =~ ~s(method="post")
    assert live =~ ~s(name="mfa[method]" value="totp")
    assert live =~ ~s(name="mfa[method]" value="backup")
    assert live =~ "Plug.CSRFProtection.get_csrf_token()"
    assert live =~ "cannot consume a factor without rotating the persisted browser session"
    refute live =~ "case Auth.mfa_verify(user, code)"
    assert controller =~ "defp complete_mfa_session(conn, user, old_session, remember_me)"
  end

  @tag :live
  test "unselected LiveView MFA keeps its ordinary event destination" do
    live = render_template("mfa_challenge_live.ex", app_sessions: false)

    assert live =~ "phx-submit=\"verify_totp\""
    assert live =~ "phx-submit=\"verify_backup\""
    refute live =~ ~s(action={~p"/users/mfa"})
  end

  defp render_template(name, opts) do
    EEx.eval_file(Path.join(@template_dir, name), Keyword.put(@binding, :opts, opts))
  end
end
