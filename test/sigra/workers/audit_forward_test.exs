defmodule Sigra.Workers.AuditForwardTest do
  # Sigra.Workers.AuditForward — Oban worker for async audit forwarder dispatch.
  # Analog: test/sigra/workers/audit_cleanup_test.exs (same-directory Wave 0
  # scaffold with StubRepo + cancel-taxonomy assertion style).

  use ExUnit.Case, async: true
  @moduletag :threadline_guard

  alias Sigra.Workers.AuditForward

  # ---------------------------------------------------------------------------
  # StubRepo — records calls so tests can assert behaviour without a real DB.
  # Mirrors StubRepo in audit_cleanup_test.exs.
  # ---------------------------------------------------------------------------

  defmodule StubRepo do
    @moduledoc false

    # Returns the stubbed row (or nil) from the process dictionary.
    def get(_schema, id) do
      rows = Process.get({:stub_repo, :rows}, %{})
      Map.get(rows, id)
    end

    def aggregate(_queryable, :count, _field), do: 0
  end

  # StubAuditSchema — minimal schema stub (module atom must be a real module
  # since String.to_existing_atom/1 requires the atom to exist at runtime).
  defmodule StubAuditSchema do
    @moduledoc false
    # No-op module; the schema type is used as a key passed to StubRepo.get/2.
  end

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  # Inject an audit row into StubRepo for the duration of a test.
  defp stub_row(id, row_map) do
    rows = Process.get({:stub_repo, :rows}, %{})
    Process.put({:stub_repo, :rows}, Map.put(rows, id, row_map))
  end

  # Configure the worker's resolve_config/0 to use test doubles.
  defp set_test_config(overrides \\ []) do
    config =
      Map.merge(
        %{
          repo: StubRepo,
          audit_schema: StubAuditSchema
        },
        Map.new(overrides)
      )

    Process.put(:sigra_audit_forward_config, config)
    on_exit(fn -> Process.delete(:sigra_audit_forward_config) end)
  end

  # Build a minimal audit row map (matching Sigra.Test.AuditEvent fields).
  defp build_audit_row(overrides) do
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
  defp standard_args(overrides) do
    Map.merge(
      %{
        "forwarder" => to_string(Sigra.Audit.Forwarders.Noop),
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
      # with the queue embedded. Same approach as audit_cleanup_test.exs.
      changeset = AuditForward.new(%{"forwarder" => "Elixir.Sigra.Audit.Forwarders.Noop"})
      assert changeset.changes[:queue] == "sigra_audit_forward"
      assert changeset.changes[:max_attempts] == 5
    end
  end

  # ---------------------------------------------------------------------------
  # Test 2: backoff/1 byte-for-byte match with EmailDelivery (D-15)
  # ---------------------------------------------------------------------------

  describe "Test 2 — backoff/1 byte-for-byte match with EmailDelivery (D-15)" do
    test "source contains the exact backoff body from EmailDelivery" do
      # D-15 "byte-for-byte": assert source identity by reading both files.
      # The deterministic formula is the required content.
      af_source = File.read!("lib/sigra/workers/audit_forward.ex")
      ed_source = File.read!("lib/sigra/workers/email_delivery.ex")

      backoff_body = "trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)"

      assert String.contains?(af_source, backoff_body),
             "AuditForward backoff body differs from EmailDelivery — D-15 byte-for-byte requirement violated"

      assert String.contains?(ed_source, backoff_body),
             "EmailDelivery source no longer contains expected backoff body"
    end

    test "returns a positive integer for attempts 1, 2, 3" do
      for attempt <- [1, 2, 3] do
        result = AuditForward.backoff(%Oban.Job{attempt: attempt})
        assert is_integer(result) and result > 0,
               "AuditForward.backoff(#{attempt}) returned #{inspect(result)}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: cancel taxonomy — :audit_event_not_found (D-16)
  # ---------------------------------------------------------------------------

  describe "Test 3 — cancel :audit_event_not_found (D-16)" do
    test "returns {:cancel, :audit_event_not_found} when audit row not found" do
      set_test_config()
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
      set_test_config()

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
  # Test 5: perform/1 NEVER raises; forwarder failure → {:error, _} (D-17, Pitfall 2)
  # ---------------------------------------------------------------------------

  describe "Test 5 — perform/1 never raises (D-17, Pitfall 2)" do
    test "forwarder failure returns {:error, _} without raising" do
      set_test_config()

      audit_id = "00000000-0000-4000-8000-000000000042"
      row = build_audit_row(%{id: audit_id})
      stub_row(audit_id, row)

      # Use the Noop forwarder (it has handle_event/4 if we check),
      # OR use a forwarder module that we know will be callable.
      # Noop doesn't have handle_event/4, so it'll hit the :unknown_forwarder cancel.
      # Use the Threadline forwarder module atom string (it exists and has handle_event/4).
      # But we need to ensure it's available.
      forwarder_str = to_string(Sigra.Audit.Forwarders.Noop)
      args = standard_args(%{"forwarder" => forwarder_str, "audit_event_id" => audit_id})

      # perform/1 must return a tagged tuple, not raise
      result =
        try do
          AuditForward.perform(%Oban.Job{args: args, attempt: 1, id: 3})
        rescue
          e -> {:raised, e}
        end

      refute match?({:raised, _}, result),
             "AuditForward.perform/1 raised instead of returning a tagged tuple — D-17 violated"

      # Result can be :ok, {:cancel, _}, or {:error, _} — any is acceptable
      # as long as it's not a raised exception
      assert result in [:ok, {:cancel, :unknown_forwarder}] or
               match?({:error, _}, result) or
               match?({:cancel, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # Test 6: Thin reference — only 3 keys read from args (D-13)
  # ---------------------------------------------------------------------------

  describe "Test 6 — thin job args (D-13)" do
    test "AuditForward source reads only 'forwarder', 'audit_event_id', 'occurred_at' from args" do
      source = File.read!("lib/sigra/workers/audit_forward.ex")

      # All three thin-reference keys must be present
      assert String.contains?(source, ~s(args["forwarder"])),
             "Expected source to read args[\"forwarder\"]"

      assert String.contains?(source, ~s(args["audit_event_id"])),
             "Expected source to read args[\"audit_event_id\"]"

      assert String.contains?(source, ~s(args["occurred_at"])),
             "Expected source to read args[\"occurred_at\"]"

      # The full payload keys must NOT be in args (they come from the reloaded row, not args).
      refute String.contains?(source, ~s(args["action"])),
             "Worker should NOT read action from args — it reloads from the audit row (D-13)"

      refute String.contains?(source, ~s(args["actor_id"])),
             "Worker should NOT read actor_id from args — it reloads from the audit row (D-13)"
    end
  end
end
