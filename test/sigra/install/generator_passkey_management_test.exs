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

  describe "mfa_settings_live.ex passkey management rows" do
    test "renders compact rows with friendly labels and limited metadata" do
      content = read_core_template("mfa_settings_live.ex")

      assert content =~ "Auth.passkey_label(passkey)"
      assert content =~ "Added"
      assert content =~ "Last used"
      assert content =~ "Never used"

      refute content =~ "passkey.aaguid"
      refute content =~ "passkey.transports"
      refute content =~ "passkey.rp_id"
    end

    test "supports row-local inline rename" do
      content = read_core_template("mfa_settings_live.ex")

      for expected <- [
            "Rename",
            "Save name",
            ~s(def handle_event("open_passkey_rename"),
            ~s(def handle_event("cancel_passkey_rename"),
            ~s(def handle_event("save_passkey_name"),
            "Auth.rename_passkey(user, credential_id, nickname || \"\")",
            "Passkey name saved."
          ] do
        assert content =~ expected
      end
    end

    test "uses row-local controller POST form for sudo-aware delete confirmation" do
      content = read_core_template("mfa_settings_live.ex")

      for expected <- [
            "Delete",
            "Delete this passkey?",
            "Delete this passkey? You'll still need another sign-in method before removing your last recovery option.",
            "You're removing your last passkey. Make sure you can still sign in with your password, authenticator code, backup code, or magic link.",
            ~S(~p"/users/settings/mfa/passkeys/#{passkey.credential_id}/delete"),
            ~s(method="post"),
            "_csrf_token",
            ~s(def handle_event("confirm_passkey_delete"),
            ~s(def handle_event("cancel_passkey_delete")
          ] do
        assert content =~ expected
      end

      refute content =~ ~s(def handle_event("delete_passkey")
      refute content =~ "Auth.delete_passkey("
    end
  end

  defp read_core_template(name) do
    File.read!(Path.join(@core_template_dir, name))
  end
end
