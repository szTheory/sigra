defmodule Sigra.Install.Features.CoreTest do
  @moduledoc """
  Unit tests for `Sigra.Install.Features.Core` — the behaviour implementation
  that owns every v1.0 installer concern after Phase 11 Wave 3.

  These tests prove the pure-data contract of Features.Core's callbacks; the
  Wave 4 walker refactor will plumb these return values through the live
  `mix sigra.install` flow. The monolith `lib/mix/tasks/sigra.install.ex`
  is intentionally UNTOUCHED in Wave 3, so the golden-diff test continues
  to cover byte-identity of the end-to-end install output.
  """
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Core

  # Binding shape Features.Core expects. Mirrors the shape
  # `lib/mix/tasks/sigra.install.ex:generate/4` builds today (atoms for
  # otp_app, string inspect forms for module names) plus a Core-specific
  # `:opts` sub-keyword for option gating.
  @binding [
    otp_app: :my_app,
    context_alias: "Accounts",
    context_module: "MyApp.Accounts",
    schema_module: "MyApp.Accounts.User",
    schema_alias: "User",
    table_name: "users",
    web_module: "MyAppWeb",
    app_module: "MyApp",
    app_name: "MyApp",
    from_email: "noreply@example.com",
    log_in_url: "/users/log_in",
    reset_password_url: "http://localhost:4000/users/reset-password",
    settings_url: "http://localhost:4000/users/settings",
    repo_module: "MyApp.Repo",
    binary_id: true,
    live: true,
    api: false,
    jwt: false,
    adapter: :postgres,
    opts: [live: true, api: false, jwt: false, binary_id: true]
  ]

  describe "behaviour contract" do
    test "implements all 5 Feature callbacks with correct arities" do
      Code.ensure_loaded!(Core)
      assert function_exported?(Core, :enabled?, 1)
      assert function_exported?(Core, :files, 1)
      assert function_exported?(Core, :injections, 1)
      assert function_exported?(Core, :migrations, 1)
      assert function_exported?(Core, :post_instructions, 2)
    end

    test "declares @behaviour Sigra.Install.Feature" do
      behaviours =
        Core.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()

      assert Sigra.Install.Feature in behaviours
    end
  end

  describe "enabled?/1" do
    test "always returns true — Core is mandatory (Phase 11 SC #4)" do
      assert Core.enabled?([]) == true
      assert Core.enabled?(live: false, api: true, jwt: true) == true
      assert Core.enabled?(anything: :whatever) == true
    end
  end

  describe "migrations/1" do
    test "returns exactly 4 slot entries in canonical order" do
      # Phase 24.1: :audit_events_org_columns moved to the Organizations
      # feature so its hard FK to the organizations table lands AFTER
      # that table is created, and is omitted entirely under
      # --no-organizations.
      slots = Core.migrations(@binding)
      assert length(slots) == 4

      assert [
               {:primary, "core/migration.exs", _primary_basename},
               {:active_org_column, "core/add_active_organization_id_to_user_sessions.exs",
                _active_org_basename},
               {:api_token, "core/api_token_migration.exs", _api_basename},
               {:audit_events, "core/create_audit_events.exs", _audit_basename}
             ] = slots
    end

    test "basenames match today's monolith targets (byte-identity contract)" do
      slots = Core.migrations(@binding)

      assert Enum.any?(slots, fn {:primary, _, base} ->
               String.contains?(base, "create_sigra_auth_tables") and
                 String.ends_with?(base, ".exs")
             end)

      assert Enum.any?(slots, fn
               {:active_org_column, _, base} ->
                 String.contains?(base, "add_active_organization_id_to_user_sessions") and
                   String.ends_with?(base, ".exs")

               _ ->
                 false
             end)

      assert Enum.any?(slots, fn
               {:api_token, _, base} ->
                 String.contains?(base, "create_user_api_tokens") and
                   String.ends_with?(base, ".exs")

               _ ->
                 false
             end)

      assert Enum.any?(slots, fn
               {:audit_events, _, base} ->
                 String.contains?(base, "create_audit_events") and
                   String.ends_with?(base, ".exs")

               _ ->
                 false
             end)
    end
  end

  describe "files/1" do
    test "default binding (live=true, api=false, jwt=false) returns base+live UI" do
      tuples = Core.files(@binding)
      sources = Enum.map(tuples, fn {:eex, src, _} -> src end)

      # Every source is under core/
      assert Enum.all?(sources, &String.starts_with?(&1, "core/"))

      # Base files are present
      assert "core/user.ex" in sources
      assert "core/user_token.ex" in sources
      assert "core/scope.ex" in sources
      assert "core/auth.ex" in sources
      assert "core/user_auth.ex" in sources
      assert "core/error_handler.ex" in sources
      assert "core/session_controller.ex" in sources
      assert "core/auth_fixtures.ex" in sources
      assert "core/conn_case_helpers.ex" in sources
      assert "core/emails.ex" in sources
      assert "core/auth_mailer.ex" in sources
      assert "core/confirmation_controller.ex" in sources
      assert "core/confirmation_html.ex" in sources
      assert "core/reset_password_controller.ex" in sources
      assert "core/reset_password_html.ex" in sources
      assert "core/user_session.ex" in sources
      assert "core/sudo_controller.ex" in sources
      assert "core/sudo_html.ex" in sources
      assert "core/user_mfa_credential.ex" in sources
      assert "core/user_backup_code.ex" in sources
      assert "core/mfa_challenge_controller.ex" in sources
      assert "core/mfa_challenge_html.ex" in sources
      assert "core/audit_event.ex" in sources
      assert "core/vault.ex" in sources
      assert "core/encrypted_binary.ex" in sources
      assert "core/mailer.ex" in sources

      # login_html is ALWAYS generated (Phase 10.1.1 B9/D-12)
      assert "core/login_html.ex" in sources

      # Default --live: LiveView UI templates present
      assert "core/session_live.ex" in sources
      assert "core/registration_live.ex" in sources
      assert "core/confirmation_live.ex" in sources
      assert "core/reset_password_live.ex" in sources
      assert "core/mfa_challenge_live.ex" in sources
      assert "core/mfa_settings_live.ex" in sources
      assert "core/settings_live.ex" in sources
      assert "core/reactivation_live.ex" in sources

      # Default: excludes --api group
      refute "core/api_token_controller.ex" in sources
      refute "core/user_api_token.ex" in sources

      # Default: excludes --jwt group
      refute "core/token_controller.ex" in sources

      # Default: excludes --no-live controller-mode templates
      refute "core/registration_html.ex" in sources
      refute "core/mfa_settings_html.ex" in sources

      # Phase 11 Wave 4: migration templates are inlined into files/1 at
      # fixed monolith positions so the walker's create_file loop emits
      # them in byte-identical order to the v1.0 monolith. The slot
      # metadata remains in migrations/1 for the MigrationTimestamps
      # allocator.
      assert "core/migration.exs" in sources
      assert "core/add_active_organization_id_to_user_sessions.exs" in sources
      assert "core/create_audit_events.exs" in sources
      # api_token migration is only included with --api/--jwt
      refute "core/api_token_migration.exs" in sources
    end

    test "default (live=true, api=false, jwt=false) returns exactly 38 files" do
      # 28 base_files + 9 ui_files (live-mode) + 3 inlined migrations
      # (primary + active_org_column + audit_events); api_token migration
      # is --api-only; audit_events_org_columns moved to the Organizations
      # feature in Phase 24.1 (was previously in Core's files/1).
      assert length(Core.files(@binding)) == 38
    end

    test "--no-live excludes LiveView UI templates and includes controller-mode UI" do
      binding = Keyword.put(@binding, :opts, live: false, api: false, jwt: false)
      sources = binding |> Core.files() |> Enum.map(fn {:eex, src, _} -> src end)

      # Live UI templates absent
      refute "core/session_live.ex" in sources
      refute "core/registration_live.ex" in sources
      refute "core/mfa_settings_live.ex" in sources
      refute "core/settings_live.ex" in sources
      refute "core/reactivation_live.ex" in sources

      # Controller-mode UI templates present
      assert "core/login_html.ex" in sources
      assert "core/registration_html.ex" in sources
      assert "core/mfa_settings_html.ex" in sources
    end

    test "--no-live returns exactly 32 files" do
      binding = Keyword.put(@binding, :opts, live: false, api: false, jwt: false)
      assert length(Core.files(binding)) == 32
    end

    test "falls back to the plaintext stub when encryption-requiring features are disabled" do
      binding =
        Keyword.put(@binding, :opts, live: true, api: false, jwt: false, mfa: false, oauth: false)

      sources = binding |> Core.files() |> Enum.map(fn {:eex, src, _} -> src end)

      assert "core/encrypted.ex" in sources
      refute "core/vault.ex" in sources
      refute "core/encrypted_binary.ex" in sources
    end

    test "--api includes api_files group" do
      binding = Keyword.put(@binding, :opts, live: true, api: true, jwt: false)
      sources = binding |> Core.files() |> Enum.map(fn {:eex, src, _} -> src end)

      assert "core/api_token_controller.ex" in sources
      assert "core/user_api_token.ex" in sources

      # --api alone does NOT include jwt group
      refute "core/token_controller.ex" in sources
    end

    test "--jwt implies --api and includes jwt token controller" do
      binding = Keyword.put(@binding, :opts, live: true, api: false, jwt: true)
      sources = binding |> Core.files() |> Enum.map(fn {:eex, src, _} -> src end)

      # The monolith treats --jwt as implying --api
      assert "core/api_token_controller.ex" in sources
      assert "core/user_api_token.ex" in sources
      assert "core/token_controller.ex" in sources
    end

    test "file targets are binding-interpolated project-relative paths" do
      tuples = Core.files(@binding)

      # Every target is project-relative (no leading /)
      Enum.each(tuples, fn {:eex, _src, target} ->
        refute String.starts_with?(target, "/"),
               "target #{target} must be project-relative"
      end)

      targets = Enum.map(tuples, fn {:eex, _, t} -> t end)

      # Spot-check a few canonical targets to lock in the monolith's shape
      assert "lib/my_app/accounts/user.ex" in targets
      assert "lib/my_app/accounts/user_token.ex" in targets
      assert "lib/my_app/accounts.ex" in targets
      assert "lib/my_app_web/user_auth.ex" in targets
      assert "lib/my_app_web/auth_error_handler.ex" in targets
      assert "lib/my_app_web/controllers/session_controller.ex" in targets
      assert "lib/my_app_web/controllers/auth/sudo_controller.ex" in targets
      assert "lib/my_app_web/controllers/session_html.ex" in targets
      assert "lib/my_app_web/live/auth/session_live.ex" in targets
      assert "test/support/fixtures/auth_fixtures.ex" in targets
      assert "test/support/conn_case_helpers.ex" in targets
      assert "lib/my_app/mailer.ex" in targets
    end

    test "file list has no duplicate source-target pairs" do
      tuples = Core.files(Keyword.put(@binding, :opts, live: true, api: true, jwt: true))

      assert length(tuples) == length(Enum.uniq(tuples)),
             "duplicate file entries: #{inspect(tuples -- Enum.uniq(tuples))}"
    end
  end

  describe "isolation invariant (Pitfall X-1)" do
    test "Core module code contains no references to Organizations/Passkeys/Admin" do
      # Strip the @moduledoc string so the isolation-boundary prose
      # (which *describes* the isolation against Organizations/Passkeys)
      # doesn't false-positive against its own documentation.
      source = File.read!("lib/sigra/install/features/core.ex")

      code =
        Regex.replace(~r/@moduledoc\s+"""[\s\S]*?"""\s*\n/m, source, "", global: false)

      refute code =~ "Features.Organizations"
      refute code =~ "Features.Passkeys"
      refute code =~ "Features.Admin"
      refute code =~ ~r/\bOrganization\b/
      refute code =~ ~r/\bPasskey\b/
      refute code =~ ~r/\bAdmin\b/
    end
  end

  describe "template coverage" do
    test "every rendered template across all option combinations exists on disk" do
      binding = Keyword.put(@binding, :opts, live: true, api: true, jwt: true)

      live_binding = binding
      nolive_binding = Keyword.put(binding, :opts, live: false, api: true, jwt: true)

      file_sources =
        (Core.files(live_binding) ++ Core.files(nolive_binding))
        |> Enum.map(fn {:eex, src, _} -> src end)
        |> Enum.uniq()

      migration_sources =
        binding |> Core.migrations() |> Enum.map(fn {_slot, src, _} -> src end)

      all_sources = Enum.sort(file_sources ++ migration_sources)

      # Every referenced template file must exist on disk under priv/templates
      Enum.each(all_sources, fn src ->
        full = Path.join(["priv/templates/sigra.install", src])
        assert File.exists?(full), "Features.Core references missing template: #{src}"
      end)
    end

    test "files/1 + migrations/1 reference exactly the templates the v1.0 monolith generates" do
      # Full-flags union: the set of distinct source basenames Features.Core
      # can emit across any combination of --live/--api/--jwt is the same set
      # the v1.0 monolith renders. The 3 orphan templates documented in the
      # Wave 3 summary (auth_api_token.ex, auth_hooks.ex,
      # api_token_created_email.ex) are intentionally NOT referenced — they
      # exist in priv/templates/sigra.install/core/ as copy-paste hints but
      # have never been part of the rendered set, and preserving that keeps
      # the golden-diff contract. Any template added in a future phase must
      # be explicitly routed through files/1 or migrations/1.
      #
      # Phase 24.1: alter_audit_events_add_org_columns.exs is also an orphan
      # from Core's perspective. The template file still lives under core/
      # (where the other audit_events migrations live) but the Organizations
      # feature owns emission of this migration so the hard FK to the
      # organizations table lands AFTER that table is created and is
      # omitted entirely under --no-organizations.
      orphans =
        ~w(auth_api_token.ex auth_hooks.ex api_token_created_email.ex alter_audit_events_add_org_columns.exs)

      on_disk =
        "priv/templates/sigra.install/core"
        |> File.ls!()
        |> Enum.reject(&(&1 in orphans))
        |> Enum.sort()

      live_binding =
        Keyword.put(@binding, :opts, live: true, api: true, jwt: true, mfa: true, oauth: true)

      nolive_binding =
        Keyword.put(@binding, :opts, live: false, api: true, jwt: true, mfa: true, oauth: true)

      stub_binding =
        Keyword.put(@binding, :opts, live: true, api: false, jwt: false, mfa: false, oauth: false)

      referenced =
        (Core.files(live_binding) ++ Core.files(nolive_binding) ++ Core.files(stub_binding))
        |> Enum.map(fn {:eex, src, _} -> Path.basename(src) end)
        |> Kernel.++(
          Enum.map(Core.migrations(live_binding), fn {_, src, _} -> Path.basename(src) end)
        )
        |> Enum.uniq()
        |> Enum.sort()

      assert referenced == on_disk,
             """
             Features.Core template coverage mismatch.
             Missing (on disk, not referenced): #{inspect(on_disk -- referenced)}
             Extra (referenced, not on disk): #{inspect(referenced -- on_disk)}
             """
    end
  end

  describe "injections/1" do
    test "returns a non-empty list of %Injection{} records" do
      injections = Core.injections(@binding)
      assert is_list(injections)
      assert length(injections) >= 4
      assert Enum.all?(injections, &match?(%Sigra.Install.Injection{}, &1))
    end

    test "markers are unique per target file" do
      # Injector idempotency is per-file, so the (target, marker) pair must
      # be unique. Matching the v1.0 monolith, multiple targets share the
      # "# Sigra authentication" marker (router.ex, config.exs, test.exs);
      # that's fine because each file is inspected independently.
      binding = Keyword.put(@binding, :opts, live: true, api: true, jwt: true)

      pairs =
        binding
        |> Core.injections()
        |> Enum.map(&{&1.target, &1.marker})

      uniq = Enum.uniq(pairs)

      assert length(pairs) == length(uniq),
             "duplicate (target, marker) pairs: #{inspect(pairs -- uniq)}"
    end

    test "every injection target is project-relative (no absolute paths)" do
      targets = @binding |> Core.injections() |> Enum.map(& &1.target)
      assert Enum.all?(targets, fn t -> not String.starts_with?(t, "/") end)
    end

    test "every injection anchor is supported by Sigra.Install.Injector.apply/2" do
      # apply_anchor/3 in injector.ex handles these anchors. Phase 11
      # Wave 4 added :elixir_config / :append_eof / :conn_case_helpers
      # for non-Elixir-module targets (config.exs, test.exs, conn_case.ex)
      # so byte output matches the v1.0 monolith's specialized
      # inject_config / inject_test_config / inject_conn_case helpers.
      supported = [
        :before_last_end,
        :after_use_block,
        :at_top,
        :browser_pipeline,
        :elixir_config,
        :append_eof,
        :conn_case_helpers,
        :vault_child
      ]

      anchors = @binding |> Core.injections() |> Enum.map(& &1.anchor) |> Enum.uniq()

      Enum.each(anchors, fn a ->
        assert a in supported, "Injector does not support anchor #{inspect(a)}"
      end)
    end

    test "default opts emit the 4 base injections (router, config, test, conn_case)" do
      targets = @binding |> Core.injections() |> Enum.map(& &1.target)

      router_markers =
        @binding
        |> Core.injections()
        |> Enum.filter(&(&1.target == "lib/my_app_web/router.ex"))
        |> Enum.map(& &1.marker)

      assert "lib/my_app_web/router.ex" in targets
      assert "config/config.exs" in targets
      assert "config/test.exs" in targets
      assert "test/support/conn_case.ex" in targets
      assert "import MyAppWeb.UserAuth" in router_markers
      assert "plug :fetch_current_scope" in router_markers
      assert "# Sigra authentication" in router_markers
    end

    test "browser pipeline injection hydrates current_scope before auth gates" do
      [browser_inj] =
        @binding
        |> Core.injections()
        |> Enum.filter(&(&1.marker == "plug :fetch_current_scope" and &1.target =~ "router.ex"))

      assert browser_inj.anchor == :browser_pipeline
      assert browser_inj.content == "    plug :fetch_current_scope"
    end

    test "router import injection makes auth plugs available to the browser pipeline" do
      [import_inj] =
        @binding
        |> Core.injections()
        |> Enum.filter(&(&1.marker == "import MyAppWeb.UserAuth" and &1.target =~ "router.ex"))

      assert import_inj.anchor == :after_use_block
      assert import_inj.content == "import MyAppWeb.UserAuth"
    end

    test "--api adds api-router + api-config injections" do
      binding = Keyword.put(@binding, :opts, live: true, api: true, jwt: false)
      injections = Core.injections(binding)
      markers = Enum.map(injections, & &1.marker)

      assert "# Sigra API" in markers
      assert "api_token:" in markers
      # --api alone: no JWT marker
      refute "# Sigra JWT" in markers
    end

    test "--jwt adds jwt-router injection in addition to api-router" do
      binding = Keyword.put(@binding, :opts, live: true, api: false, jwt: true)
      injections = Core.injections(binding)
      markers = Enum.map(injections, & &1.marker)

      assert "# Sigra API" in markers
      assert "# Sigra JWT" in markers
    end

    test "router injection content contains the mandatory plug pipeline + routes" do
      [router_inj] =
        @binding
        |> Core.injections()
        |> Enum.filter(&(&1.marker == "# Sigra authentication" and &1.target =~ "router.ex"))

      assert router_inj.content =~ "pipeline :require_authenticated"
      assert router_inj.content =~ "plug :require_authenticated_user"
      assert router_inj.content =~ "plug :require_mfa"
      assert router_inj.content =~ "get \"/log_in\", SessionController, :new"
      assert router_inj.content =~ "post \"/log_in\", SessionController, :create"
      # Default binding is --live: LiveView route is present
      assert router_inj.content =~ "live \"/register\", RegistrationLive"
    end

    test "--no-live router injection emits controller-mode registration routes" do
      binding = Keyword.put(@binding, :opts, live: false, api: false, jwt: false)

      [router_inj] =
        binding
        |> Core.injections()
        |> Enum.filter(&(&1.marker == "# Sigra authentication" and &1.target =~ "router.ex"))

      refute router_inj.content =~ "live \"/register\", RegistrationLive"
      assert router_inj.content =~ "get \"/register\", RegistrationController, :new"
      assert router_inj.content =~ "post \"/register\", RegistrationController, :create"
    end

    test "config injection contains Sigra config block with host otp_app" do
      [config_inj] =
        @binding
        |> Core.injections()
        |> Enum.filter(&(&1.marker == "# Sigra authentication" and &1.target =~ "config.exs"))

      assert config_inj.content =~ "config :my_app, :sigra"
      assert config_inj.content =~ "repo: MyApp.Repo"
      assert config_inj.content =~ "user_schema: MyApp.Accounts.User"
      assert config_inj.content =~ "email_module: MyApp.Accounts.Emails"
      assert config_inj.content =~ "mailer: MyApp.Accounts.Mailer"
    end
  end

  # post_instructions/2 tests live in
  # test/sigra/install/features/core_post_instructions_test.exs
  # because that function reads (and mutates!) host-app config files,
  # which requires async: false + a temp-dir cd. Running them inline
  # here would pollute the Sigra repo's own config/dev.exs.
end
