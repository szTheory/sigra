defmodule Sigra.RateLimiters.Hammer do
  @moduledoc """
  Hammer 7.x rate limiter implementation.

  Requires the host app to define a Hammer module with `use Hammer, backend: :ets`
  and start it in the supervision tree. Configure the module name via:

      config :sigra, hammer_module: MyApp.RateLimit

  ## Hammer 7.x API

  Hammer 7.x uses `hit(key, scale_ms, limit)` -- note that the window (scale)
  comes before the limit. This wrapper adapts the `Sigra.RateLimiter.check_rate/3`
  signature `(key, limit, window_ms)` to the correct Hammer parameter order.

  ## Fail-Open Behavior

  If the configured Hammer module is unavailable (e.g., GenServer not started),
  the wrapper logs a warning and returns `{:allow, 0}` -- failing open to avoid
  blocking legitimate requests when rate limiting infrastructure is down.
  """

  @behaviour Sigra.RateLimiter

  require Logger

  @impl Sigra.RateLimiter
  def check_rate(key, limit, window_ms) do
    module = hammer_module()

    try do
      # Hammer 7.x: hit(key, scale_ms, limit) -- note parameter order
      module.hit(key, window_ms, limit)
    rescue
      _ ->
        # Fail open per D-41 if Hammer GenServer not running
        Logger.warning("[Sigra] Hammer rate limiter unavailable, failing open")
        {:allow, 0}
    end
  end

  defp hammer_module do
    Application.get_env(:sigra, :hammer_module) ||
      raise "Sigra.RateLimiters.Hammer requires :hammer_module config. " <>
              "Set `config :sigra, hammer_module: MyApp.RateLimit` in your config."
  end
end
