defmodule ExampleWeb.AdminUserSessionsLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Sigra.Admin.Authorizer.UnauthorizedError

  # Phase 200 (CR-03): destructive per-user session management moved out of
  # UserShowLive into Sigra.Admin.Live.UserSessionsLive at
  # /admin/users/:id/sessions (and the org-scoped equivalent). This is the
  # deny-path + happy-path regression coverage the new route was missing.

  describe "revoke flow (happy path)" do
    test "open dialog -> confirm revokes a single session and the list updates", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      target = user_fixture(%{email: "sessions-revoke-one@example.com", display_name: "Revoke One"})

      keep = session_fixture(target, %{ip: "10.9.9.1"})
      victim = session_fixture(target, %{ip: "10.9.9.2"})

      {:ok, view, html} =
        conn
        |> log_in_user(platform_admin)
        |> live("/admin/users/#{target.id}/sessions")

      assert html =~ "Revoke all sessions"
      assert html =~ keep.ip
      assert html =~ victim.ip

      html =
        render_click(view, :open_revoke_session, %{
          "token" => Base.url_encode64(victim.hashed_token, padding: false)
        })

      # The APG confirm dialog opens with the new copy (not the old detail-page string).
      assert html =~ "Revoke this session?"
      assert html =~ "The user will be signed out of this session immediately."

      html = render_click(view, :confirm_action, %{})

      assert html =~ "Session revoked."
      assert html =~ keep.ip
      refute html =~ victim.ip
    end

    test "open dialog -> confirm revokes all sessions and shows the empty state", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      target = user_fixture(%{email: "sessions-revoke-all@example.com", display_name: "Revoke All"})

      session_fixture(target, %{ip: "10.8.8.1"})
      session_fixture(target, %{ip: "10.8.8.2"})

      {:ok, view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live("/admin/users/#{target.id}/sessions")

      html = render_click(view, :open_revoke_all_sessions, %{})

      assert html =~ "Revoke all sessions?"
      assert html =~ "The user will be signed out of all active sessions immediately."

      html = render_click(view, :confirm_action, %{})

      assert html =~ "All active sessions revoked."
      assert html =~ "No active sessions"
      refute html =~ "10.8.8.1"
      refute html =~ "10.8.8.2"
    end

    test "cancelling the confirm dialog leaves sessions intact", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      target = user_fixture(%{email: "sessions-cancel@example.com", display_name: "Cancel Revoke"})

      session = session_fixture(target, %{ip: "10.7.7.7"})

      {:ok, view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live("/admin/users/#{target.id}/sessions")

      render_click(view, :open_revoke_session, %{
        "token" => Base.url_encode64(session.hashed_token, padding: false)
      })

      html = render_click(view, :cancel_confirm, %{})

      refute html =~ "Revoke this session?"
      assert html =~ session.ip
    end

    test "a malformed token reference flashes an error instead of crashing", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      target = user_fixture(%{email: "sessions-bad-token@example.com", display_name: "Bad Token"})

      session_fixture(target, %{ip: "10.6.6.6"})

      {:ok, view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live("/admin/users/#{target.id}/sessions")

      html = render_click(view, :open_revoke_session, %{"token" => "not-valid-base64!!"})

      assert html =~ "Invalid session reference."
      refute html =~ "Revoke this session?"
    end
  end

  describe "scope safety + authorization" do
    test "the global scope ribbon and breadcrumbs reflect the active scope", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      target = user_fixture(%{email: "sessions-global-scope@example.com", display_name: "Global Scope"})

      session_fixture(target, %{ip: "10.5.5.5"})

      {:ok, _view, html} =
        conn
        |> log_in_user(platform_admin)
        |> live(
          "/admin/users/#{target.id}/sessions?return_to=#{URI.encode_www_form("/admin/users?q=sessions-global-scope")}"
        )

      assert html =~ "Global user operations"

      breadcrumb = breadcrumb_fragment(html)

      assert breadcrumb =~ ~s(href="/admin")
      assert breadcrumb =~ "Overview"
      assert breadcrumb =~ ~s(href="/admin/users?q=sessions-global-scope")
      assert breadcrumb =~ "Users"
      assert breadcrumb =~ target.email
      assert breadcrumb =~ "Sessions"
      assert html_offset(breadcrumb, "Users") < html_offset(breadcrumb, target.email)
      assert html_offset(breadcrumb, target.email) < html_offset(breadcrumb, "Sessions")
    end

    test "the organization scope ribbon names the active organization", %{conn: conn} do
      org_admin = org_admin_fixture()
      org = create_organization(%{name: "Sessions Org", slug: "sessions-org"})
      create_membership(org_admin, org, :admin)

      target =
        user_fixture(%{email: "sessions-org-member@example.com", display_name: "Org Member"})

      create_membership(target, org, :member)
      session_fixture(target, %{ip: "10.4.4.4"})

      {:ok, _view, html} =
        conn
        |> log_in_user(org_admin)
        |> live("/admin/organizations/#{org.slug}/users/#{target.id}/sessions")

      assert html =~ "Organization-scoped user operations for Sessions Org"

      breadcrumb = breadcrumb_fragment(html)

      assert breadcrumb =~ ~s(href="/admin/organizations/#{org.slug}")
      assert breadcrumb =~ "Users"
      assert breadcrumb =~ target.email
      assert breadcrumb =~ "Sessions"
    end

    test "an org-scoped admin cannot load the sessions route for a user outside their org", %{
      conn: conn
    } do
      org_admin = org_admin_fixture()
      home_org = create_organization(%{name: "Home Org", slug: "home-org"})
      other_org = create_organization(%{name: "Other Org", slug: "other-org"})

      create_membership(org_admin, home_org, :admin)

      outsider =
        user_fixture(%{email: "sessions-outsider@example.com", display_name: "Outsider"})

      create_membership(outsider, other_org, :member)
      session_fixture(outsider, %{ip: "10.3.3.3"})

      conn = log_in_user(conn, org_admin)

      # Loading the home-org-scoped sessions route for a user who only belongs to
      # another org denies via Detail.load! (same not_found contract the detail
      # page enforces), raised during handle_params.
      assert_raise UnauthorizedError, fn ->
        live(conn, "/admin/organizations/#{home_org.slug}/users/#{outsider.id}/sessions")
      end
    end
  end

  defp platform_admin_fixture do
    user_fixture(%{
      email: "platform-admin+#{System.unique_integer([:positive])}@example.com",
      display_name: "Platform Admin"
    })
  end

  defp org_admin_fixture do
    user_fixture(%{
      email: "org-admin+#{System.unique_integer([:positive])}@example.com",
      display_name: "Organization Admin"
    })
  end

  defp html_offset(html, needle) do
    case :binary.match(html, needle) do
      {offset, _length} -> offset
      :nomatch -> nil
    end
  end

  defp breadcrumb_fragment(html) do
    case :binary.match(html, ~s(aria-label="Breadcrumb")) do
      {start, _} -> binary_part(html, start, min(2_000, byte_size(html) - start))
      :nomatch -> ""
    end
  end
end
