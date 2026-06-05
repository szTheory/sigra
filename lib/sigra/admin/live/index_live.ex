defmodule Sigra.Admin.Live.IndexLive do
  @moduledoc """
  Global admin orientation surface.
  """

  use Phoenix.LiveView

  import Sigra.Admin.Components

  alias Sigra.Admin.Users.Query

  @impl true
  def mount(_params, _session, socket) do
    config = runtime_config!()
    admin_scope = socket.assigns.admin_scope

    if connected?(socket) do
      {:ok,
       socket
       |> assign(:sigra_config, config)
       |> assign(:summary_counts, Query.summary_counts(config, admin_scope))
       |> assign(:loading, false)
       |> assign(:page_title, "Global overview")}
    else
      {:ok,
       socket
       |> assign(:sigra_config, config)
       |> assign(:summary_counts, %{})
       |> assign(:loading, true)
       |> assign(:page_title, "Global overview")}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :needs_review, Sigra.Admin.needs_review(assigns.summary_counts))

    ~H"""
    <section class="sg-stack sg-stack--6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Admin overview</p>
        <h1 class="sg-page-title">What do you need to do?</h1>
        <p class="sg-page-copy">
          Start from the job at hand — find a user, investigate an event, or review risky accounts.
          Posture counts below stay live: every one is an entry point into a filtered list.
        </p>
      </header>

      <%!-- Opt in to role=status because the alarm appears only after LiveView connects. --%>
      <.notice
        :if={not @loading}
        tone={if @needs_review > 0, do: :risk, else: :ok}
        role="status"
      >
        <%= if @needs_review > 0 do %>
          {@needs_review} accounts need review —
          <a href="/admin/users?needs_review=true">Review now</a>
        <% else %>
          All clear
        <% end %>
      </.notice>

      <div class="sg-grid sg-grid--3">
        <.task_card
          title="Find a user"
          body="Search by email or ID, inspect security state, revoke sessions, and start support actions."
          href="/admin/users"
          action="Find a user"
        />
        <.task_card
          title="Investigate an event"
          body="Filter security events, distinguish actor from effective user, and export CSV evidence."
          href="/admin/audit"
          action="Investigate audit"
        />
        <.task_card
          title="Review risky accounts"
          body="Jump straight to locked or deletion-scheduled accounts before they surprise support."
          href="/admin/users?needs_review=true"
          action="Review locked"
        />
      </div>

      <section
        class="sg-card sg-posture-strip sg-stack sg-stack--3"
        aria-busy={if @loading, do: "true"}
      >
        <div class="sg-cluster sg-cluster--3">
          <%= if @loading do %>
            <.skeleton class="sg-metric-link" />
            <.skeleton class="sg-metric-link" />
            <.skeleton class="sg-metric-link" />
            <.skeleton class="sg-metric-link" />
            <.skeleton class="sg-metric-link" />
            <.skeleton class="sg-metric-link" />
          <% else %>
            <.stat_link label="Total" value={Map.get(@summary_counts, :total, 0)} href="/admin/users" />
            <.stat_link
              label="Confirmed"
              value={Map.get(@summary_counts, :confirmed, 0)}
              href="/admin/users?confirmed=true"
            />
            <.stat_link
              label="MFA"
              value={Map.get(@summary_counts, :mfa, 0)}
              href="/admin/users?mfa=true"
            />
            <.stat_link
              label="Passkeys"
              value={Map.get(@summary_counts, :passkeys, 0)}
              href="/admin/users?passkeys=true"
            />
            <.stat_link
              label="Locked"
              value={Map.get(@summary_counts, :locked, 0)}
              href="/admin/users?needs_review=true"
            />
            <.stat_link
              label="Deleted"
              value={Map.get(@summary_counts, :deleted, 0)}
              href="/admin/users?deleted=true"
            />
          <% end %>
        </div>
      </section>

      <section class="sg-stack sg-stack--3">
        <div class="sg-stack sg-stack--1">
          <h2 class="sg-section-heading">What Sigra can do</h2>
          <p class="sg-section-copy">This admin console surfaces:</p>
        </div>
        <div class="sg-capability sg-grid sg-grid--3">
          <.capability label="Sessions" desc="View and revoke active sessions per user." />
          <.capability label="MFA (TOTP)" desc="See TOTP enrollment and backup-code state." />
          <.capability label="Passkeys" desc="Inspect registered WebAuthn credentials." />
          <.capability label="OAuth identities" desc="View linked social/OIDC identities." />
          <.capability label="Audit evidence" desc="Filter security events and export CSV." />
          <.capability label="Impersonation" desc="Start scoped sudo sessions with an audit trail." />
          <.capability label="Organization scoping" desc="Operate bounded to a single tenant." />
        </div>
      </section>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :desc, :string, required: true

  defp capability(assigns) do
    ~H"""
    <div class="sg-capability__item">
      <span class="sg-capability__label">{@label}</span>
      <span class="sg-capability__desc">{@desc}</span>
    </div>
    """
  end

  defp runtime_config! do
    Sigra.Admin.runtime_config!("Sigra admin overview")
  end
end
