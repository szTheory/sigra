defmodule Sigra.Install.GeneratorPasskeysOptOutTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag timeout: 180_000
  @moduletag :scaffold

  @cases [
    %{label: "passkeys disabled", flags: ["--no-passkeys"]},
    %{
      label: "passkeys disabled with organizations disabled",
      flags: ["--no-organizations", "--no-passkeys"]
    },
    %{
      label: "B2C Alpha profile omits admin, organizations, and passkeys",
      flags: ["--no-admin", "--no-organizations", "--no-passkeys"],
      b2c_alpha?: true
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
    for %{label: label, flags: flags} = install_case <- @cases do
      @tag flags: flags
      @tag b2c_alpha?: Map.get(install_case, :b2c_alpha?, false)
      test "#{label} omits passkey routes, files, dependencies, and residue", %{
        flags: flags,
        b2c_alpha?: b2c_alpha?
      } do
        {:ok, %{app_dir: app_dir}} =
          InstallFixture.setup_tmp_app_without_install(app_name: unique_app_name())

        on_exit(fn -> File.rm_rf(Path.dirname(app_dir)) end)

        assert {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, flags)

        if b2c_alpha? do
          set_dummy_cloak_key!()
          add_cloak_ecto!(app_dir)
          assert {:ok, _stdout} = InstallFixture.run_mix(app_dir, ["deps.get"])

          assert {:ok, _stdout} =
                   InstallFixture.run_mix(app_dir, ["sigra.gen.oauth", "--providers", "google"])
        end

        # --warnings-as-errors guards the complete emitted host, including OAuth
        # generation for B2C Alpha, against dead code in opt-out builds.
        assert {:ok, _stdout} =
                 InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])

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
        refute router =~ "# Sigra passkeys"
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

        if b2c_alpha? do
          application = File.read!(Path.join(app_dir, "lib/#{otp_app(app_dir)}/application.ex"))

          assert File.exists?(
                   Path.join(app_dir, "lib/#{otp_app(app_dir)}/accounts/user_identity.ex")
                 )

          assert File.exists?(Path.join(app_dir, "lib/#{otp_app(app_dir)}/vault.ex"))
          assert File.exists?(Path.join(app_dir, "lib/#{otp_app(app_dir)}/encrypted/binary.ex"))

          assert File.exists?(
                   Path.join(
                     app_dir,
                     "lib/#{otp_app(app_dir)}_web/controllers/oauth_controller.ex"
                   )
                 )

          assert File.exists?(
                   Path.join(app_dir, "lib/#{otp_app(app_dir)}_web/controllers/oauth_html.ex")
                 )

          assert File.exists?(
                   Path.join(
                     app_dir,
                     "lib/#{otp_app(app_dir)}_web/controllers/oauth_buttons.html.heex"
                   )
                 )

          assert migration_present?(app_dir, "*_create_user_identities.exs")
          assert router =~ "get \"/log_in\", SessionController, :new"
          assert router =~ "post \"/log_in\", SessionController, :create"
          assert router =~ "get \"/log_in/:token\", SessionController, :magic_link"
          assert session_controller =~ "Auth.authenticate_user"
          assert session_controller =~ "def create(conn, %{\"_action\" => \"magic_link\""
          assert session_controller =~ "Auth.request_magic_link"
          assert session_controller =~ "def magic_link(conn, %{\"token\" => token})"
          assert session_controller =~ "Auth.verify_magic_link"
          assert router =~ "# Sigra OAuth"
          assert router =~ "get \"/:provider\", OAuthController, :request"
          assert router =~ "get \"/:provider/callback\", OAuthController, :callback"
          assert config_exs =~ "# Sigra OAuth providers"
          assert config_exs =~ "GOOGLE_CLIENT_ID"
          assert config_exs =~ "GOOGLE_CLIENT_SECRET"
          assert application =~ "Vault"

          refute router =~ "# Sigra admin"
          refute router =~ "/admin"
          refute router =~ "# Sigra organizations"
          refute router =~ "/organizations"

          refute File.exists?(
                   Path.join(app_dir, "lib/#{otp_app(app_dir)}_web/components/admin_shell.ex")
                 )

          refute File.exists?(
                   Path.join(app_dir, "lib/#{otp_app(app_dir)}/accounts/organization.ex")
                 )

          refute File.exists?(Path.join(app_dir, "lib/#{otp_app(app_dir)}/organizations.ex"))
          refute File.exists?(Path.join(app_dir, "lib/#{otp_app(app_dir)}/sigra_admin_access.ex"))
          refute File.exists?(Path.join(app_dir, "priv/static/assets/sigra_admin.css"))
          refute File.exists?(Path.join(app_dir, "priv/static/images/sigra-logo-primary.svg"))
          refute migration_present?(app_dir, "*_create_platform_admin_grants.exs")
          refute migration_present?(app_dir, "*_create_organizations.exs")
        end
      end
    end

    test "explicitly names both disabled flag combinations in this suite" do
      source = File.read!(__ENV__.file)

      assert source =~ "--no-passkeys"
      assert source =~ "--no-organizations\", \"--no-passkeys"
      assert source =~ "--no-admin\", \"--no-organizations\", \"--no-passkeys"
      assert source =~ "passkeys disabled"
      assert source =~ "opt out"
    end

    test "fresh-host smoke locks the B2C Alpha retained-core and Google OAuth contract" do
      source = File.read!("scripts/ci/passkeys-opt-out-smoke.sh")

      assert source =~ "--no-admin --no-organizations --no-passkeys"
      assert source =~ "add_cloak_ecto"
      assert source =~ "{:cloak_ecto, \"~> 1.3\"}"
      assert source =~ "mix sigra.gen.oauth --providers google"
      assert source =~ "sigra_b2c_alpha"
      assert source =~ "get \"/log_in\", SessionController, :new"
      assert source =~ "post \"/log_in\", SessionController, :create"
      assert source =~ "get \"/log_in/:token\", SessionController, :magic_link"
      assert source =~ "Auth.authenticate_user"
      assert source =~ "def create\\(conn, %\\{\\\"_action\\\" => \\\"magic_link\\\""
      assert source =~ "Auth.request_magic_link"
      assert source =~ "def magic_link\\(conn, %\\{\\\"token\\\" => token\\}\\)"
      assert source =~ "Auth.verify_magic_link"
      assert source =~ "find_matches"
      assert source =~ "grep -En --"
      assert source =~ "oauth_controller.ex"
      assert source =~ "oauth_html.ex"
      assert source =~ "oauth_buttons.html.heex"
      assert source =~ "create_user_identities.exs"
      assert source =~ "# Sigra OAuth providers"
      assert source =~ "GOOGLE_CLIENT_ID"
      assert source =~ "GOOGLE_CLIENT_SECRET"

      assert source =~
               "assert_glob_missing \"priv/repo/migrations/*_create_platform_admin_grants.exs\""

      assert source =~ "assert_glob_missing \"priv/repo/migrations/*_create_organizations.exs\""
      assert source =~ "assert_glob_missing \"priv/repo/migrations/*_create_user_passkeys.exs\""
      assert source =~ "# Sigra admin"
      assert source =~ "# Sigra organizations"
      assert source =~ "# Sigra passkeys"
      assert source =~ "assert_no_match '/admin'"
      assert source =~ "assert_no_match '/organizations'"
      assert source =~ "mix compile --warnings-as-errors"
      assert source =~ "mix assets.deploy"
      assert source =~ "mix ecto.migrate"
      assert source =~ "curl -sf"
    end
  end

  defp migration_present?(app_dir, pattern) do
    app_dir
    |> Path.join("priv/repo/migrations/#{pattern}")
    |> Path.wildcard()
    |> Enum.any?()
  end

  defp set_dummy_cloak_key! do
    prior = System.get_env("CLOAK_KEY")
    System.put_env("CLOAK_KEY", "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=")

    on_exit(fn ->
      if prior do
        System.put_env("CLOAK_KEY", prior)
      else
        System.delete_env("CLOAK_KEY")
      end
    end)
  end

  defp add_cloak_ecto!(app_dir) do
    mix_exs = Path.join(app_dir, "mix.exs")
    content = File.read!(mix_exs)

    unless content =~ "{:cloak_ecto," do
      patched =
        Regex.replace(
          ~r/(      \{:sigra, path: .+\},\n)/,
          content,
          "\\1      {:cloak_ecto, \"~> 1.3\"},\n",
          global: false
        )

      if patched == content do
        raise "Failed to add cloak_ecto to #{mix_exs} — Sigra path dependency anchor not found"
      end

      File.write!(mix_exs, patched)
    end
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
