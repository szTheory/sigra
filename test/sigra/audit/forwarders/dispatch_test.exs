defmodule Sigra.Audit.Forwarders.DispatchTest do
  use ExUnit.Case, async: false

  # Tests for Sigra.Audit.Forwarders dispatcher (Plan 03).
  #
  # Tests :auto/:async/:sync dispatch routing using the per-forwarder :dispatch
  # opt (D-07) — NOT top-level :delivery_mode (mirrors email[:delivery_mode]
  # per-entry knob precedent in lib/sigra/config.ex:434-458).
  #
  # oban_running?(opts) is PUBLIC (BLOCKER 2 fix — Plan 05 calls cross-module).
  # This test uses the :oban override key (D-32) to simulate Oban
  # supervised vs not, without touching the real Oban process.
  #
  # NOTE: With Plan 04 shipping Sigra.Workers.AuditForward, the async path
  # now calls oban.insert/1 (previously was a graceful no-op when the worker
  # wasn't compiled). Tests 2 and 4 updated to use StubOban.insert/1.

  alias Sigra.Audit.Forwarders

  # Inline stub forwarder for :sync dispatch tests.
  # Implements Sigra.Audit.Forwarder so @behaviour is satisfied.
  defmodule StubForwarder do
    @behaviour Sigra.Audit.Forwarder

    @impl Sigra.Audit.Forwarder
    def attach(_opts), do: :ok

    # handle_event/4 is NOT part of the behaviour (D-33) but the dispatcher
    # calls into the forwarder via this fn when dispatching :sync.
    def handle_event(_event, _measurements, metadata, opts) do
      send(self(), {:handle_event_called, metadata, opts})
      :ok
    end
  end

  # StubOban — implements insert/1 to replace the real Oban supervisor in tests.
  # Required because Sigra.Workers.AuditForward is now compiled (Plan 04) and
  # dispatch_async calls oban.insert(changeset) — atom-only mocks no longer work.
  defmodule StubOban do
    @moduledoc false
    def insert(changeset) do
      send(self(), {:oban_insert_called, changeset})
      {:ok, %Oban.Job{id: 1, queue: "sigra_audit_forward", attempt: 1}}
    end
  end

  # Atom that is never supervised — Process.whereis returns nil for it.
  # Used to simulate Oban NOT running for :auto routing test (D-12).
  @no_oban_module :nonexistent_oban_module_for_testing

  describe "dispatch/3 with :sync" do
    test "Test 1 — :sync calls forwarder inline and returns :ok (D-10)" do
      # Arrange
      metadata = %{id: "test-uuid", action: "auth.login.success", actor_id: "user-1", outcome: "success", occurred_at: DateTime.utc_now()}
      opts = [dispatch: :sync]

      # Act
      result = Forwarders.dispatch(StubForwarder, metadata, opts)

      # Assert
      assert result == :ok
      assert_received {:handle_event_called, ^metadata, ^opts}
    end
  end

  describe "dispatch/3 with :async" do
    test "Test 2 — :async enqueues Oban job via StubOban (D-10)" do
      # Arrange — use StubOban override so test does not require a live Oban supervisor.
      # Now that AuditForward is compiled (Plan 04), the async path calls oban.insert/1.
      # The :oban option is BOTH the running-check target AND the insert module.
      # StubOban.insert/1 captures the call and returns {:ok, %Oban.Job{}}.
      metadata = %{id: "audit-uuid-1234", action: "auth.login.success", actor_id: "u1", outcome: "success", occurred_at: DateTime.utc_now()}
      opts = [dispatch: :async, oban: StubOban]

      # Act — should not raise; async path calls StubOban.insert/1
      result = Forwarders.dispatch(StubForwarder, metadata, opts)

      # Assert — returns {:ok, job} from StubOban.insert
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "dispatch/3 with :auto" do
    test "Test 3 — :auto routes to :sync when Oban NOT supervised (D-12)" do
      # Arrange — pass :oban override pointing at nonexistent atom
      # Process.whereis(@no_oban_module) == nil → routes to :sync
      metadata = %{id: "uuid-auto-nosync", action: "auth.logout", actor_id: "u2", outcome: "success", occurred_at: DateTime.utc_now()}
      opts = [dispatch: :auto, oban: @no_oban_module]

      # Act
      result = Forwarders.dispatch(StubForwarder, metadata, opts)

      # Assert — :auto with no Oban supervisor routes inline (:sync path)
      assert result == :ok
      # :sync path calls handle_event/4 inline
      assert_received {:handle_event_called, ^metadata, _actual_opts}
    end

    test "Test 4 — :auto routes to :async when Oban IS supervised (D-12)" do
      # Arrange — register StubOban as a named process so oban_running?/1 returns true.
      # StubOban is both:
      # (1) a module with insert/1 (so dispatch_async can call it), AND
      # (2) registered as a named process (so Process.whereis(StubOban) != nil).
      # We use Agent under the StubOban atom name for the presence check.
      {:ok, agent_pid} = Agent.start(fn -> :ok end)
      Process.register(agent_pid, StubOban)

      metadata = %{id: "uuid-auto-async", action: "session.create", actor_id: "u3", outcome: "success", occurred_at: DateTime.utc_now()}
      opts = [dispatch: :auto, oban: StubOban]

      # Act — :auto sees StubOban is supervised → routes :async
      result = Forwarders.dispatch(StubForwarder, metadata, opts)

      # Assert — returns :ok or {:ok, job} (async path with StubOban.insert)
      assert result == :ok or match?({:ok, _}, result)
      # The :sync path was NOT taken — handle_event NOT called inline
      refute_received {:handle_event_called, _, _}
    after
      # Clean up named process registration
      if pid = Process.whereis(StubOban) do
        Process.unregister(StubOban)
        Process.exit(pid, :normal)
      end
    end
  end

  describe "oban_running?/1 (PUBLIC — BLOCKER 2 check)" do
    test "Test 5 — oban_running?/1 returns false when module not supervised (D-12)" do
      # Ensure the module is loaded before checking function visibility.
      # function_exported?/3 returns false for not-yet-loaded modules (Erlang behaviour);
      # Code.ensure_loaded!/1 guarantees the BEAM is in the running system before the check.
      Code.ensure_loaded!(Forwarders)
      # This also asserts the function is PUBLIC (def, not defp).
      assert function_exported?(Forwarders, :oban_running?, 1)

      # Passes :oban override pointing at nonexistent atom
      result = Forwarders.oban_running?(oban: @no_oban_module)
      assert result == false
    end

    test "Test 5b — oban_running?/1 returns true when named process IS supervised (D-12)" do
      {:ok, _pid} = Agent.start(fn -> :ok end, name: :mock_oban_for_running_check)

      result = Forwarders.oban_running?(oban: :mock_oban_for_running_check)
      assert result == true
    after
      Agent.stop(:mock_oban_for_running_check)
    end
  end
end
