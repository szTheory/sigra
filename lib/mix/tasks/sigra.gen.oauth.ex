defmodule Mix.Tasks.Sigra.Gen.Oauth do
  @moduledoc """
  Generates OAuth support for Sigra authentication.

  Creates UserIdentity schema, Vault, encrypted type, migration,
  OAuth controller, HTML templates, settings page, email templates,
  test helpers, and injects routes and config.

  ## Usage

      mix sigra.gen.oauth

  ## Options

    * `--providers` - Comma-separated list of providers to configure
      (e.g., `--providers google,github`)
    * `--live` / `--no-live` - Generate LiveView settings page (default: false)
    * `--no-vault` - Skip Vault and Encrypted.Binary generation
      (use if already created by another generator)

  ## Requirements

  Requires `cloak_ecto` in your dependencies:

      {:cloak_ecto, "~> 1.3"}

  ## Examples

      mix sigra.gen.oauth
      mix sigra.gen.oauth --providers google,github
      mix sigra.gen.oauth --live
      mix sigra.gen.oauth --no-vault

  """
  @shortdoc "Generates OAuth support for Sigra authentication"

  use Mix.Task

  @switches [
    providers: :string,
    live: :boolean,
    no_vault: :boolean,
    binary_id: :boolean
  ]

  @default_opts [live: false, no_vault: false, binary_id: true]

  @impl true
  def run(args) do
    {opts, _parsed, _} = OptionParser.parse(args, switches: @switches)
    opts = Keyword.merge(@default_opts, opts)

    # Check for cloak_ecto dependency (D-23)
    check_cloak_ecto!()

    base = Mix.Phoenix.base()
    web_module = Module.concat([Mix.Phoenix.web_module(base)])
    otp_app = Mix.Phoenix.otp_app()
    otp_app_str = to_string(otp_app)

    # Detect context module from existing sigra config or default to Accounts
    context_name = detect_context_name(otp_app, base)
    context_module = Module.concat([base, context_name])
    schema_alias = "User"

    app_name = otp_app |> to_string() |> Macro.camelize()
    from_email = "noreply@example.com"
    login_path = "/users/log_in"
    auth_path = "/auth"
    settings_path = "/users/settings/oauth"
    password_path = "/users/settings/password"

    binding = [
      context_module: inspect(context_module),
      schema_alias: schema_alias,
      web_module: inspect(web_module),
      app_module: inspect(Module.concat([base])),
      app_name: app_name,
      from_email: from_email,
      login_path: login_path,
      auth_path: auth_path,
      settings_path: settings_path,
      password_path: password_path,
      otp_app: otp_app,
      binary_id: Keyword.get(opts, :binary_id, true)
    ]

    context_underscore = Macro.underscore(context_name)

    # Check for existing migration
    existing_migration =
      Path.join(["priv", "repo", "migrations"])
      |> File.ls()
      |> case do
        {:ok, files} -> Enum.find(files, &String.contains?(&1, "create_user_identities"))
        _ -> nil
      end

    migration_path =
      if existing_migration do
        Path.join(["priv", "repo", "migrations", existing_migration])
      else
        Path.join(["priv", "repo", "migrations", "#{timestamp()}_create_user_identities.exs"])
      end

    # Core files (always generated)
    files = [
      {:eex, "oauth_migration.exs", migration_path},
      {:eex, "user_identity.ex",
       Path.join(["lib", otp_app_str, context_underscore, "user_identity.ex"])},
      {:eex, "oauth_controller.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "oauth_controller.ex"])},
      {:eex, "oauth_html.ex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "oauth_html.ex"])},
      {:eex, "oauth_buttons.html.heex",
       Path.join(["lib", "#{otp_app_str}_web", "controllers", "oauth_buttons.html.heex"])},
      {:eex, "provider_linked_email.ex",
       Path.join(["lib", otp_app_str, context_underscore, "emails", "provider_linked.ex"])},
      {:eex, "provider_unlinked_email.ex",
       Path.join(["lib", otp_app_str, context_underscore, "emails", "provider_unlinked.ex"])},
      {:eex, "oauth_test_helpers.ex", Path.join(["test", "support", "oauth_test_helpers.ex"])}
    ]

    # Vault files (conditional on --no-vault)
    vault_files =
      unless opts[:no_vault] do
        vault_path = Path.join(["lib", otp_app_str, "vault.ex"])
        encrypted_path = Path.join(["lib", otp_app_str, "encrypted", "binary.ex"])

        [
          {:eex, "vault.ex", vault_path},
          {:eex, "encrypted_binary.ex", encrypted_path}
        ]
      else
        []
      end

    # Settings page (LiveView or controller HTML)
    settings_files =
      if opts[:live] do
        [
          {:eex, "oauth_settings_live.ex",
           Path.join(["lib", "#{otp_app_str}_web", "live", "oauth_settings_live.ex"])}
        ]
      else
        [
          {:eex, "oauth_settings.html.heex",
           Path.join(["lib", "#{otp_app_str}_web", "controllers", "oauth_settings.html.heex"])}
        ]
      end

    all_files = files ++ vault_files ++ settings_files

    # Generate files from templates (idempotent: skip existing)
    for {_type, template_name, target_path} <- all_files do
      if File.exists?(target_path) do
        Mix.shell().info([:yellow, "* skipping ", :reset, target_path, " (already exists)"])
      else
        # Ensure parent directory exists
        target_path |> Path.dirname() |> File.mkdir_p!()
        template_path = find_template(template_name)
        content = EEx.eval_file(template_path, binding)
        Mix.Generator.create_file(target_path, content)
      end
    end

    # Inject routes, config, and vault into host app
    inject_into_files(binding, opts)

    # Print post-install instructions
    print_instructions(opts, binding)
  end

  defp check_cloak_ecto! do
    deps = Mix.Project.config()[:deps] || []

    has_cloak =
      Enum.any?(deps, fn
        {:cloak_ecto, _} -> true
        {:cloak_ecto, _, _} -> true
        _ -> false
      end)

    unless has_cloak do
      Mix.raise("""
      mix sigra.gen.oauth requires cloak_ecto for encrypted token storage.

      Add to your mix.exs deps:

          {:cloak_ecto, "~> 1.3"}

      Then run:

          mix deps.get
          mix sigra.gen.oauth
      """)
    end
  end

  defp detect_context_name(otp_app, _base) do
    # Try to detect from existing sigra config
    case Application.get_env(otp_app, :sigra, [])[:user_schema] do
      nil ->
        "Accounts"

      schema_module ->
        # Extract context from schema module (e.g., MyApp.Accounts.User -> "Accounts")
        parts = Module.split(schema_module)

        case length(parts) do
          n when n >= 3 -> Enum.at(parts, -2)
          _ -> "Accounts"
        end
    end
  end

  defp find_template(name) do
    # Check for user overrides first
    user_override = Path.join([File.cwd!(), "priv", "templates", "sigra.gen.oauth", name])

    if File.exists?(user_override) do
      user_override
    else
      Application.app_dir(:sigra, Path.join(["priv", "templates", "sigra.gen.oauth", name]))
    end
  end

  defp inject_into_files(binding, opts) do
    web_module = binding[:web_module]
    otp_app = binding[:otp_app]
    otp_app_str = to_string(otp_app)

    # Router injection: OAuth routes
    router_path = Path.join(["lib", "#{otp_app_str}_web", "router.ex"])

    if File.exists?(router_path) do
      oauth_routes = """
        # Sigra OAuth
        scope "/auth", #{web_module} do
          pipe_through [:browser]

          get "/:provider", OAuthController, :request
          get "/:provider/callback", OAuthController, :callback
        end
      """

      inject_file(router_path, &Sigra.Install.Injector.inject_oauth_routes(&1, oauth_routes))
    end

    # Config injection: OAuth provider config stub
    config_path = Path.join(["config", "config.exs"])

    if File.exists?(config_path) do
      providers_config = build_providers_config(binding, opts)

      inject_file(config_path, &Sigra.Install.Injector.inject_oauth_config(&1, providers_config))
    end

    # Application.ex injection: Vault in supervision tree
    unless opts[:no_vault] do
      app_path = Path.join(["lib", otp_app_str, "application.ex"])

      if File.exists?(app_path) do
        app_module = binding[:app_module]

        inject_file(
          app_path,
          &Sigra.Install.Injector.inject_vault_child(&1, app_module)
        )
      end
    end
  end

  defp build_providers_config(binding, opts) do
    otp_app = to_string(binding[:otp_app])
    providers = opts[:providers]

    if providers do
      provider_list =
        providers
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(fn p ->
          upper = String.upcase(p)

          "        " <>
            p <>
            ": [\n" <>
            "          client_id: System.get_env(\"" <>
            upper <>
            "_CLIENT_ID\"),\n" <>
            "          client_secret: System.get_env(\"" <>
            upper <>
            "_CLIENT_SECRET\"),\n" <>
            "          redirect_uri: \"http://localhost:4000/auth/" <>
            p <> "/callback\"\n" <> "        ]"
        end)
        |> Enum.join(",\n")

      "\n# Sigra OAuth providers\n" <>
        "# Move secrets to config/runtime.exs for production\n" <>
        "config :" <>
        otp_app <>
        ", :sigra,\n" <>
        "  oauth: [\n" <>
        "    providers: [\n" <>
        provider_list <>
        "\n    ]\n  ]\n"
    else
      "\n# Sigra OAuth providers\n" <>
        "# Uncomment and configure with your provider credentials:\n" <>
        "# config :" <>
        otp_app <>
        ", :sigra,\n" <>
        "#   oauth: [\n" <>
        "#     providers: [\n" <>
        "#       google: [\n" <>
        "#         client_id: System.get_env(\"GOOGLE_CLIENT_ID\"),\n" <>
        "#         client_secret: System.get_env(\"GOOGLE_CLIENT_SECRET\"),\n" <>
        "#         redirect_uri: \"http://localhost:4000/auth/google/callback\"\n" <>
        "#       ]\n" <>
        "#     ]\n" <>
        "#   ]\n"
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

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp print_instructions(opts, binding) do
    otp_app = binding[:otp_app]

    vault_instructions =
      unless opts[:no_vault] do
        """

          2. Generate a CLOAK_KEY:

                 elixir -e '32 |> :crypto.strong_rand_bytes() |> Base.encode64() |> IO.puts()'

             Add it to your environment: export CLOAK_KEY="<generated key>"
        """
      else
        ""
      end

    providers_instructions =
      if opts[:providers] do
        providers =
          opts[:providers]
          |> String.split(",")
          |> Enum.map(&String.trim/1)

        env_vars =
          Enum.map(providers, fn p ->
            upper = String.upcase(p)
            "         - " <> upper <> "_CLIENT_ID and " <> upper <> "_CLIENT_SECRET"
          end)
          |> Enum.join("\n")

        "\n      4. Configure provider credentials in config/runtime.exs:\n" <> env_vars <> "\n"
      else
        "\n      4. Configure providers in config/config.exs or config/runtime.exs:\n\n" <>
          "             config :" <>
          to_string(otp_app) <>
          ", :sigra,\n" <>
          "               oauth: [\n" <>
          "                 providers: [\n" <>
          "                   google: [\n" <>
          "                     client_id: \"...\",\n" <>
          "                     client_secret: \"...\",\n" <>
          "                     redirect_uri: \"http://localhost:4000/auth/google/callback\"\n" <>
          "                   ]\n" <>
          "                 ]\n" <>
          "               ]\n"
      end

    Mix.shell().info("""

    Sigra OAuth has been generated!

    Next steps:

      1. Run the migration:

             mix ecto.migrate
    #{vault_instructions}
      3. Add cloak_ecto to your deps (if not already):

             {:cloak_ecto, "~> 1.3"}
    #{providers_instructions}
    #{if opts[:live], do: "  LiveView settings page was generated for OAuth account management.\n", else: "  Controller-based settings page was generated for OAuth account management.\n"}
    """)
  end
end
