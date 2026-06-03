defmodule Sigra.OAuthCeremonyAuditTest do
  @moduledoc """
  Merge-blocking OAuth ceremony + audit proofs for **OA-01** (registration and
  authorize flows) using a real `PostgresRepo` and Sandbox. Requirement trace:
  `.planning/milestones/v1.6-REQUIREMENTS.md` (OA-01).
  """

  use Sigra.Test.PostgresCase, async: false

  alias Sigra.Audit.Assertions
  alias Sigra.OAuth
  alias Sigra.OAuth.Callback
  alias Sigra.Test.AuditEvent, as: AuditTestEvent

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

  defmodule MockStrategy do
    @moduledoc false
    def authorize_url(_config) do
      {:ok,
       %{
         url: "https://provider.example.com/auth?state=original&scope=email",
         session_params: %{code_verifier: "pkce_verifier"}
       }}
    end

    def callback(_config, _params) do
      {:ok,
       %{
         user: %{
           "sub" => "uid_123",
           "email" => "test@example.com",
           "name" => "Test",
           "picture" => nil,
           "email_verified" => true
         },
         token: %{
           "access_token" => "tok",
           "refresh_token" => "ref",
           "expires_in" => 3600
         }
       }}
    end
  end

  setup %{repo: repo} do
    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE IF NOT EXISTS oauth_atomic_users (
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
      CREATE TABLE IF NOT EXISTS oauth_atomic_identities (
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

  defp authorize_oauth_config(repo) do
    repo
    |> oauth_config()
    |> Map.put(:secret_key_base, String.duplicate("a", 64))
    |> Map.put(:oauth,
      enabled: true,
      providers: [
        mock: [client_id: "test_id", client_secret: "test_secret", strategy: MockStrategy]
      ],
      session_type: :remember_me,
      link_confirmation: :required,
      trust_provider_email: true
    )
  end

  defp token do
    %{
      "access_token" => "a",
      "refresh_token" => "b",
      "expires_in" => 3600
    }
  end

  defp user_info(email) do
    %{
      "sub" => "sub-#{:erlang.unique_integer([:positive])}",
      "email" => email,
      "name" => "N",
      "picture" => nil,
      "email_verified" => true
    }
  end

  describe "registration" do
    test "persists oauth.register_via_oauth after successful registration", %{repo: repo} do
      assert {:ok, :registered, user, _} =
               Callback.process_callback(
                 oauth_config(repo),
                 :google,
                 user_info("persist@example.com"),
                 token()
               )

      assert user.email == "persist@example.com"

      Assertions.assert_audit_fields(repo, AuditTestEvent, %{
        action: "oauth.register_via_oauth",
        actor_id: user.id,
        target_id: user.id
      })
    end
  end

  describe "authorize" do
    test "persists oauth.authorize after successful authorize_url", %{repo: repo} do
      config = authorize_oauth_config(repo)

      assert {:ok, _url, _} = OAuth.authorize_url(config, :mock, [])

      Assertions.assert_audit_fields(repo, AuditTestEvent, %{
        action: "oauth.authorize",
        metadata: %{"provider" => "mock"}
      })
    end
  end
end
