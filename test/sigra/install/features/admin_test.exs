defmodule Sigra.Install.Features.AdminTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Admin

  describe "enabled?/1" do
    test "returns true by default" do
      assert Admin.enabled?([])
      assert Admin.enabled?([]) == true
    end

    test "supports explicit default-on and opt-out flags" do
      assert Admin.enabled?(admin: true)
      refute Admin.enabled?(admin: false)
    end
  end

  describe "files/1" do
    test "owns the generated admin policy and shell boundary files" do
      assert [
               {:eex, "admin/policy.ex", "lib/my_app/sigra_admin_policy.ex"},
               {:eex, "admin/components/admin_shell.ex",
                "lib/my_app_web/components/admin_shell.ex"}
             ] = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")
    end
  end

  describe "migrations/1" do
    test "does not introduce any admin migrations in plan 27-01" do
      assert [] = Admin.migrations([])
    end
  end

  describe "injections/1" do
    test "owns the admin router fragment with global and org-scoped mounts" do
      [injection] = Admin.injections(otp_app: :my_app, web_module: "MyAppWeb")

      assert injection.target == "lib/my_app_web/router.ex"
      assert injection.marker == "# Sigra admin"
      assert injection.anchor == :before_last_end
      assert injection.content =~ ~s(live "/admin")
      assert injection.content =~ ~s(scope "/admin/organizations/:org")
      assert injection.content =~ "live_session"
    end
  end

  describe "template ownership guards" do
    test "admin templates exist on disk" do
      assert File.exists?("priv/templates/sigra.install/admin/policy.ex")
      assert File.exists?("priv/templates/sigra.install/admin/router_injection.ex")
      assert File.exists?("priv/templates/sigra.install/admin/components/admin_shell.ex")
    end
  end

  describe "Mix.Tasks.Sigra.Install admin surface" do
    test "registers Admin as a default-on opt-out feature" do
      source = File.read!("lib/mix/tasks/sigra.install.ex")

      assert source =~ "Sigra.Install.Features.Admin"
      assert source =~ "admin: :boolean"
      assert source =~ "admin: true"
      assert source =~ "admin?: Keyword.get(opts, :admin, true)"
      assert source =~ "--no-admin"
    end
  end
end
