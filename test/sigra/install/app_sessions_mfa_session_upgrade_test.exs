defmodule Sigra.Install.AppSessionsMFASessionUpgradeTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

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
  test "ordinary standard sessions cannot consume a TOTP factor" do
    controller = compiled_controller()
    user = %{id: "user-1", email: "person@example.com"}

    conn = request_conn(user, %{id: "standard", type: :standard})

    _response = controller.create(conn, %{"mfa" => %{"method" => "totp", "code" => "123456"}})

    assert factor_counts() == %{totp: 0, backup: 0, complete: 0, rotate: 0}
  end

  @tag :controller
  test "ordinary remember-me sessions cannot consume a backup code" do
    controller = compiled_controller()
    user = %{id: "user-1", email: "person@example.com"}

    conn = request_conn(user, %{id: "remember", type: :remember_me})

    _response =
      controller.create(conn, %{"mfa" => %{"method" => "backup", "code" => "unused-code"}})

    assert factor_counts() == %{totp: 0, backup: 0, complete: 0, rotate: 0}
  end

  @tag :controller
  test "a pending session invokes one selected verifier then rotates that exact row to hosted continuation" do
    controller = compiled_controller()
    user = %{id: "user-1", email: "person@example.com"}
    pending = %{id: "pending", type: :mfa_pending, user_id: user.id}

    conn = request_conn(user, pending)

    response =
      controller.create(conn, %{"mfa" => %{"method" => "backup", "code" => "unused-code"}})

    assert factor_counts() == %{totp: 0, backup: 1, complete: 1, rotate: 1}
    assert Process.get(:sigra_mfa_upgrade_session) == pending
    assert response.private[:sigra_test_redirect] == "/users/app-login/continue"
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

  defp compiled_controller do
    reset_factor_counts()
    compile_fixture_modules()

    module =
      Module.concat(MyAppWeb, "MFAChallengeController#{System.unique_integer([:positive])}")

    source =
      render_template("mfa_challenge_controller.ex", app_sessions: true)
      |> String.replace(
        "defmodule MyAppWeb.MFAChallengeController do",
        "defmodule #{inspect(module)} do"
      )

    Code.compile_string(source)
    module
  end

  defp compile_fixture_modules do
    Code.compile_string("""
    defmodule MyAppWeb do
      defmacro __using__(:controller) do
        quote do
          import Plug.Conn
          import MyAppWeb.ControllerStubs
          import MyAppWeb, only: [sigil_p: 2]
        end
      end

      defmacro sigil_p({:<<>>, _, [path]}, _modifiers), do: path
    end

    defmodule MyAppWeb.ControllerStubs do
      def put_flash(conn, _kind, _message), do: conn
      def render(conn, _template, _assigns), do: conn
      def redirect(conn, to: path), do: Plug.Conn.put_private(conn, :sigra_test_redirect, path)
    end

    defmodule MyAppWeb.UserAuth do
      def put_user_session_token(conn, _token) do
        MyApp.Auth.update_counts(:rotate)
        conn
      end
    end

    defmodule MyAppWeb.AppLoginContinuation do
      def fetch(conn), do: {:ok, conn, "profile-1"}
      def clear(conn), do: conn
    end

    defmodule MyApp.Auth do
      def mfa_verify(_user, _code) do
        update_counts(:totp)
        {:ok, :verified}
      end

      def mfa_verify_backup(_user, _code) do
        update_counts(:backup)
        {:ok, :verified}
      end

      def complete_mfa_verification(_user, session, _opts) do
        update_counts(:complete)
        Process.put(:sigra_mfa_upgrade_session, session)
        {:ok, %{session: %{token: "rotated-token"}}}
      end

      def sigra_config, do: %{mfa: []}

      def update_counts(key) do
        counts = Process.get(:sigra_mfa_factor_counts)
        Process.put(:sigra_mfa_factor_counts, Map.update!(counts, key, &(&1 + 1)))
      end
    end
    """)
  end

  defp request_conn(user, session) do
    conn(:post, "/users/mfa")
    |> init_test_session(%{})
    |> assign(:current_scope, %{user: user})
    |> put_private(:sigra_session, session)
  end

  defp reset_factor_counts do
    Process.put(:sigra_mfa_factor_counts, %{totp: 0, backup: 0, complete: 0, rotate: 0})
    Process.delete(:sigra_mfa_upgrade_session)
  end

  defp factor_counts, do: Process.get(:sigra_mfa_factor_counts)
end
