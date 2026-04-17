defmodule ExampleWeb.AdminAuditIndexLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.AuditEvent
  alias Example.Repo

  describe "Phase 30 admin audit explorer contracts" do
    test "global explorer preserves URL-driven filters across sort and pagination links", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      actor = user_fixture(%{email: "actor-audit@example.com", display_name: "Actor Audit"})
      subject = user_fixture(%{email: "subject-audit@example.com", display_name: "Subject Audit"})

      insert_audit_event(%{
        action: "admin.users.session.revoke",
        actor_id: actor.id,
        effective_user_id: subject.id,
        target_id: subject.id
      })

      older =
        insert_audit_event(%{
          action: "admin.impersonation.start",
          actor_id: actor.id,
          effective_user_id: subject.id,
          target_id: subject.id
        })

      query =
        URI.encode_query(%{
          "effective_user" => subject.id,
          "action_prefix" => "admin.impersonation",
          "page_size" => "1"
        })

      html =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/audit?" <> query)
        |> html_response(200)

      assert html =~ "Audit"
      assert html =~ "Subject Audit"
      assert html =~ "Actor Audit"
      assert html =~ ~s(name="effective_user")
      assert html =~ ~s(value="#{subject.id}")
      assert html =~ ~s(name="action_prefix")
      assert html =~ ~s(value="admin.impersonation")
      assert html =~ ~s(name="page_size")
      assert html =~ ~s(value="1")
      assert html =~ "/admin/audit?action_prefix=admin.impersonation&amp;effective_user=#{subject.id}&amp;page_size=1&amp;sort=occurred_at"
      assert html =~ "/admin/audit?action_prefix=admin.impersonation&amp;cursor="
      assert html =~ older.id
    end

    test "organization explorer fails closed outside the resolved organization scope", %{conn: conn} do
      org_admin = org_admin_fixture()
      allowed_org = create_organization(%{name: "Allowed Audit Org", slug: "allowed-audit-org"})
      other_org = create_organization(%{name: "Other Audit Org", slug: "other-audit-org"})
      create_membership(org_admin, allowed_org, :admin)

      allowed_user = user_fixture(%{email: "allowed-org-audit@example.com"})
      other_user = user_fixture(%{email: "other-org-audit@example.com"})

      insert_audit_event(%{
        action: "session.create",
        actor_id: allowed_user.id,
        effective_user_id: allowed_user.id,
        organization_id: allowed_org.id
      })

      insert_audit_event(%{
        action: "session.create",
        actor_id: other_user.id,
        effective_user_id: other_user.id,
        organization_id: other_org.id
      })

      conn =
        conn
        |> log_in_user(org_admin)
        |> get("/admin/organizations/#{allowed_org.slug}/audit?organization=#{other_org.id}")

      assert conn.status == 404
      assert html_response(conn, 404) =~ "organization admin scope"
    end

    test "impersonation rows show actor and effective user labels without exposing metadata blobs", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()
      actor = user_fixture(%{email: "real-admin-audit@example.com", display_name: "Real Admin"})
      effective_user = user_fixture(%{email: "effective-audit@example.com", display_name: "Effective User"})

      insert_audit_event(%{
        action: "admin.impersonation.start",
        actor_id: actor.id,
        effective_user_id: effective_user.id,
        target_id: effective_user.id,
        metadata: %{"impersonation_reason" => "raw-metadata-should-not-render"}
      })

      html =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/audit?action_prefix=admin.impersonation")
        |> html_response(200)

      assert html =~ "Impersonation"
      assert html =~ "Real Admin"
      assert html =~ "Effective User"
      assert html =~ "acting as"
      refute html =~ "raw-metadata-should-not-render"
      refute html =~ "metadata"
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

  defp insert_audit_event(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

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
