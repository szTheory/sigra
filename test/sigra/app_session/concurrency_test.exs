defmodule Sigra.AppSession.ConcurrencyTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.AppSession
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

  test "two barrier-released callers serialize refresh into one rotate and one reuse in both audit modes",
       %{repo: repo} do
    parent = self()

    for {mode, config} <- [audit_on: config(repo, true), audit_off: config(repo, false)] do
      {:ok, user} = repo.insert(%User{email: "app-session-concurrency-#{mode}@example.com"})

      assert {:ok, %{access_token: predecessor_access, refresh_token: raw, family_id: family_id}} =
               AppSession.issue(config, user, "#{mode}")

      callers =
        for _ <- 1..2 do
          Task.async(fn ->
            Ecto.Adapters.SQL.Sandbox.allow(repo, parent, self())
            send(parent, {:refresh_caller_ready, self()})

            receive do
              :go -> AppSession.refresh(config, raw)
            end
          end)
        end

      for _ <- callers do
        assert_receive {:refresh_caller_ready, caller}
        send(caller, :go)
      end

      results = Enum.map(callers, &Task.await(&1, 5_000))
      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, :reuse_detected}, &1)) == 1

      {:ok, %{access_token: replacement_access}} = Enum.find(results, &match?({:ok, _}, &1))

      assert not is_nil(repo.get!(Family, family_id).revoked_at)

      assert repo.aggregate(
               Ecto.Query.from(t in Token, where: t.family_id == ^family_id),
               :count,
               :id
             ) == 4

      assert repo.aggregate(
               Ecto.Query.from(t in Token,
                 where: t.family_id == ^family_id and is_nil(t.revoked_at)
               ),
               :count,
               :id
             ) == 0

      assert {:error, :invalid_token} = AppSession.authenticate(config, predecessor_access)
      assert {:error, :invalid_token} = AppSession.authenticate(config, replacement_access)

      expected_audits = if mode == :audit_on, do: 2, else: 0

      assert repo.aggregate(
               Ecto.Query.from(e in AuditEvent,
                 where:
                   e.actor_id == ^user.id and
                     e.action in ["session.app_refresh", "session.app_refresh_reuse"]
               ),
               :count,
               :id
             ) == expected_audits
    end
  end

  defp config(repo, audit?) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      audit: if(audit?, do: [audit_schema: AuditEvent], else: []),
      app_session: [family_schema: Family, token_schema: Token]
    )
  end
end
