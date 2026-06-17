defmodule Sigra.Admin.Live.OrganizationLive do
  @moduledoc """
  Organization-scoped admin orientation surface.
  """

  use Phoenix.LiveView

  import Sigra.Admin.Components

  alias Sigra.Admin.Organizations.Detail
  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Query

  @impl true
  def mount(_params, _session, socket) do
    config = runtime_config!()
    admin_scope = socket.assigns.admin_scope
    organization_name = organization_name(admin_scope)

    socket =
      socket
      |> assign(:sigra_config, config)
      |> assign(:organization_name, organization_name)
      |> assign(:page_title, "#{organization_name} overview")

    if connected?(socket) do
      {:ok,
       socket
       |> assign(:loading, false)
       |> assign(:summary_counts, Query.summary_counts(config, admin_scope))
       |> assign(:members, Detail.member_roster(config, admin_scope))
       |> assign(:pending_invitations, Detail.pending_invitations(config, admin_scope))}
    else
      {:ok,
       socket
       |> assign(:loading, true)
       |> assign(:summary_counts, %{})
       |> assign(:members, [])
       |> assign(:pending_invitations, [])}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :needs_review, Sigra.Admin.needs_review(assigns.summary_counts))

    ~H"""
    <section class="sg-stack sg-stack--6">
      <%!-- [1] open header — unchanged --%>
      <header class="sg-page-header">
        <p class="sg-page-kicker">Organization overview</p>
        <h1 class="sg-page-title">{@organization_name}</h1>
        <p class="sg-page-copy">
          Work inside this organization scope: support members, inspect security posture, and review audit evidence without losing tenant context.
        </p>
      </header>

      <%!-- [2] LOUD ALARM — first child after header; only when data loaded (D-02, Landmine 3) --%>
      <%!-- Opt in to role=status because the alarm appears only after LiveView connects. --%>
      <%!-- scope_ribbon intentionally omitted on Overview: topbar sg-scope-pill is sufficient (UI-SPEC L152). --%>
      <.notice
        :if={not @loading}
        tone={if @needs_review > 0, do: :risk, else: :ok}
        role="status"
      >
        <%= if @needs_review > 0 do %>
          {@needs_review} {if @needs_review == 1, do: "account needs", else: "accounts need"} review — <.notice_link href={users_path(@admin_scope) <> "?needs_review=true"}>Review accounts</.notice_link>
        <% else %>
          All clear
        <% end %>
      </.notice>

      <%!-- [3] PRIMARY content — task_card grid --%>
      <div class="sg-grid sg-grid--2">
        <.task_card
          title="Support members"
          body="Search org members, open account detail, and pivot through session, security, and membership state."
          href={users_path(@admin_scope)}
          action="Open members"
        />
        <.task_card
          title="Investigate org events"
          body="Filter audit evidence scoped to this organization and export only its events."
          href={audit_path(@admin_scope)}
          action="Open audit"
        />
      </div>

      <%!-- Org-only demoted scoped-detail tail (D-05) — BELOW the shared front-door archetype --%>
      <section class="sg-card sg-stack sg-stack--3">
        <h2 class="sg-section-heading">Members</h2>
        <%= if @loading do %>
          <.skeleton class="sg-list-row" /><.skeleton class="sg-list-row" /><.skeleton class="sg-list-row" />
        <% else %>
          <p :if={@members == []} class="sg-section-copy">
            No members yet — invite teammates to populate this organization.
          </p>
          <div :if={@members != []} class="sg-list">
            <div :for={member <- @members} class="sg-list-row">
              <p class="sg-meta-value">{member.display_name}</p>
              <div class="sg-cluster">
                <span class="sg-status-pill" data-tone={role_tone(member.role)}>{role_label(member.role)}</span>
                <span :if={member.locked?} class="sg-status-pill" data-tone="risk">Locked</span>
                <span :if={member.deletion_scheduled?} class="sg-status-pill" data-tone="warn">Deletion scheduled</span>
                <span :if={member.confirmed?} class="sg-status-pill" data-tone="ok">Confirmed</span>
                <span :if={not member.confirmed?} class="sg-status-pill" data-tone="warn">Unconfirmed</span>
              </div>
            </div>
          </div>
        <% end %>
      </section>

      <section class="sg-card sg-stack sg-stack--3">
        <h2 class="sg-section-heading">Pending invitations</h2>
        <%= if @loading do %>
          <.skeleton class="sg-list-row" /><.skeleton class="sg-list-row" />
        <% else %>
          <p :if={@pending_invitations == []} class="sg-section-copy">
            No pending invitations.
          </p>
          <div :if={@pending_invitations != []} class="sg-list">
            <div
              :for={invite <- @pending_invitations}
              class="sg-list-row"
              data-tone={if(invite.expired?, do: "risk", else: nil)}
            >
              <p class="sg-meta-value">{invite.email}</p>
              <div class="sg-cluster">
                <span class="sg-status-pill" data-tone={role_tone(invite.role)}>{role_label(invite.role)}</span>
                <span :if={invite.expired?} class="sg-status-pill" data-tone="risk">Expired</span>
                <span :if={not invite.expired?} class="sg-meta-label">Expires {format_date(invite.expires_at)}</span>
              </div>
            </div>
          </div>
        <% end %>
      </section>
    </section>
    """
  end

  defp role_tone(role) do
    case to_string(role) do
      # Owner/Admin share the same visual tone; the label carries the distinction.
      "owner" -> "info"
      "admin" -> "info"
      _ -> "ok"
    end
  end

  defp role_label(role) do
    case to_string(role) do
      "owner" -> "Owner"
      "admin" -> "Admin"
      "member" -> "Member"
      other -> String.capitalize(other)
    end
  end

  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
  defp format_date(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%Y-%m-%d")
  defp format_date(nil), do: "—"
  defp format_date(_), do: "—"

  defp organization_name(%Scope{organization: %{name: name}}) when is_binary(name), do: name
  defp organization_name(%Scope{organization_slug: slug}) when is_binary(slug), do: slug
  defp organization_name(_), do: "Organization"

  defp users_path(%Scope{organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/users"

  defp audit_path(%Scope{organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/audit"

  defp runtime_config! do
    Sigra.Admin.runtime_config!("Sigra organization admin overview")
  end
end
