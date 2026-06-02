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
    <section class="space-y-6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Admin overview</p>
        <h1 class="sg-page-title text-3xl font-semibold">Operate Sigra with confidence</h1>
        <p class="sg-page-copy text-sm text-base-content/70">
          Start with the job at hand: support a user, investigate security state, or collect scoped audit evidence.
        </p>
      </header>

      <dl class="sg-metric-grid">
        <.metric label="Total users" value={Map.get(@summary_counts, :total, 0)} />
        <.metric label="Confirmed" value={Map.get(@summary_counts, :confirmed, 0)} tone="ok" />
        <.metric label="MFA enabled" value={Map.get(@summary_counts, :mfa, 0)} />
        <.metric label="Locked" value={Map.get(@summary_counts, :locked, 0)} tone="risk" />
        <.metric label="Deleted" value={Map.get(@summary_counts, :deleted, 0)} tone="warn" />
      </dl>

      <div class="grid gap-4 lg:grid-cols-3">
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
          title="Check risky states"
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
  attr :tone, :string, default: nil

  defp metric(assigns) do
    ~H"""
    <div class="sg-metric">
      <dt>{@label}</dt>
      <dd>{@value}</dd>
      <span :if={@tone} class="sg-status-pill mt-3" data-tone={@tone}>
        {status_label(@tone)}
      </span>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :body, :string, required: true
  attr :href, :string, required: true
  attr :action, :string, required: true

  defp task_card(assigns) do
    ~H"""
    <article class="sg-card sg-card-hover rounded-lg border border-base-300 bg-base-100 p-5">
      <h2 class="sg-section-heading">{@title}</h2>
      <p class="sg-section-copy mt-2 min-h-14">{@body}</p>
      <a href={@href} class="sg-press btn btn-primary mt-4 min-h-11 w-full sm:w-auto">
        {@action}
      </a>
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
