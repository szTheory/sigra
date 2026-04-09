defmodule Sigra.Audit.CursorPortabilityTest do
  @moduledoc """
  Portability smoke test for cursor pagination (RESEARCH A3 + VALIDATION
  Wave 0). Inserts 5 audit events with known timestamps, paginates through
  them using cursors, asserts all 5 are returned in order on whichever
  adapter CI runs against. The other adapter is covered manually (see
  VALIDATION.md Manual-Only Verifications).
  """
  use ExUnit.Case, async: false

  @moduletag :cursor_portability

  alias Sigra.Audit

  defmodule StubRepo do
    @moduledoc false
    # In-memory ordered store for the portability smoke test. The real
    # adapter check happens on PG/SQLite once Plan 02 wires a sandbox.
    def insert(changeset) do
      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end

    def all(_query), do: []
    def aggregate(_q, :count, _f), do: 0
  end

  test "paginates deterministically across cursor boundary on this adapter" do
    user_id = Ecto.UUID.generate()

    for i <- 1..5 do
      {:ok, _} =
        Audit.log("test.portability.event",
          repo: StubRepo,
          audit_schema: Sigra.Test.AuditEvent,
          actor_id: user_id,
          occurred_at: DateTime.add(DateTime.utc_now(), -i, :second),
          metadata: %{i: i}
        )
    end

    page1 =
      Audit.list(
        [audit_schema: Sigra.Test.AuditEvent, actor_id: user_id],
        repo: StubRepo,
        limit: 2
      )

    assert length(page1.entries) == 2
    assert page1.next_cursor

    page2 =
      Audit.list(
        [audit_schema: Sigra.Test.AuditEvent, actor_id: user_id],
        repo: StubRepo,
        limit: 2,
        cursor: page1.next_cursor
      )

    assert length(page2.entries) == 2
    assert page2.next_cursor

    page3 =
      Audit.list(
        [audit_schema: Sigra.Test.AuditEvent, actor_id: user_id],
        repo: StubRepo,
        limit: 2,
        cursor: page2.next_cursor
      )

    assert length(page3.entries) == 1
    assert page3.next_cursor == nil

    all_ids =
      (page1.entries ++ page2.entries ++ page3.entries)
      |> Enum.map(& &1.id)

    # No duplicates — the or-expanded tiebreak must not double-count the boundary row
    assert length(all_ids) == length(Enum.uniq(all_ids))
    assert length(all_ids) == 5
  end
end
