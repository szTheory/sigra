defmodule Sigra.Test.AuditFixtures do
  @moduledoc """
  Shared helpers for audit log tests.

  - `audit_event_fixture/1` — build a valid attrs map (override any field)
  - `assert_audit_event/2` — assert a row with matching action exists
  - `clear_audit_events/1` — wipe audit rows between tests

  Wave 0 scaffold. The real assertions become meaningful once Plans 02-04 land
  the `Sigra.Audit` module and the host-app schema.
  """
  import ExUnit.Assertions
  import Ecto.Query

  @doc """
  Build a valid `Sigra.Audit.log/3` attrs map. Pass overrides as a map or keyword.
  """
  def audit_event_fixture(overrides \\ %{}) do
    %{
      action: "test.event.one",
      outcome: "success",
      actor_id: Ecto.UUID.generate(),
      actor_type: "user",
      occurred_at: DateTime.utc_now(),
      metadata: %{}
    }
    |> Map.merge(Map.new(overrides))
  end

  @doc """
  Assert at least one audit row exists in `repo` with the given action.
  Uses `Sigra.Test.AuditEvent` as the schema by default.
  """
  def assert_audit_event(repo, action, schema \\ Sigra.Test.AuditEvent) do
    count =
      from(e in schema, where: e.action == ^action)
      |> repo.aggregate(:count, :id)

    assert count >= 1, "expected an audit row with action=#{action}, found none"
  end

  @doc """
  Delete all audit rows. Use in test setup blocks.
  """
  def clear_audit_events(repo, schema \\ Sigra.Test.AuditEvent) do
    repo.delete_all(schema)
  end
end
