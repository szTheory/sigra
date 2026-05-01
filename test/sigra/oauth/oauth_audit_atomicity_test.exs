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

  defmodule MockStrategy do
    @moduledoc false
    def refresh(_config, "refresh_me", _config2) do
      {:ok, %{"access_token" => "new_acc", "refresh_token" => "new_ref", "expires_in" => 3600}}
    end

    def refresh(_config, "bad_refresh", _config2) do
      {:error, %Assent.InvalidResponseError{response: %{body: %{"error" => "invalid_grant"}}}}
    end
  end

  defp refresh_oauth_config(repo, site_url) do
    repo
    |> oauth_config()
    |> Map.put(:secret_key_base, String.duplicate("a", 64))
    |> Map.put(:oauth, [
      enabled: true,
      providers: [
        mock: [client_id: "test_id", client_secret: "test_secret", strategy: MockStrategy, base_url: site_url, token_url: "#{site_url}/token"]
      ]
    ])
  end

  describe "refresh token atomicity" do
    setup do
      TestServer.start()
      %{site_url: TestServer.url()}
    end

    test "rolls back token rotation when oauth.token_refreshed audit insert is rejected", %{repo: repo, site_url: site_url} do
      TestServer.add("/token",
        via: :post,
        to: fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "access_token" => "new_acc",
              "refresh_token" => "new_ref",
              "expires_in" => 3600,
              "token_type" => "Bearer"
            })
          )
        end
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        ALTER TABLE audit_events
        ADD CONSTRAINT oauth_audit_ref_guard CHECK (action <> 'oauth.token_refreshed')
        """,
        []
      )

      config = refresh_oauth_config(repo, site_url)
      user = repo.insert!(%OAuthUser{email: "test@example.com"})

      identity =
        repo.insert!(%OAuthIdentity{
          user_id: user.id,
          provider: "mock",
          provider_uid: "uid_123",
          encrypted_access_token: "expired",
          encrypted_refresh_token: "refresh_me",
          token_expires_at: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -3600, :second),
          last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      try do
        # We catch the exception or match the returned {:error, :temporarily_unavailable}
        # since persist_refresh rescues repo.transaction failures and returns an error
        # rather than raising (except Ecto.ConstraintError which raises if not mapped).
        assert_raise Ecto.ConstraintError, fn ->
          Sigra.OAuth.refresh_token(config, Sigra.Identity.from_schema(identity))
        end

        reloaded = repo.get!(OAuthIdentity, identity.id)
        assert reloaded.encrypted_access_token == "expired"
        assert reloaded.encrypted_refresh_token == "refresh_me"
        assert [] == repo.all(from(a in AuditTestEvent, where: like(a.action, "oauth.%")))
      after
        Ecto.Adapters.SQL.query!(
          repo,
          "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS oauth_audit_ref_guard",
          []
        )
      end
    end

    test "leaves persistence unchanged and returns classified error on invalid_grant", %{repo: repo, site_url: site_url} do
      TestServer.add("/token",
        via: :post,
        to: fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            400,
            Jason.encode!(%{"error" => "invalid_grant"})
          )
        end
      )

      config = refresh_oauth_config(repo, site_url)
      user = repo.insert!(%OAuthUser{email: "test@example.com"})

      identity =
        repo.insert!(%OAuthIdentity{
          user_id: user.id,
          provider: "mock",
          provider_uid: "uid_123",
          encrypted_access_token: "expired",
          encrypted_refresh_token: "bad_refresh",
          token_expires_at: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -3600, :second),
          last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert {:error, :reauth_required} = Sigra.OAuth.refresh_token(config, Sigra.Identity.from_schema(identity))

      reloaded = repo.get!(OAuthIdentity, identity.id)
      assert reloaded.encrypted_access_token == "expired"
      assert reloaded.encrypted_refresh_token == "bad_refresh"
      assert [] == repo.all(from(a in AuditTestEvent, where: like(a.action, "oauth.%")))
    end
  end
end
