defmodule Sigra.Organizations.ConfigTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Sigra.Organizations

  describe "@org_config_schema Phase 17 keys" do
    test "default invitation_ttl is 7 days in milliseconds" do
      schema = Organizations.__config_schema__()

      assert Keyword.fetch!(schema, :invitation_ttl)[:default] == :timer.hours(24 * 7)
    end

    test "default invitation_rate_limit_per_user is {20, 24h}" do
      schema = Organizations.__config_schema__()

      assert Keyword.fetch!(schema, :invitation_rate_limit_per_user)[:default] ==
               {20, :timer.hours(24)}
    end

    test "default invitation_rate_limit_per_org is {50, 24h}" do
      schema = Organizations.__config_schema__()

      assert Keyword.fetch!(schema, :invitation_rate_limit_per_org)[:default] ==
               {50, :timer.hours(24)}
    end

    test "default invitation_cleanup_retention_days is 30" do
      schema = Organizations.__config_schema__()

      assert Keyword.fetch!(schema, :invitation_cleanup_retention_days)[:default] == 30
    end

    test "emails_module default is nil" do
      schema = Organizations.__config_schema__()

      assert Keyword.fetch!(schema, :emails_module)[:default] == nil
    end

    test "secret_key_base default is nil" do
      schema = Organizations.__config_schema__()

      assert Keyword.fetch!(schema, :secret_key_base)[:default] == nil
    end

    test "url_builder default is nil" do
      schema = Organizations.__config_schema__()

      assert Keyword.fetch!(schema, :url_builder)[:default] == nil
    end
  end

  describe "__warn_long_invitation_ttl__/1" do
    test "emits a warning when invitation_ttl > 30 days" do
      config = %{invitation_ttl: :timer.hours(24 * 31)}

      log =
        capture_log(fn ->
          assert Organizations.__warn_long_invitation_ttl__(config) == :ok
        end)

      assert log =~ "invitation_ttl configured to 31 days"
      assert log =~ "30-day recommended phishing-window ceiling"
    end

    test "does not emit a warning at or below 30 days" do
      config = %{invitation_ttl: :timer.hours(24 * 30)}

      log =
        capture_log(fn ->
          assert Organizations.__warn_long_invitation_ttl__(config) == :ok
        end)

      refute log =~ "phishing-window"
    end

    test "does not emit a warning for the 7-day default" do
      config = %{invitation_ttl: :timer.hours(24 * 7)}

      log =
        capture_log(fn ->
          assert Organizations.__warn_long_invitation_ttl__(config) == :ok
        end)

      refute log =~ "phishing-window"
    end
  end
end
