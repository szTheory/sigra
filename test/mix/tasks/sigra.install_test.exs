defmodule Mix.Tasks.Sigra.InstallTest do
  use ExUnit.Case

  alias Mix.Tasks.Sigra.Install

  defmodule PostgresRepo do
    def __adapter__, do: Ecto.Adapters.Postgres
  end

  defmodule MyXQLRepo do
    def __adapter__, do: Ecto.Adapters.MyXQL
  end

  defmodule SQLiteRepo do
    def __adapter__, do: Ecto.Adapters.SQLite3
  end

  defmodule UnknownRepo do
    def __adapter__, do: Sigra.Test.UnsupportedAdapter
  end

  defmodule UndetectableRepo do
  end

  setup do
    otp_app = Mix.Phoenix.otp_app()
    previous_repos = Application.get_env(otp_app, :ecto_repos)

    on_exit(fn ->
      if is_nil(previous_repos) do
        Application.delete_env(otp_app, :ecto_repos)
      else
        Application.put_env(otp_app, :ecto_repos, previous_repos)
      end
    end)

    %{otp_app: otp_app}
  end

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

  describe "adapter validation" do
    test "refuses MyXQL projects before generation", %{otp_app: otp_app} do
      Application.put_env(otp_app, :ecto_repos, [MyXQLRepo])

      assert_raise Mix.Error,
                   ~r/Sigra supports PostgreSQL only\. Detected Ecto\.Adapters\.MyXQL\. mix sigra\.install cannot continue\. See guides\/introduction\/installation\.md/,
                   fn ->
                     Install.run(["Accounts", "User", "users"])
                   end
    end

    test "refuses SQLite projects before generation", %{otp_app: otp_app} do
      Application.put_env(otp_app, :ecto_repos, [SQLiteRepo])

      assert_raise Mix.Error,
                   ~r/Sigra supports PostgreSQL only\. Detected Ecto\.Adapters\.SQLite3\. mix sigra\.install cannot continue\. See guides\/introduction\/installation\.md/,
                   fn ->
                     Install.run(["Accounts", "User", "users"])
                   end
    end

    test "refuses unknown adapters before generation", %{otp_app: otp_app} do
      Application.put_env(otp_app, :ecto_repos, [UnknownRepo])

      assert_raise Mix.Error,
                   ~r/Sigra supports PostgreSQL only\. Detected Sigra\.Test\.UnsupportedAdapter\. mix sigra\.install cannot continue\. See guides\/introduction\/installation\.md/,
                   fn ->
                     Install.run(["Accounts", "User", "users"])
                   end
    end

    test "refuses undetectable adapters before generation", %{otp_app: otp_app} do
      Application.put_env(otp_app, :ecto_repos, [UndetectableRepo])

      assert_raise Mix.Error,
                   ~r/Sigra supports PostgreSQL only\. Detected an unknown adapter\. mix sigra\.install cannot continue\. See guides\/introduction\/installation\.md/,
                   fn ->
                     Install.run(["Accounts", "User", "users"])
                   end
    end
  end

  describe "template rendering" do
    setup do
      tmp_dir =
        Path.join(System.tmp_dir!(), "sigra_install_test_#{System.unique_integer([:positive])}")

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

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "user.ex"])

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

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "user.ex"])

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

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "migration.exs"])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "CREATE EXTENSION IF NOT EXISTS citext")
      assert String.contains?(content, ":citext")
      assert String.contains?(content, "create table(:users)")
      assert String.contains?(content, "unique_index(:users, [:email]")
    end

    test "renders scope template with defstruct" do
      binding = [
        context_module: "MyApp.Accounts",
        schema_alias: "User",
        # Phase 24.1: scope.ex gates Organization struct references on
        # `<%= if organizations? do %>` so the --no-organizations install
        # path compiles.
        organizations?: true
      ]

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "scope.ex"])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "defstruct user: nil")
      assert String.contains?(content, "MyApp.Accounts.Scope")
    end

    test "renders auth context template" do
      binding = [
        context_module: "MyApp.Accounts",
        schema_alias: "User",
        repo_module: "MyApp.Repo",
        web_module: "MyAppWeb",
        otp_app: :my_app,
        api: false,
        jwt: false,
        organizations?: true,
        passkeys?: false,
        opts: []
      ]

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "auth.ex"])

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
        web_module: "MyAppWeb",
        # Phase 24.1: error_handler.ex gates the :no_active_org branch
        # on `<%= if organizations? do %>` so the --no-organizations
        # install leg compiles (it avoids referencing the unverified
        # ~p"/organizations" route).
        organizations?: true
      ]

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "error_handler.ex"])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "@behaviour Sigra.Plug.ErrorHandler")
      assert String.contains?(content, "def auth_error(conn, :unauthenticated")
      assert String.contains?(content, "def auth_error(conn, :stale_sudo")
      assert String.contains?(content, "def auth_error(conn, :rate_limited")
    end

    test "renders fixtures template" do
      binding = [
        context_module: "MyApp.Accounts",
        context_alias: "Accounts",
        schema_alias: "User",
        repo_module: "MyApp.Repo",
        web_module: "MyAppWeb",
        app_module: "MyApp"
      ]

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "auth_fixtures.ex"])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "def user_fixture(")
      assert String.contains?(content, "def extract_user_token(")
      assert String.contains?(content, "unique_user_email")
    end

    test "renders fixtures template with Phase 4 session fixtures" do
      binding = [
        context_module: "MyApp.Accounts",
        context_alias: "Accounts",
        schema_alias: "User",
        repo_module: "MyApp.Repo",
        web_module: "MyAppWeb",
        app_module: "MyApp"
      ]

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "auth_fixtures.ex"])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "def session_fixture(")
      assert String.contains?(content, "def remembered_session_fixture(")
      assert String.contains?(content, "def locked_user_fixture(")
      assert String.contains?(content, "def sudo_session_fixture(")
      assert String.contains?(content, "MyApp.Accounts.UserSession")
      assert String.contains?(content, "MyApp.Repo.insert!")
    end

    test "renders session_live template with UI-SPEC compliance" do
      binding = [
        web_module: "MyAppWeb",
        context_module: "MyApp.Accounts"
      ]

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "session_live.ex"])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "defmodule MyAppWeb.Auth.SessionLive do")
      assert String.contains?(content, "Active Sessions")
      assert String.contains?(content, "These devices are currently signed in to your account.")
      assert String.contains?(content, "This device")
      assert String.contains?(content, "Revoke session")
      assert String.contains?(content, "Log out of all devices")
      assert String.contains?(content, "Session revoked.")
      assert String.contains?(content, "mx-auto max-w-2xl")
      assert String.contains?(content, "bg-brand/10")
      assert String.contains?(content, "text-red-600")
      assert String.contains?(content, "data-confirm")
    end

    test "renders user_session schema template" do
      binding = [
        context_module: "MyApp.Accounts",
        schema_alias: "User",
        binary_id: false
      ]

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "user_session.ex"])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "defmodule MyApp.Accounts.UserSession do")
      assert String.contains?(content, ~s|schema "user_sessions"|)
      assert String.contains?(content, "field :hashed_token, :binary")
      assert String.contains?(content, "belongs_to :user")
    end

    test "renders sudo_controller template" do
      binding = [
        web_module: "MyAppWeb",
        context_module: "MyApp.Accounts"
      ]

      template_path =
        Path.join([
          File.cwd!(),
          "priv",
          "templates",
          "sigra.install",
          "core",
          "sudo_controller.ex"
        ])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "defmodule MyAppWeb.Auth.SudoController do")
      assert String.contains?(content, "def new(conn,")
      assert String.contains?(content, "def create(conn,")
      assert String.contains?(content, "Sigra.Crypto.verify_password")
    end

    test "renders sudo_html template" do
      binding = [
        web_module: "MyAppWeb"
      ]

      template_path =
        Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", "sudo_html.ex"])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "defmodule MyAppWeb.Auth.SudoHTML do")
      assert String.contains?(content, "Confirm your password")
      assert String.contains?(content, ~s|action={~p"/users/sudo"}|)
    end

    test "renders conn_case_helpers with session type options" do
      binding = [
        web_module: "MyAppWeb",
        context_module: "MyApp.Accounts",
        context_alias: "Accounts",
        app_module: "MyApp"
      ]

      template_path =
        Path.join([
          File.cwd!(),
          "priv",
          "templates",
          "sigra.install",
          "core",
          "conn_case_helpers.ex"
        ])

      content = EEx.eval_file(template_path, binding)

      assert String.contains?(content, "def log_in_user(conn, user, opts \\\\ [])")
      assert String.contains?(content, "Keyword.get(opts, :type, :standard)")
    end
  end
end
