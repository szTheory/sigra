defmodule ExampleWeb.AdminShellTest do
  use ExampleWeb.ConnCase, async: false

  alias Example.AccountsFixtures
  alias Example.Accounts.Scope
  alias ExampleWeb.Components.AdminShell
  alias ExampleWeb.Layouts
  alias ExampleWeb.AuthErrorHandler

  import Phoenix.LiveViewTest

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
      assert html =~ "Users"
      assert html =~ "href=\"/admin/users\""
      assert html =~ "Audit"
      assert html =~ "href=\"/admin/audit\""
      assert html =~ "What do you need to do?"
      assert html =~ "data-scope=\"global\""
      assert sidebar_workspace_before_overviews?(html)
      assert bottom_nav_users_first?(html)
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
      assert html =~ "Organization overview"
      assert html =~ "Users"
      assert html =~ "href=\"/admin/organizations/#{organization.slug}/users\""
      assert html =~ "Audit"
      assert html =~ "href=\"/admin/organizations/#{organization.slug}/audit\""
      assert html =~ "Work inside this organization scope"
      assert html =~ "data-scope=\"organization\""
      assert html =~ "Org · Acme Ops"
      assert sidebar_workspace_before_overviews?(html)
    end

    test "renders explicit impersonation chrome with real admin, effective user, and app-wide stop path" do
      admin =
        AccountsFixtures.user_fixture(%{
          email: "platform-admin+#{System.unique_integer([:positive])}@example.com",
          display_name: "Real Admin"
        })

      target =
        AccountsFixtures.user_fixture(%{
          email: "impersonated+#{System.unique_integer([:positive])}@example.com",
          display_name: "Impersonated User"
        })

      html =
        render_component(&AdminShell.admin_shell/1,
          admin_scope: %{mode: :global, platform_admin?: true},
          current_scope: %Scope{user: target, impersonating_from: admin},
          inner_block: [%{inner_block: fn _, _ -> "Body" end}]
        )

      assert html =~ "Impersonating Impersonated User"
      assert html =~ "Signed in as Real Admin"
      assert html =~ "End impersonation"
      assert html =~ "action=\"/impersonation\""
      assert html =~ "method=\"post\""
      assert html =~ "name=\"_method\""
      assert html =~ "value=\"delete\""
      refute html =~ "Special session"
    end

    test "impersonation chrome remains visible while active and does not expose a dismiss-only control" do
      admin =
        AccountsFixtures.user_fixture(%{
          email: "platform-admin+#{System.unique_integer([:positive])}@example.com",
          display_name: "Real Admin"
        })

      target =
        AccountsFixtures.user_fixture(%{
          email: "impersonated+#{System.unique_integer([:positive])}@example.com",
          display_name: "Impersonated User"
        })

      html =
        render_component(&Layouts.app/1,
          flash: %{},
          current_scope: %Scope{user: target, impersonating_from: admin},
          user_organizations: [],
          inner_block: [%{inner_block: fn _, _ -> "Body" end}]
        )

      assert html =~ "Impersonating Impersonated User"
      assert html =~ "Signed in as Real Admin"
      assert html =~ "End impersonation"
      assert html =~ "action=\"/impersonation\""
      refute html =~ "Dismiss"
      refute html =~ "Hide banner"
    end
  end

  defp sidebar_workspace_before_overviews?(html) do
    ws = html_offset(html, "sg-nav-title\">Workspace<")
    ov = html_offset(html, "sg-nav-title\">Overviews<")
    is_integer(ws) and is_integer(ov) and ws < ov
  end

  defp bottom_nav_users_first?(html) do
    case :binary.match(html, "aria-label=\"Admin bottom nav\"") do
      {start, _} ->
        len = min(2500, byte_size(html) - start)
        fragment = binary_part(html, start, len)

        case {:binary.match(fragment, "<span>Users</span>"),
              :binary.match(fragment, "<span>Global</span>")} do
          {{u0, _}, {g0, _}} when u0 < g0 -> true
          _ -> false
        end

      :nomatch ->
        false
    end
  end

  defp html_offset(html, needle) do
    case :binary.match(html, needle) do
      {offset, _length} -> offset
      :nomatch -> nil
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
