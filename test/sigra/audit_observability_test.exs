defmodule Sigra.AuditObservabilityTest do
  use ExUnit.Case, async: false

  # Wave 0 scaffold. Verifies the [:sigra, :audit, :log] telemetry contract
  # from D-24. Plan 02 implements the actual emit. Tests are RED until then.

  alias Sigra.Audit

  defmodule StubRepo do
    @moduledoc false
    def insert(changeset) do
      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end
  end

  setup do
    :telemetry_test.attach_event_handlers(self(), [[:sigra, :audit, :log]])
    :ok
  end

  test "telemetry fires once on successful log/3" do
    assert {:ok, _} =
             Audit.log("test.event.one",
               repo: StubRepo,
               audit_schema: Sigra.Test.AuditEvent
             )

    assert_received {[:sigra, :audit, :log], _ref, _measurements,
                     %{action: "test.event.one", outcome: "success"}}

    refute_received {[:sigra, :audit, :log], _, _, _}
  end

  test "telemetry does NOT fire on validation failure (no false positives)" do
    assert {:error, _} =
             Audit.log("BAD",
               repo: StubRepo,
               audit_schema: Sigra.Test.AuditEvent
             )

    refute_received {[:sigra, :audit, :log], _, _, _}
  end

  test "telemetry payload includes actor_id and outcome (D-24)" do
    actor_id = Ecto.UUID.generate()

    assert {:ok, _} =
             Audit.log("test.event.two",
               repo: StubRepo,
               audit_schema: Sigra.Test.AuditEvent,
               actor_id: actor_id
             )

    assert_received {[:sigra, :audit, :log], _ref, _measurements, metadata}
    assert metadata.actor_id == actor_id
    assert metadata.outcome == "success"
  end
end
