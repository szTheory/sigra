defmodule Sigra.SuspiciousLoginTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.SuspiciousLogin

  setup :verify_on_exit!

  # Base config with suspicious login enabled
  defp build_config(overrides \\ []) do
    defaults = %Sigra.Config{
      repo: Sigra.MockRepo,
      user_schema: Sigra.SuspiciousLoginTest.TestUser,
      session: [
        store: Sigra.MockSessionStore,
        session_schema: Sigra.SuspiciousLoginTest.TestUser
      ],
      geo_ip: Keyword.get(overrides, :geo_ip, []),
      suspicious_login: Keyword.get(overrides, :suspicious_login, [enabled: true, notify: true])
    }

    struct(defaults, Keyword.drop(overrides, [:geo_ip, :suspicious_login]))
  end

  defp build_session(ip) do
    %Sigra.Session{
      id: 1,
      user_id: 1,
      hashed_token: "hashed",
      type: :standard,
      ip: ip,
      inserted_at: DateTime.utc_now()
    }
  end

  describe "detect/4" do
    test "returns :ok when login IP matches an existing session IP" do
      config = build_config()

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts ->
        [build_session("1.2.3.4"), build_session("5.6.7.8")]
      end)

      result = SuspiciousLogin.detect(config, 1, "1.2.3.4")

      assert :ok = result
    end

    test "returns {:suspicious, details} when login IP not in any session IP" do
      config = build_config()

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts ->
        [build_session("1.2.3.4"), build_session("5.6.7.8")]
      end)

      result = SuspiciousLogin.detect(config, 1, "9.9.9.9")

      assert {:suspicious, details} = result
      assert details.ip == "9.9.9.9"
    end

    test "returns :ok when user has no prior sessions (first login ever)" do
      config = build_config()

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [] end)

      result = SuspiciousLogin.detect(config, 1, "9.9.9.9")

      assert :ok = result
    end

    test "returns :ok when suspicious_login config enabled: false" do
      config = build_config(suspicious_login: [enabled: false, notify: true])

      # No session store calls expected
      result = SuspiciousLogin.detect(config, 1, "9.9.9.9")

      assert :ok = result
    end

    test "details include geo_city, geo_country_code when GeoIP configured" do
      config = build_config(geo_ip: [module: Sigra.MockGeoIP])

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts ->
        [build_session("1.2.3.4")]
      end)

      Sigra.MockGeoIP
      |> expect(:lookup, fn "9.9.9.9" ->
        {:ok, %{city: "Berlin", country_code: "DE"}}
      end)

      result = SuspiciousLogin.detect(config, 1, "9.9.9.9")

      assert {:suspicious, details} = result
      assert details.ip == "9.9.9.9"
      assert details.geo_city == "Berlin"
      assert details.geo_country_code == "DE"
    end

    test "details include ip with geo_city: nil, geo_country_code: nil when no GeoIP" do
      config = build_config()

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts ->
        [build_session("1.2.3.4")]
      end)

      result = SuspiciousLogin.detect(config, 1, "9.9.9.9")

      assert {:suspicious, details} = result
      assert details.ip == "9.9.9.9"
      assert details.geo_city == nil
      assert details.geo_country_code == nil
    end

    test "emits [:sigra, :security, :suspicious_login] telemetry event when suspicious" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :security, :suspicious_login]])
      config = build_config()

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts ->
        [build_session("1.2.3.4")]
      end)

      SuspiciousLogin.detect(config, 1, "9.9.9.9")

      assert_received {[:sigra, :security, :suspicious_login], ^ref, _measurements, metadata}
      assert metadata.user_id == 1
      assert metadata.ip == "9.9.9.9"
    end

    test "telemetry metadata includes user_id, ip, geo_city, geo_country_code per D-57" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :security, :suspicious_login]])
      config = build_config(geo_ip: [module: Sigra.MockGeoIP])

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts ->
        [build_session("1.2.3.4")]
      end)

      Sigra.MockGeoIP
      |> expect(:lookup, fn "9.9.9.9" ->
        {:ok, %{city: "Tokyo", country_code: "JP"}}
      end)

      SuspiciousLogin.detect(config, 1, "9.9.9.9")

      assert_received {[:sigra, :security, :suspicious_login], ^ref, _measurements, metadata}
      assert metadata.user_id == 1
      assert metadata.ip == "9.9.9.9"
      assert metadata.geo_city == "Tokyo"
      assert metadata.geo_country_code == "JP"
    end
  end
end
