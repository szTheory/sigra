defmodule Sigra.Install.AppSessionsGeneratorTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.AppSessions
  alias Sigra.Install.MigrationTimestamps

  @binding [
    otp_app: :my_app,
    context_alias: "Accounts",
    context_module: "MyApp.Accounts",
    schema_module: "MyApp.Accounts.User",
    schema_alias: "User",
    table_name: "users",
    web_module: "MyAppWeb",
    app_module: "MyApp",
    repo_module: "MyApp.Repo",
    binary_id: true,
    adapter: :postgres
  ]

  @app_sources [
    "app_sessions/user_app_session_family.ex",
    "app_sessions/user_app_session_token.ex",
    "app_sessions/app_sessions_migration.exs"
  ]

  @template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "app_sessions"])

  describe "feature selection" do
    test "is enabled only when app sessions are selected" do
      assert AppSessions.enabled?(app_sessions: true)
      refute AppSessions.enabled?(app_sessions: false, app_password_login: true)
      refute AppSessions.enabled?(api: true)
      refute AppSessions.enabled?(jwt: true)
    end

    test "the complete option matrix keeps API, JWT, and app-session artifacts independent" do
      for app_sessions? <- [false, true],
          app_password_login? <- [false, true],
          api? <- [false, true],
          jwt? <- [false, true] do
        sources =
          @binding
          |> Keyword.put(:opts,
            app_sessions: app_sessions?,
            app_password_login: app_password_login?,
            api: api?,
            jwt: jwt?
          )
          |> AppSessions.files()
          |> Enum.map(fn {:eex, source, _target} -> source end)

        assert Enum.all?(@app_sources, &(&1 in sources == app_sessions?))
        refute Enum.any?(sources, &String.starts_with?(&1, "core/api_token"))
        refute "core/auth_jwt.ex" in sources
      end
    end

    test "direct password login adds no artifact group before its templates are registered" do
      direct_sources =
        @binding
        |> Keyword.put(:opts,
          app_sessions: true,
          app_password_login: true,
          api: false,
          jwt: false
        )
        |> AppSessions.files()
        |> Enum.map(fn {:eex, source, _target} -> source end)

      assert direct_sources == @app_sources
    end
  end

  describe "migration slots" do
    test "allocates deterministic family, token, and ceremony slots" do
      slots = AppSessions.migrations(@binding)
      assert Enum.map(slots, &elem(&1, 0)) == [:family, :token, :ceremony]

      timestamps =
        MigrationTimestamps.allocate([AppSessions], ~U[2026-08-12 12:00:00Z])[AppSessions]

      assert timestamps == %{
               family: "20260812120000",
               token: "20260812120001",
               ceremony: "20260812120002"
             }
    end
  end

  describe "rendered app-session persistence" do
    test "renders paired Phase 245 family and token schemas" do
      family = render_template("user_app_session_family.ex")
      token = render_template("user_app_session_token.ex")

      assert family =~ "defmodule MyApp.Accounts.UserAppSessionFamily"
      assert family =~ "field :client_ref, :string"
      assert family =~ "field :absolute_expires_at, :utc_datetime_usec"
      assert family =~ "field :revoked_at, :utc_datetime_usec"
      assert family =~ "belongs_to :user, MyApp.Accounts.User"

      assert token =~ "defmodule MyApp.Accounts.UserAppSessionToken"
      assert token =~ "field :kind, Ecto.Enum, values: [:access, :refresh]"
      assert token =~ "field :digest, :binary"
      assert token =~ "field :expires_at, :utc_datetime_usec"
      assert token =~ "field :consumed_at, :utc_datetime_usec"
      assert token =~ "belongs_to :family, MyApp.Accounts.UserAppSessionFamily"
    end

    test "renders digest-only family and token migration inventory with auth prefix" do
      migration = render_template("app_sessions_migration.exs", auth_prefix: "auth")

      assert migration =~ "create table(:user_app_session_families"
      assert migration =~ "create table(:user_app_session_tokens"
      assert migration =~ "add :digest, :binary, null: false"
      assert migration =~ "create unique_index(:user_app_session_tokens, [:digest], @prefix_opts)"
      assert migration =~ "create index(:user_app_session_families, [:user_id, :revoked_at]"

      assert migration =~
               "create index(:user_app_session_tokens, [:family_id, :kind, :consumed_at]"

      assert migration =~ "on_delete: :delete_all"
      assert migration =~ "@auth_prefix \"auth\""
      refute migration =~ "access_token"
      refute migration =~ "refresh_token"
    end

    test "does not select persistence files when app sessions are disabled" do
      assert [] = AppSessions.files(Keyword.put(@binding, :opts, app_sessions: false))
    end
  end

  defp render_template(name, overrides \\ []) do
    binding =
      @binding
      |> Keyword.merge(auth_prefix: nil, migration_timestamps: %{ceremony: "20260812120002"})
      |> Keyword.merge(overrides)

    EEx.eval_file(Path.join(@template_dir, name), binding)
  end
end
