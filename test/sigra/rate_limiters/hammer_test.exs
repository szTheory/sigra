defmodule Sigra.RateLimiters.HammerTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.RateLimiters.Hammer

  # Define a mock Hammer module for testing
  defmodule MockHammer do
    def hit(_key, _window_ms, _limit) do
      send(self(), {:hammer_hit, _key, _window_ms, _limit})
      {:allow, 1}
    end
  end

  setup :verify_on_exit!

  describe "check_rate/3" do
    test "delegates to Hammer module hit/3 with correct parameter order" do
      Application.put_env(:sigra, :hammer_module, MockHammer)
      on_exit(fn -> Application.delete_env(:sigra, :hammer_module) end)

      assert {:allow, 1} = Hammer.check_rate("test:key", 10, 60_000)

      # Verify Hammer 7.x parameter order: hit(key, scale_ms, limit)
      assert_received {:hammer_hit, "test:key", 60_000, 10}
    end

    test "returns {:allow, count} on success" do
      defmodule AllowHammer do
        def hit(_key, _window_ms, _limit), do: {:allow, 5}
      end

      Application.put_env(:sigra, :hammer_module, AllowHammer)
      on_exit(fn -> Application.delete_env(:sigra, :hammer_module) end)

      assert {:allow, 5} = Hammer.check_rate("test:key", 10, 60_000)
    end

    test "returns {:deny, retry_after_ms} when rate exceeded" do
      defmodule DenyHammer do
        def hit(_key, _window_ms, _limit), do: {:deny, 30_000}
      end

      Application.put_env(:sigra, :hammer_module, DenyHammer)
      on_exit(fn -> Application.delete_env(:sigra, :hammer_module) end)

      assert {:deny, 30_000} = Hammer.check_rate("test:key", 10, 60_000)
    end

    test "fails open with warning when Hammer module raises" do
      defmodule CrashHammer do
        def hit(_key, _window_ms, _limit), do: raise("not started")
      end

      Application.put_env(:sigra, :hammer_module, CrashHammer)
      on_exit(fn -> Application.delete_env(:sigra, :hammer_module) end)

      assert {:allow, 0} = Hammer.check_rate("test:key", 10, 60_000)
    end

    test "raises when :hammer_module not configured" do
      Application.delete_env(:sigra, :hammer_module)

      assert_raise RuntimeError, ~r/requires :hammer_module config/, fn ->
        Hammer.check_rate("test:key", 10, 60_000)
      end
    end
  end

  describe "behaviour" do
    test "implements Sigra.RateLimiter behaviour" do
      Code.ensure_loaded!(Hammer)
      assert function_exported?(Hammer, :check_rate, 3)
    end
  end
end
