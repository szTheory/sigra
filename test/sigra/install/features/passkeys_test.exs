defmodule Sigra.Install.Features.PasskeysTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Passkeys

  describe "enabled?/1" do
    test "is opt-in" do
      refute Passkeys.enabled?([])
      assert Passkeys.enabled?(passkeys: true)
      refute Passkeys.enabled?(passkeys: false)
    end
  end

  describe "files/1" do
    test "emits the user_passkey schema and passkey_hooks.js asset" do
      assert [
               {:eex, "passkeys/user_passkey.ex", "lib/my_app/accounts/user_passkey.ex"},
               {:eex, "passkeys/passkey_hooks.js", "assets/js/passkey_hooks.js"}
             ] = Passkeys.files(otp_app: :my_app, context_alias: "Accounts")
    end
  end

  describe "migrations/1" do
    test "owns the user_passkeys migration slot" do
      assert [
               {:user_passkeys, "passkeys/create_user_passkeys.exs",
                "create_user_passkeys.exs"}
             ] = Passkeys.migrations([])
    end
  end

  test "owns app.js passkey injection and echoes manual fallback instructions from the report" do
    [injection] = Passkeys.injections([])

    assert injection.target == "assets/js/app.js"
    assert injection.marker == "// Sigra passkeys:start"
    assert injection.anchor == :app_js_passkeys
    assert injection.content =~ ~s(import { PasskeyHooks } from "./passkey_hooks")

    report =
      %Sigra.Install.Report{}
      |> Sigra.Install.Report.record_manual_action("""
      Passkeys generated `assets/js/passkey_hooks.js`, but Sigra could not safely edit `assets/js/app.js`.

      Add these lines manually to your LiveSocket setup:

        import { PasskeyHooks } from "./passkey_hooks"
        hooks: { ...colocatedHooks, ...PasskeyHooks }
      """)

    assert [
             instructions
           ] = Passkeys.post_instructions([], report)

    assert instructions =~ ~s(import { PasskeyHooks } from "./passkey_hooks")
    assert instructions =~ ~s(hooks: { ...colocatedHooks, ...PasskeyHooks })
  end
end
