defmodule Sigra.Passkeys.RateLimitTest do
  use ExUnit.Case, async: true

  alias Sigra.Passkeys

  defmodule TestUser do
    defstruct [:id]
  end

  defmodule RecordingLimiter do
    @behaviour Sigra.RateLimiter

    @impl Sigra.RateLimiter
    def check_rate(key, limit, window_ms) do
      send(self(), {:check_rate, key, limit, window_ms})

      case Process.get({__MODULE__, :mode}, :counting) do
        :counting ->
          count = Process.get({__MODULE__, key}, 0) + 1
          Process.put({__MODULE__, key}, count)

          if count <= limit do
            {:allow, count}
          else
            {:deny, window_ms}
          end

        {:reply, reply} ->
          reply
      end
    end
  end

  test "rate_limit_ceremony/3 builds a user-scoped registration key and denies the sixth hit" do
    Process.put({RecordingLimiter, :mode}, :counting)
    user_id = "user-123"
    config = config()

    for _ <- 1..5 do
      assert :ok = Passkeys.rate_limit_ceremony(config, user_id, :registration)
    end

    assert {:error, :rate_limited, %{retry_after_ms: 60_000}} =
             Passkeys.rate_limit_ceremony(config, user_id, :registration)

    assert_received {:check_rate, "sigra:passkeys:registration:user:user-123", 5, 60_000}
  end

  test "rate_limit_ceremony/3 builds an authentication key with the exact namespace" do
    Process.put({RecordingLimiter, :mode}, {:reply, {:allow, 1}})
    config = config()

    assert :ok = Passkeys.rate_limit_ceremony(config, 42, :authentication)

    assert_received {:check_rate, "sigra:passkeys:authentication:user:42", 5, 60_000}
  end

  test "rate_limit_ceremony/3 maps deny tuples to the public error shape" do
    Process.put({RecordingLimiter, :mode}, {:reply, {:deny, 12_345}})
    config = config()

    assert {:error, :rate_limited, %{retry_after_ms: 12_345}} =
             Passkeys.rate_limit_ceremony(config, "user-123", :registration)
  end

  defp config do
    Sigra.Config.new!(
      repo: Sigra.MockRepo,
      user_schema: TestUser,
      rate_limiting: [limiter: RecordingLimiter],
      passkeys: [
        rp_id: "sigra.test",
        origin: "https://sigra.test",
        ceremony_rate_limit: [limit: 5, window_ms: 60_000]
      ]
    )
  end
end
