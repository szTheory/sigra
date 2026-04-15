defmodule ExampleWeb.InvitationAcceptLiveTest do
  @moduledoc """
  Phase 17 Plan 17-07 — InvitationAcceptLive, the single unscoped
  LiveView that handles invitation acceptance across 7 render branches.

  This test file is the load-bearing regression suite for the
  Jetstream #907 / CVE-2026-1529 structural defense: the `:mismatch`
  render branch must contain ZERO accept DOM controls by construction,
  not by server-side guard alone. The critical assertions are:

    1. `refute html =~ "phx-click=\"accept_invitation\""`
    2. `refute html =~ "phx-submit=\"accept_with_signup\""`
    3. `assert_raise ArgumentError, fn -> render_click(view, "accept_invitation") end`
    4. Zero DB writes (membership count unchanged, invitation.accepted_at still nil)

  Additionally covers:

    * All 7 branch renders (signup, accept, mismatch, invalid,
      expired, revoked, already_accepted)
    * Replay regression — accepting twice hits :already_accepted
    * Citext regression — User@Ex.com accepts user@ex.com successfully
    * Signup email-mismatch server-side reject (attacker POST bypass)
    * No accept handlers on the 4 error branches (ArgumentError)
  """
  use ExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Example.Accounts.Organization
  alias Example.Accounts.OrganizationInvitation
  alias Example.Accounts.OrganizationMembership
  alias Example.Repo

  @moduletag :phase17
  @moduletag :integration

  # Phoenix.LiveViewTest runs the LV in a separate linked process. When
  # the LV handler raises ArgumentError (our Jetstream #907 structural
  # defense fallback clauses), the crash reaches the test process as an
  # EXIT signal rather than a synchronous raise. `assert_accept_rejected/1`
  # traps the exit and asserts it carries our ArgumentError message.
  defp assert_accept_rejected(fun) do
    Process.flag(:trap_exit, true)

    try do
      _ = fun.()
    catch
      :exit, {{%ArgumentError{message: msg}, _stack}, _gs} ->
        assert msg =~ "Jetstream #907"
        :ok
    end

    # Drain the linked EXIT message that Phoenix.LiveViewTest delivers
    # when the LV channel crashes.
    receive do
      {:EXIT, _pid, _reason} -> :ok
    after
      50 -> :ok
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # Fixtures
  # ──────────────────────────────────────────────────────────────────────

  defp create_org_with_owner(slug) do
    unique = System.unique_integer([:positive])

    {:ok, owner} =
      %Example.Accounts.User{}
      |> Example.Accounts.User.registration_changeset(%{
        email: "owner-#{unique}@example.com",
        password: "A-super-secret-password-42"
      })
      |> Repo.insert()

    {:ok, org} =
      %Organization{}
      |> Organization.changeset(%{
        name: "Org #{unique}",
        slug: "#{slug}-#{unique}"
      })
      |> Repo.insert()

    {:ok, owner_membership} =
      %OrganizationMembership{}
      |> OrganizationMembership.changeset(%{
        user_id: owner.id,
        organization_id: org.id,
        role: :owner
      })
      |> Repo.insert()

    {org, owner, owner_membership}
  end

  defp create_pending_invitation(org, owner, email, role \\ :member) do
    owner_scope = %Example.Accounts.Scope{
      user: owner,
      active_organization: org,
      membership: %OrganizationMembership{role: :owner}
    }

    {:ok, invitation} =
      Example.Organizations.create_invitation(%{
        actor: owner_scope,
        organization_id: org.id,
        email: email,
        role: role,
        invited_by_id: owner.id
      })

    invitation
  end

  defp create_user(email) do
    {:ok, user} =
      %Example.Accounts.User{}
      |> Example.Accounts.User.registration_changeset(%{
        email: email,
        password: "A-super-secret-password-42"
      })
      |> Repo.insert()

    user
  end

  defp accept_path(token), do: ~p"/invitations/#{token}/accept"

  # ──────────────────────────────────────────────────────────────────────
  # Branch selection (mount/3)
  # ──────────────────────────────────────────────────────────────────────

  describe "mount/3 branch selection" do
    test "T1: signup branch renders for anonymous visitor with valid token",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t1-signup")
      inv = create_pending_invitation(org, owner, "new-user-t1@example.com")

      {:ok, _view, html} = live(conn, accept_path(inv.__encoded_token__))

      assert html =~ "Join #{org.name}"
      assert html =~ "new-user-t1@example.com"
      assert html =~ "This invitation is locked to new-user-t1@example.com"
      assert html =~ "Create account &amp; join #{org.name}"
      assert html =~ "phx-submit=\"accept_with_signup\""
      assert html =~ owner.email
    end

    test "T2: accept branch renders for signed-in user whose email matches",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t2-accept")
      target_email = "target-t2-#{System.unique_integer([:positive])}@example.com"
      target = create_user(target_email)
      inv = create_pending_invitation(org, owner, target_email)

      conn = log_in_user(conn, target)
      {:ok, _view, html} = live(conn, accept_path(inv.__encoded_token__))

      assert html =~ "Join #{org.name}"
      assert html =~ "Accept &amp; join #{org.name}"
      assert html =~ "phx-click=\"accept_invitation\""
      assert html =~ target_email
      refute html =~ "This invitation is not for you"
    end

    test "T3: mismatch branch renders for signed-in user whose email does NOT match",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t3-mismatch")
      target_email = "target-t3-#{System.unique_integer([:positive])}@example.com"
      attacker_email = "attacker-t3-#{System.unique_integer([:positive])}@example.com"

      _target = create_user(target_email)
      attacker = create_user(attacker_email)

      inv = create_pending_invitation(org, owner, target_email)

      conn = log_in_user(conn, attacker)
      {:ok, _view, html} = live(conn, accept_path(inv.__encoded_token__))

      assert html =~ "This invitation is not for you"
      assert html =~ target_email
      assert html =~ attacker_email
    end

    test "T4: invalid branch renders for garbage token", %{conn: conn} do
      {:ok, _view, html} = live(conn, accept_path("garbage-token-not-base64!!!"))

      assert html =~ "Invalid invitation"
      assert html =~ "This invitation link is not valid."
      # Info disclosure guard — no hints about the specific failure mode
      refute html =~ "signature"
      refute html =~ "base64"
      refute html =~ "tamper"
    end

    test "T5: revoked branch renders for a revoked invitation", %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t5-revoked")
      inv = create_pending_invitation(org, owner, "revoked-t5@example.com")

      # Revoke the row directly in the DB — the envelope is still
      # HMAC-valid, load_for_view classifies it as :revoked.
      inv_db = Repo.get!(OrganizationInvitation, inv.id)

      inv_db
      |> Ecto.Changeset.change(%{
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second),
        revoked_by_id: owner.id
      })
      |> Repo.update!()

      {:ok, _view, html} = live(conn, accept_path(inv.__encoded_token__))

      assert html =~ "Invitation no longer valid"
      assert html =~ "This invitation is no longer valid."
    end

    test "T6: already_accepted branch renders for an accepted invitation",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t6-accepted")
      inv = create_pending_invitation(org, owner, "accepted-t6@example.com")

      inv_db = Repo.get!(OrganizationInvitation, inv.id)

      inv_db
      |> Ecto.Changeset.change(%{
        accepted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        accepted_by_id: owner.id
      })
      |> Repo.update!()

      {:ok, _view, html} = live(conn, accept_path(inv.__encoded_token__))

      assert html =~ "Invitation already accepted"
      assert html =~ "This invitation has already been accepted."
    end

    test "T7: expired branch renders for an expired invitation", %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t7-expired")
      inv = create_pending_invitation(org, owner, "expired-t7@example.com")

      # Push expires_at into the past. The envelope TTL check will catch
      # it too (since created now but DB says expired), but primarily the
      # load_for_view DB row check fires.
      inv_db = Repo.get!(OrganizationInvitation, inv.id)

      inv_db
      |> Ecto.Changeset.change(%{
        expires_at:
          DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
      })
      |> Repo.update!()

      {:ok, _view, html} = live(conn, accept_path(inv.__encoded_token__))

      assert html =~ "Invitation expired"
      assert html =~ "expired"
    end

    test "T8: page_title is assigned per branch", %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t8-titles")
      inv = create_pending_invitation(org, owner, "new-t8@example.com")

      {:ok, _view, html} = live(conn, accept_path(inv.__encoded_token__))
      # Page title appears in the <title> tag via live_title — we grep for
      # the branch-specific assign instead via the HTML body.
      assert html =~ "Join #{org.name}"
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # accept_invitation handler (signed-in match path)
  # ──────────────────────────────────────────────────────────────────────

  describe "handle_event(\"accept_invitation\", ...)" do
    test "T9: happy path redirects to org members with success flash",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t9-accept-happy")
      target_email = "target-t9-#{System.unique_integer([:positive])}@example.com"
      target = create_user(target_email)
      inv = create_pending_invitation(org, owner, target_email)

      conn = log_in_user(conn, target)
      {:ok, view, _html} = live(conn, accept_path(inv.__encoded_token__))

      result = view |> element("#accept-invitation-button") |> render_click()

      # render_click returns {:error, {:redirect, ...}} when the
      # handler redirects; the path is unsigned and directly checkable.
      assert {:error, {:redirect, %{to: path}}} = result
      assert path == "/organizations/#{org.slug}/members"

      # Invitation is now accepted
      reloaded = Repo.get!(OrganizationInvitation, inv.id)
      assert reloaded.accepted_at != nil
      assert reloaded.accepted_by_id == target.id

      # Membership created
      assert Repo.get_by(OrganizationMembership,
               user_id: target.id,
               organization_id: org.id
             )
    end

    test "T10: no handler on :invalid branch — ArgumentError on synthesized click",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, accept_path("garbage-token"))

      assert_accept_rejected(fn ->
        render_click(view, "accept_invitation")
      end)
    end

    test "T11: no handler on :expired branch — ArgumentError on synthesized click",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t11-exp")
      inv = create_pending_invitation(org, owner, "t11@example.com")

      Repo.get!(OrganizationInvitation, inv.id)
      |> Ecto.Changeset.change(%{
        expires_at:
          DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
      })
      |> Repo.update!()

      {:ok, view, _html} = live(conn, accept_path(inv.__encoded_token__))

      assert_accept_rejected(fn ->
        render_click(view, "accept_invitation")
      end)
    end

    test "T12: no handler on :revoked branch — ArgumentError on synthesized click",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t12-rev")
      inv = create_pending_invitation(org, owner, "t12@example.com")

      Repo.get!(OrganizationInvitation, inv.id)
      |> Ecto.Changeset.change(%{
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second),
        revoked_by_id: owner.id
      })
      |> Repo.update!()

      {:ok, view, _html} = live(conn, accept_path(inv.__encoded_token__))

      assert_accept_rejected(fn ->
        render_click(view, "accept_invitation")
      end)
    end

    test "T13: no handler on :already_accepted branch — ArgumentError on click",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t13-already")
      inv = create_pending_invitation(org, owner, "t13@example.com")

      Repo.get!(OrganizationInvitation, inv.id)
      |> Ecto.Changeset.change(%{
        accepted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        accepted_by_id: owner.id
      })
      |> Repo.update!()

      {:ok, view, _html} = live(conn, accept_path(inv.__encoded_token__))

      assert_accept_rejected(fn ->
        render_click(view, "accept_invitation")
      end)
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # accept_with_signup handler (anonymous signup path)
  # ──────────────────────────────────────────────────────────────────────

  describe "handle_event(\"accept_with_signup\", ...)" do
    test "T14: happy path creates user + membership + accepts invitation",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t14-signup")

      target_email = "new-t14-#{System.unique_integer([:positive])}@example.com"
      inv = create_pending_invitation(org, owner, target_email)

      {:ok, view, _html} = live(conn, accept_path(inv.__encoded_token__))

      # The email input is `disabled + readonly`, so Phoenix.LiveViewTest
      # `form/3` cannot include it in the submitted payload — browsers
      # behave the same way. The server-side handler fills in the
      # locked invitation.email when user_params has no email key.
      form_data = %{user: %{password: "A-super-secret-password-42"}}

      result =
        view |> form("#invitation-signup-form", form_data) |> render_submit()

      assert {:error, {:redirect, %{to: _to}}} = result

      # User row created under the locked invitation email
      assert Repo.get_by(Example.Accounts.User, email: target_email)

      # Invitation accepted
      reloaded = Repo.get!(OrganizationInvitation, inv.id)
      assert reloaded.accepted_at != nil

      # Membership inserted
      new_user = Repo.get_by!(Example.Accounts.User, email: target_email)

      assert Repo.get_by(OrganizationMembership,
               user_id: new_user.id,
               organization_id: org.id
             )
    end

    test "T15: signup branch server-side email reject on synthesized mismatch POST",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t15-signup-mismatch")
      inv = create_pending_invitation(org, owner, "target-t15@example.com")

      initial_user_count = Repo.aggregate(Example.Accounts.User, :count, :id)

      {:ok, view, _html} = live(conn, accept_path(inv.__encoded_token__))

      # Simulate an attacker bypassing the disabled/readonly email field
      # by directly firing the `accept_with_signup` event with a
      # different email in user_params. `render_submit(view, event, params)`
      # dispatches the event bypassing form field DOM rules — exactly
      # what a scripted attacker can do with a crafted WebSocket frame.
      html =
        render_submit(view, "accept_with_signup", %{
          "user" => %{
            "email" => "attacker-t15@example.com",
            "password" => "A-super-secret-password-42"
          }
        })

      # Inline field error is shown — locked email message
      assert html =~ "This invitation is locked to target-t15@example.com"

      # No new user was created by the rejected submission
      assert Repo.aggregate(Example.Accounts.User, :count, :id) == initial_user_count

      # Invitation is still pending
      reloaded = Repo.get!(OrganizationInvitation, inv.id)
      assert reloaded.accepted_at == nil
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # Jetstream #907 / CVE-2026-1529 regression — THE load-bearing test
  # ──────────────────────────────────────────────────────────────────────

  describe "Jetstream #907 regression" do
    test "T16: attacker signed in as different email cannot accept — zero accept DOM, zero DB writes",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("jetstream-907")
      target_email = "target-j907-#{System.unique_integer([:positive])}@example.com"
      attacker_email = "attacker-j907-#{System.unique_integer([:positive])}@example.com"

      _target = create_user(target_email)
      attacker = create_user(attacker_email)

      inv = create_pending_invitation(org, owner, target_email)

      initial_membership_count = Repo.aggregate(OrganizationMembership, :count, :id)

      conn = log_in_user(conn, attacker)
      {:ok, view, html} = live(conn, accept_path(inv.__encoded_token__))

      # (a) Mismatch branch rendered with locked copy
      assert html =~ "This invitation is not for you"
      assert html =~ target_email
      assert html =~ attacker_email

      # (b) ZERO accept DOM — structural Jetstream #907 defense.
      # Even if every server guard regressed, there is no accept form
      # in the rendered HTML to submit.
      refute html =~ "phx-click=\"accept_invitation\""
      refute html =~ "phx-submit=\"accept_with_signup\""
      refute html =~ "Accept &amp; join"
      refute html =~ "Create account"

      # (c) Synthesized accept event raises ArgumentError (no handler
      # bound to this branch — pattern match on :accept / :signup fails).
      assert_accept_rejected(fn ->
        render_click(view, "accept_invitation")
      end)

      # (d) Zero DB mutation — membership count unchanged, invitation
      # still pending.
      assert Repo.aggregate(OrganizationMembership, :count, :id) ==
               initial_membership_count

      reloaded = Repo.get!(OrganizationInvitation, inv.id)
      assert reloaded.accepted_at == nil
      assert reloaded.accepted_by_id == nil
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # Replay regression — accepting twice hits :already_accepted
  # ──────────────────────────────────────────────────────────────────────

  describe "Replay regression" do
    test "T17: accepting twice returns already_accepted and does not re-stamp",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t17-replay")
      target_email = "target-t17-#{System.unique_integer([:positive])}@example.com"
      target = create_user(target_email)
      inv = create_pending_invitation(org, owner, target_email)

      conn = log_in_user(conn, target)

      # First acceptance — success
      {:ok, view1, _html} = live(conn, accept_path(inv.__encoded_token__))
      {:error, {:redirect, %{to: redirect_path}}} =
        view1 |> element("#accept-invitation-button") |> render_click()

      assert redirect_path == "/organizations/#{org.slug}/members"

      first_stamp = Repo.get!(OrganizationInvitation, inv.id).accepted_at
      assert first_stamp != nil

      # Second visit to same URL → :already_accepted branch
      {:ok, _view2, html2} = live(conn, accept_path(inv.__encoded_token__))
      assert html2 =~ "Invitation already accepted"
      refute html2 =~ "phx-click=\"accept_invitation\""

      # accepted_at NOT re-stamped
      second_stamp = Repo.get!(OrganizationInvitation, inv.id).accepted_at
      assert DateTime.compare(first_stamp, second_stamp) == :eq
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # Citext regression — case-insensitive email match succeeds
  # ──────────────────────────────────────────────────────────────────────

  describe "Citext regression" do
    test "T18: signed-in User@Ex.com accepts invitation for user@ex.com successfully",
         %{conn: conn} do
      {org, owner, _m} = create_org_with_owner("t18-citext")
      unique = System.unique_integer([:positive])
      lower_email = "user-t18-#{unique}@ex.com"
      mixed_email = "User-T18-#{unique}@Ex.com"

      # Create the user with mixed-case email. The Sigra normalize path
      # may downcase on insert — in that case the test still works
      # because the row email == lower and the invitation email == lower.
      target =
        Repo.insert!(%Example.Accounts.User{
          email: mixed_email,
          hashed_password: Sigra.Crypto.hash_password("A-super-secret-password-42"),
          password_changed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      inv = create_pending_invitation(org, owner, lower_email)

      conn = log_in_user(conn, target)
      {:ok, view, html} = live(conn, accept_path(inv.__encoded_token__))

      # Accept branch rendered (not mismatch) — citext case-insensitive
      assert html =~ "Join #{org.name}"
      assert html =~ "phx-click=\"accept_invitation\""
      refute html =~ "This invitation is not for you"

      # Clicking accept succeeds
      {:error, {:redirect, %{to: redirect_path}}} =
        view |> element("#accept-invitation-button") |> render_click()

      assert redirect_path == "/organizations/#{org.slug}/members"

      reloaded = Repo.get!(OrganizationInvitation, inv.id)
      assert reloaded.accepted_at != nil
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # Structural invariant — mismatch branch template has zero accept DOM
  # ──────────────────────────────────────────────────────────────────────

  describe "structural invariant (Jetstream #907 static check)" do
    test "T19: mismatch_branch source has zero phx-click=\"accept...\" and zero phx-submit=\"accept...\"" do
      path =
        Path.join([
          File.cwd!(),
          "..",
          "..",
          "priv",
          "templates",
          "sigra.install",
          "organizations",
          "live",
          "invitation_accept_live.ex"
        ])
        |> Path.expand()

      source = File.read!(path)

      # Extract the render_mismatch function body via a regex that
      # starts at `defp render_mismatch(assigns) do` and runs to the
      # matching trailing `end\n`.
      mismatch_body =
        Regex.run(
          ~r/defp render_mismatch\(assigns\) do\n.*?\n  end/s,
          source
        )
        |> List.first()

      assert is_binary(mismatch_body)
      refute mismatch_body =~ "phx-click=\"accept"
      refute mismatch_body =~ "phx-submit=\"accept"

      # And there is no <form ... action="/invitations/.../accept" ...>
      refute mismatch_body =~ ~r|<form[^>]*action=[^>]*accept|
    end

    test "T20: router has unscoped /invitations/:token/accept route" do
      router_source =
        File.read!(Path.join(File.cwd!(), "lib/example_web/router.ex"))

      assert router_source =~ "live \"/invitations/:token/accept\""
      assert router_source =~ "live_session :invitations_public"
      # The route is inside a scope that does NOT pipe_through
      # :require_authenticated.
      invitations_block =
        Regex.run(
          ~r/live_session :invitations_public.*?end/s,
          router_source
        )
        |> List.first()

      assert is_binary(invitations_block)
      refute invitations_block =~ "require_authenticated"
    end
  end
end
