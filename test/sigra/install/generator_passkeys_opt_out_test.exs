defmodule Sigra.Install.GeneratorPasskeysOptOutTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag timeout: 180_000

  @cases [
    %{label: "passkeys disabled", flags: ["--no-passkeys"]},
    %{
      label: "passkeys disabled with organizations disabled",
      flags: ["--no-organizations", "--no-passkeys"]
    }
  ]

  @forbidden_strings [
    "Sigra.Passkeys",
    "Sigra.Plug.PasskeyChallenge",
    "@simplewebauthn/browser",
    "{:wax_, \"~> 0.7\"}",
    "passkey_primary_enabled",
    "/users/log_in/passkey",
    "/users/mfa/passkey",
    "/users/settings/mfa/passkeys",
    "enroll_passkey",
    "Continue with passkey",
    "Use a passkey",
    "Add a passkey after creating your account"
  ]

  describe "mix sigra.install opt out" do
    for %{label: label, flags: flags} <- @cases do
      @tag flags: flags
      test "#{label} omits passkey routes, files, dependencies, and residue", %{flags: flags} do
        {:ok, %{app_dir: app_dir}} =
          InstallFixture.setup_tmp_app_without_install(app_name: unique_app_name())

        on_exit(fn -> File.rm_rf(Path.dirname(app_dir)) end)

        assert {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, flags)
        # --warnings-as-errors guards against dead code in opt-out builds, e.g. an
        # impersonation guard helper whose only caller is passkey-gated (Phase 221).
        assert {:ok, _stdout} = InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])

        refute File.exists?(Path.join(app_dir, "assets/js/passkey_hooks.js"))
        refute File.exists?(Path.join(app_dir, "assets/js/passkey_browser.js"))

        refute File.exists?(
                 Path.join(app_dir, "lib/#{otp_app(app_dir)}/accounts/user_passkey.ex")
               )

        refute migration_present?(app_dir, "*_create_user_passkeys.exs")

        router = File.read!(Path.join(app_dir, "lib/#{otp_app(app_dir)}_web/router.ex"))
        mix_exs = File.read!(Path.join(app_dir, "mix.exs"))
        config_exs = File.read!(Path.join(app_dir, "config/config.exs"))
        auth_ex = File.read!(Path.join(app_dir, "lib/#{otp_app(app_dir)}/accounts.ex"))

        session_controller =
          File.read!(
            Path.join(app_dir, "lib/#{otp_app(app_dir)}_web/controllers/session_controller.ex")
          )

        refute router =~ "/users/log_in/passkey"
        refute router =~ "/users/mfa/passkey"
        refute router =~ "/users/settings/mfa/passkeys"
        refute mix_exs =~ "{:wax_, \"~> 0.7\"}"
        refute config_exs =~ "passkeys:"
        refute config_exs =~ "passkey_primary_enabled"
        refute auth_ex =~ "Sigra.Passkeys"
        refute auth_ex =~ "Sigra.Plug.PasskeyChallenge"
        refute session_controller =~ "passkey_primary_enabled"

        for forbidden <- @forbidden_strings do
          refute tree_contains?(app_dir, forbidden),
                 "unexpected residue #{inspect(forbidden)} in generated app"
        end
      end
    end

    test "explicitly names both disabled flag combinations in this suite" do
      source = File.read!(__ENV__.file)

      assert source =~ "--no-passkeys"
      assert source =~ "--no-organizations\", \"--no-passkeys"
      assert source =~ "passkeys disabled"
      assert source =~ "opt out"
    end
  end

  defp migration_present?(app_dir, pattern) do
    app_dir
    |> Path.join("priv/repo/migrations/#{pattern}")
    |> Path.wildcard()
    |> Enum.any?()
  end

  defp tree_contains?(app_dir, needle) do
    [
      Path.join(app_dir, "lib/**/*"),
      Path.join(app_dir, "config/**/*"),
      Path.join(app_dir, "assets/**/*"),
      Path.join(app_dir, "priv/**/*"),
      Path.join(app_dir, "mix.exs"),
      Path.join(app_dir, "package.json")
    ]
    |> Enum.flat_map(&Path.wildcard(&1, match_dot: true))
    |> Enum.filter(&File.regular?/1)
    |> Enum.any?(fn path -> File.read!(path) =~ needle end)
  end

  defp otp_app(app_dir) do
    app_dir
    |> Path.basename()
    |> Macro.underscore()
  end

  defp unique_app_name do
    "sigra_passkeys_opt_out_#{System.unique_integer([:positive])}"
  end
end
