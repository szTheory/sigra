defmodule Sigra.Admin.ComponentsTest do
  use ExUnit.Case, async: true
  @endpoint nil
  import Phoenix.LiveViewTest
  alias Sigra.Admin.Components

  # ---------------------------------------------------------------------------
  # Golden module attributes (D-11)
  #
  # Each golden is captured from the ORIGINAL defp/inline markup output in the
  # live views (characterization fidelity — not authored from the new component).
  # The 7 strict goldens reproduce bytes that the original markup would produce
  # with the same fixed literal assigns.
  #
  # Strict byte-equal goldens (7): stat_link, task_card, summary_chip,
  # applied_chip, empty_state, page_back, scope_ribbon.
  #
  # Full target golden (1): notice — target sg-notice form (D-07/D-12),
  # deliberately ≠ current sg-list-row call sites.
  #
  # D-13: NO mneme / auto_assert / snapshot library. Literal == strings only.
  # Each assertion carries a component-naming, contract-citing,
  # do-not-re-record drift message.
  # ---------------------------------------------------------------------------

  # stat_link — original defp metric_link/1 from index_live.ex:118-125
  # Fixed assigns: label: "Total users", value: 1234, href: "/admin/users"
  @stat_link_golden "<a href=\"/admin/users\" class=\"sg-metric-link \">\n  <span class=\"sg-metric-link__label\">Total users</span>\n  <span class=\"sg-metric-link__value\">1234</span>\n</a>"

  # task_card — original defp task_card/1 from index_live.ex:132-144
  # Fixed assigns: title/body/href/action
  @task_card_golden "<article class=\"sg-card sg-card-hover sg-stack sg-stack--3 \">\n  <div class=\"sg-stack sg-stack--2\">\n    <h2 class=\"sg-section-heading\">Invite your team</h2>\n    <p class=\"sg-section-copy\">Add teammates.</p>\n  </div>\n  <div class=\"sg-cluster\">\n    <a href=\"/admin/users/invite\" class=\"sg-btn sg-btn--primary\">Send invitations</a>\n  </div>\n</article>"

  # summary_chip — original defp summary_chip/1 from users_index_live.ex:336-343
  # Fixed assigns: label: "MFA enabled", value: 7
  @summary_chip_golden "<div class=\"sg-metric \">\n  <dt>MFA enabled</dt>\n  <dd>7</dd>\n</div>"

  # applied_chip — original inline markup from users_index_live.ex:168-178
  # Fixed assigns: label: "Active", remove_href: "/admin/users?status="
  @applied_chip_golden "<span class=\"sg-applied-chip \">\n  <span>Active</span>\n  <a class=\"sg-applied-chip__remove\" href=\"/admin/users?status=\" aria-label=\"Remove filter Active\">\n    <span aria-hidden=\"true\">&times;</span>\n    <span class=\"sr-only\">remove</span>\n  </a>\n</span>"

  # empty_state — original inline markup from users_index_live.ex:285-302
  # Fixed assigns: title: "No users match this view"; inner_block with fixed literal body.
  # NOTE: inner_block returns a raw string which is HTML-escaped by render_slot/1.
  @empty_state_golden "<div class=\"sg-empty-state sg-stack sg-stack--3 \">\n  <p class=\"sg-empty-state__title\">No users match this view</p>\n  Try adjusting your filters.\n</div>"

  # page_back — original inline <a> from user_show_live.ex:91-93
  # Fixed assigns: return_to: "/admin/users", label: "Back to users"
  @page_back_golden "<a class=\"sg-btn sg-btn--ghost sg-btn--sm \" href=\"/admin/users\">\n  <span aria-hidden=\"true\">&larr;</span> Back to users\n</a>"

  # scope_ribbon — original inline <span> from user_show_live.ex:94
  # Fixed assigns: copy: "Platform admin"
  @scope_ribbon_golden "<span class=\"sg-muted sg-text-sm \">Platform admin</span>"

  # notice — TARGET sg-notice form (D-07/D-12), deliberately ≠ current sg-list-row.
  # The original call site (user_show_live.ex:131-133) uses sg-list-row with string tone.
  # summary_alert/1 (user_show_live.ex:488-504) returns {"risk", msg} — tone is a STRING.
  # In HEEx attribute position, atom :risk renders as "risk", so data-tone="risk" matches.
  # The notice component ships sg-notice (pixel-neutral — sg-notice is a byte-clone of
  # sg-list-row per app.css:945-993, Phase 154 intent).
  @notice_golden "<div class=\"sg-notice \" data-tone=\"risk\">\n  <p class=\"sg-text-sm\">Locked — revoke active logins and unlock below.</p>\n</div>"

  # ---------------------------------------------------------------------------
  # Strict byte-equal assertions (7) — D-11
  # ---------------------------------------------------------------------------

  test "stat_link renders original metric_link bytes faithfully" do
    html =
      render_component(&Components.stat_link/1,
        label: "Total users",
        value: 1234,
        href: "/admin/users"
      )

    assert html == @stat_link_golden,
           "stat_link drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  test "task_card renders original task_card bytes faithfully" do
    html =
      render_component(&Components.task_card/1,
        title: "Invite your team",
        body: "Add teammates.",
        href: "/admin/users/invite",
        action: "Send invitations"
      )

    assert html == @task_card_golden,
           "task_card drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  test "summary_chip renders original summary_chip bytes faithfully" do
    html =
      render_component(&Components.summary_chip/1,
        label: "MFA enabled",
        value: 7
      )

    assert html == @summary_chip_golden,
           "summary_chip drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  test "applied_chip renders original inline applied chip bytes faithfully" do
    html =
      render_component(&Components.applied_chip/1,
        label: "Active",
        remove_href: "/admin/users?status="
      )

    assert html == @applied_chip_golden,
           "applied_chip drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  test "empty_state renders original inline empty state bytes faithfully" do
    html =
      render_component(&Components.empty_state/1,
        title: "No users match this view",
        inner_block: [%{inner_block: fn _, _ -> "Try adjusting your filters." end}]
      )

    assert html == @empty_state_golden,
           "empty_state drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  test "page_back renders original inline page back anchor bytes faithfully" do
    html =
      render_component(&Components.page_back/1,
        return_to: "/admin/users",
        label: "Back to users"
      )

    assert html == @page_back_golden,
           "page_back drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  test "scope_ribbon renders original inline scope span bytes faithfully" do
    html =
      render_component(&Components.scope_ribbon/1,
        copy: "Platform admin"
      )

    assert html == @scope_ribbon_golden,
           "scope_ribbon drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  # ---------------------------------------------------------------------------
  # Full target golden assertion (1) — notice — D-12
  # ---------------------------------------------------------------------------

  test "notice renders target sg-notice form with string-equivalent tone" do
    html =
      render_component(&Components.notice/1,
        tone: :risk,
        inner_block: [
          %{inner_block: fn _, _ -> "Locked — revoke active logins and unlock below." end}
        ]
      )

    assert html == @notice_golden,
           "notice drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  # ---------------------------------------------------------------------------
  # Structural assertions (2) — stat, skeleton — D-12
  # ---------------------------------------------------------------------------

  test "stat renders read-only KPI with sg-metric* classes, no <a>, no sg-stat" do
    html =
      render_component(&Components.stat/1,
        label: "Active sessions",
        value: 42
      )

    assert html =~ "sg-metric",
           "stat drifted: required sg-metric* class missing — see admin-design-contract.md; do not re-record Playwright baselines"

    refute html =~ "<a",
           "stat drifted: must not render an <a> element — see admin-design-contract.md; do not re-record Playwright baselines"

    refute html =~ "sg-stat",
           "stat drifted: must not use invented sg-stat class — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  test "skeleton renders loading placeholder with sg-skeleton class" do
    html = render_component(&Components.skeleton/1, [])

    assert html =~ "sg-skeleton",
           "skeleton drifted: required sg-skeleton class missing — see admin-design-contract.md; do not re-record Playwright baselines"
  end
end
