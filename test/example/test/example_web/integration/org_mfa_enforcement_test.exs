defmodule ExampleWeb.OrgMfaEnforcementTest do
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Example.Accounts.{AuditEvent, Organization, OrganizationMembership}
  alias Example.Repo

  defp create_org!(user, role, attrs) do
    {:ok, org} =
      %Organization{}
      |> Organization.changeset(
        Map.merge(
          %{name: "Org #{System.unique_integer([:positive])}", slug: "org-#{System.unique_integer([:positive])}"},
          attrs
        )
      )
      |> Repo.insert()

    {:ok, _membership} =
      %OrganizationMembership{}
      |> OrganizationMembership.changeset(%{
        user_id: user.id,
        organization_id: org.id,
        role: role
      })
      |> Repo.insert()

    org
  end

  defp add_member!(org, user, role) do
    %OrganizationMembership{}
    |> OrganizationMembership.changeset(%{
      user_id: user.id,
      organization_id: org.id,
      role: role
    })
    |> Repo.insert!()
  end

  test "admin enables policy and enforcement applies per organization", %{conn: conn} do
    %{user: admin} = Example.AccountsFixtures.mfa_user_fixture()
    member = Example.AccountsFixtures.user_fixture()
    enrolled_member = Example.AccountsFixtures.mfa_user_fixture().user

    enforced_org = create_org!(admin, :admin, %{name: "Enforced Org", slug: "enforced-org"})
    other_org = create_org!(admin, :owner, %{name: "Other Org", slug: "other-org"})

    add_member!(enforced_org, member, :member)
    add_member!(enforced_org, enrolled_member, :member)
    add_member!(other_org, member, :member)

    admin_conn = log_in_user(conn, admin)

    {:ok, lv, _html} = live(admin_conn, ~p"/organizations/#{enforced_org.slug}/settings")

    lv
    |> element("input[phx-click=toggle_mfa_policy]")
    |> render_click()

    lv
    |> element("form[phx-submit=save_mfa_policy]")
    |> render_submit()

    assert Repo.reload!(enforced_org).enforce_mfa_for_members == true

    audit_rows =
      Repo.all(
        from(a in AuditEvent,
          where: a.action == "organization.mfa_policy_change",
          order_by: [asc: a.inserted_at]
        )
      )

    assert [%AuditEvent{} = audit] = audit_rows
    assert audit.actor_id == admin.id
    assert audit.metadata["new_value"] == true

    blocked_conn =
      build_conn()
      |> log_in_user(member)
      |> get(~p"/organizations/#{enforced_org.slug}/members")

    assert redirected_to(blocked_conn) == "/users/settings/mfa"
    assert get_session(blocked_conn, :user_return_to) == "/organizations/#{enforced_org.slug}/members"

    passing_conn =
      build_conn()
      |> log_in_user(enrolled_member)
      |> get(~p"/organizations/#{enforced_org.slug}/members")

    assert html_response(passing_conn, 200) =~ "Members"

    other_org_conn =
      build_conn()
      |> log_in_user(member)
      |> get(~p"/organizations/#{other_org.slug}/members")

    assert html_response(other_org_conn, 200) =~ "Members"
  end
end
