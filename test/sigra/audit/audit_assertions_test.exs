defmodule Sigra.Audit.AuditAssertionsTest do
  use ExUnit.Case, async: true

  alias Sigra.Audit.Assertions
  alias Sigra.Test.AuditEvent, as: AuditTestEvent

  defmodule FakeRowRepo do
    @moduledoc false
    def one(_queryable) do
      key = {__MODULE__, :row}

      case Process.get(key) do
        %AuditTestEvent{} = cached ->
          cached

        _ ->
          now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
          uid = Ecto.UUID.generate()

          row = %AuditTestEvent{
            id: Ecto.UUID.generate(),
            action: "auth.login.success",
            outcome: "success",
            actor_id: uid,
            target_id: uid,
            metadata: %{method: "password"},
            inserted_at: now
          }

          Process.put(key, row)
          row
      end
    end
  end

  describe "assert_audit_fields/3" do
    test "raises when a field does not match the row returned by the repo" do
      assert_raise ArgumentError, ~r/outcome/, fn ->
        Assertions.assert_audit_fields(FakeRowRepo, AuditTestEvent, %{
          action: "auth.login.success",
          outcome: "failure"
        })
      end
    end

    test "passes when all fields match" do
      Process.delete({FakeRowRepo, :row})

      Assertions.assert_audit_fields(FakeRowRepo, AuditTestEvent, %{
        action: "auth.login.success",
        outcome: "success",
        metadata: %{method: "password"}
      })
    end
  end

  describe "latest_audit_event/3" do
    test "raises when audit_schema is nil" do
      assert_raise ArgumentError, ~r/audit_schema is required/, fn ->
        Assertions.latest_audit_event(FakeRowRepo, nil, action: "x")
      end
    end
  end

  describe "optional audit tag pattern" do
    @tag :audit_optional
    test "moduledoc: skip DB assertions when host omits audit_schema" do
      # Integration suites gate on `audit[:audit_schema]`; when nil, do not
      # call `assert_audit_fields/3` / `latest_audit_event/3` (they raise).
      assert true
    end
  end
end

defmodule Sigra.Audit.AuditAssertionsPostgresTest do
  use ExUnit.Case, async: false

  alias Sigra.Audit.Assertions
  alias Sigra.Test.AuditEvent, as: AuditTestEvent

  setup do
    start_supervised!({Sigra.Test.PostgresRepo, Sigra.Test.PostgresRepo.default_config()})
    repo = Sigra.Test.PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

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
      """,
      []
    )

    Ecto.Adapters.SQL.query!(repo, "TRUNCATE TABLE audit_events", [])
    %{repo: repo}
  end

  test "latest_audit_event/3 returns latest row ordered by inserted_at desc", %{repo: repo} do
    uid = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {:ok, _} =
      %AuditTestEvent{}
      |> Sigra.Audit.Changeset.changeset(
        %{
          action: "auth.login.failure",
          outcome: "failure",
          actor_id: uid,
          actor_type: "user",
          target_id: uid,
          metadata: %{reason: "invalid_password"},
          occurred_at: now
        },
        allow_reserved: true
      )
      |> repo.insert()

    Process.sleep(10)

    {:ok, _} =
      %AuditTestEvent{}
      |> Sigra.Audit.Changeset.changeset(
        %{
          action: "auth.login.success",
          outcome: "success",
          actor_id: uid,
          actor_type: "user",
          target_id: uid,
          metadata: %{method: "password"},
          occurred_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
        },
        allow_reserved: true
      )
      |> repo.insert()

    row =
      Assertions.latest_audit_event(repo, AuditTestEvent,
        actor_id: uid,
        action: "auth.login.success"
      )

    assert row.action == "auth.login.success"
    assert row.outcome == "success"

    Assertions.assert_audit_fields(repo, AuditTestEvent, %{
      action: "auth.login.success",
      outcome: "success",
      metadata: %{method: "password"}
    })
  end
end
