defmodule Sigra.Plug.RateLimit do
  @moduledoc """
  IP-based rate limiting plug for auth routes.

  Rate limits non-safe HTTP methods (POST, PUT, PATCH, DELETE) by client
  IP address. GET and HEAD requests pass through without rate checking.
  When the rate is exceeded, returns 429 with a `Retry-After` header.
  Response content is delegated to the configured error handler for
  content negotiation (JSON for API, flash redirect for browser).

  ## Options

    * `:limit` - Maximum requests within window. Default: `10`.
    * `:window` - Window size in milliseconds. Default: `60_000` (1 minute).
    * `:key_prefix` - Prefix for rate limit key. Default: `"sigra"`.
    * `:limit_config_key` - Optional `:sigra` application-env key whose
      positive-integer value overrides `:limit` for each request.
    * `:window_config_key` - Optional `:sigra` application-env key whose
      positive-integer value overrides `:window` for each request.
    * `:error_handler` - Module implementing `Sigra.Plug.ErrorHandler`. Required.
    * `:limiter` - Module implementing `Sigra.RateLimiter`. If `nil`,
      resolved at call time: uses Hammer if loaded, otherwise Noop with warning.

  ## Key Format

  Rate limit keys are formatted as `"{key_prefix}:ip:{ip_address}"`.
  For example: `"sigra:ip:127.0.0.1"`.

  ## Proxy Considerations

  This plug reads `conn.remote_ip` as-is. Applications behind a reverse
  proxy (Nginx, Cloudflare, AWS ALB) must configure `remote_ip` or
  `plug_cloudflare` to set `conn.remote_ip` to the real client IP.

  ## Example

      plug Sigra.Plug.RateLimit,
        limit: 10,
        window: :timer.minutes(1),
        key_prefix: "login",
        error_handler: MyAppWeb.AuthErrorHandler

  """

  @behaviour Plug

  require Logger

  @impl Plug
  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, 10),
      window: Keyword.get(opts, :window, 60_000),
      key_prefix: Keyword.get(opts, :key_prefix, "sigra"),
      limit_config_key: Keyword.get(opts, :limit_config_key),
      window_config_key: Keyword.get(opts, :window_config_key),
      error_handler: Keyword.fetch!(opts, :error_handler),
      limiter: Keyword.get(opts, :limiter)
    }
  end

  @impl Plug
  def call(%{method: method} = conn, _opts) when method in ["GET", "HEAD"], do: conn

  def call(conn, opts) do
    limiter = resolve_limiter(opts.limiter)
    limit = runtime_positive_integer(opts.limit_config_key, opts.limit)
    window = runtime_positive_integer(opts.window_config_key, opts.window)
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    key = "#{opts.key_prefix}:ip:#{ip}"

    case limiter.check_rate(key, limit, window) do
      {:allow, _count} ->
        conn

      {:deny, retry_after_ms} ->
        retry_after_s = div(retry_after_ms + 999, 1000)

        Sigra.Telemetry.event(
          [:sigra, :security, :rate_limited],
          %{},
          %{ip: ip, key_prefix: opts.key_prefix, retry_after: retry_after_s}
        )

        conn
        |> Plug.Conn.put_resp_header("retry-after", Integer.to_string(retry_after_s))
        |> opts.error_handler.auth_error(:rate_limited, retry_after: retry_after_s)
        |> Plug.Conn.halt()
    end
  end

  defp resolve_limiter(nil) do
    if Sigra.OptionalDeps.hammer_available?() do
      Sigra.RateLimiters.Hammer
    else
      Logger.warning(
        "[Sigra] No rate limiter configured. Using Noop (fail-open). " <>
          "Add :hammer to your deps for IP rate limiting."
      )

      Sigra.RateLimiters.Noop
    end
  end

  defp resolve_limiter(module), do: module

  defp runtime_positive_integer(nil, default), do: default

  defp runtime_positive_integer(key, default) do
    case Application.get_env(:sigra, key, default) do
      value when is_integer(value) and value > 0 -> value
      _ -> default
    end
  end
end
