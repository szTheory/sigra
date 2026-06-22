defmodule ExampleWeb.Phase27IntegrationTest do
  use ExampleWeb.ConnCase, async: false

  alias Example.AccountsFixtures

  @moduletag :phase27
  @moduletag :integration

  describe "platform admin routes" do
    test "platform admin reaches /admin and sees the needs-led landing", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      # /admin renders the needs-led landing launcher (200), not a redirect — it is
      # the entry point the whole admin IA (nav "Global overview", Cmd-K jump,
      # breadcrumbs) is built around.
      html =
        conn
        |> log_in_user(platform_admin)
        |> get(~p"/admin")
        |> html_response(200)

      assert html =~ "What do you need to do?"
      assert html =~ "Admin"
      assert html =~ "Global"
    end

    test "platform admin can intentionally enter /admin/organizations/:org", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      organization = AccountsFixtures.create_organization(%{name: "Acme HQ", slug: "acme-hq"})

      # The org root renders the organization overview landing (200) in tenant scope.
      html =
        conn
        |> log_in_user(platform_admin)
        |> get(~p"/admin/organizations/#{organization.slug}")
        |> html_response(200)

      assert html =~ "Admin"
      assert html =~ organization.name
      assert html =~ "Organization"
    end
  end

  describe "org admin routing" do
    test "authenticated org admin is denied global /admin, redirected home (no raw 403)",
         %{conn: conn} do
      org_admin = org_admin_fixture()

      conn =
        conn
        |> log_in_user(org_admin)
        |> get(~p"/admin")

      # An authenticated user lacking platform scope is sent to their account
      # hub with a flash rather than dead-ending on a raw 403 (least surprise).
      assert redirected_to(conn) == ~p"/app"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "don't have access"
    end

    test "org admin reaches only their allowed /admin/organizations/:org", %{conn: conn} do
      org_admin = org_admin_fixture()

      organization =
        AccountsFixtures.create_organization(%{name: "Allowed Org", slug: "allowed-org"})

      AccountsFixtures.create_membership(org_admin, organization, :admin)

      html =
        conn
        |> log_in_user(org_admin)
        |> get(~p"/admin/organizations/#{organization.slug}")
        |> html_response(200)

      assert html =~ "Admin"
      assert html =~ organization.name
      assert html =~ "Organization"
    end

    test "org admin gets a not found response on an out-of-scope organization slug", %{conn: conn} do
      org_admin = org_admin_fixture()

      allowed_org =
        AccountsFixtures.create_organization(%{name: "Allowed Org", slug: "allowed-scope"})

      _membership = AccountsFixtures.create_membership(org_admin, allowed_org, :admin)
      other_org = AccountsFixtures.create_organization(%{name: "Other Org", slug: "other-scope"})

      conn =
        conn
        |> log_in_user(org_admin)
        |> get(~p"/admin/organizations/#{other_org.slug}")

      assert conn.status == 404
      assert html_response(conn, 404) =~ "organization admin scope"
    end
  end

  defp platform_admin_fixture do
    AccountsFixtures.user_fixture(%{
      email: "platform-admin+#{System.unique_integer([:positive])}@example.com"
    })
  end

  defp org_admin_fixture do
    AccountsFixtures.user_fixture(%{
      email: "org-admin+#{System.unique_integer([:positive])}@example.com"
    })
  end
end
