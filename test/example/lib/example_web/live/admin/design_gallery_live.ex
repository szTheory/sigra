defmodule ExampleWeb.Admin.DesignGalleryLive do
  @moduledoc """
  Example-only design gallery for /admin/_design.

  Renders all 13 Sigra.Admin.Components + meta-component groups (MG-1..MG-5)
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
              <.stat_link href="/admin/users" label="Total Users" value={3_842} />
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
            </div>
          </div>

          <%!-- board-summary_chip --%>
          <div id="board-summary_chip" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">summary_chip</p>
            <div class="sg-stack sg-stack--3">
              <%!-- summary_chip emits bare <dt>/<dd> with no <dl> of its own,
                   so each board variant is wrapped in <dl class="sg-metric-grid">
                   exactly as the real admin does (a11y dlitem rule). --%>
              <span class="sg-muted sg-text-xs">basic</span>
              <dl class="sg-metric-grid">
                <.summary_chip label="Sessions" value={12} />
              </dl>

              <span class="sg-muted sg-text-xs">enhanced: icon, value_unit, subvalue, help, tone: risk</span>
              <dl class="sg-metric-grid">
                <.summary_chip
                  label="Failed Logins"
                  value={7}
                  icon="shield-check"
                  value_unit="today"
                  subvalue="Spike detected"
                  help="Logins that failed authentication."
                  tone="risk"
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
            </div>
          </div>

          <%!-- board-applied_chip --%>
          <div id="board-applied_chip" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">applied_chip</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.applied_chip label="Status: Active" remove_href="?status=" />
            </div>
          </div>

          <%!-- board-empty_state --%>
          <div id="board-empty_state" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">empty_state</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.empty_state title="No users found">
                <p>Adjust your filters.</p>
              </.empty_state>
            </div>
          </div>

          <%!-- board-page_back --%>
          <div id="board-page_back" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">page_back</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default</span>
              <.page_back return_to="/admin" label="Dashboard" />
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

          <%!-- board-field_help --%>
          <div id="board-field_help" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">field_help</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">default (panel hidden)</span>
              <.field_help id="fh-example" label="API Token">
                Token generated at account creation.
              </.field_help>
            </div>
          </div>

          <%!-- board-skeleton --%>
          <div id="board-skeleton" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">skeleton</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">loading placeholder</span>
              <.skeleton class="sg-w-48 sg-h-4" />
            </div>
          </div>

          <%!-- board-audit_row --%>
          <div id="board-audit_row" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">audit_row</p>
            <div class="sg-stack sg-stack--3">
              <span class="sg-muted sg-text-xs">show_detail: false (compact)</span>
              <.audit_row row={%{
                id: "uuid-1234",
                inserted_at: ~N[2026-01-15 10:30:00],
                action: "auth.login.success",
                action_label: "Login",
                action_badge: nil,
                actor_label: "alice@example.test",
                effective_user_label: "alice@example.test",
                actor_summary: "alice@example.test",
                outcome: "success"
              }} />

              <span class="sg-muted sg-text-xs">show_detail: true, show_codes: true (action_badge: info)</span>
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

              <span class="sg-muted sg-text-xs">tone: risk (non-success outcome)</span>
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
            <dl class="sg-metric-grid">
              <.summary_chip label="Total Users" value={3_842} />
              <.summary_chip label="Active Sessions" value={127} />
              <.summary_chip label="Failed Logins" value={7} tone="risk" />
              <.summary_chip label="MFA Enabled" value={94} tone="ok" />
            </dl>
          </div>

          <%!-- board-mg-2: Filter Panel + Applied-chip Row --%>
          <div id="board-mg-2" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-2 Filter Panel + Applied-chip Row</p>
            <div class="sg-stack sg-stack--3">
              <form class="sg-stack sg-stack--2">
                <label class="sg-label" for="mg2-status">Status</label>
                <select id="mg2-status" class="sg-select" name="status">
                  <option value="">All</option>
                  <option value="active" selected>Active</option>
                  <option value="suspended">Suspended</option>
                </select>
              </form>
              <div class="sg-cluster sg-cluster--start">
                <.applied_chip label="Status: Active" remove_href="?status=" />
                <.applied_chip label="MFA: Enabled" remove_href="?mfa=" />
                <a href="?" class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
              </div>
            </div>
          </div>

          <%!-- board-mg-3: Task-card Grid --%>
          <div id="board-mg-3" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-3 Task-card Grid</p>
            <div class="sg-grid sg-grid--2">
              <.task_card
                title="Review flagged accounts"
                body="3 accounts require immediate attention."
                href="/admin/users?flagged=true"
                action="Review"
              />
              <.task_card
                title="Invite your team"
                body="Add teammates so they can access the admin panel."
                href="/admin/users/invite"
                action="Send invitations"
              />
            </div>
          </div>

          <%!-- board-mg-4: Alarm Notice Band --%>
          <div id="board-mg-4" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-4 Alarm Notice Band</p>
            <div class="sg-stack sg-stack--3">
              <.notice tone={:risk}>
                High login failure rate detected — <.notice_link href="/admin/audit">View audit log</.notice_link>
              </.notice>
              <.notice tone={:ok}>
                All scheduled maintenance tasks completed successfully.
              </.notice>
            </div>
          </div>

          <%!-- board-mg-5: Audit Feed + Pagination --%>
          <div id="board-mg-5" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">MG-5 Audit Feed + Pagination</p>
            <div class="sg-stack sg-stack--3">
              <%!-- Desktop table header --%>
              <div class="sg-table-header sg-hidden-mobile">
                <span>Event</span>
                <span>Actor</span>
                <span>Time</span>
              </div>
              <%!-- Audit rows --%>
              <.audit_row row={%{
                id: "uuid-aaaa",
                inserted_at: ~N[2026-01-15 14:00:00],
                action: "auth.login.success",
                action_label: "Login",
                action_badge: nil,
                actor_label: "alice@example.test",
                effective_user_label: "alice@example.test",
                actor_summary: "alice@example.test",
                outcome: "success"
              }} />
              <.audit_row row={%{
                id: "uuid-bbbb",
                inserted_at: ~N[2026-01-15 13:45:00],
                action: "auth.login.failure",
                action_label: "Login failed",
                action_badge: nil,
                actor_label: "bob@example.test",
                effective_user_label: "bob@example.test",
                actor_summary: "bob@example.test",
                outcome: "failure"
              }} />
              <%!-- Pagination --%>
              <nav class="sg-pagination" aria-label="Audit feed pagination">
                <a href="#" class="sg-btn sg-btn--ghost sg-btn--sm" aria-label="Previous page">
                  &larr; Previous
                </a>
                <a href="#" class="sg-btn sg-btn--ghost sg-btn--sm" aria-label="Next page">
                  Next &rarr;
                </a>
              </nav>
            </div>
          </div>
        </div>
      </section>
    </section>
    """
  end
end
