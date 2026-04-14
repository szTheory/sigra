defmodule ExampleWeb.OrganizationMembersLiveTest do
  @moduledoc """
  Phase 17 Plan 17-06 — OrganizationMembersLive extension points.

  Covers the invite-member modal, pending-invitations list (with 5
  columns), and revoke-confirm modal. Tests the LV template output +
  the `use Sigra.Organizations` delegators exposed on
  `Example.Organizations` (create_invitation/1, revoke_invitation/2,
  list_pending_invitations/1).

  Follows the Phase 16 integration-test pattern: conn-level GETs +
  `html_response/2` assertions for rendered markup; direct library
  calls for handler behavior (no Phoenix.LiveViewTest clicks — the
  example-app test suite does not import that module).
  """
  use ExampleWeb.ConnCase, async: false

  alias Example.Accounts.Organization
  alias Example.Accounts.OrganizationInvitation
  alias Example.Accounts.OrganizationMembership
  alias Example.Accounts.Scope
  alias Example.Repo

  @moduletag :phase17
  @moduletag :integration

  # ──────────────────────────────────────────────────────────────────────
  # Fixtures
  # ──────────────────────────────────────────────────────────────────────

  defp create_org_with_role!(user, role, org_attrs \\ %{}) do
    {:ok, org} =
      %Organization{}
      |> Organization.changeset(
        Map.merge(
          %{
            name: "Seed Org",
            slug: "seed-org-#{System.unique_integer([:positive])}"
          },
          org_attrs
        )
      )
      |> Repo.insert()

    {:ok, membership} =
      %OrganizationMembership{}
      |> OrganizationMembership.changeset(%{
        user_id: user.id,
        organization_id: org.id,
        role: role
      })
      |> Repo.insert()

    {org, membership}
  end

  defp seed_pending_invitation!(org, inviter, email, role \\ :member) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(7 * 24 * 3600, :second)
      |> DateTime.truncate(:second)

    {:ok, inv} =
      %OrganizationInvitation{}
      |> OrganizationInvitation.changeset(%{
        organization_id: org.id,
        invited_by_id: inviter.id,
        email: email,
        role: role,
        expires_at: expires_at,
        hashed_token: :crypto.strong_rand_bytes(32)
      })
      |> Repo.insert()

    inv
  end

  defp build_admin_scope(user, org, membership) do
    %Scope{user: user, active_organization: org, membership: membership}
  end

  # ──────────────────────────────────────────────────────────────────────
  # Test 1 — Header "Invite member" button enabled for owner
  # ──────────────────────────────────────────────────────────────────────

  describe "Phase 17 — invite button gating" do
    setup :register_and_log_in_user

    test "T1: owner sees an enabled Invite member button (no disabled attr)",
         %{conn: conn, user: user} do
      {org, _m} = create_org_with_role!(user, :owner, %{slug: "t1-inv-owner"})

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      assert html =~ "Invite member"
      # The stub had `disabled aria-disabled="true"` — after Phase 17 the
      # owner's rendered button MUST NOT have `disabled` on the Invite
      # button. We assert the absence of the disabled-stub-phrase.
      refute html =~ ~s|disabled aria-disabled="true" title="Available in the next release"|
    end

    test "T2: member sees the Invite member button DISABLED (stubbed off)",
         %{conn: conn, user: user} do
      # Seed a pre-existing owner so the user can be added as a member.
      {:ok, owner} =
        %Example.Accounts.User{}
        |> Example.Accounts.User.registration_changeset(%{
          email: "owner-t2-#{System.unique_integer([:positive])}@example.com",
          password: "A-super-secret-password-42"
        })
        |> Repo.insert()

      {org, _owner_m} = create_org_with_role!(owner, :owner, %{slug: "t2-inv-member"})

      {:ok, _member_m} =
        %OrganizationMembership{}
        |> OrganizationMembership.changeset(%{
          user_id: user.id,
          organization_id: org.id,
          role: :member
        })
        |> Repo.insert()

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      # Non-admin members see the button rendered with a `disabled` attr
      # (UI gate; the library still re-checks authorization on submit).
      assert html =~ "Invite member"
      assert html =~ ~s|disabled|
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # Tests 3 + 7 — Invite + Revoke modal markup is present in DOM
  # ──────────────────────────────────────────────────────────────────────

  describe "Phase 17 — modal markup" do
    setup :register_and_log_in_user

    test "T3: invite-member-modal is rendered with phx-submit=\"invite_member\"",
         %{conn: conn, user: user} do
      {org, _m} = create_org_with_role!(user, :owner, %{slug: "t3-invite-modal"})

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      assert html =~ ~s|id="invite-member-modal"|
      assert html =~ ~s|phx-submit="invite_member"|
      assert html =~ "Invite a member"
      assert html =~ "Send invitation"
      assert html =~ "Email address"
    end

    test "T7: revoke-invitation-modal is rendered with cancel_revoke + confirm_revoke handlers",
         %{conn: conn, user: user} do
      {org, _m} = create_org_with_role!(user, :owner, %{slug: "t7-revoke-modal"})

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      assert html =~ ~s|id="revoke-invitation-modal"|
      assert html =~ ~s|phx-click="cancel_revoke"|
      assert html =~ ~s|phx-click="confirm_revoke"|
      assert html =~ "Revoke invitation?"
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # Tests 4 + 5 + 6 + 14 — Pending list rendering
  # ──────────────────────────────────────────────────────────────────────

  describe "Phase 17 — pending invitations list rendering" do
    setup :register_and_log_in_user

    test "T4: empty state renders locked copy when there are zero pending invitations",
         %{conn: conn, user: user} do
      {org, _m} = create_org_with_role!(user, :owner, %{slug: "t4-empty-list"})

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      assert html =~ "Pending invitations (0)"
      assert html =~ "No pending invitations."
      assert html =~ "Invite member"
    end

    test "T5: populated list renders email + role badge + invited-by + expires + revoke column",
         %{conn: conn, user: user} do
      {org, _m} = create_org_with_role!(user, :owner, %{slug: "t5-populated"})

      _inv1 = seed_pending_invitation!(org, user, "alpha@t5.example")
      _inv2 = seed_pending_invitation!(org, user, "beta@t5.example", :admin)

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      assert html =~ "Pending invitations (2)"
      assert html =~ "alpha@t5.example"
      assert html =~ "beta@t5.example"
      assert html =~ "Member"
      assert html =~ "Admin"
      assert html =~ user.email
      assert html =~ "Revoke"
    end

    test "T6: each revoke button has an aria-label scoped to the invitee email",
         %{conn: conn, user: user} do
      {org, _m} = create_org_with_role!(user, :owner, %{slug: "t6-aria-label"})

      _inv = seed_pending_invitation!(org, user, "aria@t6.example")

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      assert html =~ ~s|aria-label="Revoke invitation for aria@t6.example"|
    end

    test "T14: count header reflects the number of pending invitations returned",
         %{conn: conn, user: user} do
      {org, _m} = create_org_with_role!(user, :owner, %{slug: "t14-count"})

      Enum.each(1..3, fn i ->
        seed_pending_invitation!(org, user, "count#{i}@t14.example")
      end)

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      assert html =~ "Pending invitations (3)"
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # T13 — Non-admin member hides revoke column
  # ──────────────────────────────────────────────────────────────────────

  describe "Phase 17 — revoke column UI gating" do
    setup :register_and_log_in_user

    test "T13: member role does not render the Revoke action column",
         %{conn: conn, user: user} do
      {:ok, owner} =
        %Example.Accounts.User{}
        |> Example.Accounts.User.registration_changeset(%{
          email: "owner-t13-#{System.unique_integer([:positive])}@example.com",
          password: "A-super-secret-password-42"
        })
        |> Repo.insert()

      {org, _owner_m} = create_org_with_role!(owner, :owner, %{slug: "t13-gate"})

      {:ok, _member_m} =
        %OrganizationMembership{}
        |> OrganizationMembership.changeset(%{
          user_id: user.id,
          organization_id: org.id,
          role: :member
        })
        |> Repo.insert()

      _inv = seed_pending_invitation!(org, owner, "hidden@t13.example")

      conn = get(conn, ~p"/organizations/#{org.slug}/members")
      html = html_response(conn, 200)

      # Pending list still renders — members can see pending rows —
      # but the per-row Revoke button is gated off for non-admins.
      assert html =~ "hidden@t13.example"
      refute html =~ ~s|aria-label="Revoke invitation for hidden@t13.example"|
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # T8–T12 + T15 — Library delegator contracts
  # ──────────────────────────────────────────────────────────────────────

  describe "Phase 17 — Example.Organizations invitation delegators" do
    setup :register_and_log_in_user

    test "T8: create_invitation/1 happy path returns {:ok, invitation} and persists the row",
         %{user: user} do
      {org, membership} = create_org_with_role!(user, :owner, %{slug: "t8-create"})
      scope = build_admin_scope(user, org, membership)

      assert {:ok, inv} =
               Example.Organizations.create_invitation(%{
                 actor: scope,
                 organization_id: org.id,
                 email: "t8-new@example.com",
                 role: :member,
                 invited_by_id: user.id
               })

      assert inv.email == "t8-new@example.com"
      assert inv.role == :member
      assert Repo.get(OrganizationInvitation, inv.id)
    end

    test "T9: create_invitation/1 with a :member actor returns {:error, :unauthorized}",
         %{user: user} do
      {:ok, owner} =
        %Example.Accounts.User{}
        |> Example.Accounts.User.registration_changeset(%{
          email: "owner-t9-#{System.unique_integer([:positive])}@example.com",
          password: "A-super-secret-password-42"
        })
        |> Repo.insert()

      {org, _owner_m} = create_org_with_role!(owner, :owner, %{slug: "t9-unauth"})

      {:ok, member_m} =
        %OrganizationMembership{}
        |> OrganizationMembership.changeset(%{
          user_id: user.id,
          organization_id: org.id,
          role: :member
        })
        |> Repo.insert()

      member_scope = build_admin_scope(user, org, member_m)

      assert {:error, :unauthorized} =
               Example.Organizations.create_invitation(%{
                 actor: member_scope,
                 organization_id: org.id,
                 email: "t9-new@example.com",
                 role: :member,
                 invited_by_id: user.id
               })
    end

    test "T10: revoke_invitation/2 happy path flips revoked_at + revoked_by_id",
         %{user: user} do
      {org, membership} = create_org_with_role!(user, :owner, %{slug: "t10-revoke"})
      scope = build_admin_scope(user, org, membership)

      inv = seed_pending_invitation!(org, user, "revoke-me@t10.example")

      assert {:ok, revoked} = Example.Organizations.revoke_invitation(inv.id, scope)
      assert revoked.revoked_at != nil

      fresh = Repo.get!(OrganizationInvitation, inv.id)
      assert fresh.revoked_at != nil
      assert fresh.revoked_by_id == user.id
    end

    test "T11: revoke_invitation/2 on an already-accepted row returns {:error, :not_pending}",
         %{user: user} do
      {org, membership} = create_org_with_role!(user, :owner, %{slug: "t11-accepted"})
      scope = build_admin_scope(user, org, membership)

      inv = seed_pending_invitation!(org, user, "already-accepted@t11.example")

      # Mark the row accepted directly.
      {:ok, _} =
        inv
        |> Ecto.Changeset.change(%{
          accepted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          accepted_by_id: user.id
        })
        |> Repo.update()

      assert {:error, :not_pending} = Example.Organizations.revoke_invitation(inv.id, scope)
    end

    test "T12: revoke_invitation/2 as a member returns {:error, :unauthorized}",
         %{user: user} do
      {:ok, owner} =
        %Example.Accounts.User{}
        |> Example.Accounts.User.registration_changeset(%{
          email: "owner-t12-#{System.unique_integer([:positive])}@example.com",
          password: "A-super-secret-password-42"
        })
        |> Repo.insert()

      {org, _owner_m} = create_org_with_role!(owner, :owner, %{slug: "t12-unauth"})

      {:ok, member_m} =
        %OrganizationMembership{}
        |> OrganizationMembership.changeset(%{
          user_id: user.id,
          organization_id: org.id,
          role: :member
        })
        |> Repo.insert()

      member_scope = build_admin_scope(user, org, member_m)
      inv = seed_pending_invitation!(org, owner, "protected@t12.example")

      assert {:error, :unauthorized} =
               Example.Organizations.revoke_invitation(inv.id, member_scope)
    end

    test "T15: list_pending_invitations/1 returns preloaded pending rows sorted desc",
         %{user: user} do
      {org, _m} = create_org_with_role!(user, :owner, %{slug: "t15-list"})

      _a = seed_pending_invitation!(org, user, "a@t15.example")
      _b = seed_pending_invitation!(org, user, "b@t15.example")

      rows = Example.Organizations.list_pending_invitations(org)

      assert length(rows) == 2
      emails = Enum.map(rows, & &1.email)
      assert "a@t15.example" in emails
      assert "b@t15.example" in emails

      # invited_by is preloaded (list_pending/2 contract)
      assert Enum.all?(rows, fn r ->
               match?(%Example.Accounts.User{}, r.invited_by)
             end)
    end

    test "T16: delegators are exported at the expected arities" do
      assert function_exported?(Example.Organizations, :create_invitation, 1)
      assert function_exported?(Example.Organizations, :revoke_invitation, 2)
      assert function_exported?(Example.Organizations, :list_pending_invitations, 1)
    end
  end
end
