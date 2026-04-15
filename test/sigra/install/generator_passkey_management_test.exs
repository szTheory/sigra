defmodule Sigra.Install.GeneratorPasskeyManagementTest do
  use ExUnit.Case, async: true

  @core_template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  describe "mfa_settings_live.ex passkey enrollment surface" do
    test "renders the passkeys card with exact enrollment and empty-state copy" do
      content = read_core_template("mfa_settings_live.ex")

      assert content =~ ~s(id="passkeys")
      assert content =~ "Passkeys"
      assert content =~
               "Use Face ID, Touch ID, Windows Hello, or your password manager to sign in without typing a code."

      assert content =~ "No passkeys added yet"
      assert content =~
               "Add a passkey to sign in faster on this device and keep a backup sign-in method available."

      assert content =~ "Add passkey"
      assert content =~ ~s(id="add-passkey-button")
    end

    test "uses the Phase 20 registration hook and controller POST URLs" do
      content = read_core_template("mfa_settings_live.ex")

      for expected <- [
            ~s(id="passkey-registration-hook"),
            ~s(phx-hook="PasskeyRegister"),
            "sigra:passkey-register:start",
            "sigra:passkey-register:success",
            "sigra:passkey-register:error",
            "sigra:passkey-register:aborted",
            ~s(~p"/users/settings/mfa/passkeys/options"),
            ~s(~p"/users/settings/mfa/passkeys")
          ] do
        assert content =~ expected
      end
    end

    test "keeps passkey registration completion out of the LiveView" do
      content = read_core_template("mfa_settings_live.ex")

      refute content =~ "Auth.register_passkey"
    end

    test "maps browser abort and error states without rendering raw exception names" do
      content = read_core_template("mfa_settings_live.ex")

      assert content =~ "Passkey sign-in was canceled."
      assert content =~ "Nothing changed. Try again or choose another way to continue."
      assert content =~ "That passkey request timed out."
      assert content =~ "Try again when you're ready, or use another sign-in method."
      assert content =~ "Passkeys aren't available in this browser."
      assert content =~
               "Use your password or a magic link here, or switch to a device that supports passkeys."

      refute content =~ "NotAllowedError"
      refute content =~ "AbortError"
    end
  end

  defp read_core_template(name) do
    File.read!(Path.join(@core_template_dir, name))
  end
end
