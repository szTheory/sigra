defmodule Sigra.TestingAuditTest do
  use ExUnit.Case, async: true

  # Phase 10 Plan 01 — D-18 audit test helpers in Sigra.Testing.
  #
  # Sigra has no sandboxed test repo (see audit_test.exs precedent); we use
  # an in-process StubRepo that stores inserted rows in an Agent and supports
  # the small subset of Ecto.Repo calls used by the helpers under test:
  # `insert!/1`, `one/1` (with order_by/limit/offset), and `delete_all/1`.

  import Sigra.Testing

  alias Sigra.Test.AuditEvent

  defmodule StubRepo do
    @moduledoc false
    # In-process fake repo keyed by the current test pid so async tests
    # remain isolated. Stores inserted structs; `one/1` interprets the
    # order_by/limit/offset of the query passed in.

    def start(pid) do
      Agent.start_link(fn -> [] end, name: {:via, Registry, {Sigra.TestingAuditTest.Registry, pid}})
    end

    defp agent do
      {:via, Registry, {Sigra.TestingAuditTest.Registry, self()}}
    end

    def insert!(%Ecto.Changeset{} = cs) do
      event =
        cs
        |> Ecto.Changeset.apply_changes()
        |> Map.put(:id, Ecto.UUID.generate())
        |> Map.put(:inserted_at, DateTime.utc_now())

      Agent.update(agent(), fn rows -> [event | rows] end)
      event
    end

    def one(%Ecto.Query{} = query) do
      # Our helpers pass: from(e in schema, order_by: [desc: e.inserted_at], limit: 1, offset: ^pos)
      offset =
        case query.offset do
          nil -> 0
          %{expr: n} when is_integer(n) -> n
          %{params: [{n, _}]} when is_integer(n) -> n
          _ -> 0
        end

      rows =
        Agent.get(agent(), fn rows ->
          Enum.sort_by(rows, & &1.inserted_at, {:desc, DateTime})
        end)

      Enum.at(rows, offset)
    end

    def delete_all(_schema_or_query) do
      Agent.update(agent(), fn _ -> [] end)
      {0, nil}
    end

    def all, do: Agent.get(agent(), & &1)
  end

  setup do
    start_supervised!({Registry, keys: :unique, name: Sigra.TestingAuditTest.Registry})
    {:ok, _pid} = StubRepo.start(self())
    :ok
  end

  describe "audit_event_fixture/1" do
    test "inserts a row with default action and outcome" do
      event = audit_event_fixture(repo: StubRepo, audit_schema: AuditEvent)

      assert event.id
      assert event.action == "test.event"
      assert event.outcome == "success"
    end

    test "persists overridden fields" do
      actor_id = Ecto.UUID.generate()

      event =
        audit_event_fixture(
          repo: StubRepo,
          audit_schema: AuditEvent,
          action: "billing.charge.created",
          outcome: "failure",
          actor_id: actor_id,
          metadata: %{amount: 99}
        )

      assert event.action == "billing.charge.created"
      assert event.outcome == "failure"
      assert event.actor_id == actor_id
      assert event.metadata == %{amount: 99}
    end
  end

  describe "assert_audit_event/2" do
    test "returns true when the most recent event matches" do
      _ = audit_event_fixture(repo: StubRepo, audit_schema: AuditEvent)

      assert assert_audit_event(
               %{action: "test.event", outcome: "success"},
               repo: StubRepo,
               audit_schema: AuditEvent
             ) == true
    end

    test "raises ExUnit.AssertionError on mismatch with a diff-style message" do
      _ = audit_event_fixture(repo: StubRepo, audit_schema: AuditEvent, action: "test.event")

      assert_raise ExUnit.AssertionError, ~r/action/, fn ->
        assert_audit_event(
          %{action: "other.event"},
          repo: StubRepo,
          audit_schema: AuditEvent
        )
      end
    end

    test "deep-matches a metadata subset and ignores extra keys" do
      _ =
        audit_event_fixture(
          repo: StubRepo,
          audit_schema: AuditEvent,
          metadata: %{plan: "pro", extra: "ignored"}
        )

      assert assert_audit_event(
               %{metadata: %{plan: "pro"}},
               repo: StubRepo,
               audit_schema: AuditEvent
             ) == true
    end

    test "with position: 1 checks the second-most-recent event" do
      _ = audit_event_fixture(repo: StubRepo, audit_schema: AuditEvent, action: "test.first")
      # Ensure ordering is deterministic across the two inserts.
      Process.sleep(2)
      _ = audit_event_fixture(repo: StubRepo, audit_schema: AuditEvent, action: "test.second")

      assert assert_audit_event(
               %{action: "test.first"},
               repo: StubRepo,
               audit_schema: AuditEvent,
               position: 1
             ) == true

      assert assert_audit_event(
               %{action: "test.second"},
               repo: StubRepo,
               audit_schema: AuditEvent,
               position: 0
             ) == true
    end

    test "raises when no event exists at the given position" do
      assert_raise ExUnit.AssertionError, ~r/no audit event|found none|position/, fn ->
        assert_audit_event(
          %{action: "test.event"},
          repo: StubRepo,
          audit_schema: AuditEvent
        )
      end
    end
  end
end
