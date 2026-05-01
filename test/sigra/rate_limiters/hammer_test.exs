defmodule Sigra.RateLimiters.HammerTest do
  use ExUnit.Case, async: false

  alias Sigra.RateLimiters.Hammer, as: Limiter

  defmodule TestHammer do
    use Hammer, backend: :ets
  end

  setup do
    Application.put_env(:sigra, :hammer_module, TestHammer)
    
    start_supervised!({TestHammer, clean_period: :timer.minutes(1)})

    :ok
  end

  describe "check_rate/3" do
    test "returns enriched metadata on allow" do
      key = "test_allow"
      limit = 10
      window_ms = 60_000

      assert {:allow, %{count: 1, remaining: 9, reset_ms: reset_ms}} = Limiter.check_rate(key, limit, window_ms)
      assert is_integer(reset_ms)
      assert reset_ms > System.system_time(:millisecond)
    end

    test "returns enriched metadata on deny" do
      key = "test_deny"
      limit = 1
      window_ms = 60_000

      # First hit should allow
      assert {:allow, %{count: 1, remaining: 0}} = Limiter.check_rate(key, limit, window_ms)

      # Second hit should deny
      assert {:deny, %{retry_after_ms: retry_after, reset_ms: reset_ms}} = Limiter.check_rate(key, limit, window_ms)
      assert is_integer(retry_after)
      assert retry_after > 0
      assert retry_after <= 60_000
      assert is_integer(reset_ms)
      assert reset_ms > System.system_time(:millisecond)
    end
  end
end
