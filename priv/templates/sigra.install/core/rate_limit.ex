# Generated module: defmodule #{app_module}.RateLimit
defmodule <%= app_module %>.RateLimit do
  @moduledoc """
  Host-owned Hammer ETS limiter for Sigra's generated authentication routes.

  The generated router explicitly selects `Sigra.RateLimiters.Hammer`; adjust
  the host's rate-limit configuration to fit its traffic and abuse posture.
  """

  use Hammer, backend: :ets
end
