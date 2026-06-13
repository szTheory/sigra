defmodule Sigra.Install.GeneratorEmailTest do
  use ExUnit.Case, async: true

  @template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  @base_binding [
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
    reset_password_url: "/users/reset_password",
    settings_url: "/users/settings",
    binary_id: false,
    adapter: :postgres,
    # Phase 24 D-04.3: emails.ex now contains a conditional EEx block
    # `<%= if organizations? do %>` around organization_invitation/4.
    # Default leg includes the block.
    organizations?: true,
    passkeys?: true
  ]

  describe "emails.ex template" do
    test "compiles with sample bindings" do
      content = render_template("emails.ex")
      assert is_binary(content)
    end

    test "defines the module" do
      content = render_template("emails.ex")
      assert content =~ "defmodule MyApp.Auth.Emails do"
    end

    test "imports Swoosh.Email" do
      content = render_template("emails.ex")
      assert content =~ "import Swoosh.Email"
    end

    test "contains confirmation_email function" do
      content = render_template("emails.ex")
      assert content =~ "def confirmation_email(user, url, code)"
    end

    test "contains reset_password_email function" do
      content = render_template("emails.ex")
      assert content =~ "def reset_password_email(user, url)"
    end

    test "contains magic_link_email function" do
      content = render_template("emails.ex")
      assert content =~ "def magic_link_email(user, url)"
    end

    test "contains oauth_reset_email function" do
      content = render_template("emails.ex")
      assert content =~ "def oauth_reset_email(user, provider)"
    end

    test "contains base_layout helper" do
      content = render_template("emails.ex")
      assert content =~ "defp base_layout(content_html)"
    end

    test "contains base_email helper" do
      content = render_template("emails.ex")
      assert content =~ "defp base_email(to)"
    end

    test "uses gettext for i18n" do
      content = render_template("emails.ex")
      assert content =~ ~s(dgettext("sigra")
    end

    test "drives CTA button color from branding tokens" do
      content = render_template("emails.ex")
      assert content =~ "branding.accent_color"
      assert content =~ "branding.accent_foreground"
    end

    test "drives layout colors from branding tokens" do
      content = render_template("emails.ex")
      assert content =~ "branding.background_color"
      assert content =~ "branding.surface_color"
    end

    test "uses accessible table layout" do
      content = render_template("emails.ex")
      assert content =~ ~s(role="presentation")
    end

    test "sets from address from binding" do
      content = render_template("emails.ex")
      assert content =~ "noreply@example.com"
      assert content =~ "Sigra.Branding.email_from(branding())"
    end
  end

  describe "auth_mailer.ex template" do
    test "compiles with sample bindings" do
      content = render_template("auth_mailer.ex")
      assert is_binary(content)
    end

    test "implements Sigra.Mailer behaviour" do
      content = render_template("auth_mailer.ex")
      assert content =~ "@behaviour Sigra.Mailer"
    end

    test "has @impl annotation" do
      content = render_template("auth_mailer.ex")
      assert content =~ "@impl Sigra.Mailer"
    end

    test "defines deliver function" do
      content = render_template("auth_mailer.ex")
      assert content =~ "def deliver(to, subject, body)"
    end

    test "handles string body" do
      content = render_template("auth_mailer.ex")
      assert content =~ "defp build_email(to, subject, body) when is_binary(body)"
    end

    test "handles html+text map body" do
      content = render_template("auth_mailer.ex")
      assert content =~ "defp build_email(to, subject, %{html: html, text: text})"
    end

    test "handles text-only map body" do
      content = render_template("auth_mailer.ex")
      assert content =~ "defp build_email(to, subject, %{text: text})"
    end
  end

  describe "confirmation_controller.ex template" do
    test "compiles with sample bindings" do
      content = render_template("confirmation_controller.ex")
      assert is_binary(content)
    end

    test "defines new action" do
      content = render_template("confirmation_controller.ex")
      assert content =~ "def new(conn, _params)"
    end

    test "defines create action for code submission" do
      content = render_template("confirmation_controller.ex")
      assert content =~ ~s|def create(conn, %{"code" => code})|
    end

    test "defines confirm action for link click" do
      content = render_template("confirmation_controller.ex")
      assert content =~ ~s|def confirm(conn, %{"token" => token})|
    end

    test "defines resend action" do
      content = render_template("confirmation_controller.ex")
      assert content =~ "def resend(conn, _params)"
    end

    test "uses gettext for i18n" do
      content = render_template("confirmation_controller.ex")
      assert content =~ ~s(dgettext("sigra")
    end
  end

  describe "confirmation_html.ex template" do
    test "compiles with sample bindings" do
      content = render_template("confirmation_html.ex")
      assert is_binary(content)
    end

    test "uses numeric inputmode" do
      content = render_template("confirmation_html.ex")
      assert content =~ ~s(inputmode="numeric")
    end

    test "uses one-time-code autocomplete" do
      content = render_template("confirmation_html.ex")
      assert content =~ ~s(autocomplete="one-time-code")
    end

    test "limits input to 6 characters" do
      content = render_template("confirmation_html.ex")
      assert content =~ ~s(maxlength="6")
    end

    test "uses .header component" do
      content = render_template("confirmation_html.ex")
      assert content =~ ".header"
    end

    test "has already_confirmed template" do
      content = render_template("confirmation_html.ex")
      assert content =~ "def already_confirmed(assigns)"
      assert content =~ "Email already confirmed"
    end

    test "has expired template" do
      content = render_template("confirmation_html.ex")
      assert content =~ "def expired(assigns)"
      assert content =~ "Confirmation link expired"
    end
  end

  describe "confirmation_live.ex template" do
    test "compiles with sample bindings" do
      content = render_template("confirmation_live.ex")
      assert is_binary(content)
    end

    test "uses phx-change for auto-submit" do
      content = render_template("confirmation_live.ex")
      assert content =~ "phx-change"
    end

    test "checks string length for auto-submit" do
      content = render_template("confirmation_live.ex")
      assert content =~ "String.length(code) == 6"
    end

    test "uses LiveView" do
      content = render_template("confirmation_live.ex")
      assert content =~ ":live_view"
    end

    test "handles already_confirmed state" do
      content = render_template("confirmation_live.ex")
      assert content =~ ":already_confirmed"
    end

    test "handles expired state" do
      content = render_template("confirmation_live.ex")
      assert content =~ ":expired"
    end
  end

  # -- Helpers --

  defp render_template(filename) do
    path = Path.join(@template_dir, filename)
    EEx.eval_file(path, @base_binding)
  end
end
