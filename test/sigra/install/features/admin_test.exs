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
    test "owns the admin router, layout, and error-handler wiring" do
      injections =
        Admin.injections(otp_app: :my_app, web_module: "MyAppWeb", app_module: "MyApp")

      assert Enum.map(injections, & &1.target) == [
               "lib/my_app_web/router.ex",
               "lib/my_app_web/components/layouts.ex",
               "lib/my_app_web/components/layouts.ex",
               "lib/my_app_web/auth_error_handler.ex"
             ]

      [router, layouts_import, layouts_admin, error_handler] = injections

      assert router.marker == "# Sigra admin"
      assert router.anchor == :before_last_end
      assert router.content =~ "Sigra.Plug.RequireAdminAccess"
      assert router.content =~ "Sigra.LiveView.AdminScope"
      assert router.content =~ "MyApp.SigraAdminPolicy"
      assert router.content =~ "{MyAppWeb.Layouts, :admin}"
      assert router.content =~ ~s(live "/admin")
      assert router.content =~ ~s(scope "/admin/organizations/:org")

      assert layouts_import.marker == "import MyAppWeb.Components.AdminShell"
      assert layouts_import.anchor == :after_use_block
      assert layouts_import.content =~ "import MyAppWeb.Components.AdminShell"

      assert layouts_admin.marker == "def admin(assigns) do"
      assert layouts_admin.anchor == :before_last_end
      assert layouts_admin.content =~ "<.admin_shell"
      assert layouts_admin.content =~ "<.flash_group"

      assert error_handler.marker == "def auth_error(conn, :insufficient_scope, _opts) do"
      assert error_handler.anchor == :before_last_end
      assert error_handler.content =~ ":insufficient_scope"
      assert error_handler.content =~ ":not_found"
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

    test "requires phoenix_live_view because admin foundation ships LiveViews" do
      source = File.read!("mix.exs")

      assert source =~ ~s({:phoenix_live_view, "~> 1.1"})
      refute source =~ ~s({:phoenix_live_view, "~> 1.1", optional: true})
    end
  end
end
