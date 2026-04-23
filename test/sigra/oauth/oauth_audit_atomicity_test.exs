defmodule Sigra.OAuthAuditAtomicityTest do
  @moduledoc """
  Rollback and constraint-rejection proofs for OAuth audit integration (phase 45
  narrative). Happy-path ceremony coverage lives in `Sigra.OAuthCeremonyAuditTest`
  (OA-01).
  """
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Sigra.OAuth.Callback
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule OAuthUser do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "oauth_atomic_users" do
      field(:email, :string)
      field(:confirmed_at, :utc_datetime)
      timestamps()
    end
  end

  defmodule OAuthIdentity do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "oauth_atomic_identities" do
      field(:user_id, :binary_id)
      field(:provider, :string)
      field(:provider_uid, :string)
      field(:provider_email, :string)
      field(:provider_name, :string)
      field(:provider_avatar_url, :string)
      field(:encrypted_access_token, :binary)
      field(:encrypted_refresh_token, :binary)
      field(:token_expires_at, :utc_datetime)
      field(:metadata, :map, default: %{})
      field(:last_used_at, :utc_datetime)
      timestamps()
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    for t <- ["oauth_atomic_identities", "oauth_atomic_users", "audit_events"] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE oauth_atomic_users (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text NOT NULL,
        confirmed_at timestamp,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE oauth_atomic_identities (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id uuid NOT NULL REFERENCES oauth_atomic_users(id) ON DELETE CASCADE,
        provider text NOT NULL,
        provider_uid text NOT NULL,
        provider_email text,
        provider_name text,
        provider_avatar_url text,
        encrypted_access_token bytea,
        encrypted_refresh_token bytea,
        token_expires_at timestamp,
        metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
        last_used_at timestamp NOT NULL,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE audit_events (
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
      "TRUNCATE TABLE oauth_atomic_identities, oauth_atomic_users, audit_events RESTART IDENTITY CASCADE",
      []
    )

    %{repo: repo}
  end

  defp oauth_config(repo) do
    %{
      repo: repo,
      user_schema: OAuthUser,
      identity_schema: OAuthIdentity,
      oauth: [
        enabled: true,
        providers: [],
        session_type: :remember_me,
        link_confirmation: :required,
        trust_provider_email: true
      ],
      session: [
        session_schema: OAuthUser,
        store: Sigra.Test.MockSessionStore
      ],
      audit: [audit_schema: AuditTestEvent]
    }
  end

  defp token do
    %{
      "access_token" => "a",
      "refresh_token" => "b",
      "expires_in" => 3600
    }
  end

  defp user_info(email \\ "new-oauth@example.com") do
    %{
      "sub" => "sub-#{:erlang.unique_integer([:positive])}",
      "email" => email,
      "name" => "N",
      "picture" => nil,
      "email_verified" => true
    }
  end

  test "rolls back registration when oauth.register_via_oauth audit insert is rejected", %{
    repo: repo
  } do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT oauth_audit_reg_guard CHECK (action <> 'oauth.register_via_oauth')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        Callback.process_callback(
          oauth_config(repo),
          :google,
          user_info(),
          token()
        )
      end

      assert [] == repo.all(OAuthUser)
      assert [] == repo.all(from(a in AuditTestEvent, where: like(a.action, "oauth.%")))
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS oauth_audit_reg_guard",
        []
      )
    end
  end
end
