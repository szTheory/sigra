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
              <.notice tone={:info}>
                Impersonation session active. End it before navigating away.
              </.notice>
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
              <.audit_row row={
                %{
                  id: "uuid-1234",
                  inserted_at: ~N[2026-01-15 10:30:00],
                  action: "auth.login.success",
                  action_label: "Login succeeded",
                  action_badge: nil,
                  actor_label: "alice@example.test",
                  effective_user_label: "alice@example.test",
                  actor_summary: "alice@example.test",
                  outcome: "success"
                }
              } />

              <span class="sg-muted sg-text-xs">info full with codes</span>
              <.audit_row
                row={
                  %{
                    id: "uuid-5678",
                    inserted_at: ~N[2026-01-15 11:00:00],
                    action: "admin.impersonation.start",
                    action_label: "Impersonation started",
                    action_badge: "Impersonation",
                    actor_label: "admin@example.test",
                    effective_user_label: "alice@example.test",
                    actor_summary: "admin@example.test acting as alice@example.test",
                    outcome: "success"
                  }
                }
                show_detail
                show_codes
              />

              <span class="sg-muted sg-text-xs">risk failure</span>
              <.audit_row row={
                %{
                  id: "uuid-9999",
                  inserted_at: ~N[2026-01-15 09:00:00],
                  action: "auth.login.failure",
                  action_label: "Login failed",
                  action_badge: nil,
                  actor_label: "unknown@example.test",
                  effective_user_label: "unknown@example.test",
                  actor_summary: "unknown@example.test",
                  outcome: "failure"
                }
              } />
            </div>
          </div>
        </div>
      </section>

      <section class="sg-stack sg-stack--4">
        <h2 class="sg-section-heading">Component Groups</h2>
        <div class="sg-stack sg-stack--6">
          <%!-- board-mg-1: Metric / Summary Strip --%>
          <%!-- Mirrors the slim 3-chip User health metric strip (Plan 201: Total + Locked + Deletion scheduled). --%>
          <div id="board-mg-1" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-1 Metric / Summary Strip</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-1-populated" class="sg-stack sg-stack--2">
                <p class="sg-muted sg-text-xs">populated</p>
                <dl class="sg-metric-grid">
                  <.summary_chip label="Total users" value={3_842} />
                  <.summary_chip label="Locked users" value={7} tone="risk" />
                  <.summary_chip label="Deletion scheduled" value={3} tone="warn" />
                </dl>
              </div>
              <div data-testid="mg-1-zero" class="sg-stack sg-stack--2">
                <p class="sg-muted sg-text-xs">zero</p>
                <dl class="sg-metric-grid">
                  <.summary_chip label="Total users" value={0} />
                  <.summary_chip label="Locked users" value={0} />
                  <.summary_chip label="Deletion scheduled" value={0} />
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
          <%!-- Applied chips sit contiguous with the filter panel (inside the form), per Plan 201 D-01. --%>
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
                    <button type="button" class="sg-btn sg-btn--primary">Search</button>
                    <a href="?" class="sg-btn sg-btn--ghost">Clear</a>
                  </div>
                  <div class="sg-cluster sg-cluster--start">
                    <.applied_chip label="Status: Active" remove_href="?status=" />
                    <.applied_chip label="Search: alice" remove_href="?q=" />
                    <a href="?" class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
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
              <div
                data-testid="mg-2-loading"
                class="sg-filter-panel sg-stack sg-stack--3"
                aria-busy="true"
              >
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

          <%!-- board-mg-5: User Results + Pagination --%>
          <section id="board-mg-5" class="sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-5 User Results + Pagination</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-5-populated" class="sg-stack sg-stack--3">
                <div data-testid="mg-5-desktop-results" class="sg-table-panel sg-show-desktop">
                  <table class="sg-table">
                    <thead>
                      <tr>
                        <th>User</th>
                        <th>Status</th>
                        <th>Organizations</th>
                        <th>Activity</th>
                        <th class="sg-cell-right">Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>
                          <div class="sg-stack sg-stack--1">
                            <span class="sg-strong">Alice Admin</span>
                            <span class="sg-muted sg-text-sm sg-truncate" title="alice@example.test">
                              alice@example.test
                            </span>
                            <code class="sg-code">user_188_alice</code>
                          </div>
                        </td>
                        <td>
                          <%!-- Secured row: no pills (absence of Unconfirmed/No MFA/Locked/Deletion means healthy). --%>
                          <div class="sg-cluster sg-cluster--2"></div>
                        </td>
                        <td>
                          <div class="sg-stack sg-stack--1 sg-text-sm">
                            <span>Rail Ops</span>
                            <span class="sg-muted">2 organizations</span>
                          </div>
                        </td>
                        <td>
                          <div class="sg-stack sg-stack--1 sg-text-sm">
                            <span>Seen today</span>
                            <span class="sg-muted">Registered 2026-01-02</span>
                          </div>
                        </td>
                        <td class="sg-cell-right">
                          <a
                            class="sg-btn sg-btn--secondary sg-btn--sm"
                            href="/admin/users/user_188_alice"
                          >
                            Open user
                          </a>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <div class="sg-stack sg-stack--1">
                            <span class="sg-strong">Bob User</span>
                            <span class="sg-muted sg-text-sm sg-truncate" title="bob@example.test">
                              bob@example.test
                            </span>
                            <code class="sg-code">user_188_bob</code>
                          </div>
                        </td>
                        <td>
                          <%!-- Unsecured row: No MFA (warn). --%>
                          <div class="sg-cluster sg-cluster--2">
                            <span class="sg-status-pill" data-tone="warn">No MFA</span>
                          </div>
                        </td>
                        <td>
                          <div class="sg-stack sg-stack--1 sg-text-sm">
                            <span class="sg-muted">1 organization</span>
                          </div>
                        </td>
                        <td>
                          <div class="sg-stack sg-stack--1 sg-text-sm">
                            <span>Seen this week</span>
                            <span class="sg-muted">Registered 2026-02-14</span>
                          </div>
                        </td>
                        <td class="sg-cell-right">
                          <a
                            class="sg-btn sg-btn--secondary sg-btn--sm"
                            href="/admin/users/user_188_bob"
                          >
                            Open user
                          </a>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <div data-testid="mg-5-mobile-results" class="sg-stack sg-stack--3 sg-show-mobile">
                  <article class="sg-card sg-stack sg-stack--3">
                    <div class="sg-stack sg-stack--1">
                      <span class="sg-strong">Alice Admin</span>
                      <span class="sg-muted sg-text-sm sg-truncate" title="alice@example.test">
                        alice@example.test
                      </span>
                      <code class="sg-code">user_188_alice</code>
                    </div>
                    <%!-- Secured row: no pills. --%>
                    <div class="sg-cluster sg-cluster--2"></div>
                    <dl class="sg-kv">
                      <div>
                        <dt class="sg-meta-label">Organizations</dt>
                        <dd class="sg-meta-value">Rail Ops</dd>
                        <dd class="sg-muted sg-text-sm">2 organizations</dd>
                      </div>
                      <div>
                        <dt class="sg-meta-label">Activity</dt>
                        <dd class="sg-meta-value">Seen today</dd>
                      </div>
                      <div>
                        <dt class="sg-meta-label">Registered</dt>
                        <dd class="sg-meta-value">2026-01-02</dd>
                      </div>
                    </dl>
                    <a
                      class="sg-btn sg-btn--secondary sg-btn--block"
                      href="/admin/users/user_188_alice"
                    >
                      Open user
                    </a>
                  </article>
                  <article class="sg-card sg-stack sg-stack--3">
                    <div class="sg-stack sg-stack--1">
                      <span class="sg-strong">Bob User</span>
                      <span class="sg-muted sg-text-sm sg-truncate" title="bob@example.test">
                        bob@example.test
                      </span>
                      <code class="sg-code">user_188_bob</code>
                    </div>
                    <%!-- Unsecured row: No MFA (warn). --%>
                    <div class="sg-cluster sg-cluster--2">
                      <span class="sg-status-pill" data-tone="warn">No MFA</span>
                    </div>
                    <dl class="sg-kv">
                      <div>
                        <dt class="sg-meta-label">Organizations</dt>
                        <dd class="sg-meta-value sg-muted sg-text-sm">1 organization</dd>
                      </div>
                      <div>
                        <dt class="sg-meta-label">Activity</dt>
                        <dd class="sg-meta-value">Seen this week</dd>
                      </div>
                      <div>
                        <dt class="sg-meta-label">Registered</dt>
                        <dd class="sg-meta-value">2026-02-14</dd>
                      </div>
                    </dl>
                    <a
                      class="sg-btn sg-btn--secondary sg-btn--block"
                      href="/admin/users/user_188_bob"
                    >
                      Open user
                    </a>
                  </article>
                </div>
                <nav class="sg-cluster sg-cluster--between" aria-label="User results pagination">
                  <a
                    class="sg-btn sg-btn--secondary sg-btn--icon is-disabled"
                    aria-disabled="true"
                    aria-label="Previous page"
                  >
                    <span aria-hidden="true">&larr;</span>
                    <span class="sr-only">Previous page</span>
                  </a>
                  <span class="sg-muted sg-text-sm sg-tabular">Showing 1-1 of 1 users</span>
                  <a class="sg-btn sg-btn--secondary sg-btn--icon" href="#" aria-label="Next page">
                    <span aria-hidden="true">&rarr;</span>
                    <span class="sr-only">Next page</span>
                  </a>
                </nav>
              </div>
              <div data-testid="mg-5-zero">
                <.empty_state title="No users match this view">
                  <p class="sg-muted sg-text-sm">
                    Clear one or more filters to widen the result set.
                  </p>
                </.empty_state>
              </div>
              <div data-testid="mg-5-loading" class="sg-stack sg-stack--3" aria-busy="true">
                <.skeleton />
                <.skeleton />
                <.skeleton />
              </div>
              <div data-testid="mg-5-error">
                <.notice tone={:risk}>
                  Unable to load users. Refresh the page, then try again.
                </.notice>
              </div>
            </div>
          </section>

          <%!-- board-mg-6: Audit Feed + Pagination --%>
          <div id="board-mg-6" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-6 Audit Feed + Pagination</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-6-populated" class="sg-stack sg-stack--3">
                <div data-testid="mg-6-desktop-results" class="sg-table-panel sg-show-desktop">
                  <table class="sg-table">
                    <thead>
                      <tr>
                        <th>Occurred</th>
                        <th>Event</th>
                        <th>Actor</th>
                        <th>Outcome</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr data-tone="info">
                        <td>
                          <span class="sg-text-sm">2026-01-15 14:00</span>
                          <code class="sg-code">evt_188_login</code>
                        </td>
                        <td>
                          <span class="sg-status-pill" data-tone="info">Impersonation</span>
                          <code class="sg-code">admin.impersonation.start</code>
                        </td>
                        <td>
                          <span>admin@example.test acting as alice@example.test</span>
                          <span class="sg-muted sg-text-sm">Actor: admin@example.test</span>
                          <span class="sg-muted sg-text-sm">Effective user: alice@example.test</span>
                        </td>
                        <td><span class="sg-muted">success</span></td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <div data-testid="mg-6-mobile-results" class="sg-stack sg-stack--3 sg-show-mobile">
                  <.audit_row
                    row={
                      %{
                        id: "evt_188_login",
                        inserted_at: ~N[2026-01-15 14:00:00],
                        action: "admin.impersonation.start",
                        action_label: "Impersonation",
                        action_badge: "Impersonation",
                        actor_label: "admin@example.test",
                        effective_user_label: "alice@example.test",
                        actor_summary: "admin@example.test acting as alice@example.test",
                        outcome: "success"
                      }
                    }
                    show_detail
                    show_codes
                  />
                </div>
                <nav class="sg-cluster sg-cluster--between" aria-label="Audit feed pagination">
                  <a
                    class="sg-btn sg-btn--secondary sg-btn--icon is-disabled"
                    aria-disabled="true"
                    aria-label="Previous page"
                  >
                    <span aria-hidden="true">&larr;</span>
                    <span class="sr-only">Previous page</span>
                  </a>
                  <span class="sg-muted sg-text-sm">Page 1</span>
                  <a class="sg-btn sg-btn--secondary sg-btn--icon" href="#" aria-label="Next page">
                    <span aria-hidden="true">&rarr;</span>
                    <span class="sr-only">Next page</span>
                  </a>
                  <a class="sg-btn sg-btn--secondary sg-btn--sm" href="/admin/audit/export.csv">
                    Export CSV
                  </a>
                </nav>
              </div>
              <div data-testid="mg-6-zero">
                <.empty_state title="No audit events match this view">
                  <p class="sg-muted sg-text-sm">Clear one or more filters to widen the timeline.</p>
                </.empty_state>
              </div>
              <div data-testid="mg-6-loading" class="sg-list" aria-busy="true">
                <.skeleton class="sg-list-row" />
                <.skeleton class="sg-list-row" />
              </div>
              <div data-testid="mg-6-error">
                <.notice tone={:risk}>
                  Unable to load audit events. Refresh the page, then try again.
                </.notice>
              </div>
              <div data-testid="mg-6-coherence-a" class="sg-list">
                <.audit_row
                  row={
                    %{
                      id: "evt_188_login",
                      inserted_at: ~N[2026-01-15 14:00:00],
                      action: "admin.impersonation.start",
                      action_label: "Impersonation",
                      action_badge: "Impersonation",
                      actor_label: "admin@example.test",
                      effective_user_label: "alice@example.test",
                      actor_summary: "admin@example.test acting as alice@example.test",
                      outcome: "success"
                    }
                  }
                  show_detail
                  show_codes
                />
              </div>
              <div data-testid="mg-6-coherence-b" class="sg-list">
                <.audit_row
                  row={
                    %{
                      id: "evt_188_login",
                      inserted_at: ~N[2026-01-15 14:00:00],
                      action: "admin.impersonation.start",
                      action_label: "Impersonation",
                      action_badge: "Impersonation",
                      actor_label: "admin@example.test",
                      effective_user_label: "alice@example.test",
                      actor_summary: "admin@example.test acting as alice@example.test",
                      outcome: "success"
                    }
                  }
                  show_detail
                  show_codes
                />
              </div>
            </div>
          </div>

          <%!-- board-mg-7: Organization Member Roster --%>
          <div id="board-mg-7" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-7 Organization Member Roster</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-7-populated" class="sg-list">
                <article class="sg-list-row sg-stack sg-stack--2">
                  <div class="sg-cluster sg-cluster--between">
                    <span class="sg-strong">alice@example.test</span>
                    <span class="sg-status-pill" data-tone="info">Owner</span>
                  </div>
                  <span class="sg-muted sg-text-sm">Joined 2026-01-02</span>
                </article>
              </div>
              <div data-testid="mg-7-zero">
                <.empty_state title="No members yet">
                  <p class="sg-muted sg-text-sm">Invite a teammate to start this organization.</p>
                </.empty_state>
              </div>
              <div data-testid="mg-7-loading" class="sg-list" aria-busy="true">
                <.skeleton class="sg-list-row" />
                <.skeleton class="sg-list-row" />
              </div>
              <div data-testid="mg-7-error">
                <.notice tone={:risk}>
                  Unable to load members. Refresh the page, then check the organization scope.
                </.notice>
              </div>
            </div>
          </div>

          <%!-- board-mg-8: Pending Invitations --%>
          <div id="board-mg-8" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-8 Pending Invitations</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-8-populated" class="sg-list">
                <article class="sg-list-row sg-stack sg-stack--2" data-tone="warn">
                  <div class="sg-cluster sg-cluster--between">
                    <span class="sg-strong">new.admin@example.test</span>
                    <span class="sg-status-pill" data-tone="warn">Pending</span>
                  </div>
                  <span class="sg-muted sg-text-sm">Invited 2026-01-12</span>
                </article>
              </div>
              <div data-testid="mg-8-zero">
                <.empty_state title="No pending invitations.">
                  <p class="sg-muted sg-text-sm">
                    Invitations appear here until accepted or expired.
                  </p>
                </.empty_state>
              </div>
              <div data-testid="mg-8-loading" class="sg-list" aria-busy="true">
                <.skeleton class="sg-list-row" />
                <.skeleton class="sg-list-row" />
              </div>
              <div data-testid="mg-8-error">
                <.notice tone={:risk}>
                  Unable to load pending invitations. Refresh the page, then check invitation settings.
                </.notice>
              </div>
            </div>
          </div>

          <%!-- board-mg-9: Identity Header + Summary Facts --%>
          <div id="board-mg-9" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-9 Identity Header + Summary Facts</p>
            <div class="sg-stack sg-stack--3">
              <header data-testid="mg-9-populated" class="sg-page-header">
                <p class="sg-page-kicker">Identity &amp; Status</p>
                <h3 class="sg-page-title">Alice Admin</h3>
                <span class="sg-muted sg-text-sm">alice@example.test</span>
                <code class="sg-code">user_188_alice</code>
                <div class="sg-cluster sg-cluster--2">
                  <span class="sg-status-pill" data-tone="ok">Active</span>
                  <span class="sg-status-pill" data-tone="info">MFA enabled</span>
                </div>
                <dl class="sg-summary-facts">
                  <div>
                    <dt class="sg-kv__term">MFA</dt>
                    <dd class="sg-kv__value">Enabled</dd>
                  </div>
                  <div>
                    <dt class="sg-kv__term">Passkeys</dt>
                    <dd class="sg-kv__value sg-summary-facts__num">2</dd>
                  </div>
                  <div>
                    <dt class="sg-kv__term">Active</dt>
                    <dd class="sg-kv__value sg-summary-facts__num">1</dd>
                  </div>
                </dl>
              </header>
              <div data-testid="mg-9-zero">
                <p class="sg-muted sg-text-sm">
                  Optional identity fields collapse without blank labels.
                </p>
              </div>
              <div data-testid="mg-9-loading" class="sg-stack sg-stack--2" aria-busy="true">
                <.skeleton />
                <.skeleton />
              </div>
              <div data-testid="mg-9-error">
                <.notice tone={:risk}>
                  Unable to load user identity. Return to users, then open the account again.
                </.notice>
              </div>
            </div>
          </div>

          <%!-- board-mg-10: Detail Facts + Membership Panels --%>
          <div id="board-mg-10" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-10 Detail Facts + Membership Panels</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-10-populated" class="sg-detail-grid">
                <section class="sg-detail-panel sg-stack sg-stack--3">
                  <h3 class="sg-section-heading">Security</h3>
                  <dl class="sg-kv">
                    <div>
                      <dt class="sg-kv__term">MFA</dt>
                      <dd class="sg-kv__value">Enabled</dd>
                    </div>
                    <div>
                      <dt class="sg-kv__term">Passkeys</dt>
                      <dd class="sg-kv__value">2 passkeys</dd>
                    </div>
                  </dl>
                </section>
                <section class="sg-detail-panel sg-stack sg-stack--3">
                  <h3 class="sg-section-heading">Recent Audit</h3>
                  <.audit_row row={
                    %{
                      id: "evt_188_login",
                      inserted_at: ~N[2026-01-15 14:00:00],
                      action: "auth.login.success",
                      action_label: "Login",
                      action_badge: nil,
                      actor_label: "alice@example.test",
                      effective_user_label: "alice@example.test",
                      actor_summary: "alice@example.test",
                      outcome: "success"
                    }
                  } />
                </section>
              </div>
              <div data-testid="mg-10-zero">
                <.empty_state title="No linked identities">
                  <p class="sg-muted sg-text-sm">
                    This user signs in without a visible external identity provider.
                  </p>
                </.empty_state>
              </div>
              <div data-testid="mg-10-loading" class="sg-detail-grid" aria-busy="true">
                <.skeleton class="sg-detail-panel" />
                <.skeleton class="sg-detail-panel" />
              </div>
              <div data-testid="mg-10-error">
                <.notice tone={:risk}>
                  Unable to load detail panels. Refresh the page, then check user detail logs.
                </.notice>
              </div>
            </div>
          </div>

          <%!-- board-mg-11: Destructive Action + Confirmation --%>
          <div id="board-mg-11" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-11 Destructive Action + Confirmation</p>
            <div class="sg-stack sg-stack--3">
              <div data-testid="mg-11-populated" class="sg-danger-panel sg-stack sg-stack--3">
                <h3 class="sg-section-heading">Danger Zone</h3>
                <p class="sg-muted sg-text-sm">
                  Session revocation signs users out of active browsers.
                </p>
                <button type="button" class="sg-btn sg-btn--danger sg-btn--sm">
                  Revoke all sessions
                </button>
              </div>
              <div data-testid="mg-11-zero">
                <p class="sg-muted sg-text-sm">Dangerous actions are hidden when unavailable.</p>
              </div>
              <div
                data-testid="mg-11-loading"
                class="sg-danger-panel sg-stack sg-stack--2"
                aria-busy="true"
              >
                <.skeleton />
                <.skeleton />
              </div>
              <div data-testid="mg-11-error">
                <.notice tone={:risk}>
                  Unable to revoke sessions. Refresh the page, then try again.
                </.notice>
              </div>
              <div
                class="sg-confirm-overlay"
                role="presentation"
                data-testid="mg-11-coherence-a"
                style="position: relative; inset: auto;"
              >
                <section
                  class="sg-confirm-dialog"
                  role="dialog"
                  aria-modal="true"
                  aria-labelledby="mg-11-confirm-title-a"
                >
                  <p id="mg-11-confirm-title-a" class="sg-section-heading">Revoke all sessions?</p>
                  <p class="sg-text-sm">
                    Revoke every active session for alice@example.test? This signs them out everywhere.
                  </p>
                  <div class="sg-confirm-dialog__actions">
                    <button type="button" class="sg-btn sg-btn--ghost sg-btn--sm">
                      Keep sessions
                    </button>
                    <button type="button" class="sg-btn sg-btn--danger sg-btn--sm">
                      Revoke all sessions
                    </button>
                  </div>
                </section>
              </div>
              <div
                class="sg-confirm-overlay"
                role="presentation"
                data-testid="mg-11-coherence-b"
                style="position: relative; inset: auto;"
              >
                <section
                  class="sg-confirm-dialog"
                  role="dialog"
                  aria-modal="true"
                  aria-labelledby="mg-11-confirm-title-b"
                >
                  <p id="mg-11-confirm-title-b" class="sg-section-heading">Revoke all sessions?</p>
                  <p class="sg-text-sm">
                    Revoke every active session for alice@example.test? This signs them out everywhere.
                  </p>
                  <div class="sg-confirm-dialog__actions">
                    <button type="button" class="sg-btn sg-btn--ghost sg-btn--sm">
                      Keep sessions
                    </button>
                    <button type="button" class="sg-btn sg-btn--danger sg-btn--sm">
                      Revoke all sessions
                    </button>
                  </div>
                </section>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- ================================================================
           Page Composites — board-cfg-* (D-08, D-09)
           Each composite mirrors a full admin page archetype in its loaded
           (populated) state. All assigns are static literals — no DB, no
           Repo, no Ecto.Query imports.
           ================================================================ --%>
      <section class="sg-stack sg-stack--4">
        <h2 class="sg-section-heading">Page Composites</h2>
        <div class="sg-stack sg-stack--6">

          <%!-- board-cfg-overview — Overview archetype; see index_live.ex + admin-design-contract.md Overview Archetype --%>
          <section id="board-cfg-overview" class="sg-stack sg-stack--4">
            <header class="sg-page-header">
              <p class="sg-page-kicker">Platform admin</p>
              <h1 class="sg-page-title">Overview</h1>
              <p class="sg-page-copy">
                Monitor platform health and respond to alerts before they escalate.
              </p>
            </header>
            <.notice tone={:risk}>
              2 accounts locked —
              <.notice_link href="/admin/users?locked=true">Review accounts</.notice_link>
            </.notice>
            <div class="sg-grid sg-grid--3">
              <.task_card
                title="Manage users"
                body="Review accounts, unlock users, and manage access."
                href="/admin/users"
                action="Open users"
              />
              <.task_card
                title="Review audit trail"
                body="Inspect recent activity and investigate anomalies."
                href="/admin/audit"
                action="Open audit"
              />
              <.task_card
                title="Manage organizations"
                body="Add, remove, or reconfigure organization memberships."
                href="/admin/organizations"
                action="Open organizations"
              />
            </div>
          </section>

          <%!-- board-cfg-users-list — List archetype; see users_index_live.ex + admin-design-contract.md List Archetype --%>
          <section id="board-cfg-users-list" class="sg-stack sg-stack--4">
            <header class="sg-page-header">
              <p class="sg-page-kicker">User operations</p>
              <h1 class="sg-page-title">Users</h1>
            </header>
            <.scope_ribbon copy="Viewing all organizations" />
            <section class="sg-stack sg-stack--4">
              <h2 class="sg-section-heading">Find users</h2>
              <form class="sg-filter-panel sg-stack sg-stack--3">
                <div class="sg-search-row">
                  <label class="sg-field" for="cfg-users-search">
                    <span class="sg-field-label">Search</span>
                    <input id="cfg-users-search" class="sg-input" value="" placeholder="Email, user id, or name" />
                  </label>
                  <button type="button" class="sg-btn sg-btn--primary">Search</button>
                  <a href="?" class="sg-btn sg-btn--ghost">Clear</a>
                </div>
                <div class="sg-cluster sg-cluster--start">
                  <.applied_chip label="Status: Locked" remove_href="?status=" />
                  <a href="?" class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
                </div>
              </form>
            </section>
            <section class="sg-stack sg-stack--3">
              <h2 class="sg-section-heading">User health</h2>
              <dl class="sg-metric-grid">
                <.summary_chip label="Total users" value={46} />
                <.summary_chip label="Locked" value={2} tone="risk" />
                <.summary_chip label="Deletion scheduled" value={1} tone="warn" />
              </dl>
            </section>
          </section>

          <%!-- board-cfg-user-detail — Detail archetype; see user_show_live.ex + admin-design-contract.md Detail Archetype --%>
          <section id="board-cfg-user-detail" class="sg-stack sg-stack--4">
            <header class="sg-page-header">
              <p class="sg-page-kicker">User detail</p>
              <h1 class="sg-page-title">alice@demo.tasklane.test</h1>
            </header>
            <.scope_ribbon copy="Platform admin" />
            <.page_back return_to="/admin/users" label="Back to users" />
            <article class="sg-stack sg-stack--3">
              <h2 class="sg-section-heading">Identity</h2>
              <div class="sg-stack sg-stack--2">
                <span class="sg-strong">Alice Admin</span>
                <code class="sg-code">alice@demo.tasklane.test</code>
                <div class="sg-cluster sg-cluster--2">
                  <span class="sg-status-pill" data-tone="info">MFA enabled</span>
                </div>
              </div>
            </article>
            <article class="sg-stack sg-stack--3">
              <h2 class="sg-section-heading">Sessions</h2>
              <div class="sg-list">
                <article class="sg-list-row sg-stack sg-stack--2">
                  <div class="sg-cluster sg-cluster--between">
                    <span class="sg-strong">Chrome on macOS</span>
                    <span class="sg-status-pill" data-tone="ok">Current</span>
                  </div>
                  <span class="sg-muted sg-text-sm">Last seen today</span>
                </article>
              </div>
            </article>
            <article class="sg-stack sg-stack--3">
              <h2 class="sg-section-heading">MFA credentials</h2>
              <.empty_state title="No MFA credentials">
                <p class="sg-muted sg-text-sm">This user has not enrolled any MFA methods.</p>
              </.empty_state>
            </article>
          </section>

          <%!-- board-cfg-audit — Audit archetype; see audit_index_live.ex + admin-design-contract.md --%>
          <section id="board-cfg-audit" class="sg-stack sg-stack--4">
            <header class="sg-page-header">
              <p class="sg-page-kicker">Audit</p>
              <h1 class="sg-page-title">Audit events</h1>
            </header>
            <section class="sg-stack sg-stack--4">
              <form class="sg-filter-panel sg-stack sg-stack--3">
                <div class="sg-cluster sg-cluster--start">
                  <label class="sg-field" for="cfg-audit-from">
                    <span class="sg-field-label">From</span>
                    <input id="cfg-audit-from" class="sg-input" type="date" value="2026-01-01" />
                  </label>
                  <label class="sg-field" for="cfg-audit-to">
                    <span class="sg-field-label">To</span>
                    <input id="cfg-audit-to" class="sg-input" type="date" value="2026-01-31" />
                  </label>
                  <button type="button" class="sg-btn sg-btn--primary">Apply</button>
                  <a href="?" class="sg-btn sg-btn--ghost">Clear</a>
                </div>
                <div class="sg-cluster sg-cluster--start">
                  <.applied_chip label="Action: login" remove_href="?action=" />
                  <a href="?" class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
                </div>
              </form>
            </section>
            <div data-testid="cfg-audit-desktop-results" class="sg-table-panel sg-show-desktop">
              <table class="sg-table">
                <thead>
                  <tr>
                    <th>Event</th>
                    <th>Actor</th>
                    <th>Target</th>
                    <th>Occurred at</th>
                  </tr>
                </thead>
                <tbody>
                  <.audit_table_row row={
                    %{
                      id: "evt-cfg-01",
                      inserted_at: ~N[2026-01-15 10:30:00],
                      action: "auth.login.success",
                      action_label: "Login succeeded",
                      action_badge: nil,
                      actor_label: "alice@demo.tasklane.test",
                      effective_user_label: "alice@demo.tasklane.test",
                      actor_summary: "alice@demo.tasklane.test",
                      outcome: "success"
                    }
                  } />
                  <.audit_table_row row={
                    %{
                      id: "evt-cfg-02",
                      inserted_at: ~N[2026-01-15 09:00:00],
                      action: "auth.login.failure",
                      action_label: "Login failed",
                      action_badge: nil,
                      actor_label: "unknown@example.com",
                      effective_user_label: "unknown@example.com",
                      actor_summary: "unknown@example.com",
                      outcome: "failure"
                    }
                  } />
                </tbody>
              </table>
            </div>
            <div data-testid="cfg-audit-mobile-results" class="sg-stack sg-stack--3 sg-show-mobile">
              <.audit_row
                row={
                  %{
                    id: "evt-cfg-01",
                    inserted_at: ~N[2026-01-15 10:30:00],
                    action: "auth.login.success",
                    action_label: "Login succeeded",
                    action_badge: nil,
                    actor_label: "alice@demo.tasklane.test",
                    effective_user_label: "alice@demo.tasklane.test",
                    actor_summary: "alice@demo.tasklane.test",
                    outcome: "success"
                  }
                }
                show_detail
                show_codes
              />
              <.audit_row
                row={
                  %{
                    id: "evt-cfg-02",
                    inserted_at: ~N[2026-01-15 09:00:00],
                    action: "auth.login.failure",
                    action_label: "Login failed",
                    action_badge: nil,
                    actor_label: "unknown@example.com",
                    effective_user_label: "unknown@example.com",
                    actor_summary: "unknown@example.com",
                    outcome: "failure"
                  }
                }
                show_detail
                show_codes
              />
            </div>
          </section>

        </div>
      </section>
    </section>
    """
  end
end
