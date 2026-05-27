defmodule Sigra.AuditTelemetryTest do
  use ExUnit.Case, async: false

  # Phase 131 Plan 02 (D-31 / TL-05 enabler):
  # Asserts the [:sigra, :audit, :log] metadata is the strict 5-key superset
  # {action, actor_id, outcome, id, occurred_at}. The new pair (id, occurred_at)
  # is the canonical idempotency key the Threadline forwarder (Plan 04) ships
  # to Threadline.record_action/2 via :correlation_id, unblocking Pitfall 4
  # (cross-system dedupe) without an extra DB query inside the handler.
  #
  # Backwards-compat invariant: existing subscribers (e.g.
  # Sigra.Telemetry.attach_default_logger) pattern-match on a subset of
  # metadata, so the additive extension breaks zero callers.

  alias Sigra.Audit

  defmodule StubRepo do
    @moduledoc false
    # Mirrors test/sigra/audit_observability_test.exs StubRepo.
    def insert(changeset) do
      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end
  end

  setup do
    handler_id = {__MODULE__, make_ref()}
    test_pid = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:sigra, :audit, :log],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, handler_id: handler_id}
  end

  test "metadata superset carries :id (UUID) and :occurred_at (DateTime) plus all 3 pre-existing keys (D-31)" do
    actor_id = Ecto.UUID.generate()

    assert {:ok, _event} =
             Audit.log("test.event.telemetry_superset",
               repo: StubRepo,
               audit_schema: Sigra.Test.AuditEvent,
               actor_id: actor_id
             )

    assert_receive {:telemetry_event, _measurements, metadata}

    # All 5 D-31 keys present (strict superset).
    for key <- [:action, :actor_id, :outcome, :id, :occurred_at] do
      assert Map.has_key?(metadata, key),
             "metadata missing required key #{inspect(key)} (D-31). Got: #{inspect(Map.keys(metadata))}"
    end

    # The new pair has the right shape (Pitfall 4 idempotency key).
    assert is_binary(metadata.id), "metadata.id must be a UUID string, got: #{inspect(metadata.id)}"
    assert match?(%DateTime{}, metadata.occurred_at),
           "metadata.occurred_at must be a %DateTime{}, got: #{inspect(metadata.occurred_at)}"
  end

  test "additive only — existing keys (:action, :actor_id, :outcome) preserve their values (D-31 backwards-compat)" do
    actor_id = Ecto.UUID.generate()
    action = "test.event.telemetry_additive"

    assert {:ok, _event} =
             Audit.log(action,
               repo: StubRepo,
               audit_schema: Sigra.Test.AuditEvent,
               actor_id: actor_id
             )

    assert_receive {:telemetry_event, _measurements, metadata}

    # Existing values unchanged — adding keys must not mutate established ones
    # (RESEARCH.md §2.1 backwards-compat audit; Sigra.Telemetry.attach_default_logger
    # at lib/sigra/telemetry.ex:341-348 depends on these exact values).
    assert metadata.action == action
    assert metadata.actor_id == actor_id
    assert metadata.outcome == "success"
  end
end
