defmodule Sigra.AuditMultiStepTest do
  use ExUnit.Case, async: false

  alias Sigra.Audit
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS audit_events CASCADE", [])

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
      """,
      []
    )

    Ecto.Adapters.SQL.query!(repo, "TRUNCATE TABLE audit_events RESTART IDENTITY CASCADE", [])

    %{repo: repo}
  end

  defp audit_opts(repo, user_id) do
    [
      repo: repo,
      audit_schema: AuditTestEvent,
      actor_id: user_id,
      target_id: user_id,
      metadata: %{method: "totp"}
    ]
  end

  test "two log_multi_safe steps with distinct audit_multi_step insert two rows", %{repo: repo} do
    uid = Ecto.UUID.generate()
    base = audit_opts(repo, uid)

    multi =
      Ecto.Multi.new()
      |> Audit.log_multi_safe(
        "mfa.verify.success",
        Keyword.merge(base, audit_multi_step: :audit_mfa_verify)
      )
      |> Audit.log_multi_safe(
        "mfa.backup_code_used",
        Keyword.merge(base,
          audit_multi_step: :audit_mfa_backup,
          metadata: %{remaining: 7}
        )
      )

    assert {:ok, changes} = repo.transaction(multi)
    assert Map.has_key?(changes, :audit_mfa_verify)
    assert Map.has_key?(changes, :audit_mfa_backup)

    assert count_where(repo, "action = 'mfa.verify.success'") == 1
    assert count_where(repo, "action = 'mfa.backup_code_used'") == 1
    assert count(repo) == 2

    Audit.emit_telemetry_from_changes(changes, [:audit_mfa_verify, :audit_mfa_backup])
  end

  test "emit_telemetry_from_changes/2 emits once per step in order", %{repo: repo} do
    uid = Ecto.UUID.generate()
    base = audit_opts(repo, uid)

    multi =
      Ecto.Multi.new()
      |> Audit.log_multi_safe(
        "mfa.verify.success",
        Keyword.merge(base, audit_multi_step: :audit_mfa_verify)
      )
      |> Audit.log_multi_safe(
        "mfa.backup_code_used",
        Keyword.merge(base, audit_multi_step: :audit_mfa_backup, metadata: %{remaining: 1})
      )

    assert {:ok, changes} = repo.transaction(multi)

    parent = self()
    ref = :erlang.unique_integer([:positive])

    :telemetry.attach(
      "audit-ms-#{ref}",
      [:sigra, :audit, :log],
      fn _event, _meas, meta, _ ->
        send(parent, {:sigra_audit_log, meta[:action]})
      end,
      nil
    )

    try do
      Audit.emit_telemetry_from_changes(changes, [:audit_mfa_verify, :audit_mfa_backup])

      assert_receive {:sigra_audit_log, "mfa.verify.success"}
      assert_receive {:sigra_audit_log, "mfa.backup_code_used"}
      refute_receive {:sigra_audit_log, _}
    after
      :telemetry.detach("audit-ms-#{ref}")
    end
  end

  test "rollback on second audit emits zero telemetry events", %{repo: repo} do
    uid = Ecto.UUID.generate()
    base = audit_opts(repo, uid)

    multi =
      Ecto.Multi.new()
      |> Audit.log_multi_safe(
        "mfa.verify.success",
        Keyword.merge(base, audit_multi_step: :audit_mfa_verify)
      )
      |> Audit.log_multi_safe(
        "mfa.backup_code_used",
        Keyword.merge(base,
          audit_multi_step: :audit_mfa_backup,
          metadata: %{password: "forbidden-by-d23"}
        )
      )

    parent = self()
    ref = :erlang.unique_integer([:positive])

    :telemetry.attach(
      "audit-ms-rollback-#{ref}",
      [:sigra, :audit, :log],
      fn _event, _meas, _meta, _ ->
        send(parent, :telemetry_fired)
      end,
      nil
    )

    try do
      assert {:error, :audit_mfa_backup, %Ecto.Changeset{}, _changes} = repo.transaction(multi)
      assert count(repo) == 0

      # No success transaction — emit_telemetry_from_changes must not be used with partial changes;
      # here we assert the telemetry handler never fired during the rolled-back txn.
      refute_receive :telemetry_fired, 200
    after
      :telemetry.detach("audit-ms-rollback-#{ref}")
    end
  end

  defp count(repo) do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM audit_events", [])

    n
  end

  defp count_where(repo, where) do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT count(*)::bigint FROM audit_events WHERE #{where}",
        []
      )

    n
  end
end
