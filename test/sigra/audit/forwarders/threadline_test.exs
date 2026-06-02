defmodule Sigra.Audit.Forwarders.ThreadlineTest do
  # Wave 0 RED: Sigra.Audit.Forwarders.Threadline does not yet exist.
  # Both the module load and handler-attach tests will fail until Task 2
  # (Plan 131-04) ships the impl. Tests 1-6 per Plan 131-04 <behavior>.
  #
  # NOTE: async: false required because:
  # (1) live Postgres in Test 5 (Pitfall 2 boundary doctrine — SC-3)
  # (2) global :telemetry handler state (Tests 2, 3, 4 — auto-detach landmine)
  #
  # Analog: test/sigra/rate_limiters/hammer_test.exs (impl-with-stub-dep idiom)

  use Sigra.Test.PostgresCase, async: false
  @moduletag :requires_threadline

  alias Sigra.Audit.Forwarders.Threadline
  alias Sigra.Test.AuditEvent, as: TestAuditEvent

  # ---------------------------------------------------------------------------
  # MockThreadline — hand-stub that captures record_action/2 calls and lets
  # each test inject a custom behaviour (success, raise, exit, throw).
  # Stored in process dict of the test process so tests can retrieve calls.
  # ---------------------------------------------------------------------------

  defmodule MockThreadline do
    @moduledoc false

    # Call the test process's injected callback. The test sets up a handler
    # via `Process.put({:mock_threadline, :fn}, fn name, opts -> ... end)`.
    def record_action(name, opts) do
      case Process.get({:mock_threadline, :fn}) do
        nil ->
          # Default behaviour: success, capture args
          Process.put({:mock_threadline, :calls}, [
            {name, opts} | Process.get({:mock_threadline, :calls}, [])
          ])

          {:ok,
           %{id: "fake-action-id", name: name, correlation_id: Keyword.get(opts, :correlation_id)}}

        callback when is_function(callback, 2) ->
          Process.put({:mock_threadline, :calls}, [
            {name, opts} | Process.get({:mock_threadline, :calls}, [])
          ])

          callback.(name, opts)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Setup — prepare Test 5 table and set up teardown for handlers
  # ---------------------------------------------------------------------------

  setup %{repo: repo} do
    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE IF NOT EXISTS audit_events (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        occurred_at timestamptz NOT NULL DEFAULT now(),
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
        inserted_at timestamptz NOT NULL DEFAULT now()
      )
      """,
      []
    )

    # Clean up the Threadline handler after each test.
    on_exit(fn -> :telemetry.detach({Threadline, :test}) end)

    %{repo: repo}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Store for telemetry events captured during a test.
  # Attaches a handler to a given event list and sends captured metadata to self().
  defp capture_telemetry_event(handler_id, event_name) do
    test_pid = self()

    :telemetry.attach(
      handler_id,
      event_name,
      fn _event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event_name, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  # Build a standard audit event metadata map (D-31 superset).
  defp audit_metadata(overrides \\ %{}) do
    Map.merge(
      %{
        action: "auth.login.success",
        actor_id: "user-abc-123",
        outcome: :success,
        id: "00000000-0000-4000-8000-000000000001",
        occurred_at: ~U[2026-05-27 12:00:00Z]
      },
      overrides
    )
  end

  # Attach the Threadline forwarder with the given opts (overrides are merged).
  # Returns the handler_id so tests can inspect it.
  defp attach_threadline(extra_opts \\ []) do
    opts =
      Keyword.merge(
        [
          id: :test,
          dispatch: :sync,
          repo: Sigra.Test.PostgresRepo,
          audit_schema: TestAuditEvent,
          threadline_module: MockThreadline
        ],
        extra_opts
      )

    :ok = Threadline.attach(opts)
    {Threadline, :test}
  end

  # ---------------------------------------------------------------------------
  # Test 1: Happy path — :correlation_id idempotency (D-19, RESEARCH.md §4 path 1)
  # ---------------------------------------------------------------------------

  describe "Test 1 — happy path + :correlation_id idempotency (D-19)" do
    test "fires [:sigra, :audit, :forward, :ok] with forwarder: :threadline and duration_ms (D-28, D-30)" do
      capture_telemetry_event("test-forward-ok-1", [:sigra, :audit, :forward, :ok])

      metadata = audit_metadata()
      _handler_id = attach_threadline()

      Process.put({:mock_threadline, :fn}, nil)
      Process.put({:mock_threadline, :calls}, [])

      :telemetry.execute([:sigra, :audit, :log], %{count: 1}, metadata)

      assert_receive {:telemetry_event, [:sigra, :audit, :forward, :ok], measurements,
                      forward_meta},
                     1_000

      # D-30: forwarder atom, NOT module name
      assert forward_meta.forwarder == :threadline
      refute forward_meta.forwarder == Sigra.Audit.Forwarders.Threadline

      # D-28: duration_ms is an integer
      assert is_integer(measurements.duration_ms)

      # :correlation_id = audit UUID (RESEARCH.md §4 path 1, §7.2)
      calls = Process.get({:mock_threadline, :calls}, [])
      assert length(calls) >= 1
      {_name, call_opts} = List.last(calls)
      assert Keyword.get(call_opts, :correlation_id) == metadata.id
    end
  end

  # ---------------------------------------------------------------------------
  # Test 2: AUTO-DETACH LANDMINE (D-19, D-20, RESEARCH.md §8 "red ink")
  # Handler MUST remain attached after a raised event.
  # ---------------------------------------------------------------------------

  describe "Test 2 — auto-detach landmine (D-19, D-20)" do
    test "handler stays attached after MockThreadline raises on first event" do
      capture_telemetry_event("test-forward-error-2", [:sigra, :audit, :forward, :error])

      metadata = audit_metadata()
      _handler_id = attach_threadline()

      # Inject a raise on the FIRST call
      Process.put({:mock_threadline, :fn}, fn _name, _opts ->
        raise RuntimeError, "injected failure"
      end)

      # Fire event 1 — handler raises mid-body
      :telemetry.execute([:sigra, :audit, :log], %{count: 1}, metadata)

      # Assert :error telemetry fired (kind: :error for rescued RuntimeError)
      assert_receive {:telemetry_event, [:sigra, :audit, :forward, :error], _measurements,
                      error_meta},
                     1_000

      assert error_meta.kind == :error

      # NOW: clear the injection and fire event 2 BEFORE any sleep
      Process.put({:mock_threadline, :fn}, nil)
      Process.put({:mock_threadline, :calls}, [])

      :telemetry.execute([:sigra, :audit, :log], %{count: 1}, metadata)

      # Assert handler is STILL attached: it receives the second call
      # (if it had been auto-detached, this assertion would time out / fail).
      handler_id = {Threadline, :test}

      assert :telemetry.list_handlers([:sigra, :audit, :log])
             |> Enum.any?(fn h -> h.id == handler_id end),
             "handler was auto-detached after the first raised event — D-20 landmine"

      # MockThreadline should have received the second call
      calls = Process.get({:mock_threadline, :calls}, [])
      assert length(calls) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: catch :exit (D-19)
  # ---------------------------------------------------------------------------

  describe "Test 3 — catch :exit (D-19)" do
    test "fires [:sigra, :audit, :forward, :error] with kind: :exit when MockThreadline exits" do
      capture_telemetry_event("test-forward-error-3", [:sigra, :audit, :forward, :error])

      metadata = audit_metadata()
      _handler_id = attach_threadline()

      Process.put({:mock_threadline, :fn}, fn _name, _opts ->
        exit(:boom)
      end)

      :telemetry.execute([:sigra, :audit, :log], %{count: 1}, metadata)

      assert_receive {:telemetry_event, [:sigra, :audit, :forward, :error], _measurements,
                      error_meta},
                     1_000

      assert error_meta.kind == :exit
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4: catch :throw (D-19)
  # ---------------------------------------------------------------------------

  describe "Test 4 — catch :throw (D-19)" do
    test "fires [:sigra, :audit, :forward, :error] with kind: :throw when MockThreadline throws" do
      capture_telemetry_event("test-forward-error-4", [:sigra, :audit, :forward, :error])

      metadata = audit_metadata()
      _handler_id = attach_threadline()

      Process.put({:mock_threadline, :fn}, fn _name, _opts ->
        throw(:nope)
      end)

      :telemetry.execute([:sigra, :audit, :log], %{count: 1}, metadata)

      assert_receive {:telemetry_event, [:sigra, :audit, :forward, :error], _measurements,
                      error_meta},
                     1_000

      assert error_meta.kind == :throw
    end
  end

  # ---------------------------------------------------------------------------
  # Test 5: Pitfall 2 boundary doctrine (D-21, SC-3)
  # Forwarder failure MUST NOT roll back the originating Sigra audit transaction.
  # Uses live Postgres at localhost:5432 (CLAUDE.md mandates this).
  # ---------------------------------------------------------------------------

  describe "Test 5 — Pitfall 2 boundary doctrine (D-21, SC-3)" do
    test "forwarder failure does NOT roll back the audit row", %{repo: repo} do
      # Count rows before the test
      rows_before = repo.aggregate(TestAuditEvent, :count, :id)

      # Insert an audit row in a real transaction (mirrors the auth flow pattern)
      attrs = %{
        action: "auth.login.success",
        outcome: "success",
        occurred_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      }

      {:ok, audit_event} =
        %TestAuditEvent{}
        |> Ecto.Changeset.cast(attrs, [:action, :outcome, :occurred_at])
        |> Ecto.Changeset.validate_required([:action, :outcome, :occurred_at])
        |> repo.insert()

      rows_after_insert = repo.aggregate(TestAuditEvent, :count, :id)
      assert rows_after_insert == rows_before + 1

      # Now attach the forwarder with a forced failure and fire the telemetry event
      # (simulates what the audit emit_telemetry calls would do post-commit)
      capture_telemetry_event("test-forward-error-5", [:sigra, :audit, :forward, :error])

      _handler_id = attach_threadline()

      Process.put({:mock_threadline, :fn}, fn _name, _opts ->
        raise "forced Threadline failure"
      end)

      metadata = %{
        action: audit_event.action,
        actor_id: nil,
        outcome: audit_event.outcome,
        id: audit_event.id,
        occurred_at: audit_event.occurred_at
      }

      :telemetry.execute([:sigra, :audit, :log], %{count: 1}, metadata)

      # The :error telemetry should fire (forwarder failed)
      assert_receive {:telemetry_event, [:sigra, :audit, :forward, :error], _, _}, 1_000

      # The audit row count MUST be unchanged from after insert
      # (forwarder failure did NOT roll back the originating transaction)
      rows_after_failure = repo.aggregate(TestAuditEvent, :count, :id)

      assert rows_after_failure == rows_after_insert,
             "forwarder failure incorrectly changed row count: expected #{rows_after_insert}, got #{rows_after_failure}"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 6: metadata.forwarder is an ATOM :threadline (D-30)
  # ---------------------------------------------------------------------------

  describe "Test 6 — metadata.forwarder is atom :threadline (D-30)" do
    test "forward:ok metadata.forwarder is :threadline (atom), NOT the module name" do
      capture_telemetry_event("test-forward-ok-6", [:sigra, :audit, :forward, :ok])

      metadata = audit_metadata()
      _handler_id = attach_threadline()

      Process.put({:mock_threadline, :fn}, nil)

      :telemetry.execute([:sigra, :audit, :log], %{count: 1}, metadata)

      assert_receive {:telemetry_event, [:sigra, :audit, :forward, :ok], _measurements,
                      forward_meta},
                     1_000

      assert forward_meta.forwarder == :threadline
      refute forward_meta.forwarder == Sigra.Audit.Forwarders.Threadline
    end
  end
end
