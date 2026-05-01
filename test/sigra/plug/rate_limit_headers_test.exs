defmodule Sigra.Plug.RateLimitHeadersTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Mox

  alias Sigra.Plug.RateLimit

  defmodule TestErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, :rate_limited, opts) do
      retry_after = Keyword.get(opts, :retry_after, 0)
      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(429, "Rate limited. Retry after #{retry_after}s")
    end

    @impl true
    def auth_error(conn, type, _opts) do
      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(403, "#{type}")
    end
  end

  @default_opts [
    limit: 10,
    window: 60_000,
    key_prefix: "sigra",
    error_handler: TestErrorHandler,
    limiter: Sigra.MockRateLimiter
  ]

  setup :verify_on_exit!

  describe "allow path" do
    test "emits X-RateLimit headers with remaining budget and reset time" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        # 1704067200000 is 2024-01-01 00:00:00Z
        {:allow, %{count: 1, remaining: 9, reset_ms: 1704067200000}}
      end)

      test_conn =
        conn(:post, "/login")
        |> RateLimit.call(opts)

      [limit] = Plug.Conn.get_resp_header(test_conn, "x-ratelimit-limit")
      [remaining] = Plug.Conn.get_resp_header(test_conn, "x-ratelimit-remaining")
      [reset] = Plug.Conn.get_resp_header(test_conn, "x-ratelimit-reset")

      assert limit == "10"
      assert remaining == "9"
      assert reset == "1704067200"
    end
  end

  describe "deny path" do
    test "emits X-RateLimit headers and rounded Retry-After" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:deny, %{retry_after_ms: 30_500, reset_ms: 1704067200000}}
      end)

      test_conn =
        conn(:post, "/login")
        |> RateLimit.call(opts)

      [limit] = Plug.Conn.get_resp_header(test_conn, "x-ratelimit-limit")
      [remaining] = Plug.Conn.get_resp_header(test_conn, "x-ratelimit-remaining")
      [reset] = Plug.Conn.get_resp_header(test_conn, "x-ratelimit-reset")
      [retry_after] = Plug.Conn.get_resp_header(test_conn, "retry-after")

      assert limit == "10"
      assert remaining == "0"
      assert reset == "1704067200"
      assert retry_after == "31"
      assert test_conn.status == 429
    end
  end
end
