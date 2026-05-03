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
  def check_rate(_key, limit, window_ms) do
    # Match the {:allow, map} shape Sigra.Plug.RateLimit expects (rate_limit.ex:65).
    # The previous {:allow, 1} two-tuple crashed the plug with CaseClauseError on
    # every rate-limited request in any host that fell through to this no-op
    # fallback (e.g. fresh phx.new + mix sigra.install hosts that don't pull the
    # optional :hammer dep). Return the same shape Sigra.RateLimiters.Hammer
    # produces in its fail-open paths.
    now_ms = System.system_time(:millisecond)
    reset_ms = (div(now_ms, window_ms) + 1) * window_ms
    {:allow, %{count: 1, remaining: max(0, limit - 1), reset_ms: reset_ms}}
  end
end
