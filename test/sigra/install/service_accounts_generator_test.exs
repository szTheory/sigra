defmodule Sigra.Install.ServiceAccountsGeneratorTest do
  @moduledoc """
  Phase 93 D-93-18 emission gating proof.

  The generator's gating for service-account artifacts is asymmetric but
  consistently requires both `--jwt` AND `--organizations`:

    * Organizations-feature artifacts (SA schemas, SA migration, SA LiveView,
      SA router-injection) require BOTH `--jwt` AND `--organizations`.
      The feature module is `:organizations`-gated; within it, SA files are
      `:jwt`-gated. See `lib/sigra/install/features/organizations.ex:147,192`.

    * Core-feature `oauth_token_controller.ex` (and its `POST /oauth/token`
      router injection) is also gated on BOTH `:jwt` AND `:organizations`,
      despite living in the Core feature module. Within `jwt_files/2`
      (core.ex:362-383), the function checks `organizations?` before adding the
      controller; the route injection in `injections/1` (core.ex:734-752) also
      checks `organizations?`.

  NOTE — deviation from 93-08-PLAN.md:

    1. The plan stated the OAuth controller was `:jwt`-only gated (Core feature).
       The actual generator at `lib/sigra/install/features/core.ex:375,735`
       adds an `organizations?` guard in BOTH the file list AND the route
       injection. This test reflects the **actual** generator behaviour.

    2. The plan stated "default install (no extra flags)" emits SA artifacts.
       The actual default in `sigra.install.ex:62` is `jwt: false`. JWT must
       be explicitly enabled via `--jwt`. This test passes `["--jwt"]` to
       exercise the nominal SA-enabled install path. The SUMMARY documents
       both divergences.

  Three variants are exercised via real `mix sigra.install` invocations through
  `Sigra.Test.InstallFixture` (the same harness used by `test/upgrade_test.exs`
  for non-default install flags):

    1. `--jwt` (organizations default-on) -> SA artifacts emitted; OAuth controller emitted
    2. `--jwt --no-organizations`          -> ALL SA artifacts suppressed;
                                             OAuth controller ALSO suppressed
                                             (organizations? guard in both
                                             core.ex:375 file list and core.ex:735
                                             route injection)
    3. no flags / `--no-jwt`               -> ALL SA artifacts AND OAuth controller
                                             suppressed (jwt defaults to false)

  This file is a SIBLING to `test/sigra/install/golden_diff_test.exs` rather
  than an extension, because (a) the golden test compares ONE canonical tree
  byte-for-byte, and (b) bolting per-flag variants into it would conflate
  regression detection with feature gating.

  All three variants are tagged `:integration` and may be skipped locally for
  fast feedback loops (`mix test --exclude integration`).
  """

  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag :integration
  @moduletag :slow
  @moduletag :generator_gating
  @moduletag timeout: 600_000

  # Derive the app module prefix from the app directory name. InstallFixture
  # always sets the app name from the app_name: opt; app_dir is
  # /tmp/sigra_golden_<n>/<app_name>, so the basename IS the module prefix.
  defp derive_app_module(app_dir) do
    app_dir
    |> Path.basename()
    |> String.replace("-", "_")
  end

  defp unique_app_name(prefix),
    do: "sa_gen_#{prefix}_#{:erlang.unique_integer([:positive])}"

  describe "service-account emission gating (D-93-18)" do
    test "--jwt install (organizations default-on) emits all SA artifacts and routes" do
      {:ok, %{app_dir: app_dir}} =
        InstallFixture.setup_tmp_app_without_install(app_name: unique_app_name("jwt_on"))

      on_exit(fn -> File.rm_rf!(Path.dirname(app_dir)) end)

      {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, ["--jwt"])

      app_module = derive_app_module(app_dir)

      # SA schemas exist:
      assert File.regular?(Path.join(app_dir, "lib/#{app_module}/accounts/service_account.ex")),
             "Expected lib/#{app_module}/accounts/service_account.ex to exist after --jwt install"

      assert File.regular?(
               Path.join(app_dir, "lib/#{app_module}/accounts/service_account_credential.ex")
             ),
             "Expected lib/#{app_module}/accounts/service_account_credential.ex to exist"

      # SA migration exists (timestamp-prefixed):
      migrations =
        Path.join(app_dir, "priv/repo/migrations")
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, "_create_service_accounts.exs"))

      assert length(migrations) == 1,
             "Expected exactly one *_create_service_accounts.exs migration, got: #{inspect(migrations)}"

      # SA LiveView exists:
      assert File.regular?(
               Path.join(
                 app_dir,
                 "lib/#{app_module}_web/live/organization_service_accounts_live.ex"
               )
             ),
             "Expected organization_service_accounts_live.ex to exist"

      # OAuth token controller exists:
      assert File.regular?(
               Path.join(app_dir, "lib/#{app_module}_web/controllers/oauth_token_controller.ex")
             ),
             "Expected oauth_token_controller.ex to exist"

      # Router contains the SA route AND /oauth/token route:
      router_src = File.read!(Path.join(app_dir, "lib/#{app_module}_web/router.ex"))

      assert router_src =~ "OrganizationServiceAccountsLive",
             "Expected router to reference OrganizationServiceAccountsLive"

      assert router_src =~ ~r/live\s+"\/service-accounts"/,
             "Expected /service-accounts LiveView route in router"

      assert router_src =~ "OAuthTokenController",
             "Expected router to reference OAuthTokenController"

      assert router_src =~ ~r/post\s+"\/oauth\/token"/,
             "Expected POST /oauth/token route in router"
    end

    test "--jwt --no-organizations install suppresses ALL SA artifacts including OAuth controller (both organizations? guards in core.ex fire)" do
      {:ok, %{app_dir: app_dir}} =
        InstallFixture.setup_tmp_app_without_install(app_name: unique_app_name("jwt_noorg"))

      on_exit(fn -> File.rm_rf!(Path.dirname(app_dir)) end)

      {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, ["--jwt", "--no-organizations"])

      app_module = derive_app_module(app_dir)

      # Organizations-owned SA schema files MUST NOT exist:
      refute File.exists?(Path.join(app_dir, "lib/#{app_module}/accounts/service_account.ex")),
             "service_account.ex must be absent under --jwt --no-organizations"

      refute File.exists?(
               Path.join(app_dir, "lib/#{app_module}/accounts/service_account_credential.ex")
             ),
             "service_account_credential.ex must be absent under --jwt --no-organizations"

      # SA migration MUST NOT exist:
      migrations_dir = Path.join(app_dir, "priv/repo/migrations")

      if File.dir?(migrations_dir) do
        sa_migrations =
          migrations_dir
          |> File.ls!()
          |> Enum.filter(&String.ends_with?(&1, "_create_service_accounts.exs"))

        assert sa_migrations == [],
               "Expected NO *_create_service_accounts.exs migration under --jwt --no-organizations, got: #{inspect(sa_migrations)}"
      end

      # SA LiveView MUST NOT exist:
      refute File.exists?(
               Path.join(
                 app_dir,
                 "lib/#{app_module}_web/live/organization_service_accounts_live.ex"
               )
             ),
             "organization_service_accounts_live.ex must be absent under --jwt --no-organizations"

      # Core-feature oauth_token_controller.ex MUST also be absent.
      # DEVIATION FROM PLAN: The plan stated this file is `:jwt`-only gated
      # (Core feature, core.ex:362), but the actual code at core.ex:375 checks
      # `organizations?` within `jwt_files/2`, AND core.ex:735 checks
      # `organizations?` in the route injection. Under `--no-organizations` with
      # `:jwt` still on, both the file AND the route injection are suppressed.
      refute File.exists?(
               Path.join(app_dir, "lib/#{app_module}_web/controllers/oauth_token_controller.ex")
             ),
             "oauth_token_controller.ex must be ABSENT under --jwt --no-organizations (core.ex:375 + core.ex:735 organizations? guards)"

      # Router MUST NOT contain Organizations SA route OR OAuth route:
      router_path = Path.join(app_dir, "lib/#{app_module}_web/router.ex")

      if File.regular?(router_path) do
        router_src = File.read!(router_path)

        refute router_src =~ "OrganizationServiceAccountsLive",
               "Router under --jwt --no-organizations must not reference OrganizationServiceAccountsLive"

        refute router_src =~ ~r/live\s+"\/service-accounts"/,
               "Router under --jwt --no-organizations must not declare /service-accounts route"

        refute router_src =~ "OAuthTokenController",
               "Router under --jwt --no-organizations must not reference OAuthTokenController (core.ex:735 organizations? guard)"

        refute router_src =~ ~r/post\s+"\/oauth\/token"/,
               "Router under --jwt --no-organizations must not declare POST /oauth/token route"
      end
    end

    test "--no-jwt (default) install suppresses ALL SA artifacts AND the /oauth/token route" do
      {:ok, %{app_dir: app_dir}} =
        InstallFixture.setup_tmp_app_without_install(app_name: unique_app_name("no_jwt"))

      on_exit(fn -> File.rm_rf!(Path.dirname(app_dir)) end)

      # jwt defaults to false in sigra.install.ex:62; passing no jwt flag (or
      # --no-jwt explicitly) exercises the same code path.
      {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, ["--no-jwt"])

      app_module = derive_app_module(app_dir)

      # SA schema files MUST NOT exist:
      refute File.exists?(Path.join(app_dir, "lib/#{app_module}/accounts/service_account.ex")),
             "service_account.ex must be absent under --no-jwt"

      refute File.exists?(
               Path.join(app_dir, "lib/#{app_module}/accounts/service_account_credential.ex")
             ),
             "service_account_credential.ex must be absent under --no-jwt"

      # SA LiveView MUST NOT exist:
      refute File.exists?(
               Path.join(
                 app_dir,
                 "lib/#{app_module}_web/live/organization_service_accounts_live.ex"
               )
             ),
             "organization_service_accounts_live.ex must be absent under --no-jwt"

      # SA migration MUST NOT exist:
      migrations_dir = Path.join(app_dir, "priv/repo/migrations")

      if File.dir?(migrations_dir) do
        sa_migrations =
          migrations_dir
          |> File.ls!()
          |> Enum.filter(&String.ends_with?(&1, "_create_service_accounts.exs"))

        assert sa_migrations == [],
               "Expected NO *_create_service_accounts.exs migration under --no-jwt"
      end

      # /oauth/token controller AND route MUST be absent under --no-jwt
      # (per lib/sigra/install/features/core.ex:362 `defp jwt_files(_, false), do: []`):
      refute File.exists?(
               Path.join(app_dir, "lib/#{app_module}_web/controllers/oauth_token_controller.ex")
             ),
             "oauth_token_controller.ex must be absent under --no-jwt (core.ex:362 jwt_files guard)"

      # Router assertions:
      router_path = Path.join(app_dir, "lib/#{app_module}_web/router.ex")

      if File.regular?(router_path) do
        router_src = File.read!(router_path)

        refute router_src =~ "OrganizationServiceAccountsLive",
               "Router under --no-jwt must not reference OrganizationServiceAccountsLive"

        refute router_src =~ ~r/live\s+"\/service-accounts"/,
               "Router under --no-jwt must not declare /service-accounts route"

        refute router_src =~ ~r/post\s+"\/oauth\/token"/,
               "Router under --no-jwt must not declare /oauth/token POST route"

        refute router_src =~ "OAuthTokenController",
               "Router under --no-jwt must not reference OAuthTokenController"
      end
    end
  end
end
