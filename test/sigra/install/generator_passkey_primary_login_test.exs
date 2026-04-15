defmodule Sigra.Install.GeneratorPasskeyPrimaryLoginTest do
  use ExUnit.Case, async: true

  @core_template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  describe "passkey-primary controller login template" do
    test "renders identifier-first passkey login without LiveView submission" do
      content = read_core_template("login_html.ex")

      for expected <- [
            "@passkey_primary_enabled",
            ~s(autocomplete="username webauthn"),
            ~s(id="passkey_login_form"),
            ~s(id="passkey_login_button"),
            "passkey[response]",
            "/users/log_in/passkey",
            "/users/log_in/passkey/options",
            "Continue with passkey",
            "Use password instead",
            "Email me a magic link"
          ] do
        assert content =~ expected
      end

      refute content =~ "phx-submit"
      refute content =~ "choose your sign-in method"
      refute content =~ "passkey screen"
      refute content =~ "password screen"
    end
  end

  defp read_core_template(name) do
    File.read!(Path.join(@core_template_dir, name))
  end
end
