defmodule Sigra.AppLoginAuditCofateTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.AppLogin
  alias Sigra.Test.AppLoginSchemas.{Attempt, Challenge}
  alias Sigra.Test.AppSessionSchemas.{Family, Token, User}
  alias Sigra.Test.AuditEvent

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_session_users (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), email text NOT NULL,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_session_families (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
          user_id uuid NOT NULL REFERENCES sigra_app_session_users(id), client_ref varchar(255) NOT NULL,
          absolute_expires_at timestamp NOT NULL, revoked_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_session_tokens (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
          family_id uuid NOT NULL REFERENCES sigra_app_session_families(id), kind varchar(16) NOT NULL,
          digest bytea NOT NULL, expires_at timestamp NOT NULL, consumed_at timestamp,
          superseded_at timestamp, revoked_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "CREATE UNIQUE INDEX IF NOT EXISTS sigra_app_session_tokens_digest_idx ON sigra_app_session_tokens (digest)",
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_login_attempts (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), digest bytea NOT NULL UNIQUE,
          verifier_digest bytea NOT NULL, profile_id varchar(255) NOT NULL, callback text NOT NULL,
          user_id uuid NOT NULL REFERENCES sigra_app_session_users(id), client_ref varchar(255) NOT NULL,
          expires_at timestamp NOT NULL, consumed_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS audit_events (
          id uuid PRIMARY KEY, occurred_at timestamp NOT NULL DEFAULT now(), action varchar(255) NOT NULL,
          outcome varchar(32) NOT NULL DEFAULT 'success', actor_id uuid, actor_type varchar(64) NOT NULL DEFAULT 'user',
          target_id uuid, target_type varchar(64), ip_address varchar(64), user_agent varchar(512),
          metadata jsonb NOT NULL DEFAULT '{}'::jsonb, organization_id uuid, effective_user_id uuid,
          inserted_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      :ok
    end)
  end

  test "audit-on and audit-off hosted exchanges have identical lifecycle state with bounded audit metadata",
       %{
         repo: repo
       } do
    for {mode, audit?} <- [audit_on: true, audit_off: false] do
      code = "hosted-audit-#{mode}"
      verifier = String.duplicate("v", 43)
      profile = profile()
      callback = "com.sigra.app:/login"
      {:ok, user} = repo.insert(%User{email: "hosted-audit-#{mode}@example.com"})
      attempt = insert_attempt(repo, user, code, verifier, profile, callback)

      assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
               AppLogin.exchange_hosted(config(repo, audit?), code, verifier, profile, callback)

      assert is_binary(access) and is_binary(refresh)
      assert %{consumed_at: consumed_at} = repo.get!(Attempt, attempt.id)
      assert not is_nil(consumed_at)
      assert repo.aggregate(Ecto.Query.from(f in Family, where: f.id == ^family_id), :count) == 1

      assert repo.aggregate(Ecto.Query.from(t in Token, where: t.family_id == ^family_id), :count) ==
               2

      assert audit_count(repo, user.id) == if(audit?, do: 1, else: 0)

      if audit? do
        [event] = repo.all(Ecto.Query.from(e in AuditEvent, where: e.actor_id == ^user.id))

        assert event.action == "session.app_login_exchange"

        assert event.metadata == %{
                 "attempt_id" => attempt.id,
                 "profile_id" => profile.id,
                 "family_id" => family_id
               }
      end
    end
  end

  test "audit and credential persistence faults roll back and leave the same code usable after cleanup",
       %{
         repo: repo
       } do
    verifier = String.duplicate("v", 43)
    callback = "com.sigra.app:/login"
    {:ok, user} = repo.insert(%User{email: "hosted-faults@example.com"})

    for {name, profile, audit?, add_constraint, drop_constraint} <- [
          {
            :audit,
            profile(),
            true,
            "ALTER TABLE audit_events ADD CONSTRAINT sigra_hosted_audit_failure CHECK (action <> 'session.app_login_exchange')",
            "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS sigra_hosted_audit_failure"
          },
          {
            :credential,
            %{profile() | client_ref: "blocked-client"},
            false,
            "ALTER TABLE sigra_app_session_families ADD CONSTRAINT sigra_hosted_family_failure CHECK (client_ref <> 'blocked-client')",
            "ALTER TABLE sigra_app_session_families DROP CONSTRAINT IF EXISTS sigra_hosted_family_failure"
          }
        ] do
      code = "hosted-fault-#{name}"
      attempt = insert_attempt(repo, user, code, verifier, profile, callback)

      before =
        {repo.aggregate(Family, :count), repo.aggregate(Token, :count),
         audit_count(repo, user.id)}

      Ecto.Adapters.SQL.query!(repo, drop_constraint, [])
      Ecto.Adapters.SQL.query!(repo, add_constraint, [])

      try do
        assert {:error, :invalid_code} =
                 AppLogin.exchange_hosted(
                   config(repo, audit?, [profile]),
                   code,
                   verifier,
                   profile,
                   callback
                 )

        assert %{consumed_at: nil} = repo.get!(Attempt, attempt.id)

        assert {repo.aggregate(Family, :count), repo.aggregate(Token, :count),
                audit_count(repo, user.id)} == before
      after
        Ecto.Adapters.SQL.query!(repo, drop_constraint, [])
      end

      assert {:ok, %{access_token: access, refresh_token: refresh}} =
               AppLogin.exchange_hosted(
                 config(repo, audit?, [profile]),
                 code,
                 verifier,
                 profile,
                 callback
               )

      assert is_binary(access) and is_binary(refresh)
    end
  end

  test "expired and replayed hosted codes return the same bounded result without issuing another session",
       %{
         repo: repo
       } do
    verifier = String.duplicate("v", 43)
    profile = profile()
    callback = "com.sigra.app:/login"
    {:ok, user} = repo.insert(%User{email: "hosted-terminal@example.com"})

    insert_attempt(repo, user, "hosted-expired", verifier, profile, callback,
      expires_at: DateTime.add(now(), -1, :second)
    )

    assert {:error, :invalid_code} =
             AppLogin.exchange_hosted(
               config(repo, false),
               "hosted-expired",
               verifier,
               profile,
               callback
             )

    insert_attempt(repo, user, "hosted-replayed", verifier, profile, callback)

    assert {:ok, _} =
             AppLogin.exchange_hosted(
               config(repo, false),
               "hosted-replayed",
               verifier,
               profile,
               callback
             )

    assert {:error, :invalid_code} =
             AppLogin.exchange_hosted(
               config(repo, false),
               "hosted-replayed",
               verifier,
               profile,
               callback
             )

    assert repo.aggregate(Family, :count) == 1
    assert repo.aggregate(Token, :count) == 2
  end

  defp config(repo, audit?, profiles \\ [profile()]) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      audit: if(audit?, do: [audit_schema: AuditEvent], else: []),
      app_session: [
        family_schema: Family,
        token_schema: Token,
        app_login_code_schema: Attempt,
        app_login_challenge_schema: Challenge,
        first_party_profiles: profiles
      ]
    )
  end

  defp profile,
    do: %{
      id: "ios-primary",
      client_ref: "ios-primary",
      callback_uris: ["com.sigra.app:/login"],
      direct_login: :browser_required
    }

  defp insert_attempt(repo, user, code, verifier, profile, callback, attrs \\ []) do
    attempt =
      %Attempt{
        digest: Sigra.Token.hash_token(code),
        verifier_digest: verifier |> Sigra.AppLogin.PKCE.challenge() |> Sigra.Token.hash_token(),
        profile_id: profile.id,
        callback: callback,
        user_id: user.id,
        client_ref: profile.client_ref,
        expires_at: DateTime.add(now(), 60, :second)
      }
      |> Ecto.Changeset.change(attrs)

    repo.insert!(attempt)
  end

  defp audit_count(repo, user_id),
    do: repo.aggregate(Ecto.Query.from(e in AuditEvent, where: e.actor_id == ^user_id), :count)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
