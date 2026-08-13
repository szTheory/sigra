defmodule Sigra.Install.AppSessionsAuthContinuationTest do
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

  @auth_templates [
    "session_controller.ex",
    "session_live.ex",
    "mfa_challenge_controller.ex",
    "mfa_challenge_live.ex"
  ]

  test "selected app sessions resume browser login and MFA only at the approval controller" do
    for template <- [
          "session_controller.ex",
          "mfa_challenge_controller.ex",
          "mfa_challenge_live.ex"
        ] do
      rendered = render_template(template, app_sessions: true)

      assert rendered =~ "AppLoginContinuation"
      refute rendered =~ "callback_with_code"
      refute rendered =~ "issue_app_session"
    end

    assert render_template("session_controller.ex", app_sessions: true) =~
             ~s(~p"/users/app-login/continue")

    assert render_template("session_controller.ex", app_sessions: true) =~ "%{type: :mfa_pending}"

    assert render_template("mfa_challenge_controller.ex", app_sessions: true) =~
             ~s(~p"/users/app-login/continue")

    assert render_template("mfa_challenge_live.ex", app_sessions: true) =~
             "app_login_return_to(socket)"
  end

  test "all continuation callers match the generated users-scoped approval route" do
    session_controller = render_template("session_controller.ex", app_sessions: true)
    mfa_controller = render_template("mfa_challenge_controller.ex", app_sessions: true)
    continuation =
      File.read!(
        Path.join([
          File.cwd!(),
          "priv",
          "templates",
          "sigra.install",
          "app_sessions",
          "app_login_continuation.ex"
        ])
      )

    for source <- [session_controller, mfa_controller, continuation] do
      assert source =~ "/users/app-login/continue"
      refute source =~ ~s("/app-login/continue")
    end
  end

  test "unselected app sessions keep every core auth template byte-equivalent" do
    for template <- @auth_templates do
      assert render_template(template, app_sessions: false) ==
               render_template(template, app_sessions: false, app_password_login: false)

      refute render_template(template, app_sessions: false) =~ "AppLoginContinuation"
    end
  end

  test "controller and LiveView MFA invalid continuations fall back to ordinary authentication" do
    controller = render_template("mfa_challenge_controller.ex", app_sessions: true)
    live = render_template("mfa_challenge_live.ex", app_sessions: true)

    assert controller =~ "AppLoginContinuation.clear(conn)"
    assert controller =~ "_ -> {AppLoginContinuation.clear(conn), fallback}"
    assert live =~ "AppLoginContinuation.continue_path"
    assert live =~ "~p\"/\""
  end

  defp render_template(name, opts) do
    EEx.eval_file(Path.join(@template_dir, name), Keyword.put(@binding, :opts, opts))
  end
end
