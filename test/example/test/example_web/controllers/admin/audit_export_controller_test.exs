defmodule ExampleWeb.Admin.AuditExportControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.AuditEvent
  alias Example.Repo

  @expected_header [
    "occurred_at",
    "event_id",
    "action",
    "outcome",
    "actor_id",
    "actor_label",
    "effective_user_id",
    "effective_user_label",
    "target_id",
    "target_type",
    "organization_id",
    "organization_label",
    "impersonation_state"
  ]

  describe "Phase 30 audit CSV export contracts" do
    test "global export returns text/csv for the filtered slice with fixed v1 columns", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()

      actor =
        user_fixture(%{
          email: "csv-actor@example.com",
          display_name: "CSV Actor"
        })

      subject =
        user_fixture(%{
          email: "csv-subject@example.com",
          display_name: "CSV Subject"
        })

      insert_audit_event(%{
        action: "admin.impersonation.start",
        actor_id: actor.id,
        effective_user_id: subject.id,
        target_id: subject.id
      })

      insert_audit_event(%{
        action: "session.revoke_all",
        actor_id: actor.id,
        effective_user_id: actor.id,
        target_id: actor.id
      })

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get(
          "/admin/audit/export.csv?effective_user=#{subject.id}&action_prefix=admin.impersonation&page_size=10"
        )

      assert response_content_type(conn, :csv) =~ "text/csv"

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="audit-export.csv")
             ]

      [header, row] = csv_lines(conn.resp_body)

      assert csv_cells(header) == @expected_header
      assert row =~ "admin.impersonation.start"
      assert row =~ actor.id
      assert row =~ subject.id
      assert row =~ "CSV Actor"
      assert row =~ "CSV Subject"
      assert row =~ "impersonating"
      refute conn.resp_body =~ "session.revoke_all"
      refute header =~ "metadata"
      refute conn.resp_body =~ "metadata"
    end

    test "organization-scoped per-user export uses the same normalized filter params as the explorer routes",
         %{conn: conn} do
      platform_admin = platform_admin_fixture()
      org = create_organization(%{name: "Audit CSV Org", slug: "audit-csv-org"})

      actor =
        user_fixture(%{
          email: "per-user-actor@example.com",
          display_name: "Per User Actor"
        })

      subject =
        user_fixture(%{
          email: "per-user-subject@example.com",
          display_name: "Per User Subject"
        })

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

      insert_audit_event(%{
        action: "session.revoke_all",
        actor_id: actor.id,
        effective_user_id: actor.id,
        target_id: actor.id,
        organization_id: org.id
      })

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get(
          "/admin/organizations/#{org.slug}/users/#{subject.id}/audit/export.csv?action_prefix=session&actor=#{actor.id}&page_size=10"
        )

      assert response_content_type(conn, :csv) =~ "text/csv"

      [_header, first_row] = csv_lines(conn.resp_body)

      assert conn.resp_body =~ "session.revoke_all"
      assert conn.resp_body =~ "Per User Actor"
      assert conn.resp_body =~ "Per User Subject"
      assert conn.resp_body =~ org.id
      refute conn.resp_body =~ "#{actor.id},Per User Actor,#{actor.id},Per User Actor"
      refute first_row =~ "metadata"
    end

    test "export escapes dangerous spreadsheet prefixes in derived label cells", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      org = create_organization(%{name: "@Audit Formula Org", slug: "audit-formula-org"})

      actor =
        user_fixture(%{
          email: "formula-actor@example.com",
          display_name: "=Formula Actor"
        })

      subject =
        user_fixture(%{
          email: "formula-subject@example.com",
          display_name: "+Formula Subject"
        })

      create_membership(subject, org, :member)

      insert_audit_event(%{
        action: "admin.impersonation.start",
        actor_id: actor.id,
        effective_user_id: subject.id,
        target_id: subject.id,
        organization_id: org.id
      })

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/audit/export.csv?action_prefix=admin.impersonation")

      assert conn.resp_body =~ "'=Formula Actor"
      assert conn.resp_body =~ "'+Formula Subject"
      assert conn.resp_body =~ "'@Audit Formula Org"
      refute conn.resp_body =~ ",=Formula Actor,"
      refute conn.resp_body =~ ",+Formula Subject,"
      refute conn.resp_body =~ ",@Audit Formula Org,"
    end
  end

  describe "Phase 31 direct-path negative cases (D-12/D-13/D-15)" do
    test "export with a malformed cursor returns a bad-request response, not a widened CSV", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/audit/export.csv?cursor=not-a-valid-cursor")

      # Malformed filter params must fail cleanly. They must not fall through
      # to a successful CSV response because that would hide the filter
      # regression while still emitting (potentially wrong) rows.
      refute conn.status == 200

      assert conn.status in [302, 303, 400, 422]
      assert get_resp_header(conn, "content-type")
             |> Enum.all?(&(not (&1 =~ "text/csv")))
    end

    test "export with a malformed page_size returns a bad-request response", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/audit/export.csv?page_size=0")

      refute conn.status == 200
      assert get_resp_header(conn, "content-type")
             |> Enum.all?(&(not (&1 =~ "text/csv")))
    end

    test "export with a malformed UUID param (actor) returns a bad-request response", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/audit/export.csv?actor=not-a-uuid")

      refute conn.status == 200
      assert get_resp_header(conn, "content-type")
             |> Enum.all?(&(not (&1 =~ "text/csv")))
    end

    test "unauthenticated export request is redirected, not served", %{conn: conn} do
      conn = get(conn, "/admin/audit/export.csv")

      # Must never respond with 200 text/csv for an unauthenticated caller.
      refute conn.status == 200
      assert get_resp_header(conn, "content-type")
             |> Enum.all?(&(not (&1 =~ "text/csv")))
    end

    test "non-admin user requesting the global export is denied before CSV is served", %{conn: conn} do
      non_admin = user_fixture()

      conn =
        conn
        |> log_in_user(non_admin)
        |> get("/admin/audit/export.csv")

      refute conn.status == 200
      assert get_resp_header(conn, "content-type")
             |> Enum.all?(&(not (&1 =~ "text/csv")))
    end

    test "organization-scoped export is denied for an out-of-scope organization slug", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      _org = create_organization(%{name: "Scoped Org", slug: "scoped-org"})

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/organizations/does-not-exist/audit/export.csv")

      # Unknown org slug must collapse to not_found per Phase 27 contract,
      # never to a widened global CSV.
      refute conn.status == 200
      assert get_resp_header(conn, "content-type")
             |> Enum.all?(&(not (&1 =~ "text/csv")))
    end

    test "global export with no audit events returns a header-only CSV, not an error", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get(
          "/admin/audit/export.csv?action_prefix=zzz.definitely.does.not.match.anything&page_size=10"
        )

      assert conn.status == 200
      assert response_content_type(conn, :csv) =~ "text/csv"

      lines = csv_lines(conn.resp_body)

      # Header row must always be present so downstream consumers can depend
      # on schema stability even when the filtered slice is empty.
      assert length(lines) == 1
      assert csv_cells(hd(lines)) == @expected_header
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

  defp csv_lines(body) do
    body
    |> String.trim()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim_trailing(&1, "\r"))
  end

  defp csv_cells(line) do
    String.split(line, ",")
  end
end
