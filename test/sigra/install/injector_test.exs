defmodule Sigra.Install.InjectorTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Injection
  alias Sigra.Install.Injector

  describe "inject_router_plugs/2" do
    test "injects plugs when marker is absent" do
      router_content = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
        end

        scope "/", MyAppWeb do
          pipe_through :browser
          get "/", PageController, :home
        end
      end
      """

      plug_code = """
        # Sigra authentication
        pipeline :auth do
          plug MyAppWeb.UserAuth, :fetch_current_scope
        end
      """

      assert {:ok, injected} = Injector.inject_router_plugs(router_content, plug_code)
      assert String.contains?(injected, "# Sigra authentication")
      assert String.contains?(injected, "pipeline :auth do")
    end

    test "returns :already_injected when marker is present" do
      router_content = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        # Sigra authentication
        pipeline :auth do
          plug MyAppWeb.UserAuth, :fetch_current_scope
        end
      end
      """

      plug_code = "# Sigra authentication\npipeline :auth do\nend"

      assert {:already_injected, ^router_content} =
               Injector.inject_router_plugs(router_content, plug_code)
    end

    test "injects after the first scope block" do
      router_content = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
        end

        scope "/", MyAppWeb do
          pipe_through :browser
          get "/", PageController, :home
        end
      end
      """

      plug_code = "  # Sigra authentication\n  pipeline :auth do\n  end\n"

      assert {:ok, injected} = Injector.inject_router_plugs(router_content, plug_code)
      assert String.contains?(injected, "# Sigra authentication")
    end
  end

  describe "apply/2 with :browser_pipeline anchor" do
    test "injects fetch_current_scope into the browser pipeline" do
      tmp = Path.join(System.tmp_dir!(), "sigra-router-#{System.unique_integer([:positive])}.ex")

      File.write!(
        tmp,
        """
        defmodule MyAppWeb.Router do
          use MyAppWeb, :router

          pipeline :browser do
            plug :accepts, ["html"]
            plug :fetch_session
          end
        end
        """
      )

      on_exit(fn -> File.rm_rf(tmp) end)

      injection = %Injection{
        target: tmp,
        marker: "plug :fetch_current_scope",
        anchor: :browser_pipeline,
        content: "    plug :fetch_current_scope"
      }

      assert {:ok, :injected} = Injector.apply(injection, [])

      injected = File.read!(tmp)
      assert injected =~ "plug :fetch_session\n    plug :fetch_current_scope\n  end"
    end
  end

  describe "inject_config/2" do
    test "injects config when marker is absent" do
      config_content = """
      import Config

      config :my_app,
        ecto_repos: [MyApp.Repo]

      import_config "\#{config_env()}.exs"
      """

      config_block = """

      # Sigra authentication
      config :my_app, :sigra,
        repo: MyApp.Repo,
        user_schema: MyApp.Accounts.User
      """

      assert {:ok, injected} = Injector.inject_config(config_content, config_block)
      assert String.contains?(injected, "# Sigra authentication")
      assert String.contains?(injected, ":sigra")
    end

    test "injects config before import_config on CRLF line endings without splitting the token" do
      config_content =
        "import Config\r\n\r\nconfig :my_app,\r\n  mode: :dev\r\n\r\nimport_config \"\#{config_env()}.exs\"\r\n"

      config_block = "\r\n# Sigra authentication\r\nconfig :my_app, :sigra, repo: MyApp.Repo\r\n"

      assert {:ok, injected} = Injector.inject_config(config_content, config_block)
      assert String.contains?(injected, "import_config \"\#{config_env()}.exs\"")
      refute String.contains?(injected, "\nport_config")
    end

    test "returns :already_injected when marker is present" do
      config_content = """
      import Config

      # Sigra authentication
      config :my_app, :sigra,
        repo: MyApp.Repo
      """

      config_block = "# Sigra authentication\nconfig :my_app, :sigra"

      assert {:already_injected, ^config_content} =
               Injector.inject_config(config_content, config_block)
    end
  end

  describe "inject_test_config/2" do
    test "injects argon2 test speedup config" do
      test_config = """
      import Config

      config :my_app, MyApp.Repo,
        pool: Ecto.Adapters.SQL.Sandbox
      """

      test_block = """

      # Sigra authentication
      # Speed up password hashing in tests
      config :argon2_elixir, t_cost: 1, m_cost: 8
      """

      assert {:ok, injected} = Injector.inject_test_config(test_config, test_block)
      assert String.contains?(injected, "config :argon2_elixir, t_cost: 1, m_cost: 8")
      assert String.contains?(injected, "# Sigra authentication")
    end

    test "is idempotent" do
      test_config = """
      import Config

      # Sigra authentication
      config :argon2_elixir, t_cost: 1, m_cost: 8
      """

      test_block = "# Sigra authentication\nconfig :argon2_elixir"

      assert {:already_injected, ^test_config} =
               Injector.inject_test_config(test_config, test_block)
    end
  end

  describe "inject_lifecycle_routes/2" do
    test "injects lifecycle routes when marker is absent" do
      router_content = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        # Sigra authentication
        pipeline :auth do
          plug MyAppWeb.UserAuth, :fetch_current_scope
        end

        scope "/", MyAppWeb do
          pipe_through [:browser, :auth]
          get "/", PageController, :home
        end
      end
      """

      route_code = """
        # Sigra account lifecycle
        scope "/", MyAppWeb do
          pipe_through [:browser, :auth, :require_authenticated_user]
          live "/users/settings", SettingsLive, :index
          live "/users/settings/confirm-email/:token", SettingsLive, :confirm_email
          live "/users/reactivation", ReactivationLive, :index
        end
      """

      assert {:ok, injected} = Injector.inject_lifecycle_routes(router_content, route_code)
      assert String.contains?(injected, "# Sigra account lifecycle")
      assert String.contains?(injected, "SettingsLive, :index")
      assert String.contains?(injected, "confirm-email/:token")
      assert String.contains?(injected, "ReactivationLive, :index")
    end

    test "returns :already_injected when lifecycle marker is present" do
      router_content = """
      defmodule MyAppWeb.Router do
        # Sigra account lifecycle
        live "/users/settings", SettingsLive, :index
      end
      """

      route_code = "# Sigra account lifecycle\nlive \"/users/settings\", SettingsLive"

      assert {:already_injected, ^router_content} =
               Injector.inject_lifecycle_routes(router_content, route_code)
    end

    test "injection is idempotent" do
      router_content = """
      defmodule MyAppWeb.Router do
        scope "/", MyAppWeb do
          get "/", PageController, :home
        end
      end
      """

      route_code = """
        # Sigra account lifecycle
        live "/users/settings", SettingsLive, :index
      """

      assert {:ok, first_inject} = Injector.inject_lifecycle_routes(router_content, route_code)
      assert {:already_injected, ^first_inject} = Injector.inject_lifecycle_routes(first_inject, route_code)
    end
  end

  describe "inject_oban_lifecycle_queue/1" do
    test "injects lifecycle queue alongside mailer queue" do
      config_content = """
      config :my_app, Oban,
        repo: MyApp.Repo,
        queues: [sigra_mailer: 10]
      """

      assert {:ok, injected} = Injector.inject_oban_lifecycle_queue(config_content)
      assert String.contains?(injected, "sigra_lifecycle: 5")
      assert String.contains?(injected, "sigra_mailer: 10")
    end

    test "returns :already_injected when lifecycle queue present" do
      config_content = """
      config :my_app, Oban,
        queues: [sigra_mailer: 10, sigra_lifecycle: 5]
      """

      assert {:already_injected, ^config_content} =
               Injector.inject_oban_lifecycle_queue(config_content)
    end
  end

  describe "lifecycle_template_files/0" do
    test "includes auth_hooks.ex in file list" do
      files = Injector.lifecycle_template_files()
      assert "auth_hooks.ex" in files
    end

    test "includes settings_live.ex in file list" do
      files = Injector.lifecycle_template_files()
      assert "settings_live.ex" in files
    end

    test "includes reactivation_live.ex in file list" do
      files = Injector.lifecycle_template_files()
      assert "reactivation_live.ex" in files
    end
  end

  describe "inject_conn_case/2" do
    test "injects auth helper import" do
      conn_case = """
      defmodule MyAppWeb.ConnCase do
        use ExUnit.CaseTemplate

        using do
          quote do
            @endpoint MyAppWeb.Endpoint
            use MyAppWeb, :verified_routes
            import Plug.Conn
            import Phoenix.ConnTest
          end
        end
      end
      """

      helper_code = "      import MyAppWeb.ConnCaseHelpers"

      assert {:ok, injected} = Injector.inject_conn_case(conn_case, helper_code)
      assert String.contains?(injected, "import MyAppWeb.ConnCaseHelpers")
    end

    test "is idempotent when helper already imported" do
      conn_case = """
      defmodule MyAppWeb.ConnCase do
        use ExUnit.CaseTemplate

        using do
          quote do
            import MyAppWeb.ConnCaseHelpers
            import Plug.Conn
          end
        end
      end
      """

      helper_code = "      import MyAppWeb.ConnCaseHelpers"

      assert {:already_injected, ^conn_case} =
               Injector.inject_conn_case(conn_case, helper_code)
    end
  end
end
