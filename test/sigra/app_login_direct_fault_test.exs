defmodule Sigra.AppLoginDirectFaultTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.AppLogin
  alias Sigra.Test.AppLoginSchemas.{Attempt, Challenge}
  alias Sigra.Test.AppSessionSchemas.{Family, Token, User}
  alias Sigra.Test.AuditEvent

  defmodule TelemetryHandler do
    def handle_event(event, measurements, metadata, parent),
      do: send(parent, {:audit_telemetry, event, measurements, metadata})
  end

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(&create_tables!/1)
    :ok
  end

  setup %{repo: repo} do
    {:ok, user} = repo.insert(%User{email: "direct-fault@example.com"})
    %{repo: repo, user: user, config: config(repo)}
  end

  test "direct public denials have one result while browser policy is a static pre-auth exception",
       %{
         config: config,
         user: user
       } do
    denied = [
      AppLogin.start_direct(config, "unknown", user.email, "password",
        authenticate_user: verifier(user)
      ),
      AppLogin.start_direct(config, "android-primary", user.email, "wrong",
        authenticate_user: fn _, _ -> {:error, :invalid} end
      ),
      AppLogin.start_direct(config, "android-primary", user.email, "password",
        authenticate_user: fn _, _ -> raise "callback failure" end
      ),
      AppLogin.start_direct(config, "android-primary", user.email, "password", []),
      AppLogin.complete_direct_mfa(config, "malformed", "factor",
        mfa_verify: fn _, _ -> {:ok, :verified} end
      ),
      AppLogin.complete_direct_mfa(config, nil, "factor",
        mfa_verify: fn _, _ -> {:ok, :verified} end
      )
    ]

    assert Enum.uniq(denied) == [{:error, :invalid_credentials}]

    assert {:error, :browser_required} =
             AppLogin.start_direct(config, "ios-primary", user.email, "any-password",
               authenticate_user: fn _, _ -> flunk("browser policy must not authenticate") end
             )
  end

  test "expired, replayed, and profile-mismatched MFA challenges share the direct public denial",
       %{
         repo: repo,
         config: config,
         user: user
       } do
    expired = insert_challenge(repo, user, "expired", DateTime.add(now(), -1, :second))
    replayed = insert_challenge(repo, user, "replayed", DateTime.add(now(), 300, :second), now())
    mismatched = insert_challenge(repo, user, "mismatched", DateTime.add(now(), 300, :second))

    results = [
      AppLogin.complete_direct_mfa(config, expired, "factor", mfa_verify: verifier(user)),
      AppLogin.complete_direct_mfa(config, replayed, "factor", mfa_verify: verifier(user)),
      AppLogin.complete_direct_mfa(config, mismatched, "factor",
        profile_id: "ios-primary",
        mfa_verify: verifier(user)
      )
    ]

    assert Enum.uniq(results) == [{:error, :invalid_credentials}]
  end

  test "audit rejection rolls back direct consumption and issuance without exposing a credential",
       %{
         repo: repo,
         config: config,
         user: user
       } do
    challenge = insert_challenge(repo, user, "audit-fault", DateTime.add(now(), 300, :second))

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT direct_mfa_audit_guard CHECK (action <> 'session.app_login_direct_mfa')",
      []
    )

    try do
      assert {:error, :invalid_credentials} =
               AppLogin.complete_direct_mfa(config, challenge, "factor",
                 mfa_verify: verifier(user)
               )

      assert %{consumed_at: nil} = repo.get_by!(Challenge, digest: challenge_digest(challenge))
      assert repo.aggregate(Family, :count) == 0
      assert repo.aggregate(Token, :count) == 0
      assert repo.aggregate(AuditEvent, :count) == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS direct_mfa_audit_guard",
        []
      )
    end
  end

  test "successful direct MFA emits only committed bounded audit telemetry", %{
    config: config,
    user: user
  } do
    challenge =
      insert_challenge(config.repo, user, "telemetry", DateTime.add(now(), 300, :second))

    ref = {__MODULE__, :direct_mfa_audit, System.unique_integer([:positive])}
    :ok = :telemetry.attach(ref, [:sigra, :audit, :log], &TelemetryHandler.handle_event/4, self())

    try do
      assert {:ok, _} =
               AppLogin.complete_direct_mfa(config, challenge, "factor",
                 mfa_verify: verifier(user)
               )

      assert_receive {:audit_telemetry, [:sigra, :audit, :log], %{count: 1}, metadata}
      assert metadata.action == "session.app_login_direct_mfa"
      refute Map.has_key?(metadata, :email)
      refute Map.has_key?(metadata, :password)
      refute Map.has_key?(metadata, :challenge)
      refute Map.has_key?(metadata, :code)
    after
      :telemetry.detach(ref)
    end
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      audit: [audit_schema: AuditEvent],
      app_session: [
        family_schema: Family,
        token_schema: Token,
        app_login_code_schema: Attempt,
        app_login_challenge_schema: Challenge,
        first_party_profiles: [
          %{
            id: "ios-primary",
            client_ref: "ios-primary",
            callback_uris: ["com.sigra.app:/login"],
            direct_login: :browser_required
          },
          %{
            id: "android-primary",
            client_ref: "android-primary",
            callback_uris: ["com.sigra.app:/login"],
            direct_login: :password_allowed
          }
        ]
      ]
    )
  end

  defp insert_challenge(repo, user, _suffix, expires_at, consumed_at \\ nil) do
    {challenge, digest} = Sigra.Token.generate_hashed_token()

    repo.insert!(%Challenge{
      kind: :direct_mfa,
      digest: digest,
      profile_id: "android-primary",
      user_id: user.id,
      client_ref: "android-primary",
      expires_at: expires_at,
      consumed_at: consumed_at
    })

    challenge
  end

  defp verifier(user), do: fn ^user, "factor" -> {:ok, :verified} end
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)

  defp challenge_digest(challenge) do
    {:ok, decoded} = Base.url_decode64(challenge, padding: false)
    Sigra.Token.hash_token(decoded)
  end

  defp create_tables!(repo) do
    for sql <- [
          "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"",
          "CREATE TABLE IF NOT EXISTS sigra_app_session_users (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), email text NOT NULL, inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now())",
          "CREATE TABLE IF NOT EXISTS sigra_app_session_families (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), user_id uuid NOT NULL REFERENCES sigra_app_session_users(id), client_ref varchar(255) NOT NULL, absolute_expires_at timestamp NOT NULL, revoked_at timestamp, inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now())",
          "CREATE TABLE IF NOT EXISTS sigra_app_session_tokens (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), family_id uuid NOT NULL REFERENCES sigra_app_session_families(id), kind varchar(16) NOT NULL, digest bytea NOT NULL, expires_at timestamp NOT NULL, consumed_at timestamp, superseded_at timestamp, revoked_at timestamp, inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now())",
          "CREATE UNIQUE INDEX IF NOT EXISTS sigra_direct_fault_token_digest_idx ON sigra_app_session_tokens (digest)",
          "CREATE TABLE IF NOT EXISTS sigra_app_login_challenges (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), kind varchar(32) NOT NULL, digest bytea NOT NULL UNIQUE, profile_id varchar(255) NOT NULL, user_id uuid NOT NULL REFERENCES sigra_app_session_users(id), client_ref varchar(255) NOT NULL, expires_at timestamp NOT NULL, consumed_at timestamp, inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now())",
          "CREATE TABLE IF NOT EXISTS audit_events (id uuid PRIMARY KEY, occurred_at timestamp NOT NULL DEFAULT now(), action varchar(255) NOT NULL, outcome varchar(32) NOT NULL DEFAULT 'success', actor_id uuid, actor_type varchar(64) NOT NULL DEFAULT 'user', target_id uuid, target_type varchar(64), ip_address varchar(64), user_agent varchar(512), metadata jsonb NOT NULL DEFAULT '{}'::jsonb, organization_id uuid, effective_user_id uuid, inserted_at timestamp NOT NULL DEFAULT now())"
        ] do
      Ecto.Adapters.SQL.query!(repo, sql, [])
    end
  end
end
