defmodule Sigra.RateLimiter do
  @moduledoc """
  Behaviour for rate limiting implementations.

  Sigra supports both IP-based and account-based rate limiting. When
  Hammer is available, `Sigra.RateLimiters.Hammer` provides the
  implementation. When Hammer is absent, `Sigra.RateLimiters.Noop`
  is used as a fail-open fallback with a logged warning.

  ## Return Values

  Rate limiters return tagged tuples following Hammer's convention:

  - `{:allow, count}` -- request allowed, `count` is the current request count
  - `{:deny, retry_after_ms}` -- request denied, `retry_after_ms` indicates when to retry

  ## Mox Usage

      Mox.defmock(MockRateLimiter, for: Sigra.RateLimiter)
  """

  @type check_result ::
          {:allow, %{count: pos_integer(), remaining: non_neg_integer(), reset_ms: pos_integer()}}
          | {:deny, %{retry_after_ms: pos_integer(), reset_ms: pos_integer()}}

  @doc "Checks whether a request identified by `key` should be allowed."
  @doc since: "0.1.0"
  @callback check_rate(key :: String.t(), limit :: pos_integer(), window_ms :: pos_integer()) ::
              check_result()
end
