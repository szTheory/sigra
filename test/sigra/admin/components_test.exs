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
  # Byte-equal goldens for audit_row (2): compact variant (show_detail=false,
  # show_codes=false) and full variant (show_detail=true, show_codes=true).
  # Fixed inserted_at: ~U[2026-06-04 12:30:00Z] → renders "2026-06-04 12:30".
  # With @class=nil the root <article> emits a trailing space on its class
  # attribute (Phoenix joins ["sg-list-row sg-stack sg-stack--2", nil] as
  # "sg-list-row sg-stack sg-stack--2 "), exactly as @applied_chip_golden shows.
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
  @scope_ribbon_golden "<span class=\"sg-scope-ribbon sg-muted sg-text-sm \">Platform admin</span>"

  # notice — TARGET sg-notice form (D-07/D-12), deliberately ≠ current sg-list-row.
  # The original call site (user_show_live.ex:131-133) uses sg-list-row with string tone.
  # summary_alert/1 (user_show_live.ex:488-504) returns {"risk", msg} — tone is a STRING.
  # In HEEx attribute position, atom :risk renders as "risk", so data-tone="risk" matches.
  # The notice component ships sg-notice (pixel-neutral — sg-notice is a byte-clone of
  # sg-list-row per app.css:945-993, Phase 154 intent).
  @notice_golden "<div class=\"sg-notice \" data-tone=\"risk\">\n  <div class=\"sg-text-sm\">Locked — revoke active logins and unlock below.</div>\n</div>"

  # ---------------------------------------------------------------------------
  # audit_row goldens (D-10, D-11) — Phase 158, Plan 01
  #
  # Compact variant (show_detail=false, show_codes=false):
  #   Characterization source: user_show_live.ex recent-audit block (~:264-272).
  #   Fixed row: outcome="success", action_badge=nil → audit_tone=nil → data-tone omitted.
  #   Root class: "sg-list-row sg-stack sg-stack--2 " (trailing space, @class=nil house convention).
  #   Timestamp: ~U[2026-06-04 12:30:00Z] → "2026-06-04 12:30" (no seconds, %Y-%m-%d %H:%M).
  #
  # Full variant (show_detail=true, show_codes=true):
  #   Impersonation row: action_badge="Impersonation", outcome="success" → audit_tone="info".
  #   Shows Actor/Effective-user lines and id/action code lines.
  #
  # Tone golden (D-10): risk row → data-tone="risk"; impersonation → data-tone="info"; success → omitted.
  # ---------------------------------------------------------------------------

  # Compact: success row, no badge, show_detail=false, show_codes=false
  @audit_row_compact_golden "<article class=\"sg-list-row sg-stack sg-stack--2 \">\n  <div class=\"sg-cluster sg-cluster--2\">\n    <span class=\"sg-status-pill\">Impersonation started</span>\n    \n  </div>\n  <span class=\"sg-muted sg-text-sm\">admin@example.com</span>\n  \n  \n  <span class=\"sg-muted sg-text-xs\">2026-06-04 12:30</span>\n  \n  \n</article>"

  # Full: impersonation row, badge="Impersonation", show_detail=true, show_codes=true
  @audit_row_full_golden "<article class=\"sg-list-row sg-stack sg-stack--2 \" data-tone=\"info\">\n  <div class=\"sg-cluster sg-cluster--2\">\n    <span class=\"sg-status-pill\" data-tone=\"info\">Impersonation started</span>\n    <span class=\"sg-status-pill\" data-tone=\"info\">Impersonation</span>\n  </div>\n  <span class=\"sg-muted sg-text-sm\">admin@example.com acting as user@example.com</span>\n  <span class=\"sg-muted sg-text-sm\">Actor: admin@example.com</span>\n  <span class=\"sg-muted sg-text-sm\">Effective user: user@example.com</span>\n  <span class=\"sg-muted sg-text-xs\">2026-06-04 12:30</span>\n  <code class=\"sg-code\">uuid-5678</code>\n  <code class=\"sg-code\">admin.impersonation.start</code>\n</article>"

  # Fixed rows for audit_row tests
  @compact_row %{
    id: "uuid-1234",
    inserted_at: ~U[2026-06-04 12:30:00Z],
    action: "admin.impersonation.start",
    action_label: "Impersonation started",
    action_badge: nil,
    actor_label: "admin@example.com",
    effective_user_label: "user@example.com",
    actor_summary: "admin@example.com",
    outcome: "success"
  }

  @impersonation_row %{
    id: "uuid-5678",
    inserted_at: ~U[2026-06-04 12:30:00Z],
    action: "admin.impersonation.start",
    action_label: "Impersonation started",
    action_badge: "Impersonation",
    actor_label: "admin@example.com",
    effective_user_label: "user@example.com",
    actor_summary: "admin@example.com acting as user@example.com",
    outcome: "success"
  }

  @failure_row %{
    id: "uuid-9999",
    inserted_at: ~U[2026-06-04 12:30:00Z],
    action: "auth.login.failure",
    action_label: "Login failed",
    action_badge: nil,
    actor_label: "user@example.com",
    effective_user_label: "user@example.com",
    actor_summary: "user@example.com",
    outcome: "failure"
  }

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

  # ---------------------------------------------------------------------------
  # audit_row byte-equal golden assertions (2) — D-11 / Phase 158-01
  # ---------------------------------------------------------------------------

  test "audit_row compact variant renders characterization bytes faithfully" do
    html = render_component(&Components.audit_row/1, row: @compact_row)

    assert html == @audit_row_compact_golden,
           "audit_row compact drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  test "audit_row full variant (show_detail + show_codes) renders expected bytes" do
    html =
      render_component(&Components.audit_row/1,
        row: @impersonation_row,
        show_detail: true,
        show_codes: true
      )

    assert html == @audit_row_full_golden,
           "audit_row full drifted — see admin-design-contract.md; do not re-record Playwright baselines"
  end

  # ---------------------------------------------------------------------------
  # audit_row tone-mapping golden (D-10) — single source of truth
  # ---------------------------------------------------------------------------

  test "audit_row tone-mapping: failure outcome yields data-tone=risk" do
    html = render_component(&Components.audit_row/1, row: @failure_row)

    assert html =~ ~s(data-tone="risk"),
           "audit_row tone drifted: failure row must carry data-tone=\"risk\" — do not re-record Playwright baselines"
  end

  test "audit_row tone-mapping: impersonation (action_badge present) yields data-tone=info" do
    html = render_component(&Components.audit_row/1, row: @impersonation_row)

    assert html =~ ~s(data-tone="info"),
           "audit_row tone drifted: impersonation row must carry data-tone=\"info\" — do not re-record Playwright baselines"
  end

  test "audit_row tone-mapping: plain success row yields no data-tone attribute" do
    html = render_component(&Components.audit_row/1, row: @compact_row)

    refute html =~ "data-tone",
           "audit_row tone drifted: success row must not carry data-tone — do not re-record Playwright baselines"
  end

  # ---------------------------------------------------------------------------
  # format_date unit cases — D-09 NaiveDateTime fix
  # Exercised via audit_row rendering (private helper, no public surface widened).
  # ---------------------------------------------------------------------------

  test "format_date: %DateTime formats as YYYY-MM-DD HH:MM (no seconds)" do
    row = Map.put(@compact_row, :inserted_at, ~U[2026-06-04 12:30:00Z])
    html = render_component(&Components.audit_row/1, row: row)

    assert html =~ "2026-06-04 12:30",
           "format_date drifted: %DateTime must render as YYYY-MM-DD HH:MM — do not re-record Playwright baselines"

    refute html =~ "12:30:00",
           "format_date drifted: seconds must not appear in compact timestamp — do not re-record Playwright baselines"
  end

  test "format_date: %NaiveDateTime formats as YYYY-MM-DD HH:MM (D-09 fix)" do
    row = Map.put(@compact_row, :inserted_at, ~N[2026-06-04 12:30:00])
    html = render_component(&Components.audit_row/1, row: row)

    assert html =~ "2026-06-04 12:30",
           "format_date drifted: %NaiveDateTime must render as YYYY-MM-DD HH:MM — do not re-record Playwright baselines"
  end

  test "format_date: nil renders em-dash placeholder" do
    row = Map.put(@compact_row, :inserted_at, nil)
    html = render_component(&Components.audit_row/1, row: row)

    assert html =~ "—",
           "format_date drifted: nil must render \"—\" — do not re-record Playwright baselines"
  end

  test "format_date: wrong type raises ArgumentError (D-09 no-silent-swallow)" do
    row = Map.put(@compact_row, :inserted_at, ~D[2026-06-04])

    assert_raise ArgumentError, fn ->
      render_component(&Components.audit_row/1, row: row)
    end
  end
end
