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

    test "moduledoc contains Phase 3 email and confirmation events" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Sigra.Telemetry)

      assert moduledoc =~ "Email Delivery"
      assert moduledoc =~ "[:sigra, :email, :deliver"
      assert moduledoc =~ "[:sigra, :confirmation, :verify"
      assert moduledoc =~ "[:sigra, :confirmation, :sent]"
      assert moduledoc =~ "[:sigra, :reset, :requested]"
      assert moduledoc =~ "[:sigra, :reset, :completed]"
      assert moduledoc =~ "[:sigra, :token, :expired]"
    end
  end

  describe "Phase 3 default logger events" do
    test "logs [:sigra, :email, :deliver, :stop] event" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :email, :deliver, :stop], %{}, %{email_type: :confirmation})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "email.deliver.stop"
    end

    test "logs [:sigra, :confirmation, :verify, :stop] event" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :confirmation, :verify, :stop], %{}, %{user_id: 1})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "confirmation.verify.stop"
    end

    test "logs [:sigra, :reset, :requested] event" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :reset, :requested], %{}, %{user_id: 1})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "reset.requested"
    end

    test "logs [:sigra, :reset, :completed] event" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :reset, :completed], %{}, %{user_id: 1})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "reset.completed"
    end

    test "logs [:sigra, :token, :expired] event" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :token, :expired], %{}, %{context: "confirm"})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "token.expired"
    end
  end

  describe "MFA event catalog in @moduledoc" do
    test "moduledoc contains MFA span events" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Sigra.Telemetry)

      assert moduledoc =~ "[:sigra, :mfa, :enroll"
      assert moduledoc =~ "[:sigra, :mfa, :verify"
      assert moduledoc =~ "[:sigra, :mfa, :disable"
      assert moduledoc =~ "[:sigra, :mfa, :backup_codes, :regenerate"
    end

    test "moduledoc contains MFA one-shot events" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Sigra.Telemetry)

      assert moduledoc =~ "[:sigra, :mfa, :lockout]"
      assert moduledoc =~ "[:sigra, :mfa, :pending_expired]"
      assert moduledoc =~ "[:sigra, :mfa, :trust, :granted]"
      assert moduledoc =~ "[:sigra, :mfa, :trust, :revoked_all]"
    end
  end

  describe "MFA default logger events" do
    test "logs [:sigra, :mfa, :enroll, :stop] event" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :mfa, :enroll, :stop], %{}, %{user_id: 1})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "mfa.enroll.stop"
    end

    test "logs [:sigra, :mfa, :lockout] at warning level" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :mfa, :lockout], %{}, %{user_id: 1})
        end)

      assert log =~ "[warning]"
      assert log =~ "[Sigra]"
      assert log =~ "mfa.lockout"
    end

    test "logs [:sigra, :mfa, :pending_expired] at warning level" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :mfa, :pending_expired], %{}, %{user_id: 1, ip: "1.2.3.4"})
        end)

      assert log =~ "[warning]"
      assert log =~ "mfa.pending_expired"
    end

    test "logs [:sigra, :mfa, :trust, :granted] event" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :mfa, :trust, :granted], %{}, %{user_id: 1})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "mfa.trust.granted"
    end

    test "logs [:sigra, :mfa, :trust, :revoked_all] event" do
      :ok = Telemetry.attach_default_logger()
      on_exit(fn -> :telemetry.detach("sigra-default-logger") end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Telemetry.event([:sigra, :mfa, :trust, :revoked_all], %{}, %{user_id: 1})
        end)

      assert log =~ "[Sigra]"
      assert log =~ "mfa.trust.revoked_all"
    end
  end

  describe "mfa_events/0" do
    test "returns all MFA event names" do
      events = Telemetry.mfa_events()

      assert [:sigra, :mfa, :enroll, :stop] in events
      assert [:sigra, :mfa, :verify, :stop] in events
      assert [:sigra, :mfa, :disable, :stop] in events
      assert [:sigra, :mfa, :backup_codes, :regenerate, :stop] in events
      assert [:sigra, :mfa, :lockout] in events
      assert [:sigra, :mfa, :pending_expired] in events
      assert [:sigra, :mfa, :trust, :granted] in events
      assert [:sigra, :mfa, :trust, :revoked_all] in events
    end
  end

  describe "Testing helpers" do
    test "extract_confirmation_token/1 extracts token from URL" do
      token = "abc123def456"
      url = "https://example.com/users/confirm/#{token}"

      assert Sigra.Testing.extract_confirmation_token(url) == token
    end

    test "extract_reset_token/1 extracts token from URL" do
      token = "xyz789ghi012"
      url = "https://example.com/users/reset-password/#{token}"

      assert Sigra.Testing.extract_reset_token(url) == token
    end
  end
end
