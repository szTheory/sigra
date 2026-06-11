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
      assert html =~ ~s(aria-label="Sigra admin overview")
      assert html =~ "sg-brand-mark__lockup"
      assert html =~ ~s(src="/images/sigra-logo-primary.svg")
      assert html =~ ~s(src="/images/sigra-logo-primary-dark.svg")
      refute html =~ "sg-brand-mark__word"
      refute html =~ "sg-brand-mark__rail-accent"
      refute html =~ "sg-brand-mark__core"
      assert html =~ "role=\"radiogroup\""
      assert html =~ "aria-label=\"Theme\""
      assert html =~ "data-theme-value=\"light\""
      assert html =~ "data-theme-value=\"dark\""
      assert html =~ "data-theme-value=\"system\""
      assert html =~ "phx-hook=\"ThemeSwitch\""
      assert html =~ "data-sg-admin-js"
      assert html =~ "data-sg-admin-theme-preference"
      assert html =~ "sg-admin-loading-bar"
      assert html =~ "data-sg-admin-loading-bar"
      assert html =~ "aria-hidden=\"true\""
      assert html =~ "Global"
      assert html =~ "Users"
      assert html =~ "href=\"/admin/users\""
      assert html =~ "Audit"
      assert html =~ "href=\"/admin/audit\""
      assert html =~ "Branding"
      assert html =~ "href=\"/admin/auth-branding\""
      assert_live_nav_link(html, "/admin")
      assert_live_nav_link(html, "/admin/users")
      assert_live_nav_link(html, "/admin/audit")
      assert_live_nav_link(html, "/admin/auth-branding")
      assert html =~ "What do you need to do?"
      assert html =~ "User snapshot"
      assert html =~ ~s(id="overview-metric-total-users")
      assert html =~ ~s(<dd class="sg-metric__caption">total users</dd>)
      assert html =~ ~s(id="overview-metric-new-users")
      assert html =~ "new this week"
      assert html =~ ~s(id="overview-metric-active-users")
      assert html =~ "active this week"
      assert html =~ ~s(id="overview-metric-auth-coverage")
      assert html =~ "MFA coverage"
      assert html =~ "data-scope=\"global\""
      assert sidebar_overviews_before_workspace?(html)
      assert bottom_nav_overview_first?(html)
      assert overview_breadcrumb?(html, "Overview")
    end

    test "ships cropped path-only Sigra lockup assets" do
      for path <- [
            "priv/static/images/sigra-logo-primary.svg",
            "priv/static/images/sigra-logo-primary-dark.svg"
          ] do
        source = File.read!(path)

        assert source =~ ~s(viewBox="20 12 188 54")
        assert source =~ "Inter Display Black v4.1."
        assert source =~ "<path"
        refute source =~ "<text"
        refute source =~ "font-family"
      end
    end

    test "renders parent and current breadcrumb for global workspace pages" do
      platform_admin =
        AccountsFixtures.user_fixture(%{
          email: "platform-admin+users-crumb-#{System.unique_integer([:positive])}@example.com"
        })

      conn = build_conn() |> log_in_user(platform_admin) |> get(~p"/admin/users")

      breadcrumb = breadcrumb_fragment(html_response(conn, 200))

      assert breadcrumb =~ ~s(href="/admin")
      assert breadcrumb =~ "Overview"
      assert breadcrumb =~ "sg-breadcrumb__sep"
      assert breadcrumb =~ ~s(aria-current="page")
      assert breadcrumb =~ "Users"
      assert html_offset(breadcrumb, "Overview") < html_offset(breadcrumb, "Users")
      refute breadcrumb =~ "Global"
    end

    test "renders explicit multi-step breadcrumbs when a page supplies them" do
      html =
        render_component(&AdminShell.admin_shell/1,
          admin_scope: %{mode: :global, platform_admin?: true},
          current_scope: nil,
          page_title: "User",
          admin_breadcrumbs: [
            %{label: "Overview", href: "/admin"},
            %{
              label: "Users",
              href: "/admin/users?order_by=inserted_at&order_direction=desc"
            },
            %{label: "person@example.com"}
          ],
          inner_block: [%{inner_block: fn _, _ -> "Body" end}]
        )

      breadcrumb = breadcrumb_fragment(html)

      assert breadcrumb =~ ~s(href="/admin")
      assert breadcrumb =~ "Overview"
      assert breadcrumb =~ ~s(href="/admin/users?order_by=inserted_at&amp;order_direction=desc")
      assert breadcrumb =~ "Users"
      assert breadcrumb =~ ~s(aria-current="page")
      assert breadcrumb =~ "person@example.com"
      assert html_offset(breadcrumb, "Overview") < html_offset(breadcrumb, "Users")
      assert html_offset(breadcrumb, "Users") < html_offset(breadcrumb, "person@example.com")
    end

    test "renders Admin and the organization name for an organization scope" do
      org_admin =
        AccountsFixtures.user_fixture(%{
          email: "platform-admin+org-shell-#{System.unique_integer([:positive])}@example.com"
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
      assert sidebar_overviews_before_workspace?(html)
      assert overview_breadcrumb?(html, "Overview")
      assert_live_nav_link(html, "/admin/organizations/#{organization.slug}")
      assert_live_nav_link(html, "/admin/organizations/#{organization.slug}/users")
      assert_live_nav_link(html, "/admin/organizations/#{organization.slug}/audit")
      refute_live_nav_link(html, "/admin")
    end

    test "renders Overview parent breadcrumb for organization workspace pages" do
      org_admin =
        AccountsFixtures.user_fixture(%{
          email: "org-admin+users-crumb-#{System.unique_integer([:positive])}@example.com"
        })

      organization =
        AccountsFixtures.create_organization(%{
          name: "Acme Ops",
          slug: "acme-ops-users-crumb"
        })

      AccountsFixtures.create_membership(org_admin, organization, :admin)

      conn =
        build_conn()
        |> log_in_user(org_admin)
        |> get(~p"/admin/organizations/#{organization.slug}/users")

      breadcrumb = breadcrumb_fragment(html_response(conn, 200))

      assert breadcrumb =~ ~s(href="/admin/organizations/#{organization.slug}")
      assert breadcrumb =~ "Overview"
      assert breadcrumb =~ "sg-breadcrumb__sep"
      assert breadcrumb =~ ~s(aria-current="page")
      assert breadcrumb =~ "Acme Ops Users"
      assert html_offset(breadcrumb, "Overview") < html_offset(breadcrumb, "Acme Ops Users")
      refute breadcrumb =~ "Global"
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

  defp sidebar_overviews_before_workspace?(html) do
    ov = html_offset(html, "sg-nav-title\">Overviews<")
    ws = html_offset(html, "sg-nav-title\">Workspace<")
    is_integer(ov) and is_integer(ws) and ov < ws
  end

  defp bottom_nav_overview_first?(html) do
    case :binary.match(html, "aria-label=\"Admin bottom nav\"") do
      {start, _} ->
        len = min(2500, byte_size(html) - start)
        fragment = binary_part(html, start, len)

        case {:binary.match(fragment, "<span>Global</span>"),
              :binary.match(fragment, "<span>Users</span>")} do
          {{g0, _}, {u0, _}} when g0 < u0 -> true
          _ -> false
        end

      :nomatch ->
        false
    end
  end

  defp overview_breadcrumb?(html, page_title) do
    breadcrumb = breadcrumb_fragment(html)

    breadcrumb =~ ~s(aria-label="Breadcrumb") and
      breadcrumb =~ ~s(aria-current="page") and
      breadcrumb =~ page_title and
      not String.contains?(breadcrumb, "sg-breadcrumb__sep")
  end

  defp assert_live_nav_link(html, href) do
    fragment = anchor_fragment(html, href)

    assert fragment =~ ~s(data-phx-link="redirect")
    assert fragment =~ ~s(data-phx-link-state="push")
  end

  defp refute_live_nav_link(html, href) do
    fragment = anchor_fragment(html, href)

    refute fragment =~ ~s(data-phx-link="redirect")
    refute fragment =~ ~s(data-phx-link-state="push")
  end

  defp anchor_fragment(html, href) do
    href_attr = ~s(href="#{href}")

    fragment =
      html
      |> String.split("<a", trim: true)
      |> Enum.map(&("<a" <> &1))
      |> Enum.find("", &String.contains?(&1, href_attr))

    assert fragment != "", "expected an anchor with #{href_attr}"

    case :binary.match(fragment, "</a>") do
      {stop, length} -> binary_part(fragment, 0, stop + length)
      :nomatch -> binary_part(fragment, 0, min(1_200, byte_size(fragment)))
    end
  end

  defp breadcrumb_fragment(html) do
    case :binary.match(html, ~s(aria-label="Breadcrumb")) do
      {start, _} ->
        fragment = binary_part(html, start, min(1_600, byte_size(html) - start))

        case :binary.match(fragment, "</nav>") do
          {stop, length} -> binary_part(fragment, 0, stop + length)
          :nomatch -> fragment
        end

      :nomatch ->
        ""
    end
  end

  defp html_offset(html, needle) do
    case :binary.match(html, needle) do
      {offset, _length} -> offset
      :nomatch -> nil
    end
  end

  describe "Phase 157 Overview redesign" do
    test "global overview disconnected mount (GET) renders data, not skeleton" do
      platform_admin =
        AccountsFixtures.user_fixture(%{
          email:
            "platform-admin+157-global-skel-#{System.unique_integer([:positive])}@example.com"
        })

      conn = build_conn() |> log_in_user(platform_admin) |> get(~p"/admin")
      html = html_response(conn, 200)

      refute html =~ "sg-skeleton"
      refute html =~ ~s(aria-busy="true")
      assert html =~ "sg-notice"
      assert html =~ "Find a user"
      assert html =~ "Investigate an event"
      assert html =~ "Review risky accounts"
      refute html =~ ~s(role="status")
      refute html =~ ~s(data-phx-id=)
      refute html =~ "sg-metric-link__value"
      refute html =~ "sg-card sg-posture-strip"
      refute html =~ "sg-posture-strip__risk"
      refute html =~ "What Sigra can do"
    end

    test "global overview connected mount (live/2) renders data, not skeleton" do
      AccountsFixtures.user_fixture(%{
        email: "needs-review+157-global-live-#{System.unique_integer([:positive])}@example.com"
      })
      |> AccountsFixtures.locked_user_fixture()

      platform_admin =
        AccountsFixtures.user_fixture(%{
          email:
            "platform-admin+157-global-live-#{System.unique_integer([:positive])}@example.com"
        })

      {:ok, _view, html} = build_conn() |> log_in_user(platform_admin) |> live(~p"/admin")

      refute html =~ "sg-skeleton"
      refute html =~ ~s(aria-busy="true")
      assert html =~ "sg-notice"
      assert html =~ "accounts need review"
      assert html =~ "sg-notice__action"
      assert html =~ "Review accounts"
      assert html =~ ~s(href="/admin/users?needs_review=true")
      refute html =~ ~s(role="status")
      refute html =~ "sg-metric-link__value"
      refute html =~ "sg-card sg-posture-strip"
      refute html =~ "sg-posture-strip__risk"
      refute html =~ "What Sigra can do"

      assert html_offset(html, "sg-notice") < html_offset(html, "sg-grid sg-grid--3")
    end

    test "org overview disconnected mount (GET) renders skeleton, not stat values" do
      org_admin =
        AccountsFixtures.user_fixture(%{
          email: "org-admin+157-org-skel-#{System.unique_integer([:positive])}@example.com"
        })

      organization =
        AccountsFixtures.create_organization(%{
          name: "Test Org 157",
          slug: "test-org-157-skel-#{System.unique_integer([:positive])}"
        })

      AccountsFixtures.create_membership(org_admin, organization, :admin)

      conn =
        build_conn()
        |> log_in_user(org_admin)
        |> get(~p"/admin/organizations/#{organization.slug}")

      html = html_response(conn, 200)

      assert html =~ "sg-skeleton"
      assert html =~ "Support members"
      assert html =~ "Investigate org events"
      refute html =~ "sg-metric-link__value"
      refute html =~ "sg-card sg-posture-strip"
      refute html =~ "sg-posture-strip__risk"
      refute html =~ "Scoped attention"
    end

    test "org overview connected mount (live/2) renders data, not skeleton" do
      org_admin =
        AccountsFixtures.user_fixture(%{
          email: "org-admin+157-org-live-#{System.unique_integer([:positive])}@example.com"
        })

      locked_member =
        AccountsFixtures.user_fixture(%{
          email: "needs-review+157-org-live-#{System.unique_integer([:positive])}@example.com"
        })
        |> AccountsFixtures.locked_user_fixture()

      organization =
        AccountsFixtures.create_organization(%{
          name: "Test Org 157",
          slug: "test-org-157-live-#{System.unique_integer([:positive])}"
        })

      AccountsFixtures.create_membership(org_admin, organization, :admin)
      AccountsFixtures.create_membership(locked_member, organization, :member)

      {:ok, _view, html} =
        build_conn()
        |> log_in_user(org_admin)
        |> live(~p"/admin/organizations/#{organization.slug}")

      refute html =~ "sg-skeleton"
      refute html =~ ~s(aria-busy="true")
      assert html =~ "sg-notice"
      assert html =~ "account needs review"
      assert html =~ "sg-notice__action"
      assert html =~ "Review accounts"
      assert html =~ ~s(href="/admin/organizations/#{organization.slug}/users?needs_review=true")
      assert html =~ ~s(role="status")
      refute html =~ "sg-metric-link__value"
      refute html =~ "sg-card sg-posture-strip"
      refute html =~ "sg-posture-strip__risk"
      refute html =~ "Scoped attention"

      assert html_offset(html, "sg-notice") < html_offset(html, "sg-grid sg-grid--2")

      assert html_offset(html, "sg-grid sg-grid--2") <
               html_offset(html, "Members")

      assert html =~ "Members"
      assert html =~ "Pending invitations"
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
