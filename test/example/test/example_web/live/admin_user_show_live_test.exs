defmodule ExampleWeb.AdminUserShowLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Example.Accounts.AuditEvent
  alias Example.Repo

  describe "Phase 28 admin user show contracts" do
    test "detail sections render in the locked Identity Status Sessions Security Identities Organizations Recent Audit Danger Zone order",
         %{
           conn: conn
         } do
      platform_admin = platform_admin_fixture()
      target = user_fixture(%{email: "detail-order@example.com", display_name: "Detail Order"})
      org = create_organization(%{name: "Acme Detail", slug: "acme-detail"})

      create_membership(target, org, :member)
      session_fixture(target, %{ip: "10.1.1.1"})
      passkey_fixture(target)
      insert_audit_event(target, org)

      {:ok, _view, html} =
        conn
        |> log_in_user(platform_admin)
        |> live(
          "/admin/users/#{target.id}?return_to=#{URI.encode_www_form("/admin/users?q=detail-order")}"
        )

      positions =
        [
          "Identity &amp; Status",
          "Sessions",
          "Security",
          "Identities",
          "Organizations",
          "Recent Audit",
          "Danger Zone"
        ]
        |> Enum.map(&{&1, html_offset(html, &1)})

      assert Enum.all?(positions, fn {_label, position} -> is_integer(position) end)
      assert ordered?(positions)
      assert html =~ "/admin/users?q=detail-order"
    end

    test "Revoke session and revoke all sessions keep the current scope and target identity visible in confirmations",
         %{
           conn: conn
         } do
      platform_admin = platform_admin_fixture()

      target =
        user_fixture(%{email: "detail-confirm@example.com", display_name: "Detail Confirm"})

      session = session_fixture(target, %{ip: "10.2.2.2"})
      session_fixture(target, %{ip: "10.2.2.3"})

      {:ok, view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live("/admin/users/#{target.id}")

      html =
        render_click(view, :open_revoke_session, %{
          "token" => Base.url_encode64(session.hashed_token, padding: false)
        })

      assert html =~
               "Revoke this session for #{target.email} in Global scope? The user will need to sign in again."

      html = render_click(view, :open_revoke_all_sessions, %{})

      assert html =~
               "Revoke every active session for #{target.email} in Global scope? This signs them out everywhere."
    end

    test "platform admins can pivot from a global user detail page into an organization-scoped view",
         %{
           conn: conn
         } do
      platform_admin = platform_admin_fixture()
      target = user_fixture(%{email: "detail-pivot@example.com", display_name: "Detail Pivot"})
      org = create_organization(%{name: "Acme Pivot", slug: "acme-pivot"})

      create_membership(target, org, :member)

      {:ok, _view, html} =
        conn
        |> log_in_user(platform_admin)
        |> live(
          "/admin/users/#{target.id}?return_to=#{URI.encode_www_form("/admin/users?q=detail-pivot")}"
        )

      assert html =~ "Open organization-scoped view for Acme Pivot"

      [pivot_path] =
        Regex.run(~r/href="([^"]*\/admin\/organizations\/[^"]+)"/, html, capture: :all_but_first)

      assert pivot_path =~ "/admin/organizations/"

      {:ok, _org_view, org_html} =
        conn
        |> log_in_user(platform_admin)
        |> live(pivot_path)

      assert org_html =~ "Organization-scoped user operations for Acme Pivot"
      assert org_html =~ target.email
    end
  end

  describe "Phase 29 impersonation entry contracts" do
    test "detail page renders the impersonation start action with preserved return_to near other guarded actions",
         %{conn: conn} do
      platform_admin = platform_admin_fixture()
      target = user_fixture(%{email: "impersonate-target@example.com", display_name: "Impersonate Target"})

      {:ok, _view, html} =
        conn
        |> log_in_user(platform_admin)
        |> live(
          "/admin/users/#{target.id}?return_to=#{URI.encode_www_form("/admin/users?q=impersonate-target")}"
        )

      assert html =~ "Danger Zone"
      assert html =~ "Start impersonation"
      assert html =~ "Support actions affect Impersonate Target"
      assert html =~ "action=\"/admin/users/#{target.id}/impersonation\""
      assert html =~ "name=\"return_to\""
      assert html =~ "value=\"/admin/users?q=impersonate-target\""

      assert html_offset(html, "Start impersonation") > html_offset(html, "Danger Zone")
    end

    test "detail page hides the impersonation start action while already impersonating", %{conn: conn} do
      admin = platform_admin_fixture()

      target =
        user_fixture(%{
          email: "platform-admin+impersonated-#{System.unique_integer([:positive])}@example.com",
          display_name: "Hidden Target"
        })

      impersonation_token = impersonation_token_for(target)

      {:ok, _view, html} =
        conn
        |> init_test_session(%{
          user_token: impersonation_token,
          impersonator_user_token: Example.Accounts.generate_user_session_token(admin),
          impersonation_return_to: "/admin/users?q=restore"
        })
        |> live("/admin/users/#{target.id}")

      refute html =~ "Start impersonation"
      assert html =~ "End impersonation before starting another session."
    end
  end

  defp ordered?(positions) do
    positions
    |> Enum.map(fn {_label, position} -> position end)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [left, right] -> left < right end)
  end

  defp html_offset(html, needle) do
    case :binary.match(html, needle) do
      {offset, _length} -> offset
      :nomatch -> nil
    end
  end

  defp platform_admin_fixture do
    user_fixture(%{
      email: "platform-admin+#{System.unique_integer([:positive])}@example.com",
      display_name: "Platform Admin"
    })
  end

  defp insert_audit_event(user, org) do
    now = DateTime.utc_now()

    Repo.insert!(%AuditEvent{
      action: "session.revoke_all",
      actor_id: user.id,
      actor_type: "user",
      target_id: user.id,
      target_type: "user",
      organization_id: org.id,
      metadata: %{"count" => 1},
      occurred_at: now,
      inserted_at: now
    })
  end

  defp impersonation_token_for(user) do
    Example.Accounts.generate_user_session_token(user)
  end
end
