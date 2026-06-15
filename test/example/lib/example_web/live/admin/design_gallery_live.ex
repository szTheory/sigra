defmodule ExampleWeb.Admin.DesignGalleryLive do
  @moduledoc """
  Example-only design gallery for /admin/_design.

  Renders all 13 Sigra.Admin.Components + meta-component groups (MG-1..MG-11)
  in every state, inside the real admin shell. Available in development only —
  the route is compile_env(:example, :dev_routes) gated.

  Data is all static literal assigns — no DB queries, no Query module imports.
  """
  use ExampleWeb, :live_view
  import Sigra.Admin.Components

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Design Gallery")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="sg-stack sg-stack--6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Design System</p>
        <h1 class="sg-page-title">Design Gallery</h1>
        <p class="sg-page-copy">
          Component and group state matrix for audit and regression checking.
          Available in development only.
        </p>
        <span data-testid="design-gallery-dev-only-badge">DEV ONLY</span>
      </header>

      <section class="sg-stack sg-stack--4">
        <h2 class="sg-section-heading">Components</h2>
        <div class="sg-stack sg-stack--6">
          <%!-- board-stat --%>
          <div id="board-stat" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">stat</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">read-only KPI</span>
              <.stat label="Active Users" value={1_247} />
            </div>
          </div>

          <%!-- board-stat_link --%>
          <div id="board-stat_link" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">stat_link</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.stat_link
                id="stat-link-default"
                href="/admin/users"
                label="Total Users"
                value={3_842}
              />

              <span class="sg-muted sg-text-xs">hover</span>
              <.stat_link
                id="stat-link-hover"
                href="/admin/users"
                label="Invited Users"
                value={18}
              />

              <span class="sg-muted sg-text-xs">focus-visible</span>
              <.stat_link
                id="stat-link-focus"
                href="/admin/users"
                label="Locked Users"
                value={2}
              />

              <span class="sg-muted sg-text-xs">active</span>
              <.stat_link
                id="stat-link-active"
                href="/admin/users"
                label="Needs Review"
                value={3}
              />
            </div>
          </div>

          <%!-- board-task_card --%>
          <div id="board-task_card" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">task_card</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.task_card
                title="Review flagged accounts"
                body="3 accounts require review."
                href="/admin/users?flagged=true"
                action="Review"
              />

              <span class="sg-muted sg-text-xs">hover</span>
              <.task_card
                title="Review invited accounts"
                body="18 invitations are still pending."
                href="/admin/users?invited=true"
                action="Open invitations"
              />

              <span class="sg-muted sg-text-xs">CTA focus-visible</span>
              <.task_card
                title="Unlock accounts"
                body="2 accounts are locked after failed attempts."
                href="/admin/users?locked=true"
                action="View locked users"
              />

              <span class="sg-muted sg-text-xs">CTA active</span>
              <.task_card
                title="Resolve review queue"
                body="3 accounts need an operator decision."
                href="/admin/users?needs_review=true"
                action="Review accounts"
              />

              <span class="sg-muted sg-text-xs">disabled</span>
              <div class="sg-cluster">
                <button
                  id="task-card-disabled-native"
                  class="sg-btn sg-btn--primary"
                  type="button"
                  disabled
                >
                  Disabled button
                </button>
                <a
                  id="task-card-disabled-aria"
                  class="sg-btn sg-btn--secondary"
                  aria-disabled="true"
                  tabindex="-1"
                >
                  Unavailable link
                </a>
                <span
                  id="task-card-disabled-class"
                  class="sg-btn sg-btn--ghost is-disabled"
                  aria-disabled="true"
                >
                  Disabled span
                </span>
              </div>
            </div>
          </div>

          <%!-- board-summary_chip --%>
          <div id="board-summary_chip" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">summary_chip</p>
            <div class="sg-stack sg-stack--3">
              <%!-- summary_chip emits bare <dt>/<dd> with no <dl> of its own,
                   so each board variant is wrapped in <dl class="sg-metric-grid">
                   exactly as the real admin does (a11y dlitem rule). --%>
              <span class="sg-muted sg-text-xs">tone: neutral</span>
              <dl class="sg-metric-grid">
                <.summary_chip id="summary-chip-neutral" label="Sessions" value={12} />
              </dl>

              <span class="sg-muted sg-text-xs">tone: risk</span>
              <span class="sg-muted sg-text-xs">help closed</span>
              <dl class="sg-metric-grid">
                <.summary_chip
                  id="summary-chip-help-closed"
                  label="Failed Logins"
                  value={7}
                  icon="shield-check"
                  value_unit="today"
                  subvalue="Spike detected"
                  help="Logins that failed authentication."
                  tone="risk"
                />
              </dl>

              <span class="sg-muted sg-text-xs">help open</span>
              <dl class="sg-metric-grid">
                <.summary_chip
                  id="summary-chip-help-open"
                  label="MFA Coverage"
                  value={94}
                  icon="mfa"
                  value_unit="%"
                  value_suffix="MFA coverage"
                  subvalue="6 accounts still need setup"
                  help="Shows the share of users with multifactor authentication enabled."
                  tone="ok"
                  open
                />
              </dl>

              <span class="sg-muted sg-text-xs">tone: warn</span>
              <dl class="sg-metric-grid">
                <.summary_chip label="Pending Reviews" value={4} tone="warn" />
              </dl>

              <span class="sg-muted sg-text-xs">tone: ok</span>
              <dl class="sg-metric-grid">
                <.summary_chip label="MFA Enabled" value={98} tone="ok" />
              </dl>

              <span class="sg-muted sg-text-xs">tone: info</span>
              <dl class="sg-metric-grid">
                <.summary_chip label="Active Sessions" value={31} tone="info" />
              </dl>

              <span class="sg-muted sg-text-xs">focus-visible</span>
              <dl class="sg-metric-grid">
                <.summary_chip
                  id="summary-chip-focus"
                  label="Recovery Codes"
                  value={11}
                  icon="fingerprint"
                  value_suffix="need rotation"
                  help="Shows accounts with recovery codes older than policy."
                  tone="info"
                />
              </dl>
            </div>
          </div>

          <%!-- board-applied_chip --%>
          <div id="board-applied_chip" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">applied_chip</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.applied_chip label="Role: Admin" remove_href="?role=" />

              <span class="sg-muted sg-text-xs">hover</span>
              <.applied_chip label="Role: Admin" remove_href="?role=" />

              <span class="sg-muted sg-text-xs">focus-visible</span>
              <.applied_chip label="Role: Admin" remove_href="?role=" />

              <span class="sg-muted sg-text-xs">active</span>
              <.applied_chip label="Role: Admin" remove_href="?role=" />
            </div>
          </div>

          <%!-- board-empty_state --%>
          <div id="board-empty_state" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">empty_state</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.empty_state title="No users found">
                <p>Try adjusting your filters.</p>
              </.empty_state>
            </div>
          </div>

          <%!-- board-page_back --%>
          <div id="board-page_back" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">page_back</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.page_back return_to="/admin/users" label="Back to users" />

              <span class="sg-muted sg-text-xs">hover</span>
              <.page_back return_to="/admin/users" label="Back to users" />

              <span class="sg-muted sg-text-xs">focus-visible</span>
              <.page_back return_to="/admin/users" label="Back to users" />

              <span class="sg-muted sg-text-xs">active</span>
              <.page_back return_to="/admin/users" label="Back to users" />
            </div>
          </div>

          <%!-- board-scope_ribbon --%>
          <div id="board-scope_ribbon" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">scope_ribbon</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">global scope</span>
              <.scope_ribbon copy="Viewing all organizations" />

              <span class="sg-muted sg-text-xs">org scope</span>
              <.scope_ribbon copy="Viewing Acme Corp" />
            </div>
          </div>

          <%!-- board-notice (CANARY, D-10) — all 5 tones including embedded notice_link --%>
          <div id="board-notice" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">notice</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">tone: nil (neutral)</span>
              <.notice>System maintenance scheduled for Sunday 02:00 UTC.</.notice>

              <span class="sg-muted sg-text-xs">tone: ok</span>
              <.notice tone={:ok}>All clear — no accounts need review.</.notice>

              <span class="sg-muted sg-text-xs">tone: warn</span>
              <.notice tone={:warn}>Password reset email delivery delayed.</.notice>

              <span class="sg-muted sg-text-xs">tone: risk (with embedded notice_link)</span>
              <.notice tone={:risk}>
                3 accounts need review —
                <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
              </.notice>

              <span class="sg-muted sg-text-xs">tone: info</span>
              <.notice tone={:info}>Impersonation session active. End it before navigating away.</.notice>
            </div>
          </div>

          <%!-- board-notice_link --%>
          <div id="board-notice_link" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">notice_link</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.notice tone={:risk}>
                3 accounts need review —
                <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
              </.notice>

              <span class="sg-muted sg-text-xs">hover</span>
              <.notice tone={:risk}>
                3 accounts need review —
                <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
              </.notice>

              <span class="sg-muted sg-text-xs">focus-visible</span>
              <.notice tone={:risk}>
                3 accounts need review —
                <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
              </.notice>

              <span class="sg-muted sg-text-xs">active</span>
              <.notice tone={:risk}>
                3 accounts need review —
                <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
              </.notice>
            </div>
          </div>

          <%!-- board-field_help --%>
          <div id="board-field_help" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">field_help</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">closed</span>
              <.field_help id="fh-example-closed" label="API Token">
                Token generated at account creation.
              </.field_help>

              <span class="sg-muted sg-text-xs">open</span>
              <.field_help id="fh-example-open" label="Session Lifetime" open>
                Controls how long an admin session can stay active before re-authentication.
              </.field_help>

              <span class="sg-muted sg-text-xs">focus-visible</span>
              <.field_help id="fh-example-focus" label="Invite Domain">
                Limits which email domains can receive admin invitations.
              </.field_help>

              <span class="sg-muted sg-text-xs">click/tap</span>
              <.field_help id="fh-example-click" label="Audit Retention">
                Sets how long audit events remain searchable.
              </.field_help>

              <span class="sg-muted sg-text-xs">Escape close</span>
              <.field_help id="fh-example-escape" label="Impersonation Reason">
                Records why an operator opened a support session.
              </.field_help>
            </div>
          </div>

          <%!-- board-skeleton --%>
          <div id="board-skeleton" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">skeleton</p>
            <div
              class="sg-stack sg-stack--3"
              aria-busy="true"
              aria-label="Loading users"
              data-skeleton-loading-region
            >
              <span class="sg-muted sg-text-xs">aria-busy container</span>

              <span class="sg-muted sg-text-xs">line skeleton</span>
              <.skeleton style="inline-size: 12rem; block-size: 1rem;" />

              <span class="sg-muted sg-text-xs">block skeleton</span>
              <.skeleton style="inline-size: 100%; block-size: 4rem;" />

              <span class="sg-muted sg-text-xs">card skeleton</span>
              <div class="sg-card sg-stack sg-stack--3" aria-hidden="true">
                <.skeleton style="inline-size: 45%; block-size: 1rem;" />
                <.skeleton style="inline-size: 100%; block-size: 0.75rem;" />
                <.skeleton style="inline-size: 70%; block-size: 0.75rem;" />
              </div>

              <span class="sg-muted sg-text-xs">reduced motion static</span>
            </div>
          </div>

          <%!-- board-audit_row --%>
          <div id="board-audit_row" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">audit_row</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">success compact</span>
              <.audit_row row={%{
                id: "uuid-1234",
                inserted_at: ~N[2026-01-15 10:30:00],
                action: "auth.login.success",
                action_label: "Login succeeded",
                action_badge: nil,
                actor_label: "alice@example.test",
                effective_user_label: "alice@example.test",
                actor_summary: "alice@example.test",
                outcome: "success"
              }} />

              <span class="sg-muted sg-text-xs">info full with codes</span>
              <.audit_row
                row={%{
                  id: "uuid-5678",
                  inserted_at: ~N[2026-01-15 11:00:00],
                  action: "admin.impersonation.start",
                  action_label: "Impersonation started",
                  action_badge: "Impersonation",
                  actor_label: "admin@example.test",
                  effective_user_label: "alice@example.test",
                  actor_summary: "admin@example.test acting as alice@example.test",
                  outcome: "success"
                }}
                show_detail
                show_codes
              />

              <span class="sg-muted sg-text-xs">risk failure</span>
              <.audit_row row={%{
                id: "uuid-9999",
                inserted_at: ~N[2026-01-15 09:00:00],
                action: "auth.login.failure",
                action_label: "Login failed",
                action_badge: nil,
                actor_label: "unknown@example.test",
                effective_user_label: "unknown@example.test",
                actor_summary: "unknown@example.test",
                outcome: "failure"
              }} />
            </div>
          </div>
        </div>
      </section>

      <section class="sg-stack sg-stack--4">
        <h2 class="sg-section-heading">Component Groups</h2>
        <div class="sg-stack sg-stack--6">
          <%!-- board-mg-1: Metric / Summary Strip --%>
          <div id="board-mg-1" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-1 Metric / Summary Strip</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-1-populated" class="sg-stack sg-stack--2">
                <p class="sg-muted sg-text-xs">populated</p>
                <dl class="sg-metric-grid">
                  <.summary_chip label="Total Users" value={3_842} />
                  <.summary_chip label="Active Sessions" value={127} tone="info" />
                  <.summary_chip label="Failed Logins" value={7} tone="risk" />
                  <.summary_chip label="MFA Enabled" value={94} value_unit="%" tone="ok" />
                </dl>
              </div>
              <div data-testid="mg-1-zero" class="sg-stack sg-stack--2">
                <p class="sg-muted sg-text-xs">zero</p>
                <dl class="sg-metric-grid">
                  <.summary_chip label="Total Users" value={0} />
                  <.summary_chip label="Active Sessions" value={0} tone="info" />
                  <.summary_chip label="Failed Logins" value={0} tone="ok" />
                </dl>
              </div>
              <div data-testid="mg-1-loading" class="sg-metric-grid" aria-busy="true">
                <.skeleton class="sg-card" />
                <.skeleton class="sg-card" />
                <.skeleton class="sg-card" />
              </div>
              <div data-testid="mg-1-error">
                <.notice tone={:risk}>
                  Unable to load summary metrics. Refresh the page, then check admin logs if it happens again.
                </.notice>
              </div>
            </div>
          </div>

          <%!-- board-mg-2: Filter Panel + Applied-chip Row --%>
          <div id="board-mg-2" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-2 Filter Panel + Applied-chip Row</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-2-populated" class="sg-stack sg-stack--3">
                <form class="sg-filter-panel sg-stack sg-stack--3">
                  <div class="sg-search-row">
                    <label class="sg-field" for="mg2-search">
                      <span class="sg-field-label">Search</span>
                      <input id="mg2-search" class="sg-input" value="alice" />
                    </label>
                    <button type="button" class="sg-btn sg-btn--primary">Apply filters</button>
                    <a href="?" class="sg-btn sg-btn--ghost">Clear</a>
                  </div>
                  <div class="sg-cluster sg-cluster--start">
                    <label class="sg-filter-chip">
                      <input type="checkbox" checked /> Active
                    </label>
                    <label class="sg-filter-chip">
                      <input type="checkbox" /> Locked
                    </label>
                  </div>
                </form>
                <div class="sg-cluster sg-cluster--start">
                  <.applied_chip label="Status: Active" remove_href="?status=" />
                  <.applied_chip label="Search: alice" remove_href="?q=" />
                  <a href="?" class="sg-btn sg-btn--ghost sg-btn--sm">Clear all filters</a>
                </div>
              </div>
              <div data-testid="mg-2-zero" class="sg-stack sg-stack--3">
                <form class="sg-filter-panel sg-stack sg-stack--3">
                  <div class="sg-search-row">
                    <label class="sg-field" for="mg2-zero-search">
                      <span class="sg-field-label">Search</span>
                      <input id="mg2-zero-search" class="sg-input" />
                    </label>
                    <button type="button" class="sg-btn sg-btn--primary">Apply filters</button>
                    <a href="?" class="sg-btn sg-btn--ghost">Clear</a>
                  </div>
                </form>
                <p class="sg-muted sg-text-sm">No applied filters.</p>
              </div>
              <div data-testid="mg-2-loading" class="sg-filter-panel sg-stack sg-stack--3" aria-busy="true">
                <.skeleton />
                <.skeleton />
              </div>
              <div data-testid="mg-2-error">
                <.notice tone={:risk}>
                  Unable to apply filters. Refresh the page, then try again.
                </.notice>
              </div>
              <div class="sg-cluster sg-cluster--start" data-testid="mg-2-coherence-a">
                <.applied_chip label="Status: Active" remove_href="?status=" />
                <.applied_chip label="MFA: Enabled" remove_href="?mfa=" />
              </div>
              <div class="sg-cluster sg-cluster--start" data-testid="mg-2-coherence-b">
                <.applied_chip label="Status: Active" remove_href="?status=" />
                <.applied_chip label="MFA: Enabled" remove_href="?mfa=" />
              </div>
            </div>
          </div>

          <%!-- board-mg-3: Task-card Grid --%>
          <section id="board-mg-3" class="sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-3 Task-card Grid</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-3-populated" class="sg-grid sg-grid--2">
                <.task_card
                  title="Review flagged accounts"
                  body="3 accounts require immediate attention."
                  href="/admin/users?flagged=true"
                  action="Review accounts"
                />
                <.task_card
                  title="Invite your team"
                  body="Add teammates so they can access the admin panel."
                  href="/admin/users/invite"
                  action="Send invitations"
                />
              </div>
              <p data-testid="mg-3-zero-note" class="sg-muted sg-text-sm">
                Zero state is not applicable because overview tasks are static capability launchers.
              </p>
              <p data-testid="mg-3-loading-note" class="sg-muted sg-text-sm">
                Loading state is not applicable because overview tasks are static capability launchers.
              </p>
              <div data-testid="mg-3-error">
                <.notice tone={:risk}>
                  Unable to load admin tasks. Refresh the page, then use the sidebar if the issue continues.
                </.notice>
              </div>
            </div>
          </section>

          <%!-- board-mg-4: Alarm Notice Band --%>
          <div id="board-mg-4" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-4 Alarm Notice Band</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-4-populated">
                <.notice tone={:risk}>
                  High login failure rate detected -
                  <.notice_link href="/admin/audit">View audit log</.notice_link>
                </.notice>
              </div>
              <div data-testid="mg-4-zero">
                <.notice tone={:ok}>All clear. No accounts need review.</.notice>
              </div>
              <div data-testid="mg-4-loading" aria-busy="true">
                <.skeleton />
              </div>
              <div data-testid="mg-4-error">
                <.notice tone={:risk}>
                  Unable to check review status. Refresh the page, then open users to inspect manually.
                </.notice>
              </div>
            </div>
          </div>
        </div>
      </section>
    </section>
    """
  end
end
