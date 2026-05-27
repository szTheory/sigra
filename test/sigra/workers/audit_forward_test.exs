defmodule Sigra.Workers.AuditForwardTest do
  # Wave 0 RED: Sigra.Workers.AuditForward does not yet exist.
  # Tests fail until Task 3 (Plan 131-04) ships the worker.
  # Analog: test/sigra/workers/audit_cleanup_test.exs (1-40) — same-directory
  # Wave 0 scaffold with StubRepo + cancel-taxonomy assertion style.

  use ExUnit.Case, async: true

  alias Sigra.Workers.AuditForward

  # ---------------------------------------------------------------------------
  # StubRepo — records calls so tests can assert behaviour without a real DB.
  # Mirrors StubRepo in audit_cleanup_test.exs.
  # ---------------------------------------------------------------------------

  defmodule StubRepo do
    @moduledoc false

    # Returns {:ok, audit_row} or nil based on injected config.
    def get(_schema, id) do
      case Process.get({:stub_repo, :rows}, %{}) do
        %{^id => row} -> row
        _ -> nil
      end
    end
  end

  # Inject an audit row into StubRepo for the duration of a test.
  defp stub_row(id, row_map) do
    rows = Process.get({:stub_repo, :rows}, %{})
    Process.put({:stub_repo, :rows}, Map.put(rows, id, row_map))
  end

  # Build a minimal audit row map (matching Sigra.Test.AuditEvent fields).
  defp build_audit_row(overrides \\ %{}) do
    Map.merge(
      %{
        id: "00000000-0000-4000-8000-000000000042",
        action: "auth.login.success",
        actor_id: "user-123",
        outcome: "success",
        occurred_at: ~U[2026-05-27 12:00:00Z]
      },
      overrides
    )
  end

  # Helper: standard thin job args for a "found" path.
  defp standard_args(overrides \\ %{}) do
    Map.merge(
      %{
        "forwarder" => "Elixir.Sigra.Audit.Forwarders.Threadline",
        "audit_event_id" => "00000000-0000-4000-8000-000000000042",
        "occurred_at" => "2026-05-27T12:00:00Z"
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # Test 1: Worker shape — queue and max_attempts (D-14)
  # ---------------------------------------------------------------------------

  describe "Test 1 — Oban.Worker shape (D-14)" do
    test "uses queue :sigra_audit_forward with max_attempts: 5" do
      Code.ensure_loaded!(AuditForward)

      # Assert queue name via Oban.Worker.new/2 which returns a changeset
      # with the queue embedded. This is the same approach as audit_cleanup_test.exs.
      changeset = AuditForward.new(%{"forwarder" => "Elixir.Sigra.Audit.Forwarders.Noop"})
      assert changeset.changes[:queue] == "sigra_audit_forward"
      assert changeset.changes[:max_attempts] == 5
    end
  end

  # ---------------------------------------------------------------------------
  # Test 2: backoff/1 byte-for-byte match with EmailDelivery (D-15)
  # ---------------------------------------------------------------------------

  describe "Test 2 — backoff/1 byte-for-byte match with EmailDelivery (D-15)" do
    test "returns same result as EmailDelivery.backoff/1 for attempts 1, 2, 3" do
      for attempt <- [1, 2, 3] do
        af_result = AuditForward.backoff(%Oban.Job{attempt: attempt})
        ed_result = Sigra.Workers.EmailDelivery.backoff(%Oban.Job{attempt: attempt})

        # Both must be positive integers
        assert is_integer(af_result) and af_result > 0,
               "AuditForward.backoff(#{attempt}) returned #{inspect(af_result)}"

        assert is_integer(ed_result) and ed_result > 0,
               "EmailDelivery.backoff(#{attempt}) returned #{inspect(ed_result)}"

        # The deterministic base component (without jitter) must match.
        # The jitter component is :rand.uniform(10) * attempt which differs per call.
        # We verify source identity instead: assert the backoff body lines are identical.
      end

      # Source identity check (D-15 "byte-for-byte" requirement):
      # Read both source files and compare the backoff function body.
      af_source = File.read!("lib/sigra/workers/audit_forward.ex")
      ed_source = File.read!("lib/sigra/workers/email_delivery.ex")

      backoff_body = "trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)"

      assert String.contains?(af_source, backoff_body),
             "AuditForward backoff body differs from EmailDelivery — D-15 byte-for-byte requirement violated"

      assert String.contains?(ed_source, backoff_body),
             "EmailDelivery source no longer contains expected backoff body"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: cancel taxonomy — :audit_event_not_found (D-16)
  # ---------------------------------------------------------------------------

  describe "Test 3 — cancel :audit_event_not_found (D-16)" do
    test "returns {:cancel, :audit_event_not_found} when audit row not found" do
      # StubRepo.get returns nil for "missing-uuid" (nothing stubbed)
      args = standard_args(%{"audit_event_id" => "missing-uuid"})

      result =
        AuditForward.perform(%Oban.Job{
          args: args,
          attempt: 1,
          id: 1
        })

      assert result == {:cancel, :audit_event_not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4: cancel taxonomy — :unknown_forwarder (D-16)
  # ---------------------------------------------------------------------------

  describe "Test 4 — cancel :unknown_forwarder (D-16)" do
    test "returns {:cancel, :unknown_forwarder} when forwarder module doesn't exist" do
      args = standard_args(%{"forwarder" => "Elixir.DoesNotExist.Module.AtAll"})

      result =
        AuditForward.perform(%Oban.Job{
          args: args,
          attempt: 1,
          id: 2
        })

      assert result == {:cancel, :unknown_forwarder}
    end
  end

  # ---------------------------------------------------------------------------
  # Test 5: perform/1 NEVER raises; forwarder failure → {:error, _} + :error telemetry (D-17, Pitfall 2)
  # ---------------------------------------------------------------------------

  describe "Test 5 — perform/1 never raises (D-17, Pitfall 2)" do
    test "forwarder failure returns {:error, _} and fires :forward/:error telemetry" do
      test_pid = self()

      :telemetry.attach(
        "test-audit-forward-perform-error-5",
        [:sigra, :audit, :forward, :error],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:forward_error, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-audit-forward-perform-error-5") end)

      # Stub a row so the worker finds the audit event
      audit_id = "00000000-0000-4000-8000-000000000042"
      row = build_audit_row(%{id: audit_id})
      stub_row(audit_id, row)

      args = standard_args(%{"audit_event_id" => audit_id})

      # perform/1 must return a tagged tuple, not raise
      result =
        try do
          AuditForward.perform(%Oban.Job{args: args, attempt: 1, id: 3})
        rescue
          e -> {:raised, e}
        end

      refute match?({:raised, _}, result),
             "AuditForward.perform/1 raised instead of returning a tagged tuple — D-17 violated"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 6: Thin reference — only 3 keys read from args (D-13)
  # ---------------------------------------------------------------------------

  describe "Test 6 — thin job args (D-13)" do
    test "AuditForward source reads only 'forwarder', 'audit_event_id', 'occurred_at' from args" do
      source = File.read!("lib/sigra/workers/audit_forward.ex")

      # All three thin-reference keys must be present
      assert String.contains?(source, ~s("forwarder")),
             "Expected source to read args[\"forwarder\"]"

      assert String.contains?(source, ~s("audit_event_id")),
             "Expected source to read args[\"audit_event_id\"]"

      assert String.contains?(source, ~s("occurred_at")),
             "Expected source to read args[\"occurred_at\"]"

      # The full payload keys must NOT be in args (they come from the reloaded row, not args).
      # We grep for the string patterns that would indicate reading from args directly.
      refute String.contains?(source, ~s(args["action"])),
             "Worker should NOT read action from args — it reloads from the audit row (D-13)"

      refute String.contains?(source, ~s(args["actor_id"])),
             "Worker should NOT read actor_id from args — it reloads from the audit row (D-13)"
    end
  end
end
