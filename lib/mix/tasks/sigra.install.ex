defmodule Mix.Tasks.Sigra.Install do
  @moduledoc """
  Generates Sigra authentication scaffold.

  Creates migrations, schemas, context module, plug helpers,
  and optional LiveView pages for authentication.

  ## Usage

      mix sigra.install Accounts User users

  The first argument is the context name (e.g., `Accounts`),
  the second is the schema name (e.g., `User`), and the third
  is the table name (e.g., `users`).

  ## Options

    * `--live` / `--no-live` - Generate LiveView pages (default: true)
    * `--binary-id` / `--no-binary-id` - Use UUID (binary_id) primary keys
      (default: true). Pass `--no-binary-id` to use bigint integer PKs instead.
    * `--table` - Override the table name
    * `--yes` - Non-interactive mode (accept all defaults). No-op today because
      the installer has no interactive prompts; reserved for future use and
      required by CI smoke jobs (phase 10.1.1).

  ## Examples

      mix sigra.install Accounts User users
      mix sigra.install Accounts User users --no-live
      mix sigra.install Accounts User users --no-binary-id

  """
  @shortdoc "Generates Sigra authentication scaffold"

  use Mix.Task

  @switches [
    live: :boolean,
    binary_id: :boolean,
    table: :string,
    api: :boolean,
    jwt: :boolean,
    yes: :boolean
  ]
  @default_opts [live: true, api: false, jwt: false, binary_id: true]

  @impl true
  def run(args) do
    {opts, parsed, _} = OptionParser.parse(args, switches: @switches)
    opts = Keyword.merge(@default_opts, opts)

    case parsed do
      [context_name, schema_name, table_name] ->
        validate_args!(context_name, schema_name, table_name)
        generate(context_name, schema_name, opts[:table] || table_name, opts)

      _ ->
        Mix.raise("""
        Expected exactly 3 arguments: context_name schema_name table_name

        Usage:
            mix sigra.install Accounts User users
            mix sigra.install Accounts User users --no-live
            mix sigra.install Accounts User users --binary-id
        """)
    end
  end

  defp validate_args!(context_name, schema_name, table_name) do
    unless context_name =~ ~r/^[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)*$/ do
      Mix.raise("The context name must be a valid Elixir module name (e.g., Accounts), got: #{context_name}")
    end

    unless schema_name =~ ~r/^[A-Z][A-Za-z0-9]*$/ do
      Mix.raise("The schema name must be a valid Elixir module name (e.g., User), got: #{schema_name}")
    end

    unless table_name =~ ~r/^[a-z][a-z0-9_]*$/ do
      Mix.raise("The table name must be a valid identifier (e.g., users), got: #{table_name}")
    end
  end

  defp generate(context_name, schema_name, table_name, opts) do
    base = Mix.Phoenix.base()
    web_module = Module.concat([Mix.Phoenix.web_module(base)])
    otp_app = Mix.Phoenix.otp_app()
    repo_module = get_repo_module(otp_app)
    adapter = detect_adapter(repo_module)

    app_name = otp_app |> to_string() |> Macro.camelize()
    from_email = "noreply@example.com"
    log_in_url = "/users/log_in"

    binding = [
      context_module: inspect(Module.concat([base, context_name])),
      context_alias: context_name,
      schema_module: inspect(Module.concat([base, context_name, schema_name])),
      schema_alias: schema_name,
      table_name: table_name,
      web_module: inspect(web_module),
      app_module: inspect(Module.concat([base])),
      app_name: app_name,
      from_email: from_email,
      log_in_url: log_in_url,
      otp_app: otp_app,
      repo_module: inspect(repo_module),
      binary_id: Keyword.get(opts, :binary_id, true),
      live: opts[:live],
      api: opts[:api] || opts[:jwt] || false,
      jwt: opts[:jwt] || false,
      adapter: adapter,
      reset_password_url: "\#{#{inspect(web_module)}.Endpoint.url()}/users/reset-password",
      settings_url: "\#{#{inspect(web_module)}.Endpoint.url()}/users/settings"
    ]

    context_underscore = Macro.underscore(context_name)
    otp_app_str = to_string(otp_app)

    # Check if migration already exists (prevent duplicates on re-run)
    existing_migration =
      Path.join(["priv", "repo", "migrations"])
      |> File.ls()
      |> case do
        {:ok, files} -> Enum.find(files, &String.contains?(&1, "create_sigra_auth_tables"))
        _ -> nil
      end

    # Always generated files
    migration_path =
      if existing_migration do
        Path.join(["priv", "repo", "migrations", existing_migration])
      else
        Path.join(["priv", "repo", "migrations", "#{timestamp()}_create_sigra_auth_tables.exs"])
      end

    # Check if audit_events migration already exists (prevent duplicates on re-run)
    existing_audit_migration =
      Path.join(["priv", "repo", "migrations"])
      |> File.ls()
      |> case do
        {:ok, mig_files} -> Enum.find(mig_files, &String.contains?(&1, "create_audit_events"))
        _ -> nil
      end

    audit_migration_path =
      if existing_audit_migration do
        Path.join(["priv", "repo", "migrations", existing_audit_migration])
      else
        Path.join(["priv", "repo", "migrations", "#{audit_migration_timestamp()}_create_audit_events.exs"])
      end

    files = [
      {:eex, "migration.exs", migration_path},
      {:eex, "user.ex",
       Path.join(["lib", otp_app_str, context_underscore, "user.ex"])},
      {:eex, "user_token.ex",
       Path.join(["lib", otp_app_str, context_underscore, "user_token.ex"])},
      {:eex, "scope.ex",
       Path.join(["lib", otp_app_str, context_underscore, "scope.ex"])},
      {:eex, "auth.ex",
       Path.join(["lib", otp_app_str, "#{context_underscore}.ex"])},
      {:eex, "user_auth.ex",
       Path.join(["lib", "#{otp_app_str}_web", "user_auth.ex"])},
      {:eex, "error_handler.ex",
       Path.join(["lib", "#{otp_app_str}_web", "auth_error_handler.ex"])},
      {:eex, "session_controller.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "session_controller.ex"])},
      {:eex, "auth_fixtures.ex",
       Path.join(["test", "support", "fixtures", "auth_fixtures.ex"])},
      {:eex, "conn_case_helpers.ex",
       Path.join(["test", "support", "conn_case_helpers.ex"])},
      # Phase 3: Email flow templates
      {:eex, "emails.ex",
       Path.join(["lib", otp_app_str, context_underscore, "emails.ex"])},
      {:eex, "auth_mailer.ex",
       Path.join(["lib", otp_app_str, context_underscore, "mailer.ex"])},
      {:eex, "confirmation_controller.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "confirmation_controller.ex"])},
      {:eex, "confirmation_html.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "confirmation_html.ex"])},
      {:eex, "reset_password_controller.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "reset_password_controller.ex"])},
      {:eex, "reset_password_html.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "reset_password_html.ex"])},
      # Phase 4: Session management and security baseline
      {:eex, "user_session.ex",
       Path.join(["lib", otp_app_str, context_underscore, "user_session.ex"])},
      {:eex, "sudo_controller.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "auth", "sudo_controller.ex"])},
      {:eex, "sudo_html.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "auth", "sudo_html.ex"])},
      # Phase 6: MFA schemas and controller (always generated)
      {:eex, "user_mfa_credential.ex",
       Path.join(["lib", otp_app_str, context_underscore, "user_mfa_credential.ex"])},
      {:eex, "user_backup_code.ex",
       Path.join(["lib", otp_app_str, context_underscore, "user_backup_code.ex"])},
      {:eex, "mfa_challenge_controller.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "mfa_challenge_controller.ex"])},
      {:eex, "mfa_challenge_html.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "mfa_challenge_html.ex"])},
      # Phase 9: Audit log schema and migration
      {:eex, "create_audit_events.exs", audit_migration_path},
      {:eex, "audit_event.ex",
       Path.join(["lib", otp_app_str, context_underscore, "audit_event.ex"])},
      # Phase 10.1: Encrypted.Binary passthrough stub (replaces Cloak.Vault binding)
      {:eex, "encrypted.ex",
       Path.join(["lib", otp_app_str, context_underscore, "encrypted.ex"])},
      # Phase 10.1: Swoosh mailer wrapper (skipped if host already has one)
      {:eex, "mailer.ex", Path.join(["lib", otp_app_str, "mailer.ex"])}
    ]

    # Check if API token migration already exists (prevent duplicates on re-run)
    existing_api_migration =
      Path.join(["priv", "repo", "migrations"])
      |> File.ls()
      |> case do
        {:ok, mig_files} -> Enum.find(mig_files, &String.contains?(&1, "create_user_api_tokens"))
        _ -> nil
      end

    api_migration_path =
      if existing_api_migration do
        Path.join(["priv", "repo", "migrations", existing_api_migration])
      else
        Path.join(["priv", "repo", "migrations", "#{api_token_timestamp()}_create_user_api_tokens.exs"])
      end

    # Conditionally add API token files (--api or --jwt flag)
    api_files =
      if opts[:api] || opts[:jwt] do
        [
          {:eex, "api_token_migration.exs", api_migration_path},
          {:eex, "user_api_token.ex",
           Path.join(["lib", otp_app_str, context_underscore, "user_api_token.ex"])},
          {:eex, "api_token_controller.ex",
           Path.join(["lib", "#{otp_app_str}_web", "controllers", "api_token_controller.ex"])}
        ]
      else
        []
      end

    # Conditionally add JWT token controller (--jwt flag only)
    jwt_files =
      if opts[:jwt] do
        [
          {:eex, "token_controller.ex",
           Path.join(["lib", "#{otp_app_str}_web", "controllers", "token_controller.ex"])}
        ]
      else
        []
      end

    # Conditionally add LiveView or controller-mode templates.
    #
    # Phase 10.1.1 B9/D-12: the login page is ALWAYS emitted as a plain
    # controller + SessionHTML (`login_html.ex` → `session_html.ex`),
    # even in `--live` mode. LiveView's `<.form>` registers `phx-submit`
    # by default and was swallowing the browser form submit during UAT;
    # moving the login page out of LiveView entirely is the structural
    # fix. All other --live pages continue to be LiveViews.
    login_controller_file =
      {:eex, "login_html.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "session_html.ex"])}

    ui_files =
      if opts[:live] do
        [
          login_controller_file,
          {:eex, "registration_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "registration_live.ex"])},
          # Phase 3: LiveView email flow pages
          {:eex, "confirmation_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "confirmation_live.ex"])},
          {:eex, "reset_password_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "reset_password_live.ex"])},
          # Phase 4: Session management LiveView
          {:eex, "session_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "auth", "session_live.ex"])},
          # Phase 6: MFA LiveView pages
          {:eex, "mfa_challenge_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "mfa_challenge_live.ex"])},
          {:eex, "mfa_settings_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "mfa_settings_live.ex"])},
          # Phase 8: Account lifecycle LiveView pages
          {:eex, "settings_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "settings_live.ex"])},
          {:eex, "reactivation_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "reactivation_live.ex"])}
        ]
      else
        [
          login_controller_file,
          {:eex, "registration_html.ex",
           Path.join(["lib", "#{otp_app_str}_web", "controllers", "registration_html.ex"])},
          # Phase 6: MFA controller-mode settings page
          {:eex, "mfa_settings_html.ex",
           Path.join(["lib", "#{otp_app_str}_web", "controllers", "mfa_settings_html.ex"])}
        ]
      end

    all_files = files ++ ui_files ++ api_files ++ jwt_files

    # Generate files from templates (skip existing files for idempotency)
    for {_type, template_name, target_path} <- all_files do
      if File.exists?(target_path) do
        Mix.shell().info([:yellow, "* skipping ", :reset, target_path, " (already exists)"])
      else
        template_path = find_template(template_name)
        content = EEx.eval_file(template_path, binding)
        Mix.Generator.create_file(target_path, content)
      end
    end

    # Inject into existing files
    inject_into_files(binding, opts)

    # Print post-install instructions
    print_instructions(opts)
  end

  defp find_template(name) do
    # Check for user overrides first (per D-09)
    user_override = Path.join([File.cwd!(), "priv", "templates", "sigra.install", name])

    if File.exists?(user_override) do
      user_override
    else
      Application.app_dir(:sigra, Path.join(["priv", "templates", "sigra.install", name]))
    end
  end

  defp inject_into_files(binding, _opts) do
    web_module = binding[:web_module]
    otp_app = binding[:otp_app]
    context_module = binding[:context_module]
    repo_module = binding[:repo_module]
    schema_alias = binding[:schema_alias]

    # Router injection
    router_path = Path.join(["lib", "#{otp_app}_web", "router.ex"])

    if File.exists?(router_path) do
      # Phase 10.1.1 B9/D-12: `get "/log_in"` routes to SessionController
      # in BOTH modes. The LiveView login page was swallowing form submits
      # in the browser, so login is now always a plain controller render.
      live_routes =
        if binding[:live] do
          """

              live "/register", RegistrationLive
          """
        else
          """

              get "/register", RegistrationController, :new
              post "/register", RegistrationController, :create
          """
        end

      confirmation_routes =
        if binding[:live] do
          """

              live "/confirm", ConfirmationLive
              live "/confirm/:token", ConfirmationLive, :confirm
          """
        else
          """

              get "/confirm", ConfirmationController, :new
              post "/confirm", ConfirmationController, :create
              get "/confirm/:token", ConfirmationController, :confirm
              post "/confirm/resend", ConfirmationController, :resend
          """
        end

      reset_routes =
        if binding[:live] do
          """

              live "/reset-password", ResetPasswordLive
              live "/reset-password/:token", ResetPasswordLive, :edit
          """
        else
          """

              get "/reset-password", ResetPasswordController, :new
              post "/reset-password", ResetPasswordController, :create
              get "/reset-password/:token", ResetPasswordController, :edit
              put "/reset-password/:token", ResetPasswordController, :update
          """
        end

      session_management_routes =
        if binding[:live] do
          """

              live "/sessions", Auth.SessionLive, :index
          """
        else
          ""
        end

      sudo_routes = """

            get "/sudo", Auth.SudoController, :new
            post "/sudo", Auth.SudoController, :create
      """

      # MFA challenge routes (accessible with mfa_pending sessions, D-24)
      mfa_challenge_routes =
        if binding[:live] do
          """

              live "/mfa", MFAChallengeLive
          """
        else
          """

              get "/mfa", MFAChallengeController, :new
              post "/mfa", MFAChallengeController, :create
          """
        end

      # MFA settings routes (within authenticated + MFA-verified pipeline)
      mfa_settings_routes =
        if binding[:live] do
          """

              live "/settings/mfa", MFASettingsLive
          """
        else
          ""
        end

      # Account lifecycle routes (settings + reactivation) — LiveView only
      account_lifecycle_routes =
        if binding[:live] do
          """

              live "/settings", SettingsLive, :edit
              live "/reactivation", ReactivationLive
          """
        else
          ""
        end

      router_plug_code = """
        # Sigra authentication
        import #{web_module}.UserAuth

        pipeline :require_authenticated do
          plug :require_authenticated_user
          plug :require_mfa
        end

        # MFA challenge (accessible with mfa_pending sessions, D-24)
        scope "/users", #{web_module} do
          pipe_through [:browser]
      #{mfa_challenge_routes}
        end

        scope "/users", #{web_module} do
          pipe_through [:browser, :redirect_if_user_is_authenticated]

          # Phase 10.1.1 B9: login page is a plain controller, not a LiveView.
          get "/log_in", SessionController, :new
      #{live_routes}
          post "/log_in", SessionController, :create
          get "/log_in/:token", SessionController, :magic_link
      #{confirmation_routes}
      #{reset_routes}
        end

        scope "/users", #{web_module} do
          pipe_through [:browser, :require_authenticated]

          delete "/log_out", SessionController, :delete
      #{session_management_routes}#{sudo_routes}#{mfa_settings_routes}#{account_lifecycle_routes}
        end
      """

      inject_file(router_path, &Sigra.Install.Injector.inject_router_plugs(&1, router_plug_code))
    end

    # Config injection
    config_path = Path.join(["config", "config.exs"])

    if File.exists?(config_path) do
      config_block = """

      # Sigra authentication
      config :#{otp_app}, :sigra,
        repo: #{repo_module},
        user_schema: #{context_module}.#{schema_alias}

      # Sigra worker runtime config (used by Oban workers)
      config :sigra,
        repo: #{repo_module},
        user_schema: #{context_module}.#{schema_alias},
        email_module: #{context_module}.Emails,
        mailer: #{context_module}.Mailer
      """

      inject_file(config_path, &Sigra.Install.Injector.inject_config(&1, config_block))
    end

    # Test config injection
    test_config_path = Path.join(["config", "test.exs"])

    if File.exists?(test_config_path) do
      test_block = """

      # Sigra authentication
      # Speed up password hashing in tests
      config :argon2_elixir, t_cost: 1, m_cost: 8
      """

      inject_file(
        test_config_path,
        &Sigra.Install.Injector.inject_test_config(&1, test_block)
      )
    end

    # ConnCase injection
    conn_case_path = Path.join(["test", "support", "conn_case.ex"])

    if File.exists?(conn_case_path) do
      helper_code = "      import #{web_module}.ConnCaseHelpers"

      inject_file(conn_case_path, &Sigra.Install.Injector.inject_conn_case(&1, helper_code))
    end

    # API route injection (--api or --jwt flag)
    if binding[:api] do
      inject_api_files(binding)
    end

    # Oban queue injection (per D-22)
    inject_oban_queue(otp_app)

    # Swoosh config detection (per D-19/D-55)
    inject_swoosh_config(otp_app, context_module)
  end

  defp inject_api_files(binding) do
    web_module = binding[:web_module]
    otp_app = binding[:otp_app]

    router_path = Path.join(["lib", "#{otp_app}_web", "router.ex"])

    if File.exists?(router_path) do
      api_route_code = """
        # Sigra API
        pipeline :api_authenticated do
          plug Sigra.Plug.FetchBearer
          plug Sigra.Plug.RequireAuthenticated,
            error_handler: #{web_module}.AuthErrorHandler
        end

        scope "/api", #{web_module} do
          pipe_through [:api, :api_authenticated]

          get "/tokens", APITokenController, :index
          post "/tokens", APITokenController, :create
          delete "/tokens/:id", APITokenController, :delete
          delete "/tokens", APITokenController, :delete_all
        end

        # # Mixed-mode pipeline (uncomment if you need endpoints that accept both session and bearer auth)
        # pipeline :api_or_browser do
        #   plug Sigra.Plug.FetchBearer
        #   plug Sigra.Plug.FetchSession
        # end
      """

      inject_file(router_path, &Sigra.Install.Injector.inject_api_routes(&1, api_route_code))

      # JWT routes (only with --jwt)
      if binding[:jwt] do
        jwt_route_code = """
          # Sigra JWT
          scope "/api/auth", #{web_module} do
            pipe_through :api

            post "/token", TokenController, :create
            post "/token/refresh", TokenController, :refresh
            post "/token/mfa", TokenController, :mfa
            delete "/token", TokenController, :revoke
          end
        """

        inject_file(router_path, &Sigra.Install.Injector.inject_jwt_routes(&1, jwt_route_code))
      end
    end

    # API config injection
    config_path = Path.join(["config", "config.exs"])

    if File.exists?(config_path) do
      api_config = """

      # Sigra API token configuration
      config :#{otp_app}, :sigra_api,
        api_token: [
          prefix: "sigra_sk_",
          max_tokens_per_user: 25,
          default_scopes: ["read"]
        ]
      """

      jwt_config =
        if binding[:jwt] do
          "\n  jwt: [\n    algorithm: \"HS256\",\n    access_ttl: 900,\n    refresh_ttl: 2_592_000\n  ]\n"
        else
          ""
        end

      inject_file(config_path, &Sigra.Install.Injector.inject_api_config(&1, api_config <> jwt_config))
    end

    # Print instructions for manual addition of auth_api_token.ex content
    Mix.shell().info([
      :green,
      "* API token functions available. ",
      :reset,
      "Add the delegation functions from auth_api_token.ex to your Auth context module."
    ])
  end

  defp api_token_timestamp, do: offset_timestamp(1)
  defp audit_migration_timestamp, do: offset_timestamp(2)

  # Generate a migration timestamp offset by `n` seconds from the current UTC
  # time. Carries into minutes/hours/days via gregorian-seconds arithmetic so
  # the three Sigra migration timestamps (primary + api_token + audit) never
  # collide even when the wall clock is near the end of a minute. Previously
  # used `min(ss + n, 59)` which clamped all offsets to :59 in the last ~3%
  # of each minute, defeating the intended ordering. Reviewed in 10.1 IN-01.
  defp offset_timestamp(n) do
    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    {{y, m, d}, {hh, mm, ss}} = :calendar.gregorian_seconds_to_datetime(now_secs + n)
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp inject_oban_queue(otp_app) do
    runtime_config = Path.join(["config", "runtime.exs"])
    config_path = Path.join(["config", "config.exs"])

    # Check runtime.exs first, then config.exs for Oban config
    target =
      cond do
        File.exists?(runtime_config) && File.read!(runtime_config) =~ "Oban" -> runtime_config
        File.exists?(config_path) && File.read!(config_path) =~ "Oban" -> config_path
        true -> nil
      end

    if target do
      content = File.read!(target)

      if content =~ "sigra_mailer" do
        Mix.shell().info([:yellow, "* already configured ", :reset, "Oban sigra_mailer queue"])
      else
        Mix.shell().info([:green, "* detected Oban config in ", :reset, target])

        Mix.shell().info([
          :yellow,
          "  Add the sigra_mailer queue to your Oban config:\n",
          :reset,
          "    config :#{otp_app}, Oban, queues: [sigra_mailer: 10]\n"
        ])
      end
    else
      Mix.shell().info([
        :yellow,
        "* Oban not detected. ",
        :reset,
        "Email delivery will use synchronous mode.\n",
        "  To enable async delivery, add Oban and configure the sigra_mailer queue."
      ])
    end
  end

  defp inject_swoosh_config(otp_app, context_module) do
    dev_config = Path.join(["config", "dev.exs"])

    if File.exists?(dev_config) do
      content = File.read!(dev_config)

      if content =~ "Swoosh" do
        Mix.shell().info([:yellow, "* already configured ", :reset, "Swoosh in #{dev_config}"])
      else
        swoosh_block = """

        # Sigra email delivery (dev)
        config :#{otp_app}, #{context_module}.Mailer,
          adapter: Swoosh.Adapters.Local

        config :swoosh, :api_client, false
        """

        File.write!(dev_config, content <> swoosh_block)
        Mix.shell().info([:green, "* injecting ", :reset, "Swoosh dev config into #{dev_config}"])
      end
    end
  end

  defp inject_file(path, injector_fn) do
    content = File.read!(path)

    case injector_fn.(content) do
      {:ok, new_content} ->
        File.write!(path, new_content)
        Mix.shell().info([:green, "* injecting ", :reset, path])

      {:already_injected, _content} ->
        Mix.shell().info([:yellow, "* already injected ", :reset, path])
    end
  end

  defp get_repo_module(otp_app) do
    case Application.get_env(otp_app, :ecto_repos, []) do
      [repo | _] -> repo
      [] -> Module.concat([Mix.Phoenix.base(), "Repo"])
    end
  end

  defp detect_adapter(repo_module) do
    if Code.ensure_loaded?(repo_module) and function_exported?(repo_module, :__adapter__, 0) do
      case repo_module.__adapter__() do
        Ecto.Adapters.Postgres -> :postgres
        Ecto.Adapters.MyXQL -> :mysql
        Ecto.Adapters.SQLite3 -> :sqlite
        _ -> :postgres
      end
    else
      :postgres
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i), do: String.pad_leading(to_string(i), 2, "0")

  defp print_instructions(opts) do
    Mix.shell().info("""

    Sigra authentication has been installed!

    Next steps:

      1. Run the migration:

             mix ecto.migrate

      2. Add the authentication pipeline to your router:

             # In lib/your_app_web/router.ex
             # Routes were auto-injected if the router was found.

      3. Review the generated configuration in config/config.exs

      4. (Optional) Set up rate limiting with Hammer:

             # In your application.ex children list:
             {MyApp.RateLimit, clean_period: :timer.minutes(1)}

             # Create lib/my_app/rate_limit.ex:
             defmodule MyApp.RateLimit do
               use Hammer, backend: :ets
             end

    #{if opts[:live], do: "  LiveView pages were generated for login, registration, and session management.\n", else: "  LiveView pages were NOT generated (--no-live). Use the SessionController for login.\n"}
    #{if opts[:api] || opts[:jwt], do: "  API token endpoints were generated at /api/tokens.\n  Add the functions from auth_api_token.ex to your Auth context.\n", else: ""}#{if opts[:jwt], do: "  JWT authentication endpoints were generated at /api/auth/token.\n", else: ""}
    """)
  end
end
