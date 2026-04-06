defmodule Sigra.TelemetryTest do
  use ExUnit.Case, async: true

  alias Sigra.Telemetry

  setup do
    # Detach any handler left over from previous test runs
    :telemetry.detach("sigra-default-logger")
    :ok
  end

  describe "span/3" do
    test "emits :start and :stop events for the given prefix" do
      ref = make_ref()
      self = self()

      :telemetry.attach_many(
        "test-span-#{inspect(ref)}",
        [
          [:sigra, :auth, :login, :start],
          [:sigra, :auth, :login, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(self, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-span-#{inspect(ref)}") end)

      result = Telemetry.span([:sigra, :auth, :login], %{user_id: 1}, fn -> {:ok, "result"} end)

      assert result == {:ok, "result"}

      assert_receive {:telemetry_event, [:sigra, :auth, :login, :start], %{system_time: _}, %{user_id: 1}}
      assert_receive {:telemetry_event, [:sigra, :auth, :login, :stop], %{duration: _}, %{user_id: 1}}
    end

    test "emits :exception event when function raises" do
      ref = make_ref()
      self = self()

      :telemetry.attach(
        "test-exception-#{inspect(ref)}",
        [:sigra, :auth, :login, :exception],
        fn event, measurements, metadata, _config ->
          send(self, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-exception-#{inspect(ref)}") end)

      assert_raise RuntimeError, fn ->
        Telemetry.span([:sigra, :auth, :login], %{user_id: 1}, fn -> raise "boom" end)
      end

      assert_receive {:telemetry_event, [:sigra, :auth, :login, :exception], %{duration: _},
                       %{user_id: 1, kind: :error, reason: %RuntimeError{}, stacktrace: _}}
    end
  end

  describe "event/3" do
    test "emits a one-shot telemetry event" do
      ref = make_ref()
      self = self()

      :telemetry.attach(
        "test-event-#{inspect(ref)}",
        [:sigra, :security, :rate_limited],
        fn event, measurements, metadata, _config ->
          send(self, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-event-#{inspect(ref)}") end)

      Telemetry.event([:sigra, :security, :rate_limited], %{count: 1}, %{key: "ip:1.2.3.4"})

      assert_receive {:telemetry_event, [:sigra, :security, :rate_limited], %{count: 1},
                       %{key: "ip:1.2.3.4"}}
    end

    test "emits event with default empty measurements and metadata" do
      ref = make_ref()
      self = self()

      :telemetry.attach(
        "test-event-defaults-#{inspect(ref)}",
        [:sigra, :security, :lockout],
        fn event, measurements, metadata, _config ->
          send(self, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-event-defaults-#{inspect(ref)}") end)

      Telemetry.event([:sigra, :security, :lockout])

      assert_receive {:telemetry_event, [:sigra, :security, :lockout], %{}, %{}}
    end
  end

  describe "attach_default_logger/1" do
    test "returns :ok on first call" do
      assert :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)
    end

    test "returns {:error, :already_exists} on second call" do
      assert :ok = Telemetry.attach_default_logger()
      assert {:error, :already_exists} = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)
    end

    test "accepts level option" do
      assert :ok = Telemetry.attach_default_logger(level: :warning)
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)
    end
  end

  describe "handle_event/4" do
    test "logs at :info level by default" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :security, :rate_limited], %{count: 1}, %{key: "ip:1.2.3.4"})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "security.rate_limited"
    end

    test "logs at custom level when level option is set" do
      :ok = Telemetry.attach_default_logger(level: :warning)
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :security, :rate_limited], %{count: 1}, %{key: "ip:1.2.3.4"})
        end)

      assert log =~ "[warning]"
      assert log =~ "[Sigra]"
    end
  end

  describe "event catalog in @moduledoc" do
    test "moduledoc contains all expected event names" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Sigra.Telemetry)

      assert moduledoc =~ "[:sigra, :auth, :login"
      assert moduledoc =~ "[:sigra, :auth, :logout"
      assert moduledoc =~ "[:sigra, :auth, :register"
      assert moduledoc =~ "[:sigra, :token, :generate"
      assert moduledoc =~ "[:sigra, :token, :verify"
      assert moduledoc =~ "[:sigra, :security, :rate_limited]"
      assert moduledoc =~ "[:sigra, :security, :lockout]"
      assert moduledoc =~ "[:sigra, :security, :invalid_credentials]"
      assert moduledoc =~ "NEVER included: passwords"
    end
  end
end
