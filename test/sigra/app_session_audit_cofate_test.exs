defmodule Sigra.AppSessionAuditCofateTest do
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

  setup %{repo: repo} do
    {:ok, user} = repo.insert(%User{email: "app-session-cofate@example.com"})
    %{repo: repo, user: user}
  end

  test "audit-on and audit-off refresh have identical lifecycle state except audit rows", %{
    repo: repo
  } do
    for {mode, config} <- [audit_on: config(repo, true), audit_off: config(repo, false)] do
      {:ok, mode_user} = repo.insert(%User{email: "app-session-cofate-#{mode}@example.com"})

      assert {:ok, %{refresh_token: raw, family_id: family_id}} =
               AppSession.issue(config, mode_user, "#{mode}")

      assert {:ok, %{access_token: replacement}} = AppSession.refresh(config, raw)

      assert active_token_count(repo, family_id) == 4
      assert {:ok, %{family_id: ^family_id}} = AppSession.authenticate(config, replacement)

      assert audit_count(repo, mode_user.id, ["session.app_refresh"]) ==
               if(mode == :audit_on, do: 1, else: 0)
    end
  end

  test "audit-on reuse commits family revocation and bounded reuse audit", %{
    repo: repo,
    user: user
  } do
    config = config(repo, true)

    assert {:ok, %{refresh_token: raw, family_id: family_id}} =
             AppSession.issue(config, user, "reuse")

    assert {:ok, _} = AppSession.refresh(config, raw)
    assert {:error, :reuse_detected} = AppSession.refresh(config, raw)

    assert not is_nil(repo.get!(Family, family_id).revoked_at)
    assert audit_count(repo, user.id, ["session.app_refresh", "session.app_refresh_reuse"]) == 2

    [event] =
      repo.all(Ecto.Query.from(e in AuditEvent, where: e.action == "session.app_refresh_reuse"))

    assert event.metadata == %{
             "family_id" => family_id,
             "kind" => "app_session",
             "lifecycle" => "reuse"
           }
  end

  test "replacement persistence rejection rolls back lifecycle and reveals no replacement", %{
    repo: repo,
    user: user
  } do
    config = config(repo, false)

    assert {:ok, %{refresh_token: raw, family_id: family_id}} =
             AppSession.issue(config, user, "persistence-fault")

    before = token_state(repo, family_id)

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE sigra_app_session_tokens ADD CONSTRAINT app_session_no_replacement CHECK (consumed_at IS NULL OR kind <> 'refresh') NOT VALID",
      []
    )

    try do
      assert {:error, :app_session_refresh_aborted} = AppSession.refresh(config, raw)
      assert token_state(repo, family_id) == before
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE sigra_app_session_tokens DROP CONSTRAINT IF EXISTS app_session_no_replacement",
        []
      )
    end
  end

  test "audit rejection rolls back reuse revocation and returns no replacement", %{
    repo: repo,
    user: user
  } do
    config = config(repo, true)

    assert {:ok, %{refresh_token: raw, family_id: family_id}} =
             AppSession.issue(config, user, "audit-fault")

    assert {:ok, %{refresh_token: rotated}} = AppSession.refresh(config, raw)

    Ecto.Adapters.SQL.query!(
      repo,
      "ALTER TABLE audit_events ADD CONSTRAINT app_session_no_reuse_audit CHECK (action <> 'session.app_refresh_reuse')",
      []
    )

    try do
      assert {:error, :app_session_refresh_aborted} = AppSession.refresh(config, raw)
      assert is_nil(repo.get!(Family, family_id).revoked_at)
      assert {:ok, _} = AppSession.refresh(config, rotated)
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS app_session_no_reuse_audit",
        []
      )
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

  defp active_token_count(repo, family_id),
    do:
      repo.aggregate(
        Ecto.Query.from(t in Token, where: t.family_id == ^family_id and is_nil(t.revoked_at)),
        :count,
        :id
      )

  defp audit_count(repo, user_id, actions),
    do:
      repo.aggregate(
        Ecto.Query.from(e in AuditEvent, where: e.actor_id == ^user_id and e.action in ^actions),
        :count,
        :id
      )

  defp token_state(repo, family_id) do
    repo.all(
      Ecto.Query.from(t in Token,
        where: t.family_id == ^family_id,
        order_by: t.id,
        select: {t.kind, t.consumed_at, t.superseded_at, t.revoked_at}
      )
    )
  end
end
