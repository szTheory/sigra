defmodule Sigra.Install.GeneratorPasskeyMFAChallengeTest do
  use ExUnit.Case, async: true

  @core_template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  describe "mfa_challenge_live.ex passkey-first challenge" do
    test "renders passkey-first MFA with TOTP and backup fallbacks" do
      content = read_core_template("mfa_challenge_live.ex")

      for expected <- [
            "passkey_count: Auth.passkey_count_for_user",
            "Continue with passkey",
            "Use authenticator code instead",
            "Use a backup code",
            ~s(phx-hook="PasskeyAuthenticate"),
            "sigra:passkey-authenticate:start",
            ~s(~p"/users/mfa/passkey/options"),
            ~s(~p"/users/mfa/passkey"),
            "/users/mfa/passkey"
          ] do
        assert content =~ expected
      end

      refute content =~ ~s(role="tablist")
      refute content =~ "Auth.authenticate_passkey"
    end

    test "keeps passkey completion controller-owned through a hidden POST form" do
      content = read_core_template("mfa_challenge_live.ex")

      for expected <- [
            ~s(id="passkey-mfa-complete-form"),
            ~s(action={~p"/users/mfa/passkey"}),
            ~s(name="passkey[response]"),
            ~s(id="passkey-mfa-response"),
            "JSON.encode!"
          ] do
        assert content =~ expected
      end
    end
  end

  describe "mfa_challenge_live.ex passkey recovery states" do
    test "maps abort, timeout, unsupported, and generic failures to exact recovery copy" do
      content = read_core_template("mfa_challenge_live.ex")

      for expected <- [
            "Passkey sign-in was canceled.",
            "Nothing changed. Try again or choose another way to continue.",
            "That passkey request timed out.",
            "Try again when you're ready, or use another sign-in method.",
            "Passkeys aren't available in this browser.",
            "Use your password or a magic link here, or switch to a device that supports passkeys.",
            "We couldn't finish passkey sign-in. Try again or use another way to continue.",
            "Try again",
            "Use another way",
            ~s(def handle_event("sigra:passkey-authenticate:aborted"),
            ~s(def handle_event("sigra:passkey-authenticate:error")
          ] do
        assert content =~ expected
      end

      refute content =~ "AbortError"
      refute content =~ "NotAllowedError"
      refute content =~ "WebAuthnError"
    end
  end

  defp read_core_template(name) do
    File.read!(Path.join(@core_template_dir, name))
  end
end
