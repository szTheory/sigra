defmodule ExampleWeb.AdminAuditUserLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.AuditEvent
  alias Example.Repo

  describe "Phase 158 shared chrome components (AUDX-03)" do
    test "renders Overview / Users / email / Audit breadcrumb instead of a back button", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()
      subject = user_fixture(%{email: "audit-chrome-subject@example.com"})
      return_to = "/admin/users?order_by=inserted_at&order_direction=desc"

      html =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/users/#{subject.id}/audit?return_to=#{URI.encode_www_form(return_to)}")
        |> html_response(200)

      breadcrumb = breadcrumb_fragment(html)

      assert breadcrumb =~ ~s(href="/admin")
      assert breadcrumb =~ "Overview"
      assert breadcrumb =~ ~s(href="/admin/users?order_by=inserted_at&amp;order_direction=desc")
      assert breadcrumb =~ "Users"

      assert breadcrumb =~
               ~s(href="/admin/users/#{subject.id}?return_to=%2Fadmin%2Fusers%3Forder_by%3Dinserted_at%26order_direction%3Ddesc")

      assert breadcrumb =~ subject.email
      assert breadcrumb =~ ~s(aria-current="page")
      assert breadcrumb =~ "Audit"
      assert html_offset(breadcrumb, "Overview") < html_offset(breadcrumb, "Users")
      assert html_offset(breadcrumb, "Users") < html_offset(breadcrumb, subject.email)
      assert html_offset(breadcrumb, subject.email) < html_offset(breadcrumb, "Audit")
      refute html =~ "Back to user"
      refute html =~ "&larr; Back to user"
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

  describe "204 per-user audit pagination boundary (WR-02 / D-06)" do
    test "nav is PRESENT with user-scoped hrefs when 26 events span two pages (page_size=25)", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()
      subject = user_fixture(%{email: "pag-boundary-26-subject@example.com"})
      return_to = "/admin/users?q=pag-boundary-26"

      for _i <- 1..26 do
        insert_audit_event(%{
          action: "session.create",
          actor_id: subject.id,
          effective_user_id: subject.id
        })
      end

      html =
        conn
        |> log_in_user(platform_admin)
        |> get(
          "/admin/users/#{subject.id}/audit?page_size=25&return_to=#{URI.encode_www_form(return_to)}"
        )
        |> html_response(200)

      assert html =~ ~s(aria-label="Next page"),
             "pagination nav must render a Next page link when 26 events span >1 page"

      next_href =
        html
        |> extract_next_href()

      assert next_href =~ "/admin/users/#{subject.id}/audit",
             "Next href must be user-scoped (contain /admin/users/<subject_id>/audit)"

      assert next_href =~ "cursor=",
             "Next href must carry a cursor= param for honest cursor pagination"

      assert next_href =~ "return_to=",
             "Next href must preserve return_to param"
    end

    test "nav is ABSENT when exactly 25 events fit a single page (page_size=25)", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      subject = user_fixture(%{email: "pag-boundary-25-subject@example.com"})

      for _i <- 1..25 do
        insert_audit_event(%{
          action: "session.create",
          actor_id: subject.id,
          effective_user_id: subject.id
        })
      end

      html =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/users/#{subject.id}/audit?page_size=25")
        |> html_response(200)

      refute html =~ ~s(aria-label="Next page"),
             "pagination nav must not render when 25 events fit a single page"

      refute html =~ ~s(aria-label="Previous page"),
             "pagination nav must not render previous link when on single-page result"
    end
  end

  describe "204 Event-codes disclosure archetype (WR-01 / D-07)" do
    test "desktop Event cell wraps event id and action code in a default-collapsed <details>", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()
      subject = user_fixture(%{email: "disclosure-subject@example.com"})

      event =
        insert_audit_event(%{
          action: "session.create",
          actor_id: subject.id,
          effective_user_id: subject.id
        })

      html =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/users/#{subject.id}/audit")
        |> html_response(200)

      # The desktop results table is present (we have events)
      assert html =~ ~s(data-testid="admin-audit-user-desktop-results"),
             "desktop results table must be present when there are audit events"

      # The <details> element is present and not force-opened
      assert html =~ "<details>",
             "<details> disclosure element must exist in the Event cell"

      # Scope the "not force-opened" check to the desktop results table so a future
      # unrelated <details open> elsewhere on the page (e.g. the "More filters"
      # panel) can't spuriously fail this Event-cell disclosure lock.
      desktop_results_region = extract_desktop_results_region(html)

      refute desktop_results_region =~ "<details open",
             "Event-cell <details> in the desktop results table must NOT be force-opened — it must be default-collapsed"

      # The <summary> affordance is the visible label
      assert html =~ "<summary",
             "<summary> affordance must exist inside <details>"

      assert html =~ "Event codes",
             "<summary> must contain the 'Event codes' disclosure label"

      # The event id and action code render inside the disclosure (as sg-code elements)
      event_id_string = to_string(event.id)

      # Extract the disclosure region (after the summary close tag) and assert both codes appear
      disclosure_region = extract_disclosure_region(html)

      assert disclosure_region =~ event_id_string,
             "event id must appear inside the disclosure region (after <summary>)"

      assert disclosure_region =~ event.action,
             "event action code must appear inside the disclosure region (after <summary>)"

      # Both values should be wrapped in code.sg-code elements
      assert html =~ ~s(<code class="sg-code">#{event_id_string}</code>),
             "event id must be wrapped in <code class=\"sg-code\">"

      assert html =~ ~s(<code class="sg-code">#{event.action}</code>),
             "action code must be wrapped in <code class=\"sg-code\">"
    end
  end

  defp extract_next_href(html) do
    # Delegate to the forward extractor, which anchors on the aria-label="Next page"
    # attribute within the same <a> tag (handles both attribute orders). The
    # previous outer wrapper made its first regex dead code and matched on the
    # unscoped literal "Next page" text — replaced with the correctly-anchored path.
    extract_next_href_forward(html)
  end

  defp extract_next_href_forward(html) do
    # Find the aria-label="Next page" anchor and extract its href
    case Regex.run(
           ~r/<a[^>]+href="([^"]+)"[^>]*aria-label="Next page"/,
           html
         ) do
      [_, href] -> href
      _ ->
        # Try reversed attribute order
        case Regex.run(
               ~r/<a[^>]*aria-label="Next page"[^>]*href="([^"]+)"/,
               html
             ) do
          [_, href] -> href
          _ -> ""
        end
    end
  end

  defp extract_desktop_results_region(html) do
    # Slice the rendered HTML from the desktop results table testid forward so
    # assertions about the desktop Event cell are not affected by other regions
    # (filters panel, mobile cards) on the same page.
    marker = ~s(data-testid="admin-audit-user-desktop-results")

    case :binary.match(html, marker) do
      {start, _} -> binary_part(html, start, byte_size(html) - start)
      :nomatch -> ""
    end
  end

  defp extract_disclosure_region(html) do
    # Find the "Event codes" summary text, then slice after its </summary> close tag
    # (there is also a "More filters" <details> earlier on the page — must target "Event codes")
    event_codes_marker = "Event codes"

    case :binary.match(html, event_codes_marker) do
      {marker_start, _} ->
        # Now find the </summary> that follows "Event codes"
        html_from_marker = binary_part(html, marker_start, byte_size(html) - marker_start)

        case :binary.match(html_from_marker, "</summary>") do
          {close_start, close_len} ->
            after_close_start = marker_start + close_start + close_len
            binary_part(html, after_close_start, min(500, byte_size(html) - after_close_start))

          :nomatch ->
            ""
        end

      :nomatch ->
        ""
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

  defp breadcrumb_fragment(html) do
    case :binary.match(html, ~s(aria-label="Breadcrumb")) do
      {start, _} -> binary_part(html, start, min(3_000, byte_size(html) - start))
      :nomatch -> ""
    end
  end

  defp html_offset(html, needle) do
    case :binary.match(html, needle) do
      {offset, _length} -> offset
      :nomatch -> nil
    end
  end
end
