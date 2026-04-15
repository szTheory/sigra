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
      assert content =~ "def rename_passkey(user, credential_id, nickname)"
      assert content =~ "def delete_passkey(user, credential_id)"
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
      content = read_core_template("auth.ex")

      assert content =~ "This passkey is already registered."
      assert content =~ ":duplicate_passkey"
      assert content =~ "unique"
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

  defp read_core_template(name) do
    File.read!(Path.join(@core_template_dir, name))
  end
end
