defmodule Sigra.Audit.Forwarders.NoopTest do
  use ExUnit.Case, async: true
  @moduletag :threadline_guard

  import ExUnit.CaptureLog

  # NOTE: Wave 0 contract test for Sigra.Audit.Forwarders.Noop (Phase 131,
  # TL-04). The Noop fallback module is implemented in Task 2 of Plan
  # 131-01. Tests are RED until then — they fail at compile/load time
  # because `Sigra.Audit.Forwarders.Noop` does not yet exist. Once Task 2
  # lands the module, these tests must turn green without modification.
  #
  # AAA voice + `use ExUnit.Case, async: true` mirror per
  # `test/sigra/audit/changeset_test.exs` lines 1-30.

  describe "Sigra.Audit.Forwarders.Noop.attach/1" do
    test "returns :ok — D-22" do
      # D-22: Noop.attach/1 returns :ok immediately. No side effects, no
      # raise. This is the fail-open contract.
      assert Sigra.Audit.Forwarders.Noop.attach([]) == :ok
    end

    test "does NOT subscribe to :telemetry — D-22, D-23" do
      # D-22/D-23: Noop deliberately does NOT call :telemetry.attach/4.
      # The handler-count for [:sigra, :audit, :log] before and after
      # attach/1 must be identical. (The upstream Logger.warning lives in
      # Sigra.Application.maybe_warn_missing_forwarder_deps/0, NOT here —
      # Noop is purely a passive fallback.)
      before_count = length(:telemetry.list_handlers([:sigra, :audit, :log]))

      assert Sigra.Audit.Forwarders.Noop.attach([]) == :ok

      after_count = length(:telemetry.list_handlers([:sigra, :audit, :log]))

      assert before_count == after_count,
             "Noop must not attach a telemetry handler — got #{before_count} handlers before, #{after_count} after"
    end

    test "does NOT emit any Logger output — D-23" do
      # D-23: the "configured but dep missing" Logger.warning lives
      # UPSTREAM in Sigra.Application, not inside Noop. Noop is silent.
      log =
        capture_log(fn ->
          assert Sigra.Audit.Forwarders.Noop.attach([]) == :ok
        end)

      assert log == "",
             "Noop must not log — got: #{inspect(log)} (D-23: warning lives in Sigra.Application)"
    end
  end
end
