defmodule Sigra.Admin.Live.EnterpriseConnectionLiveTest do
  use ExUnit.Case, async: true

  test "generated and example organization settings surfaces render truthful enterprise SSO states" do
    template =
      File.read!("priv/templates/sigra.install/organizations/live/organization_settings_live.ex")

    example =
      File.read!("test/example/lib/example_web/live/organization_settings_live.ex")

    for source <- [template, example] do
      assert source =~ "Enterprise SSO"
      assert source =~ "Setup"
      assert source =~ "Routing"
      assert source =~ "Reconciliation"
      assert source =~ "Enforcement"
      assert source =~ "validation_failed"
      assert source =~ "last_validation_error"
      assert source =~ "Validate"
      assert source =~ "Activate"
      assert source =~ "Disable"
      assert source =~ "Enterprise connection stayed non-active because validation failed."
    end
  end

  test "example wrapper delegates enterprise lifecycle truth to Sigra.EnterpriseConnections" do
    source = File.read!("test/example/lib/example/organizations.ex")

    assert source =~ "Sigra.EnterpriseConnections"
    assert source =~ "get_enterprise_connection"
    assert source =~ "change_enterprise_connection"
    assert source =~ "validate_enterprise_connection"
    assert source =~ "activate_enterprise_connection"
    assert source =~ "disable_enterprise_connection"
  end
end
