defmodule Sigra.RateLimiters.Hammer do
  @moduledoc """
  Hammer 7.x rate limiter implementation.

  Requires the host app to define a Hammer module with `use Hammer, backend: :ets`
  and start it in the supervision tree. Configure the module name via:

      config :sigra, hammer_module: MyApp.RateLimit

  ## Hammer 7.x API

  Hammer 7.x uses `hit(key, scale_ms, limit)` -- note that the window (scale)
  comes before the limit. This wrapper adapts the `Sigra.RateLimiter` `check_rate/3`
  callback signature `(key, limit, window_ms)` to the correct Hammer parameter order.

  ## Fail-Open Behavior

  If the configured Hammer module is unavailable (e.g., GenServer not started),
  the wrapper logs a warning and returns `{:allow, 0}` -- failing open to avoid
  blocking legitimate requests when rate limiting infrastructure is down.
  """

  @behaviour Sigra.RateLimiter

  require Logger

  @impl Sigra.RateLimiter
  def check_rate(key, limit, window_ms) do
    now_ms = System.system_time(:millisecond)
    reset_ms = (div(now_ms, window_ms) + 1) * window_ms

    case hammer_module() do
      nil ->
        # No :hammer_module configured. Fail open with a one-time warning so
        # developers see actionable remediation, but do not 500 the request —
        # the auth_rate_limit pipeline is wired in the generated router by
        # default, and a missing hammer_module config should never break login
        # / registration / confirmation flows.
        warn_missing_hammer_module_once()
        {:allow, %{count: 1, remaining: limit - 1, reset_ms: reset_ms}}

      module ->
        try do
          # Hammer 7.x: hit(key, scale_ms, limit) -- note parameter order
          case module.hit(key, window_ms, limit) do
            {:allow, count} ->
              remaining = max(0, limit - count)
              {:allow, %{count: count, remaining: remaining, reset_ms: reset_ms}}

            {:deny, retry_after_ms} ->
              {:deny, %{retry_after_ms: retry_after_ms, reset_ms: reset_ms}}
          end
        rescue
          _ ->
            # Fail open per D-41 if Hammer GenServer not running
            Logger.warning("[Sigra] Hammer rate limiter unavailable, failing open")
            {:allow, %{count: 1, remaining: limit - 1, reset_ms: reset_ms}}
        end
    end
  end

  defp hammer_module do
    Application.get_env(:sigra, :hammer_module)
  end

  defp warn_missing_hammer_module_once do
    case :persistent_term.get({__MODULE__, :missing_hammer_module_warned}, false) do
      true ->
        :ok

      false ->
        :persistent_term.put({__MODULE__, :missing_hammer_module_warned}, true)

        Logger.warning(
          "[Sigra] :hammer_module config is not set; auth_rate_limit pipeline is failing open. " <>
            "Set `config :sigra, hammer_module: MyApp.RateLimit` (with a `use Hammer, backend: :ets` " <>
            "module started in your supervision tree) to enable rate limiting."
        )
    end
  end
end
