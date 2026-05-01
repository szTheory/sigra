defmodule Sigra.OAuth.RefreshTest do
  @moduledoc """
  Dedicated Postgres suite for OAuth refresh functionality across non-Google providers.
  Verifies GitHub, Apple, Facebook, and Generic wrappers correctly dispatch refresh,
  handle rotation, and classify failures.
  """

  use ExUnit.Case, async: false

  alias Sigra.OAuth
  alias Sigra.Test.PostgresRepo
  alias Sigra.Test.AuditEvent, as: AuditTestEvent

  defmodule OAuthUser do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "oauth_refresh_users" do
      field(:email, :string)
      timestamps()
    end
  end

  defmodule OAuthIdentity do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "oauth_refresh_identities" do
      field(:user_id, :binary_id)
      field(:provider, :string)
      field(:provider_uid, :string)
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

    for t <- ["oauth_refresh_identities", "oauth_refresh_users", "audit_events"] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE oauth_refresh_users (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text NOT NULL,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE oauth_refresh_identities (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id uuid NOT NULL REFERENCES oauth_refresh_users(id) ON DELETE CASCADE,
        provider text NOT NULL,
        provider_uid text NOT NULL,
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
      "TRUNCATE TABLE oauth_refresh_identities, oauth_refresh_users, audit_events RESTART IDENTITY CASCADE",
      []
    )

    %{repo: repo}
  end

  defp oauth_config(repo, strategy_module, site_url) do
    %{
      repo: repo,
      user_schema: OAuthUser,
      identity_schema: OAuthIdentity,
      oauth: [
        enabled: true,
        providers: [
          test_provider: [
            client_id: "test_id",
            client_secret: "test_secret",
            strategy: strategy_module,
            base_url: site_url,
            token_url: "#{site_url}/token"
          ]
        ],
      ],
      audit: [audit_schema: AuditTestEvent]
    }
  end

  describe "refresh for non-Google providers" do
    setup do
      TestServer.start()
      %{site_url: TestServer.url()}
    end

    for {provider_name, strategy_module} <- [
          {"GitHub", Assent.Strategy.Github},
          {"Apple", Assent.Strategy.Apple},
          {"Facebook", Assent.Strategy.Facebook},
          {"Generic", Assent.Strategy.OAuth2}
        ] do
      test "valid refresh updates tokens for #{provider_name}", %{repo: repo, site_url: site_url} do
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

        config = oauth_config(repo, unquote(strategy_module), site_url)

        identity = %Sigra.Identity{
          id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate(),
          provider: "test_provider",
          provider_uid: "uid_123",
          encrypted_access_token: "expired",
          encrypted_refresh_token: "refresh_me",
          token_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        }

        assert {:ok, %{"access_token" => "new_acc", "refresh_token" => "new_ref"}} =
                 OAuth.refresh_token(config, identity)
      end

      test "invalid_grant yields reauth_required for #{provider_name}", %{repo: repo, site_url: site_url} do
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

        config = oauth_config(repo, unquote(strategy_module), site_url)

        identity = %Sigra.Identity{
          id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate(),
          provider: "test_provider",
          provider_uid: "uid_123",
          encrypted_access_token: "expired",
          encrypted_refresh_token: "refresh_me",
          token_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        }

        assert {:error, :reauth_required} = OAuth.refresh_token(config, identity)
      end
    end
  end
end
