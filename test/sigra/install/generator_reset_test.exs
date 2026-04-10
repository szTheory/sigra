defmodule Sigra.Install.GeneratorResetTest do
  @moduledoc """
  Tests that the reset password and user_auth EEx templates produce
  correct output when evaluated with sample assigns.

  Since generated templates contain HEEx sigils (~H) that require the
  full Phoenix stack to compile, we test at the EEx interpolation level:
  verify that EEx tags produce the expected module names and that the
  raw template text contains required patterns.
  """
  use ExUnit.Case, async: true

  @templates_dir Path.expand("../../../priv/templates/sigra.install", __DIR__)

  @sample_assigns [
    web_module: "MyAppWeb",
    context_module: "MyApp.Auth",
    schema_alias: "User",
    repo_module: "MyApp.Repo",
    otp_app: "my_app"
  ]

  describe "reset_password_controller.ex template" do
    setup do
      %{rendered: render_template("reset_password_controller.ex")}
    end

    test "renders module name from assigns", %{rendered: result} do
      assert result =~ "defmodule MyAppWeb.ResetPasswordController do"
      assert result =~ "use MyAppWeb, :controller"
      # Plan 10.1-02 fix #7 dropped the unused `alias <%= context_module %>`
      # from this template; calls are fully qualified instead.
      assert result =~ "MyApp.Auth.get_user_by_email"
      refute result =~ ~r/^\s*alias MyApp\.Auth\s*$/m
    end

    test "contains new action", %{rendered: result} do
      assert result =~ "def new(conn, _params)"
    end

    test "contains create action with enumeration-safe response", %{rendered: result} do
      assert result =~ ~s(def create(conn, %{"user" => %{"email" => email}})
      assert result =~ "If your email is in our system"
    end

    test "contains edit action with token lookup", %{rendered: result} do
      assert result =~ ~s(def edit(conn, %{"token" => token})
      assert result =~ "get_user_by_reset_password_token"
    end

    test "contains update action with auto-login after reset", %{rendered: result} do
      assert result =~ ~s(def update(conn, %{"token" => token)
      assert result =~ "reset_user_password"
      assert result =~ "log_in_user"
    end

    test "uses dgettext for i18n", %{rendered: result} do
      assert result =~ ~s(dgettext("sigra")
    end
  end

  describe "reset_password_html.ex template" do
    setup do
      %{raw: read_template("reset_password_html.ex")}
    end

    test "contains module definition EEx tag", %{raw: template} do
      assert template =~ "<%= web_module %>.ResetPasswordHTML"
    end

    test "contains request form heading", %{raw: template} do
      assert template =~ "Forgot your password?"
      assert template =~ "Send reset instructions"
    end

    test "contains password form with autocomplete", %{raw: template} do
      assert template =~ "Reset your password"
      assert template =~ ~s(autocomplete="new-password")
    end

    test "contains expired page with re-request button", %{raw: template} do
      assert template =~ "Reset link expired"
      assert template =~ "Request new reset email"
    end

    test "uses .header component", %{raw: template} do
      assert template =~ ".header"
    end

    test "uses dgettext for i18n", %{raw: template} do
      assert template =~ ~s(dgettext("sigra")
    end
  end

  describe "reset_password_live.ex template" do
    setup do
      %{raw: read_template("reset_password_live.ex")}
    end

    test "contains module definition EEx tag", %{raw: template} do
      assert template =~ "<%= web_module %>.ResetPasswordLive"
    end

    test "contains phx-change validation", %{raw: template} do
      assert template =~ "phx-change"
      assert template =~ "validate"
    end

    test "contains password strength meter", %{raw: template} do
      assert template =~ "password_strength_color"
      assert template =~ "password_strength_width"
    end

    test "contains both request and password forms", %{raw: template} do
      assert template =~ "Forgot your password?"
      assert template =~ "Reset your password"
    end

    test "handles expired token inline", %{raw: template} do
      assert template =~ "token_invalid?"
      assert template =~ "Reset link expired"
    end

    test "uses dgettext for i18n", %{raw: template} do
      assert template =~ ~s(dgettext("sigra")
    end
  end

  describe "user_auth.ex template - require_confirmed_user" do
    setup do
      raw = read_template("user_auth.ex")
      rendered = render_template("user_auth.ex")
      %{raw: raw, rendered: rendered}
    end

    test "contains require_confirmed_user function", %{rendered: result} do
      assert result =~ "def require_confirmed_user(conn, opts"
    end

    test "implements allow_with_banner mode", %{rendered: result} do
      assert result =~ ":allow_with_banner"
      assert result =~ "Please confirm your email"
    end

    test "implements block mode with auto-resend", %{rendered: result} do
      assert result =~ ":block"
      assert result =~ "deliver_user_confirmation_instructions"
      assert result =~ "You must confirm your email before logging in"
      assert result =~ "halt()"
    end

    test "uses dgettext for unconfirmed user messages", %{rendered: result} do
      assert result =~ ~s(dgettext("sigra", "Please confirm your email)
      assert result =~ ~s(dgettext("sigra", "You must confirm your email)
    end

    test "contains unconfirmed_access_mode helper", %{rendered: result} do
      assert result =~ "defp unconfirmed_access_mode(opts)"
    end
  end

  # Renders only the EEx layer (interpolates assigns), does not compile
  # the resulting Elixir/HEEx code. Suitable for templates that contain
  # ~H sigils or other constructs requiring the full Phoenix stack.
  defp render_template(filename) do
    template = read_template(filename)
    EEx.eval_string(template, assigns: @sample_assigns, file: filename)
  rescue
    # If EEx evaluation hits a CompileError from ~H sigils or similar,
    # fall back to simple string replacement for the EEx tags
    CompileError ->
      template = read_template(filename)
      simple_render(template)
  end

  defp simple_render(template) do
    template
    |> String.replace("<%= web_module %>", "MyAppWeb")
    |> String.replace("<%= context_module %>", "MyApp.Auth")
    |> String.replace("<%= schema_alias %>", "User")
    |> String.replace("<%= repo_module %>", "MyApp.Repo")
    |> String.replace("<%= otp_app %>", "my_app")
  end

  defp read_template(filename) do
    @templates_dir
    |> Path.join(filename)
    |> File.read!()
  end
end
