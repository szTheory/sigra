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
    assert controller =~ "defp browser_assurance(conn)"
    assert controller =~ "defp current_user(%{assigns: %{current_scope: %{user: user}}}), do: user"
    assert controller =~ "defp current_user(_), do: nil"
    refute controller =~ "get_in(conn.assigns, [:current_scope, :user])"
    assert controller =~ "type in [:standard, :remember_me]"
    assert controller =~ ":mfa_pending -> conn |> redirect(to: ~p\"/users/mfa\") |> halt()"
    refute controller =~ "put_flash"
    refute controller =~ "access_token"
    refute controller =~ "refresh_token"

    assert continuation =~
             "put_session(conn, @session_key, %{continuation: continuation, profile_id: profile_id})"

    assert continuation =~
             "%{continuation: continuation, profile_id: profile_id} <- get_session(conn, @session_key)"

    assert continuation =~
             "def continue_path(_endpoint, %{continuation: continuation, profile_id: profile_id}, _fallback)"

    refute continuation =~ "Phoenix.Token.sign"
    refute continuation =~ "Phoenix.Token.verify"
    assert continuation =~ "delete_session(conn, @session_key)"
    refute continuation =~ "verifier"
    refute continuation =~ "password"

    assert router =~ "pipeline :app_login_public"
    assert router =~ "key_prefix: \"app_login_public\""
    assert router =~ "limit: 4"
    assert router =~ "get \"/app-login\", AppLoginController, :start"
    assert router =~ "post \"/app-login/approve\", AppLoginController, :approve"
    assert router =~ "post \"/app-login/cancel\", AppLoginController, :cancel"
    assert router =~ "scope \"/api/app-login\", MyAppWeb do"
    assert router =~ "post \"/exchange\", AppLoginController, :exchange"
  end

  test "registers route and controller templates only with app sessions" do
    sources =
      AppSessions.files(@binding)
      |> Enum.map(fn {:eex, source, _target} -> source end)

    assert "app_sessions/app_login_controller.ex" in sources
    assert "app_sessions/app_login_continuation.ex" in sources
    assert [%{content: router}] = AppSessions.injections(@binding)
    assert router =~ "# Sigra app login"
  end

  test "renders a fixed direct-MFA factor allowlist and uniform invalid-factor path" do
    controller =
      render_template("app_login_controller.ex",
        opts: [app_sessions: true, app_password_login: true]
      )

    assert controller =~
             "def complete_direct_mfa(conn, %{\"challenge\" => challenge, \"code\" => code, \"factor\" => factor} = params)"

    assert controller =~ ~s|with ["challenge", "code", "factor"] <- Enum.sort(Map.keys(params))|
    assert controller =~ "{:ok, trusted_factor} <- direct_mfa_factor(factor)"
    assert controller =~ "AppSessions.complete_direct_mfa(challenge, code, trusted_factor)"
    assert controller =~ ~s|defp direct_mfa_factor("totp"), do: {:ok, :totp}|
    assert controller =~ ~s|defp direct_mfa_factor("backup_code"), do: {:ok, :backup_code}|
    assert controller =~ "defp direct_mfa_factor(_), do: :error"
    assert controller =~ ~s|%{error: "invalid_credentials"}|
    refute controller =~ "String.to_atom"
    refute controller =~ "String.to_existing_atom"
  end

  test "renders an explicit accessible approval decision in the auth shell" do
    html = render_template("app_login_html.ex")
    approval = File.read!(Path.join(@template_dir, "app_login_approve.html.heex"))

    assert html =~ "SigraAuthComponents"
    assert html =~ "embed_templates \"app_login_html/*\""
    assert approval =~ "<.sigra_auth_page"
    assert approval =~ "data-testid=\"app-login-approval\""
    assert approval =~ "aria-labelledby=\"app-login-decision-title\""
    assert approval =~ "Approve and continue"
    assert approval =~ "Cancel"
    assert approval =~ "data-testid=\"app-login-approve\""
    assert approval =~ "data-testid=\"app-login-cancel\""
    refute approval =~ "sg-"
  end

  defp render_template(name, overrides \\ []) do
    EEx.eval_file(Path.join(@template_dir, name), Keyword.merge(@binding, overrides))
  end
end
