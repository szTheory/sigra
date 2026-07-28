defmodule Sigra.Install.GeneratorMFATest do
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
    binary_id: false,
    adapter: :postgres,
    # Phase 24.1: core/user_auth.ex gates the :assign_user_organizations
    # on_mount clause on `<%= if organizations? do %>`. Without this
    # binding key the template compile fails with `undefined variable
    # "organizations?"`.
    organizations?: true,
    # Core templates gate passkey-related branches on `passkeys?` (EEx assigns).
    passkeys?: true
  ]

  describe "MFA template files exist" do
    test "mfa_challenge_controller.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "mfa_challenge_controller.ex"))
    end

    test "mfa_challenge_html.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "mfa_challenge_html.ex"))
    end

    test "mfa_challenge_live.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "mfa_challenge_live.ex"))
    end

    test "mfa_settings_live.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "mfa_settings_live.ex"))
    end

    test "mfa_settings_html.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "mfa_settings_html.ex"))
    end

    test "user_mfa_credential.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "user_mfa_credential.ex"))
    end

    test "user_backup_code.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "user_backup_code.ex"))
    end
  end

  describe "mfa_challenge_controller.ex template" do
    test "contains new action" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "def new(conn, _params)"
    end

    test "contains create action" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "def create(conn, %{\"mfa\" => mfa_params})"
    end

    test "handles both TOTP and backup verification methods" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "Auth.mfa_verify(user, code)"
      assert content =~ "Auth.mfa_verify_backup(user, code)"
    end

    test "contains mask_email function" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "defp mask_email(email)"
    end

    test "sets trust cookie on successful verification with trust=true" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "maybe_set_trust_cookie"
      assert content =~ "Sigra.MFA.Trust.sign"
    end

    test "contains error messages for invalid code (D-38, D-90)" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "Invalid verification code."
      assert content =~ "attempts remaining"
    end

    test "contains lockout error message (D-91)" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "Too many failed attempts. Try again in"
    end
  end

  describe "mfa_challenge_html.ex template" do
    test "contains inputmode numeric and autocomplete one-time-code" do
      content = render_template("mfa_challenge_html.ex")
      assert content =~ ~s(inputmode="numeric")
      assert content =~ ~s(autocomplete="one-time-code")
    end

    test "contains tab structure with TOTP and backup code" do
      content = render_template("mfa_challenge_html.ex")
      assert content =~ "Authenticator code"
      assert content =~ "Backup code"
    end

    test "contains trust checkbox" do
      content = render_template("mfa_challenge_html.ex")
      assert content =~ "Trust this browser for 30 days"
    end

    test "contains cancel and sign out link" do
      content = render_template("mfa_challenge_html.ex")
      assert content =~ "Cancel and sign out"
    end

    test "contains auto-submit JS script (D-36)" do
      content = render_template("mfa_challenge_html.ex")
      assert content =~ "requestSubmit()"
      assert content =~ "length === 6"
    end

    test "contains role=tablist for accessibility" do
      content = render_template("mfa_challenge_html.ex")
      assert content =~ ~s(role="tablist")
      assert content =~ ~s(role="tab")
      assert content =~ ~s(role="tabpanel")
    end
  end

  describe "mfa_challenge_live.ex template" do
    test "contains phx-change for auto-submit" do
      content = render_template("mfa_challenge_live.ex")
      assert content =~ "phx-change"
    end

    test "contains phx-submit for form submission" do
      content = render_template("mfa_challenge_live.ex")
      assert content =~ "phx-submit"
    end

    test "contains phx-click to switch from passkey flow to TOTP" do
      content = render_template("mfa_challenge_live.ex")
      assert content =~ "phx-click=\"show_totp\""
    end

    test "contains auto-submit logic at 6 digits" do
      content = render_template("mfa_challenge_live.ex")
      assert content =~ "auto_verify_totp"
      assert content =~ "String.length(code) == 6"
    end

    test "contains trust checkbox" do
      content = render_template("mfa_challenge_live.ex")
      assert content =~ "Trust this browser for 30 days"
    end

    test "contains passkey-first MFA challenge surface" do
      content = render_template("mfa_challenge_live.ex")
      assert content =~ ~s(id="mfa-passkey-panel")
      assert content =~ "PasskeyAuthenticate"
    end
  end

  describe "mfa_settings_live.ex template" do
    test "contains QR code rendering" do
      content = render_template("mfa_settings_live.ex")
      assert content =~ "raw(@svg)"
    end

    test "contains the semantic backup code list" do
      content = render_template("mfa_settings_live.ex")
      assert content =~ "sigra-auth-code-list"
    end

    test "contains acknowledgment checkbox" do
      content = render_template("mfa_settings_live.ex")
      assert content =~ "I have saved these backup codes in a safe place"
    end

    test "contains Enabled badge" do
      content = render_template("mfa_settings_live.ex")
      assert content =~ "Enabled"
      assert content =~ "sigra-auth-status sigra-auth-status--success"
    end

    test "contains backup code count display" do
      content = render_template("mfa_settings_live.ex")
      assert content =~ "of 8 backup codes remaining"
    end

    test "contains semantic danger treatment for disable confirmation" do
      content = render_template("mfa_settings_live.ex")
      assert content =~ "sigra-auth-notice sigra-auth-notice--danger"
      assert content =~ "Disable two-factor authentication"
    end

    test "contains Regenerate codes link" do
      content = render_template("mfa_settings_live.ex")
      assert content =~ "Regenerate codes"
    end

    test "contains Revoke all trusted browsers link" do
      content = render_template("mfa_settings_live.ex")
      assert content =~ "Revoke all trusted browsers"
    end
  end

  describe "user_auth.ex template" do
    test "contains require_mfa function" do
      content = render_template("user_auth.ex")
      assert content =~ "def require_mfa(conn, _opts)"
    end

    test "require_mfa redirects to /users/mfa" do
      content = render_template("user_auth.ex")
      assert content =~ ~s|redirect(to: ~p"/users/mfa")|
    end

    test "require_mfa checks mfa_pending session" do
      content = render_template("user_auth.ex")
      assert content =~ "mfa_pending"
    end
  end

  describe "generator includes MFA routes (via Features.Core)" do
    # Phase 11 Wave 4: v1.0-specific content (router routes, file list)
    # moved from the sigra.install.ex monolith into
    # Sigra.Install.Features.Core. These tests grep Features.Core's
    # source for the same assertions they used to make against the
    # monolith.
    @features_core_path Path.join([
                          File.cwd!(),
                          "lib",
                          "sigra",
                          "install",
                          "features",
                          "core.ex"
                        ])

    test "generator has MFA challenge controller routes" do
      source = File.read!(@features_core_path)
      assert source =~ ~s(MFAChallengeController, :new)
      assert source =~ ~s(MFAChallengeController, :create)
    end

    test "generator has MFA challenge LiveView route" do
      source = File.read!(@features_core_path)
      assert source =~ ~s(live "/mfa", MFAChallengeLive)
    end

    test "generator has MFA settings LiveView route" do
      source = File.read!(@features_core_path)
      assert source =~ ~s(live "/settings/mfa", MFASettingsLive)
    end

    test "generator injects require_mfa into authenticated pipeline" do
      source = File.read!(@features_core_path)
      assert source =~ "plug :require_mfa"
    end

    test "generator includes MFA schema templates in file list" do
      source = File.read!(@features_core_path)
      assert source =~ ~s("core/user_mfa_credential.ex")
      assert source =~ ~s("core/user_backup_code.ex")
    end

    test "generator includes MFA challenge templates in file list" do
      source = File.read!(@features_core_path)
      assert source =~ ~s("core/mfa_challenge_controller.ex")
      assert source =~ ~s("core/mfa_challenge_html.ex")
    end

    test "generator includes MFA LiveView templates in live file list" do
      source = File.read!(@features_core_path)
      assert source =~ ~s("core/mfa_challenge_live.ex")
      assert source =~ ~s("core/mfa_settings_live.ex")
    end

    test "generator includes MFA settings HTML in non-live file list" do
      source = File.read!(@features_core_path)
      assert source =~ ~s("core/mfa_settings_html.ex")
    end
  end

  describe "auth.ex template MFA wiring" do
    test "contains mfa_enroll function" do
      content = render_template("auth.ex")
      assert content =~ "def mfa_enroll(opts \\\\ [])"
    end

    test "contains mfa_confirm_enrollment function" do
      content = render_template("auth.ex")
      assert content =~ "def mfa_confirm_enrollment(user, raw_secret, code"
    end

    test "contains mfa_verify function" do
      content = render_template("auth.ex")
      assert content =~ "def mfa_verify(user, code"
    end

    test "contains mfa_verify_backup function" do
      content = render_template("auth.ex")
      assert content =~ "def mfa_verify_backup(user, code"
    end

    test "contains mfa_disable function" do
      content = render_template("auth.ex")
      assert content =~ "def mfa_disable(user, code"
    end

    test "contains mfa_enabled? function" do
      content = render_template("auth.ex")
      assert content =~ "def mfa_enabled?(user)"
    end

    test "contains mfa_status function" do
      content = render_template("auth.ex")
      assert content =~ "def mfa_status(user)"
    end

    test "delegates to Sigra.MFA module" do
      content = render_template("auth.ex")
      assert content =~ "Sigra.MFA.enroll("
      assert content =~ "Sigra.MFA.verify("
      assert content =~ "Sigra.MFA.disable("
    end
  end

  # -- Helpers --

  defp render_template(name) do
    path = Path.join(@template_dir, name)
    EEx.eval_file(path, @base_binding)
  end
end
