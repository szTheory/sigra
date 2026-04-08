defmodule Sigra.Install.OAuthGeneratorTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Injector

  # -- OAuth route injection --

  describe "inject_oauth_routes/2" do
    test "injects OAuth routes when marker is absent" do
      router_content = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        # Sigra authentication
        scope "/users", MyAppWeb do
          pipe_through [:browser]
          get "/log_in", SessionController, :new
        end
      end
      """

      oauth_routes = """
        # Sigra OAuth
        scope "/auth", MyAppWeb do
          pipe_through [:browser]

          get "/:provider", OAuthController, :request
          get "/:provider/callback", OAuthController, :callback
        end
      """

      assert {:ok, injected} = Injector.inject_oauth_routes(router_content, oauth_routes)
      assert String.contains?(injected, "# Sigra OAuth")
      assert String.contains?(injected, "OAuthController, :request")
      assert String.contains?(injected, "OAuthController, :callback")
      assert String.contains?(injected, "/:provider")
    end

    test "returns :already_injected when OAuth marker is present" do
      router_content = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        # Sigra OAuth
        scope "/auth", MyAppWeb do
          get "/:provider", OAuthController, :request
        end
      end
      """

      oauth_routes = "# Sigra OAuth\nscope \"/auth\""

      assert {:already_injected, ^router_content} =
               Injector.inject_oauth_routes(router_content, oauth_routes)
    end

    test "is idempotent on re-run" do
      router_content = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        scope "/", MyAppWeb do
          get "/", PageController, :home
        end
      end
      """

      oauth_routes = """
        # Sigra OAuth
        scope "/auth", MyAppWeb do
          get "/:provider", OAuthController, :request
        end
      """

      assert {:ok, first_inject} = Injector.inject_oauth_routes(router_content, oauth_routes)
      assert {:already_injected, ^first_inject} =
               Injector.inject_oauth_routes(first_inject, oauth_routes)
    end
  end

  # -- OAuth config injection --

  describe "inject_oauth_config/2" do
    test "injects OAuth config when not present" do
      config_content = """
      import Config

      # Sigra authentication
      config :my_app, :sigra,
        repo: MyApp.Repo,
        user_schema: MyApp.Accounts.User

      import_config "\#{config_env()}.exs"
      """

      oauth_config = """

      # Sigra OAuth providers
      # config :my_app, :sigra,
      #   oauth: [providers: [google: [client_id: "..."]]]
      """

      assert {:ok, injected} = Injector.inject_oauth_config(config_content, oauth_config)
      assert String.contains?(injected, "Sigra OAuth providers")
    end

    test "returns :already_injected when OAuth config exists" do
      config_content = """
      import Config

      # Sigra OAuth providers
      config :my_app, :sigra,
        oauth: [providers: [google: [client_id: "abc"]]]
      """

      oauth_config = "# Sigra OAuth providers\nconfig :my_app"

      assert {:already_injected, ^config_content} =
               Injector.inject_oauth_config(config_content, oauth_config)
    end

    test "injects before import_config when present" do
      config_content = """
      import Config

      config :my_app, ecto_repos: [MyApp.Repo]

      import_config "\#{config_env()}.exs"
      """

      oauth_config = "\n# Sigra OAuth providers\n# oauth config here\n"

      assert {:ok, injected} = Injector.inject_oauth_config(config_content, oauth_config)
      # OAuth config should appear before import_config
      oauth_pos = :binary.match(injected, "Sigra OAuth") |> elem(0)
      import_pos = :binary.match(injected, "import_config") |> elem(0)
      assert oauth_pos < import_pos
    end
  end

  # -- Vault child injection --

  describe "inject_vault_child/2" do
    test "injects Vault into supervision children list" do
      app_content = """
      defmodule MyApp.Application do
        use Application

        @impl true
        def start(_type, _args) do
          children = [
            MyApp.Repo,
            MyAppWeb.Endpoint
          ]

          opts = [strategy: :one_for_one, name: MyApp.Supervisor]
          Supervisor.start_link(children, opts)
        end
      end
      """

      assert {:ok, injected} = Injector.inject_vault_child(app_content, "MyApp")
      assert String.contains?(injected, "MyApp.Vault")
    end

    test "returns :already_injected when Vault is present" do
      app_content = """
      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            {MyApp.Vault, []},
            MyApp.Repo,
            MyAppWeb.Endpoint
          ]

          Supervisor.start_link(children, [])
        end
      end
      """

      assert {:already_injected, ^app_content} =
               Injector.inject_vault_child(app_content, "MyApp")
    end

    test "is idempotent on re-run" do
      app_content = """
      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            MyApp.Repo
          ]

          Supervisor.start_link(children, [])
        end
      end
      """

      assert {:ok, first_inject} = Injector.inject_vault_child(app_content, "MyApp")
      assert {:already_injected, ^first_inject} =
               Injector.inject_vault_child(first_inject, "MyApp")
    end
  end

  # -- Template file existence --

  describe "template files" do
    @template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.gen.oauth"])

    test "user_identity.ex template exists and has required content" do
      content = File.read!(Path.join(@template_dir, "user_identity.ex"))
      assert String.contains?(content, "Encrypted.Binary")
      assert String.contains?(content, "unique_constraint([:user_id, :provider])")
      assert String.contains?(content, "unique_constraint([:provider, :provider_uid])")
      assert String.contains?(content, "String.downcase")
    end

    test "vault.ex template exists and has required content" do
      content = File.read!(Path.join(@template_dir, "vault.ex"))
      assert String.contains?(content, "Cloak.Vault")
      assert String.contains?(content, "CLOAK_KEY")
      assert String.contains?(content, "Base.decode64!")
    end

    test "encrypted_binary.ex template exists and has required content" do
      content = File.read!(Path.join(@template_dir, "encrypted_binary.ex"))
      assert String.contains?(content, "Cloak.Ecto.Binary")
    end

    test "oauth_migration.exs template has correct table and indexes" do
      content = File.read!(Path.join(@template_dir, "oauth_migration.exs"))
      assert String.contains?(content, "create table(:user_identities)")
      assert String.contains?(content, "unique_index(:user_identities, [:user_id, :provider])")
      assert String.contains?(content, "unique_index(:user_identities, [:provider, :provider_uid])")
      assert String.contains?(content, ":encrypted_access_token, :binary")
    end

    test "oauth_controller.ex template delegates to Sigra.OAuth" do
      content = File.read!(Path.join(@template_dir, "oauth_controller.ex"))
      assert String.contains?(content, "def request")
      assert String.contains?(content, "def callback")
      assert String.contains?(content, "Sigra.OAuth.authorize_url")
      assert String.contains?(content, "Sigra.OAuth.handle_callback")
      assert String.contains?(content, ":sigra_oauth_state")
      assert String.contains?(content, ":sigra_oauth_link_intent")
    end

    test "oauth_html.ex template has provider icons" do
      content = File.read!(Path.join(@template_dir, "oauth_html.ex"))
      assert String.contains?(content, "def oauth_provider_icon(:google)")
      assert String.contains?(content, "def oauth_provider_icon(:github)")
      assert String.contains?(content, "def oauth_provider_icon(:apple)")
      assert String.contains?(content, "def oauth_provider_icon(:facebook)")
      assert String.contains?(content, ~s(aria-hidden="true"))
    end

    test "oauth_buttons.html.heex template has dynamic provider rendering" do
      content = File.read!(Path.join(@template_dir, "oauth_buttons.html.heex"))
      assert String.contains?(content, "Continue with")
      assert String.contains?(content, "space-y-3")
      assert String.contains?(content, "oauth_providers")
    end

    test "oauth_settings.html.heex template has all required sections" do
      content = File.read!(Path.join(@template_dir, "oauth_settings.html.heex"))
      assert String.contains?(content, "Connected Accounts")
      assert String.contains?(content, "Set a password first")
      assert String.contains?(content, "All available providers are connected")
      assert String.contains?(content, "data-confirm")
      assert String.contains?(content, "No connected accounts")
      assert String.contains?(content, "Add a sign-in method")
    end

    test "oauth_settings_live.ex template exists" do
      content = File.read!(Path.join(@template_dir, "oauth_settings_live.ex"))
      assert String.contains?(content, "defmodule")
      assert String.contains?(content, "Connected Accounts")
      assert String.contains?(content, "handle_event")
    end

    test "provider_linked_email.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "provider_linked_email.ex"))
      content = File.read!(Path.join(@template_dir, "provider_linked_email.ex"))
      assert String.contains?(content, "linked to your account")
      assert String.contains?(content, "Secure your account")
    end

    test "provider_unlinked_email.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "provider_unlinked_email.ex"))
      content = File.read!(Path.join(@template_dir, "provider_unlinked_email.ex"))
      assert String.contains?(content, "removed from your account")
      assert String.contains?(content, "Secure your account")
    end

    test "oauth_test_helpers.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "oauth_test_helpers.ex"))
      content = File.read!(Path.join(@template_dir, "oauth_test_helpers.ex"))
      assert String.contains?(content, "Sigra.Testing")
      assert String.contains?(content, "oauth_login")
    end
  end

  # -- Mix task module existence --

  describe "Mix.Tasks.Sigra.Gen.Oauth" do
    test "module is defined" do
      assert Code.ensure_loaded?(Mix.Tasks.Sigra.Gen.Oauth)
    end

    test "module has @shortdoc" do
      {:docs_v1, _, _, _, %{"en" => _}, _, _} = Code.fetch_docs(Mix.Tasks.Sigra.Gen.Oauth)
    end
  end
end
