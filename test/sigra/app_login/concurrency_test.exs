defmodule Sigra.AppLogin.ConcurrencyTest do
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
        CREATE TABLE IF NOT EXISTS sigra_app_login_challenges (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), kind varchar(32) NOT NULL,
          digest bytea NOT NULL UNIQUE, profile_id varchar(255) NOT NULL,
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

      :ok
    end)
  end

  test "two barrier-released callers consume one hosted code and issue one session", %{repo: repo} do
    parent = self()
    config = config(repo)
    profile = %{id: "ios-primary", client_ref: "ios-primary"}
    callback = "com.sigra.app:/login"
    code = "hosted-concurrent-code"
    verifier = String.duplicate("v", 43)
    {:ok, user} = repo.insert(%User{email: "hosted-concurrency@example.com"})
    attempt = insert_attempt(repo, user, code, verifier, profile, callback)

    callers =
      for _ <- 1..2 do
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(repo, parent, self())
          send(parent, {:hosted_exchange_ready, self()})

          receive do
            :go -> AppLogin.exchange_hosted(config, code, verifier, profile, callback)
          end
        end)
      end

    for _ <- callers do
      assert_receive {:hosted_exchange_ready, caller}
      send(caller, :go)
    end

    results = Enum.map(callers, &Task.await(&1, 5_000))

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, :invalid_code}, &1)) == 1
    assert %{consumed_at: consumed_at} = repo.get!(Attempt, attempt.id)
    assert not is_nil(consumed_at)
    assert repo.aggregate(Family, :count) == 1
    assert repo.aggregate(Token, :count) == 2
  end

  test "two ready/go callers consume one direct MFA challenge in either audit mode", %{repo: repo} do
    parent = self()

    for {mode, config} <- [audit_on: config(repo, true), audit_off: config(repo, false)] do
      family_count_before = repo.aggregate(Family, :count)
      token_count_before = repo.aggregate(Token, :count)
      {:ok, user} = repo.insert(%User{email: "direct-mfa-concurrency-#{mode}@example.com"})

      {:ok, %{mfa_challenge: challenge}} =
        AppLogin.start_direct(config, "android-primary", user.email, "password",
          authenticate_user: fn email, "password" when email == user.email ->
            {:ok, user, %{mfa_required: true}}
          end
        )

      callers =
        for _ <- 1..2 do
          Task.async(fn ->
            Ecto.Adapters.SQL.Sandbox.allow(repo, parent, self())
            send(parent, {:direct_mfa_caller_ready, self()})

            receive do
              :go ->
                AppLogin.complete_direct_mfa(config, challenge, "correct-factor",
                  mfa_verify: fn ^user, "correct-factor" -> {:ok, :verified} end
                )
            end
          end)
        end

      for _ <- callers do
        assert_receive {:direct_mfa_caller_ready, caller}
        send(caller, :go)
      end

      results = Enum.map(callers, &Task.await(&1, 5_000))

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, :invalid_credentials}, &1)) == 1

      {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
        Enum.find(results, &match?({:ok, _}, &1))

      assert %{consumed_at: consumed_at} =
               repo.get_by!(Challenge, digest: challenge_digest(challenge))

      assert not is_nil(consumed_at)
      assert repo.aggregate(Family, :count) == family_count_before + 1
      assert repo.aggregate(Token, :count) == token_count_before + 2
      assert {:ok, %{family_id: ^family_id}} = Sigra.AppSession.authenticate(config, access)
      assert {:ok, %{family_id: ^family_id}} = Sigra.AppSession.refresh(config, refresh)

      expected_audits = if mode == :audit_on, do: 1, else: 0

      assert repo.aggregate(
               Ecto.Query.from(e in AuditEvent,
                 where: e.actor_id == ^user.id and e.action == "session.app_login_direct_mfa"
               ),
               :count,
               :id
             ) == expected_audits
    end
  end

  defp config(repo, audit? \\ false) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      audit: if(audit?, do: [audit_schema: AuditEvent], else: []),
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

  defp insert_attempt(repo, user, code, verifier, profile, callback) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    repo.insert!(%Attempt{
      digest: Sigra.Token.hash_token(code),
      verifier_digest: verifier |> Sigra.AppLogin.PKCE.challenge() |> Sigra.Token.hash_token(),
      profile_id: profile.id,
      callback: callback,
      user_id: user.id,
      client_ref: profile.client_ref,
      expires_at: DateTime.add(now, 60, :second)
    })
  end

  defp challenge_digest(challenge) do
    {:ok, decoded} = Base.url_decode64(challenge, padding: false)
    Sigra.Token.hash_token(decoded)
  end
end
