defmodule Sigra.Install.GeneratorPasskeysOptOutTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag timeout: 180_000
  @moduletag :scaffold

  @cases [
    %{label: "passkeys disabled", flags: ["--no-passkeys"], variant: :no_passkeys},
    %{
      label: "passkeys disabled with organizations disabled",
      flags: ["--no-organizations", "--no-passkeys"],
      variant: :no_org_no_passkeys
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

  setup_all do
    scenarios =
      Enum.map(@cases, fn %{label: label, variant: variant} ->
        InstallFixture.checkout!(variant, "opt-out-#{label}")
      end)

    assert {:ok, results} =
             InstallFixture.run_scenarios(scenarios, fn checkout ->
               assert {:ok, _stdout} =
                        InstallFixture.run_mix(checkout.path, [
                          "compile",
                          "--warnings-as-errors"
                        ])

               {:ok, checkout}
             end)

    checkouts = Map.new(results, fn {_scenario, checkout} -> {checkout.name, checkout} end)
    {:ok, checkouts: checkouts}
  end

  describe "mix sigra.install opt out" do
    for %{label: label, flags: flags, variant: variant} <- @cases do
      @tag flags: flags, variant: variant
      test "#{label} omits passkey routes, files, dependencies, and residue", %{
        flags: _flags,
        variant: variant,
        checkouts: checkouts
      } do
        checkout = Map.fetch!(checkouts, variant)
        app_dir = checkout.path

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
    [_, app] = Regex.run(~r/app:\s+:(\w+)/, File.read!(Path.join(app_dir, "mix.exs")))
    app
  end
end
