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

  test "renders hosted browser and public credential exchange routes with dedicated rate limits" do
    controller = render_template("app_login_controller.ex")
    continuation = render_template("app_login_continuation.ex")
    router = render_template("router_injection.ex")

    assert controller =~ "def start(conn, params)"
    assert controller =~ "def approve(conn, %{} = params)"
    assert controller =~ "def cancel(conn, %{} = params)"
    assert controller =~ "def exchange(conn, params)"
    assert controller =~ "put_resp_header(\"referrer-policy\", \"no-referrer\")"
    assert controller =~ "AppLoginContinuation"

    assert controller =~
             "{:ok, :cancelled} <- AppSessions.approve_hosted(continuation, current_user(conn), :cancel)"

    assert controller =~ "{conn, _} = AppLoginContinuation.take(conn)"

    assert controller =~
             "defp invalid_request(conn), do: conn |> put_status(:bad_request) |> text(\"Invalid app login request.\")"

    {cancel_offset, _} = :binary.match(controller, "def cancel(conn, %{} = params)")
    cancel = binary_part(controller, cancel_offset, byte_size(controller) - cancel_offset)

    assert :binary.match(cancel, "{:ok, :cancelled} <- AppSessions.approve_hosted") <
             :binary.match(cancel, "{conn, _} = AppLoginContinuation.take(conn)")

    assert controller =~ "defp browser_assurance(conn)"

    assert controller =~
             "defp current_user(%{assigns: %{current_scope: %{user: user}}}), do: user"

    assert controller =~ "defp current_user(_), do: nil"
    refute controller =~ "get_in(conn.assigns, [:current_scope, :user])"
    assert controller =~ "type in [:standard, :remember_me]"
    assert controller =~ ":mfa_pending -> conn |> redirect(to: ~p\"/users/mfa\") |> halt()"
    refute controller =~ "put_flash"

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
    assert router =~ "post \"/refresh\", AppLoginController, :refresh"
  end

  test "renders a strict, bounded public refresh action without ordinary access authentication" do
    controller = render_template("app_login_controller.ex")
    router = render_template("router_injection.ex")

    assert controller =~ "def refresh(conn, %{\"refresh_token\" => token} = params)"
    assert controller =~ "[\"refresh_token\"] <- Map.keys(params)"
    assert controller =~ "true <- is_binary(token)"
    assert controller =~ "{:ok, credentials} <- AppSessions.refresh(token)"

    assert controller =~
             "def refresh(conn, _params), do: json(conn |> put_status(:bad_request), %{error: \"invalid_request\"})"

    assert controller =~ "json(conn |> put_status(:unauthorized), %{error: \"invalid_refresh\"})"
    refute controller =~ "refresh_token: token"
    refute controller =~ "FetchAppSession"

    assert router =~ "pipeline :app_login_refresh"
    assert router =~ "key_prefix: \"app_login_refresh\""
    assert router =~ "limit_config_key: :app_login_refresh_rate_limit"
    assert router =~ "window_config_key: :app_login_refresh_rate_limit_window"

    refresh_offset =
      :binary.match(router, "post \"/refresh\", AppLoginController, :refresh") |> elem(0)

    public_offset = :binary.match(router, "scope \"/api/app-login\", MyAppWeb do") |> elem(0)
    users_offset = :binary.match(router, "scope \"/users\", MyAppWeb do") |> elem(0)

    assert public_offset < refresh_offset
    assert users_offset < public_offset
    [[exchange_scope], [refresh_scope]] =
      Regex.scan(~r/scope \"\/api\/app-login\", MyAppWeb do\n(.*?)\nend/s, router,
        capture: :all_but_first
      )

    assert exchange_scope =~ "pipe_through [:api, :app_login_public]"
    assert exchange_scope =~ "post \"/exchange\", AppLoginController, :exchange"
    refute exchange_scope =~ "post \"/refresh\""
    assert refresh_scope =~ "pipe_through [:api, :app_login_refresh]"
    assert refresh_scope =~ "post \"/refresh\", AppLoginController, :refresh"
    refute router =~ "pipe_through [:api, :app_login_public, :app_session_proof]"
  end

  test "renders direct and refresh budgets in exclusive limiter scopes" do
    router =
      render_template("router_injection.ex",
        opts: [app_sessions: true, app_password_login: true]
      )

    assert router =~ "pipeline :app_login_direct"
    assert router =~ "key_prefix: \"app_login_direct\""
    assert router =~ "limit_config_key: :app_login_direct_rate_limit"
    assert router =~ "window_config_key: :app_login_direct_rate_limit_window"

    [[exchange_scope], [refresh_scope], [direct_scope]] =
      Regex.scan(~r/scope \"\/api\/app-login\", MyAppWeb do\n(.*?)\nend/s, router,
        capture: :all_but_first
      )

    assert exchange_scope =~ "pipe_through [:api, :app_login_public]"
    assert exchange_scope =~ "post \"/exchange\", AppLoginController, :exchange"
    refute exchange_scope =~ "post \"/refresh\""
    refute exchange_scope =~ "post \"/direct\""

    assert refresh_scope =~ "pipe_through [:api, :app_login_refresh]"
    assert refresh_scope =~ "post \"/refresh\", AppLoginController, :refresh"
    refute refresh_scope =~ "post \"/direct\""
    refute refresh_scope =~ "post \"/direct/mfa\""

    assert direct_scope =~ "pipe_through [:api, :app_login_direct]"
    assert direct_scope =~ "post \"/direct\", AppLoginController, :direct"
    assert direct_scope =~ "post \"/direct/mfa\", AppLoginController, :complete_direct_mfa"
    refute direct_scope =~ "post \"/refresh\""
  end

  test "renders owner-derived browser and sudo app-session revocation mutations" do
    controller = render_template("app_login_controller.ex")
    router = render_template("router_injection.ex")

    assert router =~ "pipe_through [:browser, :require_authenticated, :require_sudo]"
    assert router =~ "post \"/app-sessions/revoke\", AppLoginController, :revoke_family"
    assert router =~ "post \"/app-sessions/revoke-all\", AppLoginController, :revoke_all"

    assert controller =~ "def revoke_family(conn, %{\"family_id\" => family_id} = params)"
    assert controller =~ "[\"family_id\"] <- Map.keys(params)"
    assert controller =~ "true <- is_binary(family_id)"
    assert controller =~ "owner = conn.assigns.current_scope.user"
    assert controller =~ "AppSessions.revoke_family(owner, family_id)"
    assert controller =~ "def revoke_all(conn, %{} = params)"
    assert controller =~ "[] <- Map.keys(params)"
    assert controller =~ "AppSessions.revoke_all(owner)"
    assert controller =~ "%{ok: true}"
    assert controller =~ "%{error: \"not_found\"}"
    assert controller =~ "%{error: \"revocation_failed\"}"
    refute controller =~ "params[\"user_id\"]"
    refute controller =~ "params[\"owner_id\"]"
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
