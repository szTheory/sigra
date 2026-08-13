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
    "app_sessions/user_app_login_attempt.ex",
    "app_sessions/first_party_apps.ex",
    "app_sessions/auth_app_sessions.ex",
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

    test "direct password login reuses the app-session artifact group" do
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
    test "renders digest-only hosted-code and direct-MFA attempt storage" do
      attempt = render_template("user_app_login_attempt.ex")
      migration = render_template("app_sessions_migration.exs")

      assert attempt =~ "defmodule MyApp.Accounts.UserAppLoginAttempt"
      assert attempt =~ "field :kind, Ecto.Enum, values: [:hosted_code, :direct_mfa]"
      assert attempt =~ "field :digest, :binary"
      assert attempt =~ "field :verifier_digest, :binary"
      assert attempt =~ "field :profile_id, :string"
      assert attempt =~ "field :callback, :string"
      assert attempt =~ "field :expires_at, :utc_datetime_usec"
      assert attempt =~ "field :consumed_at, :utc_datetime_usec"
      refute attempt =~ "field :password"
      refute attempt =~ "field :challenge"
      refute attempt =~ "field :state"

      assert migration =~ "create table(:user_app_login_attempts"
      assert migration =~ "create unique_index(:user_app_login_attempts, [:digest], @prefix_opts)"

      assert migration =~
               "create index(:user_app_login_attempts, [:kind, :expires_at, :consumed_at]"

      refute migration =~ "verifier, :string"
      refute migration =~ "password, :"
    end

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

  describe "static profiles and ceremony facade" do
    test "renders finite public profiles and host configuration without secrets" do
      profiles = render_template("first_party_apps.ex")
      facade = render_template("auth_app_sessions.ex", opts: [app_sessions: true])

      assert profiles =~ "defmodule MyApp.Accounts.FirstPartyApps"
      assert profiles =~ ~s(id: "ios-primary")
      assert profiles =~ ~s(client_ref: "ios-primary")
      assert profiles =~ ~s("com.sigra.app:/login")
      assert profiles =~ ":browser_required"
      assert profiles =~ ":password_allowed"
      refute profiles =~ "secret"
      refute profiles =~ "register"

      assert facade =~ "defmodule MyApp.Accounts.Auth.AppSessions"
      assert facade =~ "family_schema: MyApp.Accounts.UserAppSessionFamily"
      assert facade =~ "token_schema: MyApp.Accounts.UserAppSessionToken"
      assert facade =~ "app_login_code_schema: MyApp.Accounts.UserAppLoginAttempt"
      assert facade =~ "app_login_challenge_schema: MyApp.Accounts.UserAppLoginAttempt"
      assert facade =~ "Sigra.AppLogin.start_hosted"
      assert facade =~ "Sigra.AppLogin.approve_hosted"
      assert facade =~ "Sigra.AppLogin.exchange_hosted"
      assert facade =~ "Sigra.AppSession.refresh"
      assert facade =~ "Sigra.AppSession.revoke_family_for_user"
      refute facade =~ "authenticate_user"
      refute facade =~ "mfa_verify"
    end

    test "emits direct password and MFA adapters only behind the password-login flag" do
      direct =
        render_template("auth_app_sessions.ex",
          opts: [app_sessions: true, app_password_login: true]
        )

      hosted = render_template("auth_app_sessions.ex", opts: [app_sessions: true])

      assert direct =~ "MyApp.Accounts.authenticate_user"
      assert direct =~ "MyApp.Accounts.mfa_verify"
      assert direct =~ "MyApp.Accounts.mfa_verify_backup"
      assert direct =~ "Sigra.AppLogin.start_direct"
      assert direct =~ "Sigra.AppLogin.complete_direct_mfa"
      refute hosted =~ "start_direct"
      refute hosted =~ "complete_direct_mfa"
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
