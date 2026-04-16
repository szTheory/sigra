defmodule ExampleWeb.AdminShellTest do
  use ExampleWeb.ConnCase, async: false

  alias Example.AccountsFixtures
  alias ExampleWeb.AuthErrorHandler

  describe "admin shell scope chrome" do
    test "renders Admin and Global for the global admin shell" do
      platform_admin =
        AccountsFixtures.user_fixture(%{
          email: "platform-admin+#{System.unique_integer([:positive])}@example.com"
        })

      conn = build_conn() |> log_in_user(platform_admin) |> get(~p"/admin")
      html = html_response(conn, 200)
      assert html =~ "Admin"
      assert html =~ "Global"
    end

    test "renders Admin and the organization name for an organization scope" do
      org_admin =
        AccountsFixtures.user_fixture(%{
          email: "org-admin+#{System.unique_integer([:positive])}@example.com"
        })

      organization =
        AccountsFixtures.create_organization(%{name: "Acme Ops", slug: "acme-ops-shell"})

      AccountsFixtures.create_membership(org_admin, organization, :admin)

      conn =
        build_conn()
        |> log_in_user(org_admin)
        |> get(~p"/admin/organizations/#{organization.slug}")

      html = html_response(conn, 200)
      assert html =~ "Admin"
      assert html =~ "Acme Ops"
      assert html =~ "Organization"
    end
  end

  describe "denied states are not blank pages" do
    test "access denied renders explicit copy for insufficient scope" do
      conn =
        build_conn()
        |> AuthErrorHandler.auth_error(:insufficient_scope, [])

      assert conn.status == 403
      assert conn.resp_body =~ "Access denied"
      refute String.trim(conn.resp_body) == ""
    end

    test "organization not found renders explicit copy instead of a blank page" do
      conn =
        build_conn()
        |> AuthErrorHandler.auth_error(:not_found, [])

      assert conn.status == 404
      assert conn.resp_body =~ "organization admin scope"
      refute String.trim(conn.resp_body) == ""
    end
  end
end
