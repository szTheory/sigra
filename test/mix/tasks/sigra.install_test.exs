defmodule Mix.Tasks.Sigra.InstallTest do
  use ExUnit.Case

  alias Mix.Tasks.Sigra.Install

  describe "argument parsing" do
    test "raises with no arguments" do
      assert_raise Mix.Error, ~r/Expected.*arguments/i, fn ->
        Install.run([])
      end
    end

    test "raises with too few arguments" do
      assert_raise Mix.Error, ~r/Expected.*arguments/i, fn ->
        Install.run(["Accounts"])
      end
    end

    test "raises with invalid context name" do
      assert_raise Mix.Error, ~r/context name/i, fn ->
        Install.run(["accounts", "User", "users"])
      end
    end

    test "raises with invalid schema name" do
      assert_raise Mix.Error, ~r/schema name/i, fn ->
        Install.run(["Accounts", "user", "users"])
      end
    end
  end

  describe "template rendering" do
    setup do
      tmp_dir = Path.join(System.tmp_dir!(), "sigra_install_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp_dir)
      on_exit(fn -> File.rm_rf!(tmp_dir) end)
      %{tmp_dir: tmp_dir}
    end

    test "renders user template with correct bindings", %{tmp_dir: _tmp_dir} do
      binding = [
        context_module: "MyApp.Accounts",
        schema_module: "MyApp.Accounts.User",
        schema_alias: "User",
        table_name: "users",
        web_module: "MyAppWeb",
        otp_app: :my_app,
        repo_module: "MyApp.Repo",
        binary_id: false,
        adapter: :postgres
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "user.ex"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "defmodule MyApp.Accounts.User do")
      assert String.contains?(content, "use Ecto.Schema")
      assert String.contains?(content, "field :email, :string")
      assert String.contains?(content, "field :password, :string, virtual: true, redact: true")
      assert String.contains?(content, "Sigra.Crypto.hash_password")
      refute String.contains?(content, "use Sigra.Schema")
      refute String.contains?(content, "binary_id")
    end

    test "renders user template with binary_id", %{tmp_dir: _tmp_dir} do
      binding = [
        context_module: "MyApp.Accounts",
        schema_module: "MyApp.Accounts.User",
        schema_alias: "User",
        table_name: "users",
        web_module: "MyAppWeb",
        otp_app: :my_app,
        repo_module: "MyApp.Repo",
        binary_id: true,
        adapter: :postgres
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "user.ex"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "@primary_key {:id, :binary_id, autogenerate: true}")
      assert String.contains?(content, "@foreign_key_type :binary_id")
    end

    test "renders migration template for postgres adapter" do
      binding = [
        repo_module: "MyApp.Repo",
        table_name: "users",
        binary_id: false,
        adapter: :postgres
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "migration.exs"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "CREATE EXTENSION IF NOT EXISTS citext")
      assert String.contains?(content, ":citext")
      assert String.contains?(content, "create table(:users)")
      assert String.contains?(content, "create unique_index(:users, [:email])")
    end

    test "renders migration template for mysql adapter" do
      binding = [
        repo_module: "MyApp.Repo",
        table_name: "users",
        binary_id: false,
        adapter: :mysql
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "migration.exs"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "size: 160")
      refute String.contains?(content, "citext")
    end

    test "renders migration template for sqlite adapter" do
      binding = [
        repo_module: "MyApp.Repo",
        table_name: "users",
        binary_id: false,
        adapter: :sqlite
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "migration.exs"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "collate: :nocase")
      refute String.contains?(content, "citext")
    end

    test "renders scope template with defstruct" do
      binding = [
        context_module: "MyApp.Accounts",
        schema_alias: "User"
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "scope.ex"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "defstruct user: nil")
      assert String.contains?(content, "MyApp.Accounts.Scope")
    end

    test "renders auth context template" do
      binding = [
        context_module: "MyApp.Accounts",
        schema_alias: "User",
        repo_module: "MyApp.Repo",
        web_module: "MyAppWeb"
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "auth.ex"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "defmodule MyApp.Accounts do")
      assert String.contains?(content, "def register_user(")
      assert String.contains?(content, "def get_user_by_email(")
      assert String.contains?(content, "def get_user_by_email_and_password(")
      assert String.contains?(content, "def generate_user_session_token(")
      assert String.contains?(content, "def get_user_by_session_token(")
      assert String.contains?(content, "def delete_user_session_token(")
    end

    test "renders error handler with Sigra.Plug.ErrorHandler behaviour" do
      binding = [
        web_module: "MyAppWeb"
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "error_handler.ex"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "@behaviour Sigra.Plug.ErrorHandler")
      assert String.contains?(content, "def auth_error(conn, :unauthenticated")
      assert String.contains?(content, "def auth_error(conn, :stale_sudo")
      assert String.contains?(content, "def auth_error(conn, :rate_limited")
    end

    test "renders fixtures template" do
      binding = [
        context_module: "MyApp.Accounts",
        schema_alias: "User"
      ]

      template_path = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "auth_fixtures.ex"])
      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "def user_fixture(")
      assert String.contains?(content, "def extract_user_token(")
      assert String.contains?(content, "unique_user_email")
    end
  end
end
