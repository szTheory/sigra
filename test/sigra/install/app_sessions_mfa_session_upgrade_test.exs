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
    assert controller =~ "Auth.complete_mfa_verification(user, old_session, remember_me: remember_me)"
    assert controller =~ "UserAuth.put_user_session_token(upgraded_session.token)"
    assert controller =~ "delete_session(:mfa_pending)"
    assert controller =~ ~s(~p"/app-login/continue")
  end

  @tag :controller
  test "controller MFA failure does not upgrade a browser session or resume approval" do
    controller = render_template("mfa_challenge_controller.ex", app_sessions: true)

    assert controller =~ "defp complete_mfa_session(conn, user, old_session, remember_me)"
    assert controller =~ "_ -> {:error, :session_upgrade_failed}"
    refute controller =~ "Auth.complete_mfa_verification(user, nil"
  end

  defp render_template(name, opts) do
    EEx.eval_file(Path.join(@template_dir, name), Keyword.put(@binding, :opts, opts))
  end
end
