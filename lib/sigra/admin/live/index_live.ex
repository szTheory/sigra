defmodule Sigra.Admin.Live.IndexLive do
  @moduledoc """
  Global admin orientation surface.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Users.Query

  @impl true
  def mount(_params, _session, socket) do
    config = runtime_config!()
    admin_scope = socket.assigns.admin_scope

    {:ok,
     socket
     |> assign(:sigra_config, config)
     |> assign(:summary_counts, Query.summary_counts(config, admin_scope))
     |> assign(:page_title, "Global overview")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="sg-stack sg-stack--6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Admin overview</p>
        <h1 class="sg-page-title">What do you need to do?</h1>
        <p class="sg-page-copy">
          Start with the job at hand — support a user, investigate security evidence, or review
          risky accounts. The counts below are live entry points into a filtered user list.
        </p>
      </header>

      <div class="sg-metric-grid">
        <.tile label="Total users" value={Map.get(@summary_counts, :total, 0)} href="/admin/users" />
        <.tile
          label="Confirmed"
          value={Map.get(@summary_counts, :confirmed, 0)}
          href="/admin/users?confirmed=true"
        />
        <.tile label="MFA enabled" value={Map.get(@summary_counts, :mfa, 0)} href="/admin/users?mfa=true" />
        <.tile
          label="Locked"
          value={Map.get(@summary_counts, :locked, 0)}
          tone="risk"
          href="/admin/users?locked=true"
        />
        <.tile
          label="Deleted"
          value={Map.get(@summary_counts, :deleted, 0)}
          tone="warn"
          href="/admin/users?deleted=true"
        />
      </div>

      <div class="sg-grid sg-grid--3">
        <.task_card
          title="Support users"
          body="Search by email, inspect account state, revoke sessions, and safely start support actions."
          href="/admin/users"
          action="Open users"
        />
        <.task_card
          title="Investigate evidence"
          body="Filter security events, distinguish actor from effective user, and export scoped CSV evidence."
          href="/admin/audit"
          action="Open audit"
        />
        <.task_card
          title="Review risky accounts"
          body="Jump straight to locked or deletion-scheduled accounts before they become support surprises."
          href="/admin/users?locked=true"
          action="Review locked users"
        />
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :href, :string, required: true
  attr :tone, :string, default: nil

  defp tile(assigns) do
    ~H"""
    <a href={@href} class="sg-tile">
      <span class="sg-metric__label">{@label}</span>
      <span class="sg-metric__value">{@value}</span>
      <span :if={@tone} class="sg-status-pill sg-tile__pill" data-tone={@tone}>
        {status_label(@tone)}
      </span>
    </a>
    """
  end

  attr :title, :string, required: true
  attr :body, :string, required: true
  attr :href, :string, required: true
  attr :action, :string, required: true

  defp task_card(assigns) do
    ~H"""
    <article class="sg-card sg-card-hover sg-stack sg-stack--3">
      <div class="sg-stack sg-stack--2">
        <h2 class="sg-section-heading">{@title}</h2>
        <p class="sg-section-copy">{@body}</p>
      </div>
      <div class="sg-cluster">
        <a href={@href} class="sg-btn sg-btn--primary">{@action}</a>
      </div>
    </article>
    """
  end

  defp status_label("ok"), do: "Healthy"
  defp status_label("warn"), do: "Needs review"
  defp status_label("risk"), do: "Risk"
  defp status_label(_), do: ""

  defp runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError, "Sigra admin overview requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "Sigra admin overview requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end
end
