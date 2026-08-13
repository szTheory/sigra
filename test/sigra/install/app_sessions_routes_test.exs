defmodule Sigra.Install.AppSessionsRoutesTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.AppSessions

  @binding [
    otp_app: :my_app,
    context_alias: "Accounts",
    context_module: "MyApp.Accounts",
    schema_module: "MyApp.Accounts.User",
    schema_alias: "User",
    table_name: "users",
    web_module: "MyAppWeb",
    app_module: "MyApp",
    repo_module: "MyApp.Repo",
    binary_id: true,
    adapter: :postgres,
    opts: [app_sessions: true]
  ]

  @template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "app_sessions"])

  test "renders hosted browser and public exchange routes with dedicated rate limits" do
    controller = render_template("app_login_controller.ex")
    continuation = render_template("app_login_continuation.ex")
    router = render_template("router_injection.ex")

    assert controller =~ "def start(conn, params)"
    assert controller =~ "def approve(conn, %{} = params)"
    assert controller =~ "def cancel(conn, %{} = params)"
    assert controller =~ "def exchange(conn, params)"
    assert controller =~ "put_resp_header(\"referrer-policy\", \"no-referrer\")"
    assert controller =~ "AppLoginContinuation"
    refute controller =~ "put_flash"
    refute controller =~ "access_token"
    refute controller =~ "refresh_token"

    assert continuation =~ "Phoenix.Token.sign"
    assert continuation =~ "Phoenix.Token.verify"
    assert continuation =~ "delete_session(conn, @session_key)"
    refute continuation =~ "verifier"
    refute continuation =~ "password"

    assert router =~ "pipeline :app_login_public"
    assert router =~ "key_prefix: \"app_login_public\""
    assert router =~ "get \"/app-login\", AppLoginController, :start"
    assert router =~ "post \"/app-login/approve\", AppLoginController, :approve"
    assert router =~ "post \"/app-login/cancel\", AppLoginController, :cancel"
    assert router =~ "post \"/api/app-login/exchange\", AppLoginController, :exchange"
  end

  test "registers route and controller templates only with app sessions" do
    sources =
      AppSessions.files(@binding)
      |> Enum.map(fn {:eex, source, _target} -> source end)

    assert "app_sessions/app_login_controller.ex" in sources
    assert "app_sessions/app_login_continuation.ex" in sources
    assert "app_sessions/router_injection.ex" in sources
  end

  defp render_template(name) do
    EEx.eval_file(Path.join(@template_dir, name), @binding)
  end
end
