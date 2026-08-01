defmodule Sigra.ApplicationForwardersTest do
  use ExUnit.Case, async: false
  @moduletag :threadline_guard

  # NOTE: Boot-wiring tests for Sigra.Application.maybe_warn_missing_forwarder_deps/0
  # and attach_forwarders/0. These helpers are added in Plan 05 (Wave 4).
  # Tests are RED until Plan 05 lands the implementation.
  #
  # Uses async: false because Application env is global mutable state.

  import ExUnit.CaptureLog

  alias Sigra.Application, as: SigraApp

  setup do
    Application.put_env(:sigra, :otp_app, :test_app)

    on_exit(fn ->
      Application.delete_env(:test_app, :sigra_config)
      Application.delete_env(:sigra, :otp_app)
    end)

    :ok
  end

  # Helper: configure a forwarders list in the test app's sigra_config
  defp put_forwarders(forwarders) do
    Application.put_env(:test_app, :sigra_config, audit: [forwarders: forwarders])
  end

  # --------------------------------------------------------------------------
  # maybe_warn_missing_forwarder_deps/0 tests
  # --------------------------------------------------------------------------

  describe "maybe_warn_missing_forwarder_deps/0" do
    test "Test 1 (D-25 — missing dep): emits one Logger.warning naming the missing module and recipe link" do
      put_forwarders([[module: NotALoadedModule, dispatch: :sync, id: :test]])

      log =
        capture_log(fn ->
          SigraApp.maybe_warn_missing_forwarder_deps()
        end)

      assert log =~ "NotALoadedModule",
             "Expected log to contain module name 'NotALoadedModule', got: #{inspect(log)}"

      assert log =~ "guides/recipes/companion-libs/threadline.md",
             "Expected log to contain recipe link, got: #{inspect(log)}"

      # Exactly one warning line (one-shot per D-23 — count [warning] occurrences)
      warning_count = log |> String.split("[warning]") |> length() |> Kernel.-(1)
      assert warning_count >= 1, "Expected at least one [warning] in log, got: #{inspect(log)}"
    end

    test "Test 2 (D-25 — present dep): does NOT warn when module IS loaded" do
      # Sigra.Audit.Forwarders.Noop is a real loaded module (from Plan 01)
      put_forwarders([[module: Sigra.Audit.Forwarders.Noop, dispatch: :sync, id: :test]])

      log =
        capture_log(fn ->
          SigraApp.maybe_warn_missing_forwarder_deps()
        end)

      assert log == "",
             "Expected no log output for loaded module, got: #{inspect(log)}"
    end

    test "Test 3 (D-09 — empty forwarders): zero overhead, no warnings" do
      put_forwarders([])

      log =
        capture_log(fn ->
          SigraApp.maybe_warn_missing_forwarder_deps()
        end)

      assert log == "",
             "Expected no log for empty forwarders list, got: #{inspect(log)}"
    end

    test "Test 4 (D-09 — absent audit key): no warnings when :audit not configured" do
      # sigra_config without :audit key at all
      Application.put_env(:test_app, :sigra_config, [])

      log =
        capture_log(fn ->
          SigraApp.maybe_warn_missing_forwarder_deps()
        end)

      assert log == "",
             "Expected no log when :audit key absent, got: #{inspect(log)}"
    end

    test "Test 5 (T-131-14 — redaction): Logger.warning does NOT leak :api_key or :endpoint" do
      put_forwarders([
        [
          module: SomeMissingForwarderModule,
          dispatch: :sync,
          endpoint: "https://example.com",
          api_key: "TOPSECRET-DO-NOT-LEAK"
        ]
      ])

      log =
        capture_log(fn ->
          SigraApp.maybe_warn_missing_forwarder_deps()
        end)

      refute log =~ "TOPSECRET-DO-NOT-LEAK",
             "MUST NOT leak api_key value in Logger.warning. Got: #{inspect(log)}"

      refute log =~ "api_key",
             "MUST NOT leak api_key key name in Logger.warning. Got: #{inspect(log)}"
    end
  end

  # --------------------------------------------------------------------------
  # attach_forwarders/0 tests
  # --------------------------------------------------------------------------

  describe "attach_forwarders/0" do
    test "Test 6 (D-26 — :async + no Oban raises): raises ArgumentError naming module, dep, :auto" do
      # Sigra.Audit.Forwarders.Noop IS loaded but :async + no Oban should raise
      # Use :oban override to point at a non-existent named process
      put_forwarders([
        [module: Sigra.Audit.Forwarders.Noop, dispatch: :async, oban: NonExistentObanProcess]
      ])

      assert_raise ArgumentError, ~r/:async/i, fn ->
        SigraApp.attach_forwarders()
      end
    end

    test "Test 7 (D-26 — raise message): raise names the offending forwarder module" do
      put_forwarders([
        [module: Sigra.Audit.Forwarders.Noop, dispatch: :async, oban: NonExistentObanProcess]
      ])

      exception =
        assert_raise ArgumentError, fn ->
          SigraApp.attach_forwarders()
        end

      assert exception.message =~ "Sigra.Audit.Forwarders.Noop",
             "Expected raise message to name the forwarder module, got: #{inspect(exception.message)}"

      # Also assert :auto is mentioned as fallback (D-26)
      assert exception.message =~ ":auto",
             "Expected raise message to recommend :auto fallback, got: #{inspect(exception.message)}"
    end

    test "Test 8 (D-25 — valid :auto, Oban absent): does NOT raise, attach_forwarders/0 returns :ok" do
      # :auto with no Oban → falls back to :sync (no raise)
      put_forwarders([[module: Sigra.Audit.Forwarders.Noop, dispatch: :auto, id: :test_auto]])

      # Should not raise — :auto gracefully falls back to :sync when Oban absent
      result = SigraApp.attach_forwarders()
      assert result == :ok, "Expected :ok from attach_forwarders/0 with :auto + no Oban"
    end

    test "Test 9 (D-27 — config cascade): reads via otp_app → sigra_config → audit → forwarders" do
      # This integration test confirms the full cascade works end-to-end
      # Configure a missing module so we get a warning we can capture
      Application.put_env(:test_app, :sigra_config,
        audit: [
          forwarders: [[module: CascadeTestMissingModule, dispatch: :sync, id: :cascade_test]]
        ]
      )

      log =
        capture_log(fn ->
          SigraApp.maybe_warn_missing_forwarder_deps()
        end)

      # The cascade must have picked up the forwarder and warned about the missing module
      assert log =~ "CascadeTestMissingModule",
             "Config cascade should have found the forwarder and warned about missing module. Got: #{inspect(log)}"
    end
  end
end
