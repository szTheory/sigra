defmodule Sigra.Admin.Live.OrganizationLive do
  @moduledoc """
  Organization-scoped admin orientation surface.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Query

  @impl true
  def mount(_params, _session, socket) do
    admin_scope = socket.assigns.admin_scope
    config = runtime_config!()
    organization_name = organization_name(admin_scope)

    {:ok,
     socket
     |> assign(:sigra_config, config)
     |> assign(:summary_counts, Query.summary_counts(config, admin_scope))
     |> assign(:organization_name, organization_name)
     |> assign(:page_title, "#{organization_name} overview")}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :needs_review, needs_review(assigns.summary_counts))

    ~H"""
    <section class="sg-stack sg-stack--6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Organization overview</p>
        <h1 class="sg-page-title">{@organization_name}</h1>
        <p class="sg-page-copy">
          Work inside this organization scope: support members, inspect security posture, and review audit evidence without losing tenant context.
        </p>
      </header>

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

      <section class="sg-card sg-stack sg-stack--3">
        <div class="sg-cluster sg-cluster--between">
          <div class="sg-stack sg-stack--1">
            <h2 class="sg-section-heading">Scoped attention</h2>
            <p class="sg-section-copy">
              Support and evidence stay bounded to {@organization_name}.
            </p>
          </div>
          <span class="sg-status-pill" data-tone={if(Map.get(@summary_counts, :locked, 0) > 0, do: "risk", else: "ok")}>
            {if(Map.get(@summary_counts, :locked, 0) > 0, do: "Needs review", else: "Healthy")}
          </span>
        </div>

        <div class="sg-list">
          <div class="sg-list-row" data-tone={if(Map.get(@summary_counts, :locked, 0) > 0, do: "risk", else: nil)}>
            <p class="sg-meta-label">Risk queue</p>
            <p class="sg-meta-value">
              {locked_summary(Map.get(@summary_counts, :locked, 0))} in this organization
            </p>
          </div>
          <div class="sg-list-row">
            <p class="sg-meta-label">Evidence boundary</p>
            <p class="sg-meta-value">Audit exports from this area stay organization-scoped.</p>
          </div>
        </div>
      </section>

      <section class="sg-card sg-posture-strip sg-stack sg-stack--3">
        <a
          href={users_path(@admin_scope) <> "?locked=true"}
          class="sg-cluster sg-cluster--start sg-posture-strip__risk"
        >
          <span class="sg-status-pill" data-tone={if(@needs_review > 0, do: "risk", else: "ok")}>
            {if(@needs_review > 0, do: "#{@needs_review} accounts need review", else: "All clear")}
          </span>
        </a>

        <div class="sg-cluster sg-cluster--3">
          <.metric_link label="Users" value={Map.get(@summary_counts, :total, 0)} href={users_path(@admin_scope)} />
          <.metric_link
            label="Confirmed"
            value={Map.get(@summary_counts, :confirmed, 0)}
            href={users_path(@admin_scope) <> "?confirmed=true"}
          />
          <.metric_link
            label="MFA"
            value={Map.get(@summary_counts, :mfa, 0)}
            href={users_path(@admin_scope) <> "?mfa=true"}
          />
          <.metric_link
            label="Passkeys"
            value={Map.get(@summary_counts, :passkeys, 0)}
            href={users_path(@admin_scope) <> "?passkeys=true"}
          />
          <.metric_link
            label="Locked"
            value={Map.get(@summary_counts, :locked, 0)}
            href={users_path(@admin_scope) <> "?locked=true"}
          />
        </div>

        <p class="sg-section-copy">
          Bounded to this org: members, audit evidence, impersonation, scoping.
        </p>
      </section>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :href, :string, required: true

  defp metric_link(assigns) do
    ~H"""
    <a href={@href} class="sg-metric-link">
      <span class="sg-metric-link__label">{@label}</span>
      <span class="sg-metric-link__value">{@value}</span>
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

  defp organization_name(%Scope{organization: %{name: name}}) when is_binary(name), do: name
  defp organization_name(%Scope{organization_slug: slug}) when is_binary(slug), do: slug
  defp organization_name(_), do: "Organization"

  defp users_path(%Scope{organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/users"

  defp audit_path(%Scope{organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/audit"

  defp needs_review(counts) do
    Map.get(counts, :locked, 0) + Map.get(counts, :deleted, 0)
  end

  defp locked_summary(1), do: "1 locked user"
  defp locked_summary(count), do: "#{count} locked users"

  defp runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError,
              "Sigra organization admin overview requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "Sigra organization admin overview requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end
end
