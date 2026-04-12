defmodule Sigra.SessionTest do
  use ExUnit.Case, async: true

  @moduletag :phase4

  alias Sigra.Session

  describe "Session struct" do
    test "can be created with all fields" do
      now = DateTime.utc_now()

      session = %Session{
        id: "sess_123",
        user_id: "user_456",
        token: "raw-token",
        hashed_token: <<1, 2, 3>>,
        type: :remember_me,
        ip: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        parsed_ua: %{browser: "Chrome", browser_version: "120", os: "macOS"},
        geo_city: "Portland",
        geo_country_code: "US",
        last_active_at: now,
        sudo_at: now,
        active_organization_id: "0190b3a4-1234-7000-8000-000000000000",
        inserted_at: now
      }

      assert session.id == "sess_123"
      assert session.user_id == "user_456"
      assert session.token == "raw-token"
      assert session.hashed_token == <<1, 2, 3>>
      assert session.type == :remember_me
      assert session.ip == "192.168.1.1"
      assert session.user_agent == "Mozilla/5.0"
      assert session.parsed_ua == %{browser: "Chrome", browser_version: "120", os: "macOS"}
      assert session.geo_city == "Portland"
      assert session.geo_country_code == "US"
      assert session.last_active_at == now
      assert session.sudo_at == now
      assert session.active_organization_id == "0190b3a4-1234-7000-8000-000000000000"
      assert session.inserted_at == now
    end

    test "defaults type to :standard" do
      session = %Session{}

      assert session.type == :standard
    end

    test "defaults optional fields to nil" do
      session = %Session{}

      assert session.id == nil
      assert session.user_id == nil
      assert session.token == nil
      assert session.hashed_token == nil
      assert session.ip == nil
      assert session.user_agent == nil
      assert session.parsed_ua == nil
      assert session.geo_city == nil
      assert session.geo_country_code == nil
      assert session.last_active_at == nil
      assert session.sudo_at == nil
      assert session.active_organization_id == nil
      assert session.inserted_at == nil
    end
  end

  describe "SessionStore behaviour" do
    test "defines 8 callbacks" do
      callbacks = Sigra.SessionStore.behaviour_info(:callbacks)

      assert length(callbacks) == 8
      assert {:create, 3} in callbacks
      assert {:fetch, 2} in callbacks
      assert {:delete, 2} in callbacks
      assert {:list_by_user, 2} in callbacks
      assert {:delete_all_for_user, 2} in callbacks
      assert {:update_activity, 3} in callbacks
      assert {:update_sudo, 3} in callbacks
      # Phase 14 (Plan 14-01, D-20) — active organization write path.
      assert {:update_active_organization, 3} in callbacks
    end
  end

  describe "GeoIP behaviour" do
    test "defines lookup/1 callback" do
      callbacks = Sigra.GeoIP.behaviour_info(:callbacks)

      assert {:lookup, 1} in callbacks
    end
  end
end
