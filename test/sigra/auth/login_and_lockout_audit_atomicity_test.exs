defmodule Sigra.Auth.LoginAndLockoutAuditAtomicityTest do
  use ExUnit.Case, async: false

  import Mox

  alias Sigra.Audit.Assertions
  alias Sigra.Auth
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  setup :verify_on_exit!

  defmodule LoginUser do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "b3_login_users_43" do
      field(:email, :string)
      field(:hashed_password, :string)
      field(:confirmed_at, :utc_datetime)
      field(:failed_login_attempts, :integer, default: 0)
      field(:locked_at, :utc_datetime)
      timestamps(type: :utc_datetime)
    end
  end

  defmodule SSOOnlyOrganizations do
    def local_auth_policy_for(%{email: "b3-sso@example.com"}, _opts) do
      %{
        organization_id: "org-b3",
        enforcement_mode: :sso_required,
        break_glass: false,
        password_login: :deny,
        password_reset: :deny
      }
    end

    def local_auth_policy_for(_user, _opts) do
      %{password_login: :allow, password_reset: :allow, break_glass: false}
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS b3_login_users_43 CASCADE", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE b3_login_users_43 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text NOT NULL,
        hashed_password text NOT NULL,
        confirmed_at timestamp,
        failed_login_attempts integer NOT NULL DEFAULT 0,
        locked_at timestamp,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE IF NOT EXISTS audit_events (
        id uuid PRIMARY KEY,
        occurred_at timestamp NOT NULL DEFAULT now(),
        action varchar(255) NOT NULL,
        outcome varchar(32) NOT NULL DEFAULT 'success',
        actor_id uuid,
        actor_type varchar(64) NOT NULL DEFAULT 'user',
        target_id uuid,
        target_type varchar(64),
        ip_address varchar(64),
        user_agent varchar(512),
        metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
        organization_id uuid,
        effective_user_id uuid,
        inserted_at timestamp NOT NULL DEFAULT now()
      )
      """
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "TRUNCATE TABLE b3_login_users_43, audit_events RESTART IDENTITY CASCADE",
      []
    )

    %{repo: repo}
  end

  defp sigra_config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: LoginUser,
      otp_app: :sigra,
      organizations_module: SSOOnlyOrganizations,
      audit: [audit_schema: AuditTestEvent],
      session: [store: Sigra.MockSessionStore, session_schema: LoginUser],
      suspicious_login: [enabled: false, notify: false],
      lockout: [threshold: 5, duration: 900, notify: false]
    )
  end

  test "config authenticate: auth.login.success + lockout reset share one transaction when audit enabled",
       %{
         repo: repo
       } do
    password = "long_password_123"
    hashed = Sigra.Crypto.hash_password(password)

    {:ok, user} =
      %LoginUser{}
      |> Ecto.Changeset.change(%{
        email: "b3-login@example.com",
        hashed_password: hashed,
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        failed_login_attempts: 2,
        locked_at: nil
      })
      |> repo.insert()

    Sigra.MockSessionStore
    |> expect(:create, fn uid, _metadata, _opts ->
      assert uid == user.id

      {:ok,
       %Sigra.Session{
         id: 1,
         user_id: uid,
         hashed_token: "token",
         type: :standard,
         inserted_at: DateTime.utc_now()
       }}
    end)

    cfg = sigra_config(repo)

    assert {:ok, logged_in, %{session: _}} =
             Auth.authenticate(cfg, %{
               "email" => user.email,
               "password" => password
             })

    refreshed = repo.get!(LoginUser, logged_in.id)
    assert refreshed.failed_login_attempts == 0

    Assertions.assert_audit_fields(repo, AuditTestEvent, %{
      action: "auth.login.success",
      actor_id: user.id,
      target_id: user.id,
      metadata: %{"method" => "password"}
    })
  end

  test "config authenticate: SSO-only denial returns before auth.login.success and session.create",
       %{repo: repo} do
    password = "long_password_123"
    hashed = Sigra.Crypto.hash_password(password)

    {:ok, user} =
      %LoginUser{}
      |> Ecto.Changeset.change(%{
        email: "b3-sso@example.com",
        hashed_password: hashed,
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        failed_login_attempts: 0,
        locked_at: nil
      })
      |> repo.insert()

    cfg = sigra_config(repo)

    assert {:error, :sso_required} =
             Auth.authenticate(cfg, %{
               "email" => user.email,
               "password" => password
             })

    assert is_nil(
             Assertions.latest_audit_event(repo, AuditTestEvent, action: "auth.login.success")
           )

    assert is_nil(Assertions.latest_audit_event(repo, AuditTestEvent, action: "session.create"))

    Assertions.assert_audit_fields(repo, AuditTestEvent, %{
      action: "auth.login.failure",
      actor_id: user.id,
      target_id: user.id,
      metadata: %{"reason" => "sso_required", "organization_id" => "org-b3"}
    })
  end
end
