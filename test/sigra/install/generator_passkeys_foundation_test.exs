defmodule Sigra.Install.GeneratorPasskeysFoundationTest do
  use ExUnit.Case, async: true

  alias Sigra.Passkeys.DeviceName

  @core_template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])
  @aaguid_snapshot Path.join([File.cwd!(), "priv", "sigra", "passkey_aaguids.json"])

  describe "AAGUID registry snapshot" do
    test "contains representative friendly authenticator labels" do
      content = File.read!(@aaguid_snapshot)

      assert content =~ "iCloud Keychain"
      assert content =~ "Google Password Manager"
      assert content =~ "1Password"
      assert content =~ "Windows Hello"
    end
  end

  describe "DeviceName.label/3" do
    test "known snapshot AAGUID resolves to a friendly name" do
      assert DeviceName.label(nil, "fbfc3007-154e-4ecc-8c0b-6e020557d7bd", nil) ==
               "iCloud Keychain"
    end

    test "unknown AAGUID falls back to the device hint" do
      assert DeviceName.label(nil, "00000000-0000-0000-0000-000000000000", "Chrome on macOS") ==
               "Chrome on macOS"
    end

    test "unknown AAGUID without a hint falls back to Passkey" do
      assert DeviceName.label(nil, "00000000-0000-0000-0000-000000000000", nil) == "Passkey"
    end

    test "nickname takes precedence over the registry label" do
      assert DeviceName.label("Work laptop", "fbfc3007-154e-4ecc-8c0b-6e020557d7bd", nil) ==
               "Work laptop"
    end
  end

  describe "auth.ex passkey template foundation" do
    test "contains passkey wrapper and discoverable-auth functions" do
      content = read_core_template("auth.ex")

      assert content =~ "alias <%= context_module %>.UserPasskey"
      assert content =~ "def passkeys_for_user(user)"
      assert content =~ "def passkey_count_for_user(user)"
      assert content =~ "def passkey_label(passkey)"
      assert content =~ "def register_passkey(user, attestation_params, details \\\\ %{})"
      assert content =~ "def authenticate_passkey(user, assertion_params)"
      assert content =~ "def authenticate_discoverable_passkey("
      assert content =~ "def rename_passkey(user, credential_id, nickname, opts \\\\ [])"
      assert content =~ "def delete_passkey(user, credential_id)"
      assert content =~ "Sigra.Passkeys.delete_with_posture"
      assert content =~ "def passkey_primary_enabled?()"
      assert content =~ "def deliver_passkey_registration_notification(user, details)"
      assert content =~ "normalize_passkey_registration_params"
      assert content =~ "normalize_passkey_assertion_params"
      assert content =~ "Base.url_decode64"
      assert content =~ "Repo.get_by(UserPasskey, credential_id:"
      assert content =~ "Repo.get(<%= schema_alias %>, passkey.user_id)"
      assert content =~ "{:ok, user, credential}"
      assert content =~ "authenticate_discoverable_passkey"
    end

    test "remaps duplicate passkey registration to friendly error contract" do
      auth_content = read_core_template("auth.ex")
      controller_content = read_core_template("session_controller.ex")

      assert auth_content =~ ":duplicate_passkey"
      assert auth_content =~ "unique"
      assert controller_content =~ "This passkey is already registered."
    end

    test "delivers passkey registration notification through Sigra delivery" do
      content = read_core_template("auth.ex")

      assert content =~ "Emails.passkey_registration_email(user, details)"
      assert content =~ "Sigra.Delivery.deliver(:passkey_registration"
    end
  end

  describe "emails.ex passkey template foundation" do
    test "contains passkey registration notification email copy" do
      content = read_core_template("emails.ex")

      assert content =~ "def passkey_registration_email(user, details)"
      assert content =~ "New Passkey Added"
      assert content =~ "New passkey added to your account"
    end
  end

  describe "controller-owned passkey completion template foundation" do
    test "user_auth exposes a public raw session token writer" do
      content = read_core_template("user_auth.ex")

      assert content =~ "def put_user_session_token"
      assert content =~ "put_token_in_session(token)"
    end

    test "auth exposes MFA session upgrade wrapper" do
      content = read_core_template("auth.ex")

      assert content =~ "def complete_mfa_verification"
      assert content =~ "Sigra.Auth.complete_mfa_verification"
    end

    test "session controller owns passkey options and completion actions" do
      content = read_core_template("session_controller.ex")

      for expected <- [
            "def passkey_registration_options",
            "def complete_passkey_registration",
            "def passkey_authentication_options",
            "%{\"conditional\" => \"true\"}",
            "conditional_passkey_authentication_options_json",
            "allowCredentials: []",
            "useBrowserAutofill: true",
            "def passkey_mfa_options",
            "def complete_passkey",
            "authenticate_discoverable_passkey",
            "ensure_passkey_primary_user_eligible",
            "def complete_mfa_passkey",
            "def delete_passkey(conn, %{\"id\" => credential_id})",
            "Auth.delete_passkey(user, credential_id)",
            "delete_passkey_success_message",
            "Last passkey deleted. Next time, sign in with your password, authenticator code, backup code, or magic link until you add another passkey.",
            "decode_passkey_response",
            "passkey[response]",
            "JSON.decode",
            "Sigra.Plug.PasskeyChallenge.issue",
            "Sigra.Plug.PasskeyChallenge.verify",
            "passkey_registration_options_json",
            "passkey_authentication_options_json",
            "UserAuth.log_in_user(user, %{})",
            "UserAuth.put_user_session_token",
            "delete_session(:mfa_pending)",
            "delete_session(:mfa_return_to)",
            "delete_session(:mfa_remember_me)",
            "mfa_return_to",
            "We couldn't finish passkey sign-in. Try again or use another way to continue."
          ] do
        assert content =~ expected
      end
    end
  end

  describe "router injection passkey controller routes" do
    @features_core_path Path.join([File.cwd!(), "lib", "sigra", "install", "features", "core.ex"])
    @features_passkeys_path Path.join([
                              File.cwd!(),
                              "lib",
                              "sigra",
                              "install",
                              "features",
                              "passkeys.ex"
                            ])
    @passkeys_router_template Path.join([
                                File.cwd!(),
                                "priv",
                                "templates",
                                "sigra.install",
                                "passkeys",
                                "router_injection.ex"
                              ])

    test "keeps require_sudo in core while passkey POST routes are feature-owned" do
      core_source = File.read!(@features_core_path)
      passkeys_source = File.read!(@features_passkeys_path)
      router_template = File.read!(@passkeys_router_template)

      assert core_source =~ "pipeline :require_sudo"
      assert core_source =~ "Sigra.Plug.RequireSudo"
      assert passkeys_source =~ "defp router_injection"

      for expected <- [
            "pipe_through [:browser, :redirect_if_user_is_authenticated]",
            "pipe_through [:browser, :require_authenticated, :require_sudo]",
            "post \"/log_in/passkey\", SessionController, :complete_passkey",
            "post \"/log_in/passkey/options\", SessionController, :passkey_authentication_options",
            "post \"/settings/mfa/passkeys/options\", SessionController, :passkey_registration_options",
            "post \"/settings/mfa/passkeys\", SessionController, :complete_passkey_registration",
            "post \"/settings/mfa/passkeys/:id/delete\", SessionController, :delete_passkey",
            "post \"/mfa/passkey\", SessionController, :complete_mfa_passkey",
            "post \"/mfa/passkey/options\", SessionController, :passkey_mfa_options"
          ] do
        assert router_template =~ expected
      end
    end

    test "delete passkey route exists only in the sudo-protected scope" do
      source = File.read!(@passkeys_router_template)

      [ordinary_scopes, after_sudo_pipe] =
        String.split(source, "pipe_through [:browser, :require_authenticated, :require_sudo]",
          parts: 2
        )

      assert after_sudo_pipe =~
               "post \"/settings/mfa/passkeys/:id/delete\", SessionController, :delete_passkey"

      refute ordinary_scopes =~
               "post \"/settings/mfa/passkeys/:id/delete\", SessionController, :delete_passkey"
    end
  end

  defp read_core_template(name) do
    File.read!(Path.join(@core_template_dir, name))
  end
end
