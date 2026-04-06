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
    * `--binary-id` - Use binary IDs instead of integer IDs
    * `--table` - Override the table name

  ## Examples

      mix sigra.install Accounts User users
      mix sigra.install Accounts User users --no-live
      mix sigra.install Accounts User users --binary-id

  """
  @shortdoc "Generates Sigra authentication scaffold"

  use Mix.Task

  @switches [live: :boolean, binary_id: :boolean, table: :string]
  @default_opts [live: true]

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

    binding = [
      context_module: inspect(Module.concat([base, context_name])),
      schema_module: inspect(Module.concat([base, context_name, schema_name])),
      schema_alias: schema_name,
      table_name: table_name,
      web_module: inspect(web_module),
      otp_app: otp_app,
      repo_module: inspect(repo_module),
      binary_id: opts[:binary_id] || false,
      live: opts[:live],
      adapter: adapter
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
       Path.join(["test", "support", "conn_case_helpers.ex"])}
    ]

    # Conditionally add LiveView templates
    live_files =
      if opts[:live] do
        [
          {:eex, "login_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "login_live.ex"])},
          {:eex, "registration_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "registration_live.ex"])}
        ]
      else
        []
      end

    all_files = files ++ live_files

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
      live_routes =
        if binding[:live] do
          """

              live "/register", RegistrationLive
              live "/log_in", LoginLive
          """
        else
          """

              get "/register", RegistrationController, :new
              post "/register", RegistrationController, :create
              get "/log_in", SessionController, :new
          """
        end

      router_plug_code = """
        # Sigra authentication
        import #{web_module}.UserAuth

        pipeline :require_authenticated do
          plug :require_authenticated_user
        end

        scope "/users", #{web_module} do
          pipe_through [:browser, :redirect_if_user_is_authenticated]
      #{live_routes}
          post "/log_in", SessionController, :create
        end

        scope "/users", #{web_module} do
          pipe_through [:browser, :require_authenticated]

          delete "/log_out", SessionController, :delete
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

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

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

    #{if opts[:live], do: "  LiveView pages were generated for login and registration.\n", else: "  LiveView pages were NOT generated (--no-live). Use the SessionController for login.\n"}
    """)
  end
end
