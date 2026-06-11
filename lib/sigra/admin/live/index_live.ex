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

    {:ok,
     socket
     |> assign(:sigra_config, config)
     |> assign(:summary_stats, Query.summary_stats(config, admin_scope))
     |> assign(:loading, false)
     |> assign(:page_title, "Global overview")}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:summary_posture, summary_group(assigns.summary_stats, :posture))
      |> assign(:summary_growth, summary_group(assigns.summary_stats, :growth))
      |> assign(:summary_activity, summary_group(assigns.summary_stats, :activity))
      |> assign(
        :needs_review,
        Sigra.Admin.needs_review(summary_group(assigns.summary_stats, :posture))
      )

    ~H"""
    <section class="sg-stack sg-stack--6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Admin overview</p>
        <h1 class="sg-page-title">What do you need to do?</h1>
        <p class="sg-page-copy">
          Start from the job at hand — find a user, investigate an event, or review risky accounts.
        </p>
      </header>

      <.notice :if={not @loading} tone={if @needs_review > 0, do: :risk, else: :ok}>
        <%= if @needs_review > 0 do %>
          {@needs_review} accounts need review —
          <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
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

      <% total_users = summary_count(@summary_posture, :total) %>
      <% new_this_week = summary_count(@summary_growth, :new_this_week) %>
      <% new_this_month = summary_count(@summary_growth, :new_this_month) %>
      <% active_this_week = summary_count(@summary_activity, :active_this_week) %>
      <% active_this_month = summary_count(@summary_activity, :active_this_month) %>
      <% mfa_users = summary_count(@summary_posture, :mfa_enabled) %>
      <% passkey_users = summary_count(@summary_posture, :passkey_users) %>
      <section class="sg-stack sg-stack--3" aria-labelledby="admin-user-snapshot-heading">
        <h2 id="admin-user-snapshot-heading" class="sg-section-heading">User snapshot</h2>
        <dl class="sg-metric-grid" aria-label="User snapshot">
          <.summary_chip
            id="overview-metric-total-users"
            icon="users"
            label="Total users"
            value={total_users}
            value_suffix="total users"
          />
          <.summary_chip
            id="overview-metric-new-users"
            icon="sparkles"
            label="New users"
            value={new_this_week}
            value_suffix="new this week"
            subvalue={month_detail(new_this_week, new_this_month)}
            help="Accounts registered since Monday UTC and since the first day of this month."
          />
          <.summary_chip
            :if={activity_available?(@summary_activity)}
            id="overview-metric-active-users"
            icon="activity"
            label="Active users"
            value={active_this_week}
            value_suffix="active this week"
            subvalue={month_detail(active_this_week, active_this_month)}
            help="Users with session activity since Monday UTC and since the first day of this month."
          />
          <.summary_chip
            id="overview-metric-auth-coverage"
            icon="mfa"
            label="Authentication coverage"
            value={percent_of(mfa_users, total_users)}
            value_unit="%"
            value_suffix="MFA coverage"
            subvalue={"#{percent_of(passkey_users, total_users)}% passkey coverage"}
            help="Coverage uses total users as the denominator."
          />
        </dl>
      </section>
    </section>
    """
  end

  defp summary_group(stats, key) when is_map(stats), do: Map.get(stats, key, %{})
  defp summary_group(_stats, _key), do: %{}

  defp summary_count(counts, key) when is_map(counts) do
    case Map.get(counts, key, 0) do
      nil -> 0
      value -> value
    end
  end

  defp summary_count(_counts, _key), do: 0

  defp activity_available?(%{available?: true}), do: true
  defp activity_available?(_activity), do: false

  defp month_detail(count, count), do: nil
  defp month_detail(_week_count, month_count), do: "#{month_count} this month"

  defp percent_of(_count, total) when total in [nil, 0], do: 0

  defp percent_of(count, total) do
    (count / total * 100)
    |> Float.round()
    |> trunc()
  end

  defp runtime_config! do
    Sigra.Admin.runtime_config!("Sigra admin overview")
  end
end
