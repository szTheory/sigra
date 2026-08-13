defmodule Sigra.AppLoginTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.AppLogin
  alias Sigra.AppSession
  alias Sigra.AppLogin.PKCE
  alias Sigra.Test.AppLoginSchemas.Attempt
  alias Sigra.Test.AppLoginSchemas.Challenge
  alias Sigra.Test.AppSessionSchemas.{Family, Token, User}
  alias Sigra.Test.AuditEvent

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_app_login_attempts (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
          digest bytea NOT NULL UNIQUE,
          verifier_digest bytea NOT NULL,
          profile_id varchar(255) NOT NULL,
          callback text NOT NULL,
          user_id uuid NOT NULL REFERENCES sigra_app_session_users(id),
          client_ref varchar(255) NOT NULL,
          expires_at timestamp NOT NULL,
          consumed_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(),
          updated_at timestamp NOT NULL DEFAULT now()
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
    end)

    :ok
  end

  setup %{repo: repo} do
    {:ok, user} = repo.insert(%User{email: "hosted-login@example.com"})
    %{repo: repo, config: config(repo), user: user}
  end

  test "consumes one locked hosted code and issues an authenticatable app session", %{
    repo: repo,
    config: config,
    user: user
  } do
    code = "hosted-code"
    verifier = String.duplicate("v", 43)
    profile = profile()
    callback = "com.sigra.app:/login"
    attempt = insert_attempt(repo, user, code, verifier, profile, callback)

    assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
             AppLogin.exchange_hosted(config, code, verifier, profile, callback)

    assert is_binary(access) and is_binary(refresh)
    assert %{consumed_at: consumed_at} = repo.get!(Attempt, attempt.id)
    assert not is_nil(consumed_at)
    assert [%Family{id: ^family_id}] = repo.all(Ecto.Query.from(f in Family))
    assert 2 = repo.aggregate(Token, :count)

    assert {:ok, %{family_id: ^family_id, user_id: user_id}} =
             AppSession.authenticate(config, access)

    assert user_id == user.id
  end

  test "starts, explicitly approves, and exchanges one S256-bound hosted ceremony", %{
    repo: repo,
    config: config,
    user: user
  } do
    verifier = String.duplicate("v", 43)
    challenge = PKCE.challenge(verifier)
    started_at = ~U[2026-08-13 00:00:00Z]

    assert {:ok, %{continuation: continuation, approval_required: true}} =
             AppLogin.start_hosted(
               config,
               %{
                 "profile_id" => "ios-primary",
                 "callback" => "com.sigra.app:/login",
                 "state" => "native-state-123",
                 "code_challenge" => challenge,
                 "code_challenge_method" => "S256"
               },
               now: started_at
             )

    assert {:ok, %{code: code, callback: "com.sigra.app:/login", state: "native-state-123"}} =
             AppLogin.approve_hosted(config, continuation, user, :approve, now: started_at)

    attempt = repo.one!(Attempt)
    assert DateTime.to_unix(attempt.expires_at) == DateTime.to_unix(started_at) + 60
    assert attempt.verifier_digest == Sigra.Token.hash_token(challenge)
    refute attempt.verifier_digest == Sigra.Token.hash_token(verifier)

    assert {:ok, %{access_token: access, refresh_token: refresh}} =
             AppLogin.exchange_hosted(config, code, verifier, profile(), "com.sigra.app:/login")

    assert is_binary(access) and is_binary(refresh)
  end

  test "rejects non-exact hosted start input and never issues a code", %{
    repo: repo,
    config: config,
    user: user
  } do
    verifier = String.duplicate("v", 43)

    valid = %{
      "profile_id" => "ios-primary",
      "callback" => "com.sigra.app:/login",
      "state" => "native-state-123",
      "code_challenge" => PKCE.challenge(verifier),
      "code_challenge_method" => "S256"
    }

    for invalid <- [
          Map.put(valid, "callback", "com.sigra.app:/login?next=https://evil.example"),
          Map.put(valid, "code_challenge_method", "plain"),
          Map.put(valid, "state", ""),
          Map.put(valid, "profile_id", ["ios-primary"]),
          Map.put(valid, "extra", "value")
        ] do
      assert {:error, :invalid_request} = AppLogin.start_hosted(config, invalid)
    end

    assert {:ok, %{continuation: continuation}} = AppLogin.start_hosted(config, valid)
    assert {:ok, :cancelled} = AppLogin.approve_hosted(config, continuation, user, :cancel)

    assert {:error, :invalid_continuation} =
             AppLogin.approve_hosted(config, continuation <> "tampered", user, :approve)

    assert 0 = repo.aggregate(Attempt, :count)
  end

  test "returns one bounded invalid-code result without issuing for terminal bindings", %{
    repo: repo,
    config: config,
    user: user
  } do
    profile = profile()
    callback = "com.sigra.app:/login"

    for {label, attrs, supplied} <- [
          {:expired, [expires_at: DateTime.add(now(), -1, :second)],
           {"code-expired", "verifier"}},
          {:consumed, [consumed_at: now()], {"code-consumed", "verifier"}},
          {:profile, [], {"code-profile", "verifier", %{profile | id: "wrong"}, callback}},
          {:callback, [], {"code-callback", "verifier", profile, "com.sigra.app:/wrong"}},
          {:verifier, [], {"code-verifier", "wrong"}}
        ] do
      {code, verifier, supplied_profile, supplied_callback} =
        case supplied do
          {code, verifier} ->
            {code, verifier, profile, callback}

          {code, verifier, supplied_profile, supplied_callback} ->
            {code, verifier, supplied_profile, supplied_callback}
        end

      insert_attempt(repo, user, code, String.duplicate("v", 43), profile, callback, attrs)

      assert {:error, :invalid_code} =
               AppLogin.exchange_hosted(
                 config,
                 code,
                 verifier,
                 supplied_profile,
                 supplied_callback
               ),
             "#{label} must normalize to invalid_code"
    end

    assert 0 = repo.aggregate(Family, :count)
    assert 0 = repo.aggregate(Token, :count)
  end

  test "rolls back consumed hosted code and app-session issuance when optional audit fails", %{
    repo: repo,
    user: user
  } do
    code = "audit-rollback-code"
    verifier = String.duplicate("v", 43)
    profile = profile()
    callback = "com.sigra.app:/login"
    attempt = insert_attempt(repo, user, code, verifier, profile, callback)

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS sigra_app_login_audit_fail",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT sigra_app_login_audit_fail CHECK (action <> 'session.app_login_exchange')",
      []
    )

    assert {:error, :invalid_code} =
             AppLogin.exchange_hosted(
               config(repo, audit?: true),
               code,
               verifier,
               profile,
               callback
             )

    assert %{consumed_at: nil} = repo.get!(Attempt, attempt.id)
    assert 0 = repo.aggregate(Family, :count)
    assert 0 = repo.aggregate(Token, :count)
  end

  test "rolls back consumed hosted code when app-session persistence fails", %{
    repo: repo,
    user: user
  } do
    code = "session-rollback-code"
    verifier = String.duplicate("v", 43)
    profile = %{profile() | client_ref: "blocked-client"}
    callback = "com.sigra.app:/login"
    attempt = insert_attempt(repo, user, code, verifier, profile, callback)

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE sigra_app_session_families DROP CONSTRAINT IF EXISTS sigra_app_login_family_fail",
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE sigra_app_session_families ADD CONSTRAINT sigra_app_login_family_fail CHECK (client_ref <> 'blocked-client')",
      []
    )

    assert {:error, :invalid_code} =
             AppLogin.exchange_hosted(config(repo), code, verifier, profile, callback)

    assert %{consumed_at: nil} = repo.get!(Attempt, attempt.id)
    assert 0 = repo.aggregate(Family, :count)
    assert 0 = repo.aggregate(Token, :count)
  end

  defp config(repo, opts \\ []) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      audit: if(Keyword.get(opts, :audit?, false), do: [audit_schema: AuditEvent], else: []),
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
          }
        ]
      ],
      secret_key_base: String.duplicate("a", 64)
    )
  end

  defp profile do
    %{id: "ios-primary", client_ref: "ios-primary"}
  end

  defp insert_attempt(repo, user, code, verifier, profile, callback, attrs \\ []) do
    now = now()

    attempt =
      struct!(Attempt, %{
        digest: Sigra.Token.hash_token(code),
        verifier_digest: verifier |> Sigra.AppLogin.PKCE.challenge() |> Sigra.Token.hash_token(),
        profile_id: profile.id,
        callback: callback,
        user_id: user.id,
        client_ref: profile.client_ref,
        expires_at: DateTime.add(now, 60, :second)
      })
      |> Ecto.Changeset.change(attrs)

    repo.insert!(attempt)
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
