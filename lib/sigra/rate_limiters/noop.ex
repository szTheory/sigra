defmodule Sigra.RateLimiters.Noop do
  @moduledoc """
  No-op rate limiter that always allows requests.

  > #### Warning {: .warning}
  >
  > This is a fallback implementation used when no rate limiting library
  > (such as Hammer) is configured. It provides **no actual rate limiting**.
  > For production use, configure a real rate limiter.

  This module is used automatically when the `:limiter` config option is
  `nil` and Hammer is not available. A warning is logged once at startup.
  """

  @behaviour Sigra.RateLimiter

  @impl Sigra.RateLimiter
  def check_rate(_key, _limit, _window_ms) do
    {:allow, 1}
  end
end
