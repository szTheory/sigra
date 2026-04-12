defmodule Sigra.Install.APITokenGeneratorTest do
  use ExUnit.Case, async: true

  @template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  @base_binding [
    context_module: "MyApp.Auth",
    schema_module: "MyApp.Auth.User",
    schema_alias: "User",
    table_name: "users",
    web_module: "MyAppWeb",
    otp_app: :my_app,
    repo_module: "MyApp.Repo",
    app_module: "MyApp",
    app_name: "MyApp",
    from_email: "noreply@example.com",
    log_in_url: "/users/log_in",
    settings_url: "http://localhost:4000/users/settings",
    binary_id: false,
    adapter: :postgres,
    api: true,
    jwt: false
  ]

  describe "API token template files exist" do
    test "api_token_migration.exs template exists" do
      assert File.exists?(Path.join(@template_dir, "api_token_migration.exs"))
    end

    test "user_api_token.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "user_api_token.ex"))
    end

    test "api_token_controller.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "api_token_controller.ex"))
    end

    test "token_controller.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "token_controller.ex"))
    end

    test "api_token_created_email.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "api_token_created_email.ex"))
    end

    test "auth_api_token.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "auth_api_token.ex"))
    end
  end

  describe "api_token_migration.exs template (Postgres)" do
    test "creates user_api_tokens table" do
      content = render_template("api_token_migration.exs")
      assert content =~ "create table(:user_api_tokens, primary_key: false)"
    end

    test "contains binary_id primary key" do
      content = render_template("api_token_migration.exs")
      assert content =~ "add :id, :binary_id, primary_key: true"
    end

    test "contains hashed_token binary column" do
      content = render_template("api_token_migration.exs")
      assert content =~ "add :hashed_token, :binary, null: false"
    end

    test "contains name column with size limit" do
      content = render_template("api_token_migration.exs")
      assert content =~ "add :name, :string, null: false, size: 255"
    end

    test "uses array type for scopes on Postgres" do
      content = render_template("api_token_migration.exs")
      assert content =~ "add :scopes, {:array, :string}, default: []"
    end

    test "contains unique index on hashed_token" do
      content = render_template("api_token_migration.exs")
      assert content =~ "create unique_index(:user_api_tokens, [:hashed_token])"
    end

    test "contains composite index for active token lookup" do
      content = render_template("api_token_migration.exs")
      assert content =~ "create index(:user_api_tokens, [:user_id, :revoked_at, :expires_at])"
    end

    test "adds token_epoch to users table" do
      content = render_template("api_token_migration.exs")
      assert content =~ ":token_epoch, :integer, default: 0, null: false"
    end

    test "does NOT contain updated_at" do
      content = render_template("api_token_migration.exs")
      refute content =~ "updated_at"
    end

    test "contains up/down functions for Postgres (not change)" do
      content = render_template("api_token_migration.exs")
      assert content =~ "def up do"
      assert content =~ "def down do"
    end
  end

  describe "api_token_migration.exs template (MySQL)" do
    test "uses string type for scopes on MySQL" do
      content = render_template("api_token_migration.exs", adapter: :mysql)
      assert content =~ "add :scopes, :string"
      refute content =~ "{:array, :string}"
    end

    test "uses change function for MySQL" do
      content = render_template("api_token_migration.exs", adapter: :mysql)
      assert content =~ "def change do"
    end
  end

  describe "api_token_migration.exs template (SQLite)" do
    test "uses string type for scopes on SQLite" do
      content = render_template("api_token_migration.exs", adapter: :sqlite)
      assert content =~ "add :scopes, :string"
      refute content =~ "{:array, :string}"
    end
  end

  describe "user_api_token.ex template" do
    test "defines schema for user_api_tokens" do
      content = render_template("user_api_token.ex")
      assert content =~ ~s(schema "user_api_tokens")
    end

    test "uses binary_id primary key" do
      content = render_template("user_api_token.ex")
      assert content =~ "@primary_key {:id, :binary_id, autogenerate: true}"
    end

    test "uses array type for scopes on Postgres" do
      content = render_template("user_api_token.ex")
      assert content =~ "field :scopes, {:array, :string}, default: []"
    end

    test "uses StringList type for scopes on MySQL" do
      content = render_template("user_api_token.ex", adapter: :mysql)
      assert content =~ "field :scopes, Sigra.Ecto.Types.StringList"
    end

    test "belongs_to user" do
      content = render_template("user_api_token.ex")
      assert content =~ "belongs_to :user, MyApp.Auth.User"
    end

    test "contains moduledoc" do
      content = render_template("user_api_token.ex")
      assert content =~ "@moduledoc"
      assert content =~ "API tokens"
    end
  end

  describe "api_token_controller.ex template" do
    test "defines index action" do
      content = render_template("api_token_controller.ex")
      assert content =~ "def index(conn, params)"
    end

    test "defines create action" do
      content = render_template("api_token_controller.ex")
      assert content =~ "def create(conn, %{\"token\" => token_params})"
    end

    test "delegates to Auth.create_api_token" do
      content = render_template("api_token_controller.ex")
      assert content =~ "Auth.create_api_token"
    end

    test "delegates to Auth.list_api_tokens" do
      content = render_template("api_token_controller.ex")
      assert content =~ "Auth.list_api_tokens"
    end

    test "delegates to Auth.revoke_api_token" do
      content = render_template("api_token_controller.ex")
      assert content =~ "Auth.revoke_api_token"
    end

    test "delegates to Auth.revoke_all_api_tokens" do
      content = render_template("api_token_controller.ex")
      assert content =~ "Auth.revoke_all_api_tokens"
    end

    test "returns raw_key only in create response (D-10, T-07-19)" do
      content = render_template("api_token_controller.ex")
      # raw_key in create
      assert content =~ "raw_key: raw_key"
      # token_json does NOT include raw_key
      refute Regex.match?(~r/defp token_json.*raw_key/s, content)
    end

    test "contains delete_all action" do
      content = render_template("api_token_controller.ex")
      assert content =~ "def delete_all(conn, _params)"
    end

    test "contains pagination support" do
      content = render_template("api_token_controller.ex")
      assert content =~ "next_cursor"
      assert content =~ "parse_limit"
    end

    test "contains changeset_errors helper" do
      content = render_template("api_token_controller.ex")
      assert content =~ "defp changeset_errors(changeset)"
    end
  end

  describe "token_controller.ex template" do
    test "defines create action with email/password" do
      content = render_template("token_controller.ex")
      assert content =~ "def create(conn, %{\"email\" => email, \"password\" => password}"
    end

    test "handles MFA required response (D-47)" do
      content = render_template("token_controller.ex")
      assert content =~ "mfa_required: true"
      assert content =~ "mfa_token"
    end

    test "defines refresh action" do
      content = render_template("token_controller.ex")
      assert content =~ "def refresh(conn, %{\"refresh_token\" => refresh_token})"
    end

    test "handles reuse detection" do
      content = render_template("token_controller.ex")
      assert content =~ ":reuse_detected"
      assert content =~ "token theft detected"
    end

    test "defines MFA action" do
      content = render_template("token_controller.ex")
      assert content =~ "def mfa(conn, %{\"mfa_token\" => mfa_token, \"code\" => code}"
    end

    test "defines revoke action" do
      content = render_template("token_controller.ex")
      assert content =~ "def revoke(conn, %{\"refresh_token\" => refresh_token})"
    end

    test "always returns success on revoke (prevent info leakage)" do
      content = render_template("token_controller.ex")
      # revoke always returns ok
      assert content =~ ~r/def revoke.*json\(conn, %\{ok: true\}\)/s
    end
  end

  describe "api_token_created_email.ex template" do
    test "defines api_token_created_email function" do
      content = render_email_template("api_token_created_email.ex")
      assert content =~ "api_token_created_email"
    end

    test "includes token name in email" do
      content = render_email_template("api_token_created_email.ex")
      assert content =~ "Token name:"
    end

    test "includes scopes in email" do
      content = render_email_template("api_token_created_email.ex")
      assert content =~ "Scopes:"
    end

    test "includes revocation guidance (T-07-22)" do
      content = render_email_template("api_token_created_email.ex")
      assert content =~ "revoke it immediately"
    end

    test "never includes raw key in email (T-07-22)" do
      content = render_email_template("api_token_created_email.ex")
      refute content =~ "raw_key"
    end
  end

  describe "auth_api_token.ex template" do
    test "defines create_api_token function" do
      content = render_api_auth_template()
      assert content =~ "def create_api_token(user, attrs)"
    end

    test "defines revoke_api_token function" do
      content = render_api_auth_template()
      assert content =~ "def revoke_api_token(token_id)"
    end

    test "defines revoke_all_api_tokens function" do
      content = render_api_auth_template()
      assert content =~ "def revoke_all_api_tokens(user)"
    end

    test "defines list_api_tokens function" do
      content = render_api_auth_template()
      assert content =~ "def list_api_tokens(user_id, opts \\\\ [])"
    end

    test "defines list_api_scopes function" do
      content = render_api_auth_template()
      assert content =~ "def list_api_scopes do"
    end

    test "delegates to Sigra.Auth" do
      content = render_api_auth_template()
      assert content =~ "Sigra.Auth.create_api_token(sigra_config()"
      assert content =~ "Sigra.Auth.revoke_api_token(sigra_config()"
      assert content =~ "Sigra.Auth.list_api_tokens(sigra_config()"
    end
  end

  describe "auth_api_token.ex template with JWT" do
    test "includes JWT functions when jwt: true" do
      content = render_api_auth_template(jwt: true)
      assert content =~ "def generate_jwt_tokens(user, scopes)"
      assert content =~ "def refresh_jwt(raw_refresh_token)"
      assert content =~ "def revoke_jwt_refresh(raw_refresh_token)"
    end

    test "excludes JWT functions when jwt: false" do
      content = render_api_auth_template(jwt: false)
      refute content =~ "def generate_jwt_tokens"
      refute content =~ "def refresh_jwt"
    end
  end

  describe "injector API functions" do
    test "inject_api_routes adds routes when marker absent" do
      router = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        scope "/", MyAppWeb do
          get "/", PageController, :home
        end
      end
      """

      api_routes = """
        # Sigra API
        scope "/api", MyAppWeb do
          get "/tokens", APITokenController, :index
        end
      """

      assert {:ok, result} = Sigra.Install.Injector.inject_api_routes(router, api_routes)
      assert result =~ "Sigra API"
      assert result =~ "APITokenController"
    end

    test "inject_api_routes is idempotent" do
      router = """
      defmodule MyAppWeb.Router do
        # Sigra API
        scope "/api", MyAppWeb do
          get "/tokens", APITokenController, :index
        end
      end
      """

      assert {:already_injected, _} = Sigra.Install.Injector.inject_api_routes(router, "new code")
    end

    test "inject_jwt_routes adds routes when marker absent" do
      router = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
      end
      """

      jwt_routes = """
        # Sigra JWT
        scope "/api/auth", MyAppWeb do
          post "/token", TokenController, :create
        end
      """

      assert {:ok, result} = Sigra.Install.Injector.inject_jwt_routes(router, jwt_routes)
      assert result =~ "Sigra JWT"
      assert result =~ "TokenController"
    end

    test "inject_jwt_routes is idempotent" do
      router = """
      defmodule MyAppWeb.Router do
        # Sigra JWT
        scope "/api/auth", MyAppWeb do
          post "/token", TokenController, :create
        end
      end
      """

      assert {:already_injected, _} = Sigra.Install.Injector.inject_jwt_routes(router, "new code")
    end

    test "inject_api_config adds config when absent" do
      config = """
      import Config

      config :my_app, MyAppWeb.Endpoint, url: [host: "localhost"]
      """

      api_config = """
      # Sigra API token configuration
      config :my_app, :sigra_api, api_token: [prefix: "sigra_sk_"]
      """

      assert {:ok, result} = Sigra.Install.Injector.inject_api_config(config, api_config)
      assert result =~ "api_token:"
    end

    test "inject_api_config is idempotent" do
      config = """
      import Config

      config :my_app, :sigra_api, api_token: [prefix: "sigra_sk_"]
      """

      assert {:already_injected, _} =
               Sigra.Install.Injector.inject_api_config(config, "new config")
    end
  end

  describe "install task includes API flags" do
    # Phase 11 Wave 4: --api/--jwt switches stay on the Mix task; the
    # API file list + router pipeline moved into
    # Sigra.Install.Features.Core.
    @install_path Path.join([File.cwd!(), "lib", "mix", "tasks", "sigra.install.ex"])
    @features_core_path Path.join([
                          File.cwd!(),
                          "lib",
                          "sigra",
                          "install",
                          "features",
                          "core.ex"
                        ])

    test "install task accepts --api flag" do
      source = File.read!(@install_path)
      assert source =~ "api: :boolean"
    end

    test "install task accepts --jwt flag" do
      source = File.read!(@install_path)
      assert source =~ "jwt: :boolean"
    end

    test "Features.Core includes api_token_migration in file list" do
      source = File.read!(@features_core_path)
      assert source =~ ~s("core/api_token_migration.exs")
    end

    test "Features.Core includes user_api_token in file list" do
      source = File.read!(@features_core_path)
      assert source =~ ~s("core/user_api_token.ex")
    end

    test "Features.Core includes api_token_controller in file list" do
      source = File.read!(@features_core_path)
      assert source =~ ~s("core/api_token_controller.ex")
    end

    test "Features.Core includes token_controller in jwt file list" do
      source = File.read!(@features_core_path)
      assert source =~ ~s("core/token_controller.ex")
    end

    test "Features.Core has API router injection content" do
      source = File.read!(@features_core_path)
      assert source =~ "# Sigra API"
      assert source =~ "APITokenController"
    end

    test "Features.Core has JWT router injection content" do
      source = File.read!(@features_core_path)
      assert source =~ "# Sigra JWT"
      assert source =~ "TokenController"
    end

    test "Features.Core generates API pipeline with FetchBearer" do
      source = File.read!(@features_core_path)
      assert source =~ "Sigra.Plug.FetchBearer"
    end

    test "Features.Core generates API pipeline with RequireAuthenticated" do
      source = File.read!(@features_core_path)
      assert source =~ "Sigra.Plug.RequireAuthenticated"
    end
  end

  # -- Helpers --

  defp render_template(name, overrides \\ []) do
    binding = Keyword.merge(@base_binding, overrides)
    path = Path.join(@template_dir, name)
    EEx.eval_file(path, binding)
  end

  defp render_email_template(name) do
    # Email templates use assigns syntax (@font_family, etc.)
    # Just read raw content for assertion-based testing
    Path.join(@template_dir, name) |> File.read!()
  end

  defp render_api_auth_template(overrides \\ []) do
    binding = Keyword.merge(@base_binding, overrides)
    path = Path.join(@template_dir, "auth_api_token.ex")
    EEx.eval_file(path, binding)
  end
end
