defmodule Sigra.Install.Features.PasskeysTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Passkeys

  describe "enabled?/1" do
    test "returns true by default" do
      assert Passkeys.enabled?([])
      assert Passkeys.enabled?([]) == true
    end

    test "supports explicit default-on and opt-out flags" do
      assert Passkeys.enabled?(passkeys: true)
      refute Passkeys.enabled?(passkeys: false)
    end
  end

  describe "files/1" do
    test "emits the user_passkey schema plus passkey browser assets" do
      assert [
               {:eex, "passkeys/user_passkey.ex", "lib/my_app/accounts/user_passkey.ex"},
               {:eex, "passkeys/passkey_browser.js", "assets/js/passkey_browser.js"},
               {:eex, "passkeys/passkey_hooks.js", "assets/js/passkey_hooks.js"},
               {:eex, "passkeys/package.json", "assets/package.json"}
             ] = Passkeys.files(otp_app: :my_app, context_alias: "Accounts")
    end
  end

  describe "migrations/1" do
    test "owns the user_passkeys migration slot" do
      assert [
               {:user_passkeys, "passkeys/create_user_passkeys.exs", "create_user_passkeys.exs"}
             ] = Passkeys.migrations([])
    end
  end

  test "owns passkey-only router, config, dependency, and app.js injections" do
    injections =
      Passkeys.injections(
        otp_app: :my_app,
        web_module: "MyAppWeb",
        app_name: "My App",
        context_module: "MyApp.Accounts"
      )

    assert Enum.any?(injections, fn injection ->
             injection.target == "lib/my_app_web/router.ex" and
               injection.marker == "# Sigra passkeys" and
               injection.content =~ ~s(post "/log_in/passkey")
           end)

    assert Enum.any?(injections, fn injection ->
             injection.target == "config/config.exs" and
               injection.marker == "# Sigra passkeys" and
               injection.content =~ "user_passkey_schema: MyApp.Accounts.UserPasskey"
           end)

    assert Enum.any?(injections, fn injection ->
             injection.target == "mix.exs" and
               injection.marker == ~s({:wax_, "~> 0.7"}) and
               injection.anchor == :mix_deps
           end)

    assert Enum.any?(injections, fn injection ->
             injection.target == "mix.exs" and
               injection.marker == ~s(cmd --cd assets npm install) and
               injection.anchor == :mix_assets_setup
           end)

    assert Enum.any?(injections, fn injection ->
             injection.target == "assets/package.json" and
               injection.marker == ~s("@simplewebauthn/browser") and
               injection.anchor == :package_json_dependencies
           end)

    assert Enum.any?(injections, fn injection ->
             injection.target == "assets/js/app.js" and
               injection.marker == "// Sigra passkeys:start" and
               injection.anchor == :app_js_passkeys and
               injection.content =~ ~s(import { PasskeyHooks } from "./passkey_hooks")
           end)
  end

  test "echoes manual fallback instructions for app.js, mix.exs, assets.setup, and assets/package.json" do
    instructions =
      %Sigra.Install.Report{}
      |> Sigra.Install.Report.record_manual_action("""
      Passkeys generated `assets/js/passkey_hooks.js`, but Sigra could not safely edit `assets/js/app.js`.

      Add these lines manually to your LiveSocket setup:

        import { PasskeyHooks } from "./passkey_hooks"
        hooks: { ...colocatedHooks, ...PasskeyHooks }
      """)
      |> Sigra.Install.Report.record_manual_action("""
      Passkeys generated passkey routes and browser assets, but Sigra could not safely edit `mix.exs`.

      Add this dependency to your `deps/0` list manually:

        {:wax_, "~> 0.7"}
      """)
      |> Sigra.Install.Report.record_manual_action("""
      Passkeys generated browser assets, but Sigra could not safely edit `mix.exs` `assets.setup`.

      Add this step to your `"assets.setup"` alias manually:

        "cmd --cd assets npm install"
      """)
      |> Sigra.Install.Report.record_manual_action("""
      Passkeys generated passkey routes and browser assets, but Sigra could not safely edit `assets/package.json`.

      Add this dependency under `"dependencies"` manually:

        "@simplewebauthn/browser": "^13.0.0"
      """)
      |> then(&Passkeys.post_instructions([], &1))

    assert Enum.any?(
             instructions,
             &String.contains?(&1, ~s(import { PasskeyHooks } from "./passkey_hooks"))
           )

    assert Enum.any?(instructions, &String.contains?(&1, ~s({:wax_, "~> 0.7"})))
    assert Enum.any?(instructions, &String.contains?(&1, ~s(cmd --cd assets npm install)))

    assert Enum.any?(
             instructions,
             &String.contains?(&1, ~s("@simplewebauthn/browser": "^13.0.0"))
           )
  end

  test "keeps passkey-only artifacts and manual action reporting inside the feature manifest boundary" do
    file_sources =
      Passkeys.files(otp_app: :my_app, context_alias: "Accounts")
      |> Enum.map(fn {:eex, source, _target} -> source end)

    assert "passkeys/user_passkey.ex" in file_sources
    assert "passkeys/passkey_browser.js" in file_sources
    assert "passkeys/passkey_hooks.js" in file_sources
    assert "passkeys/package.json" in file_sources

    assert [{:user_passkeys, "passkeys/create_user_passkeys.exs", "create_user_passkeys.exs"}] =
             Passkeys.migrations([])

    injection_targets =
      Passkeys.injections(
        otp_app: :my_app,
        web_module: "MyAppWeb",
        app_name: "My App",
        context_module: "MyApp.Accounts"
      )
      |> Enum.map(& &1.target)

    assert "lib/my_app_web/router.ex" in injection_targets
    assert "config/config.exs" in injection_targets
    assert "mix.exs" in injection_targets
    assert "assets/package.json" in injection_targets
    assert "assets/js/app.js" in injection_targets
  end
end
