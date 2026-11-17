defmodule Sigra.Install.GeneratorPasskeyPrimaryLoginTest do
  use ExUnit.Case, async: true

  @core_template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  describe "passkey-primary controller login template" do
    test "fresh passkey config uses the resolved product name and keeps ceremony settings" do
      config =
        Path.join([
          File.cwd!(),
          "priv",
          "templates",
          "sigra.install",
          "passkeys",
          "config_injection.ex"
        ])
        |> EEx.eval_file(
          otp_app: :example_app,
          app_name: "Example Product",
          context_module: "Example.Accounts"
        )

      assert config =~ ~s(rp_name: "Example Product")

      for unchanged <- [
            ~s(rp_id: "localhost"),
            ~s(origin: "http://localhost:4000"),
            "timeout_ms: 60_000",
            "attestation: :none",
            "user_verification: :preferred",
            "ceremony_rate_limit: [limit: 5, window_ms: 60_000]",
            "passkey_primary_enabled: true"
          ] do
        assert config =~ unchanged
      end
    end

    test "renders identifier-first passkey login without LiveView submission" do
      content = read_core_template("login_html.ex")

      for expected <- [
            "@passkey_primary_enabled",
            ~s(autocomplete="username webauthn"),
            ~s(id="passkey_login_form"),
            ~s(id="passkey_login_email"),
            ~s(id="magic_link_email"),
            ~s(id="login_email"),
            ~s(id="enterprise_login_email"),
            ~s(id="passkey_login_button"),
            "passkey[response]",
            "/users/log_in/passkey",
            "/users/log_in/passkey/options",
            "Continue with a passkey",
            "Other ways to sign in",
            "data-passkey-login-status",
            "Email me a sign-in link",
            "Sign in with password"
          ] do
        assert content =~ expected
      end

      refute content =~ "window.SigraPasskeys"
      refute content =~ "phx-submit"
      refute content =~ "choose your sign-in method"
      refute content =~ "passkey screen"
      refute content =~ "password screen"
      refute content =~ "Keep me logged in"
      assert content =~ "Keep me signed in"
      assert content =~ ~s|dgettext("sigra", "Sign in")|
      assert content =~ ~s|dgettext("sigra", "Create an account")|
    end
  end

  describe "passkey-primary signup and recovery invariants" do
    test "auth template requires confirmed email and mandatory magic-link recovery" do
      content = read_core_template("auth.ex")

      for expected <- [
            "passkey_primary_user_eligible?",
            "ensure_passkey_primary_user_eligible",
            "magic_link_recovery_available?",
            "confirmed_at != nil",
            "{:error, :email_not_confirmed}"
          ] do
        assert content =~ expected
      end
    end

    test "session controller refuses unconfirmed passkey-primary login before authentication" do
      content = read_core_template("session_controller.ex")

      assert content =~ "Auth.ensure_passkey_primary_user_eligible(user)"
      assert content =~ "{:error, :email_not_confirmed}"
      assert content =~ "String.slice(to_string(email), 0, 160)"

      assert content =~
               "We couldn't finish passkey sign-in. Try again or use another way to continue."
    end

    test "registration LiveView carries signup-time passkey enrollment through confirmation" do
      content = read_core_template("registration_live.ex")

      for expected <- [
            "passkey_primary_enabled",
            "enroll_passkey_after_signup",
            "user[enroll_passkey]",
            "Add a passkey after creating your account",
            "enroll_passkey = Map.get(user_params, \"enroll_passkey\") in [\"true\", true, \"on\", \"1\"]",
            "?enroll_passkey=1"
          ] do
        assert content =~ expected
      end
    end

    test "controller registration template exposes equivalent enrollment control" do
      content = read_core_template("registration_html.ex")

      for expected <- [
            "@passkey_primary_enabled",
            "user[enroll_passkey]",
            "Add a passkey after creating your account"
          ] do
        assert content =~ expected
      end
    end

    test "confirmation controller logs in confirmed users through sudo-gated enrollment return" do
      content = read_core_template("confirmation_controller.ex")

      for expected <- [
            "alias <%= web_module %>.UserAuth",
            "put_session(:user_return_to",
            "UserAuth.log_in_user(user, %{})",
            "passkey_bootstrap_return_to",
            "URI.encode_www_form(\"/users/settings/mfa?bootstrap_passkey=1#passkeys\")",
            "/users/settings/mfa?bootstrap_passkey=1#passkeys",
            "enroll_passkey"
          ] do
        assert content =~ expected
      end

      refute content =~ "return_to.*UserAuth.log_in_user"
      refute content =~ "UserAuth.log_in_user(user, %{\"return_to\""
    end
  end

  defp read_core_template(name) do
    File.read!(Path.join(@core_template_dir, name))
  end
end
