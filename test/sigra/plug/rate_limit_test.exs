defmodule Sigra.Plug.RateLimitTest do
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

  @default_opts [error_handler: TestErrorHandler, limiter: Sigra.MockRateLimiter]

  setup :verify_on_exit!

  describe "init/1" do
    test "returns opts map with defaults" do
      opts = RateLimit.init(@default_opts)
      assert opts.limit == 10
      assert opts.window == 60_000
      assert opts.key_prefix == "sigra"
      assert opts.error_handler == TestErrorHandler
      assert opts.limiter == Sigra.MockRateLimiter
    end

    test "accepts custom limit and window" do
      opts = RateLimit.init(@default_opts ++ [limit: 5, window: 30_000, key_prefix: "login"])
      assert opts.limit == 5
      assert opts.window == 30_000
      assert opts.key_prefix == "login"
    end

    test "raises when error_handler is missing" do
      assert_raise KeyError, fn ->
        RateLimit.init(limiter: Sigra.MockRateLimiter)
      end
    end
  end

  describe "call/2 - GET/HEAD passthrough" do
    test "passes GET requests through without checking rate" do
      opts = RateLimit.init(@default_opts)

      test_conn =
        conn(:get, "/login")
        |> RateLimit.call(opts)

      refute test_conn.halted
    end

    test "passes HEAD requests through without checking rate" do
      opts = RateLimit.init(@default_opts)

      test_conn =
        conn(:head, "/login")
        |> RateLimit.call(opts)

      refute test_conn.halted
    end
  end

  describe "call/2 - POST rate limiting" do
    test "checks rate for POST requests" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn key, limit, window ->
        assert key == "sigra:ip:127.0.0.1"
        assert limit == 10
        assert window == 60_000
        {:allow, %{count: 1, remaining: 9, reset_ms: 1000}}
      end)

      test_conn =
        conn(:post, "/login")
        |> RateLimit.call(opts)

      refute test_conn.halted
    end

    test "allows request when rate limiter returns {:allow, count}" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:allow, %{count: 5, remaining: 5, reset_ms: 1000}}
      end)

      test_conn =
        conn(:post, "/login")
        |> RateLimit.call(opts)

      refute test_conn.halted
    end

    test "halts with 429 when rate limiter returns {:deny, retry_after_ms}" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:deny, %{retry_after_ms: 30_000, reset_ms: 30_000}}
      end)

      test_conn =
        conn(:post, "/login")
        |> RateLimit.call(opts)

      assert test_conn.halted
      assert test_conn.status == 429
    end

    test "sets Retry-After header on 429 (seconds, rounded up)" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:deny, %{retry_after_ms: 30_500, reset_ms: 30_500}}
      end)

      test_conn =
        conn(:post, "/login")
        |> RateLimit.call(opts)

      [retry_after] = Plug.Conn.get_resp_header(test_conn, "retry-after")
      # 30_500ms rounded up = 31 seconds
      assert retry_after == "31"
    end

    test "calls error_handler.auth_error(:rate_limited, retry_after: N) on deny" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:deny, %{retry_after_ms: 60_000, reset_ms: 60_000}}
      end)

      test_conn =
        conn(:post, "/login")
        |> RateLimit.call(opts)

      assert test_conn.resp_body =~ "Retry after 60s"
    end

    test "formats IP from conn.remote_ip as key_prefix:ip:127.0.0.1" do
      opts = RateLimit.init(@default_opts ++ [key_prefix: "login"])

      expect(Sigra.MockRateLimiter, :check_rate, fn key, _limit, _window ->
        assert key == "login:ip:127.0.0.1"
        {:allow, %{count: 1, remaining: 9, reset_ms: 1000}}
      end)

      conn(:post, "/login")
      |> RateLimit.call(opts)
    end

    test "uses configured limit and window from init opts" do
      opts = RateLimit.init(@default_opts ++ [limit: 5, window: 30_000])

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, limit, window ->
        assert limit == 5
        assert window == 30_000
        {:allow, %{count: 1, remaining: 9, reset_ms: 1000}}
      end)

      conn(:post, "/login")
      |> RateLimit.call(opts)
    end

    test "emits [:sigra, :security, :rate_limited] telemetry on deny" do
      opts = RateLimit.init(@default_opts)

      :telemetry.attach(
        "test-rate-limited",
        [:sigra, :security, :rate_limited],
        fn event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-rate-limited") end)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:deny, %{retry_after_ms: 30_000, reset_ms: 30_000}}
      end)

      conn(:post, "/login")
      |> RateLimit.call(opts)

      assert_received {:telemetry_event, [:sigra, :security, :rate_limited], %{},
                       %{ip: "127.0.0.1", key_prefix: "sigra", retry_after: 30}}
    end
  end

  describe "call/2 - other HTTP methods" do
    test "checks rate for PUT requests" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:allow, %{count: 1, remaining: 9, reset_ms: 1000}}
      end)

      test_conn =
        conn(:put, "/login")
        |> RateLimit.call(opts)

      refute test_conn.halted
    end

    test "checks rate for PATCH requests" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:allow, %{count: 1, remaining: 9, reset_ms: 1000}}
      end)

      test_conn =
        conn(:patch, "/login")
        |> RateLimit.call(opts)

      refute test_conn.halted
    end

    test "checks rate for DELETE requests" do
      opts = RateLimit.init(@default_opts)

      expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
        {:allow, %{count: 1, remaining: 9, reset_ms: 1000}}
      end)

      test_conn =
        conn(:delete, "/login")
        |> RateLimit.call(opts)

      refute test_conn.halted
    end
  end
end
