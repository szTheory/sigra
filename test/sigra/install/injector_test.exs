defmodule Sigra.Install.InjectorTest do
  use ExUnit.Case, async: true

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
