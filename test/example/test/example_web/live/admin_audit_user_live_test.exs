defmodule ExampleWeb.AdminAuditUserLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.AuditEvent
  alias Example.Repo

  describe "Phase 158 shared chrome components (AUDX-03)" do
    test "renders page_back ghost-button with back arrow and 'Back to user' label", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      subject = user_fixture(%{email: "audit-chrome-subject@example.com"})

      html =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/users/#{subject.id}/audit?return_to=%2Fadmin%2Fusers%2F#{subject.id}")
        |> html_response(200)

      assert html =~ "sg-btn--ghost",
             "page_back ghost-button class must render"

      assert html =~ "Back to user",
             "page_back label must render 'Back to user'"

      assert html =~ "&larr;",
             "page_back must include left-arrow glyph"
    end

    test "renders empty_state with per-user copy when no events exist", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      subject = user_fixture(%{email: "audit-empty-subject@example.com"})

      html =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/users/#{subject.id}/audit")
        |> html_response(200)

      assert html =~ "No audit events for this user",
             "empty_state title must match per-user copy contract"

      assert html =~ "No scoped events are currently tied to this user.",
             "empty_state body must match per-user copy contract"
    end
  end

  describe "Phase 30 per-user audit explorer contracts" do
    test "global per-user audit route loads and preserves filter context in the URL", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()
      actor = user_fixture(%{email: "user-audit-actor@example.com", display_name: "Audit Actor"})

      subject =
        user_fixture(%{email: "user-audit-subject@example.com", display_name: "Audit Subject"})

      insert_audit_event(%{
        action: "session.create",
        actor_id: subject.id,
        effective_user_id: subject.id
      })

      insert_audit_event(%{
        action: "admin.impersonation.start",
        actor_id: actor.id,
        effective_user_id: subject.id,
        target_id: subject.id
      })

      html =
        conn
        |> log_in_user(platform_admin)
        |> get(
          "/admin/users/#{subject.id}/audit?action_prefix=session&page_size=1&return_to=%2Fadmin%2Fusers%3Fq%3Duser-audit"
        )
        |> html_response(200)

      assert html =~ "Audit Subject"
      assert html =~ "session.create"
      assert html =~ ~s(name="action_prefix")
      assert html =~ ~s(value="session")
      assert html =~ ~s(name="page_size")
      assert html =~ ~s(value="1")
      assert html =~ "return_to=%2Fadmin%2Fusers%3Fq%3Duser-audit"
      assert html =~ "/admin/users/#{subject.id}/audit?"
    end

    test "organization-scoped per-user audit route intentionally includes the user's global support rows",
         %{
           conn: conn
         } do
      platform_admin = platform_admin_fixture()
      org = create_organization(%{name: "Scoped Audit Org", slug: "scoped-audit-org"})
      actor = user_fixture(%{email: "scoped-actor@example.com", display_name: "Scoped Actor"})

      subject =
        user_fixture(%{email: "scoped-subject@example.com", display_name: "Scoped Subject"})

      create_membership(subject, org, :member)

      insert_audit_event(%{
        action: "session.create",
        actor_id: subject.id,
        effective_user_id: subject.id,
        organization_id: nil
      })

      insert_audit_event(%{
        action: "session.revoke_all",
        actor_id: actor.id,
        effective_user_id: subject.id,
        target_id: subject.id,
        organization_id: org.id
      })

      html =
        conn
        |> log_in_user(platform_admin)
        |> get(
          "/admin/organizations/#{org.slug}/users/#{subject.id}/audit?return_to=%2Fadmin%2Forganizations%2F#{org.slug}%2Fusers%3Fq%3Dscoped"
        )
        |> html_response(200)

      assert html =~ "Scoped Subject"
      assert html =~ "session.create"
      assert html =~ "session.revoke_all"
      assert html =~ "return_to=%2Fadmin%2Forganizations%2F#{org.slug}%2Fusers%3Fq%3Dscoped"
      assert html =~ "/admin/organizations/#{org.slug}/users/#{subject.id}/audit"
    end
  end

  defp platform_admin_fixture do
    user_fixture(%{
      email: "platform-admin+#{System.unique_integer([:positive])}@example.com",
      display_name: "Platform Admin"
    })
  end

  defp insert_audit_event(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    defaults = %{
      action: "session.create",
      actor_type: "user",
      target_type: "user",
      outcome: "success",
      occurred_at: now,
      inserted_at: now,
      metadata: %{}
    }

    %AuditEvent{}
    |> Ecto.Changeset.change(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
