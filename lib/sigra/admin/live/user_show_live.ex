defmodule Sigra.Admin.Live.UserShowLive do
  @moduledoc """
  Admin user detail surface with scope-safe session controls.
  """

  use Phoenix.LiveView

  import Sigra.Admin.Components

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Detail

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sigra_config, runtime_config!())
     |> assign(:detail, nil)
     |> assign(:return_to, nil)
     |> assign(:admin_breadcrumbs, nil)
     |> assign(:page_title, "User")}
  end

  @impl true
  def handle_params(%{"id" => user_id} = params, _uri, socket) do
    admin_scope = socket.assigns.admin_scope
    detail = Detail.load!(socket.assigns.sigra_config, admin_scope, user_id)
    return_to = sanitize_return_to(Map.get(params, "return_to"), admin_scope)

    {:noreply,
     socket
     |> assign(:detail, detail)
     |> assign(:return_to, return_to)
     |> assign(:admin_breadcrumbs, user_breadcrumbs(admin_scope, detail, return_to))
     |> assign(:page_title, detail.display_name || detail.user.email)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@detail} class="sg-stack sg-stack--6">
      <.scope_ribbon copy={scope_copy(@admin_scope)} />

      <header class="sg-page-header">
        <p class="sg-page-kicker">User</p>
        <h1 class="sg-page-title">{@detail.display_name || @detail.user.email}</h1>
        <div class="sg-cluster sg-cluster--2">
          <span class="sg-muted sg-text-sm">{@detail.user.email}</span>
          <code class="sg-code">{@detail.user.id}</code>
        </div>

        <dl class="sg-summary-facts">
          <div>
            <dt class="sg-kv__term">Sessions</dt>
            <dd class="sg-kv__value sg-summary-facts__num">{length(@detail.sessions)}</dd>
          </div>
          <div>
            <dt class="sg-kv__term">MFA</dt>
            <dd class="sg-kv__value">{mfa_value(@detail.security.mfa_status)}</dd>
          </div>
          <div>
            <dt class="sg-kv__term">Last seen</dt>
            <dd class="sg-kv__value">{last_activity(@detail.sessions)}</dd>
          </div>
        </dl>

        <.notice :if={summary_alert(@detail)} tone={elem(summary_alert(@detail), 0)}>
          {elem(summary_alert(@detail), 1)}
        </.notice>

        <div class="sg-cluster sg-cluster--2">
          <span :for={{label, tone} <- status_pills(@detail)} class="sg-status-pill" data-tone={tone}>
            {label}
          </span>
        </div>
      </header>

      <section class="sg-card sg-stack sg-stack--3">
        <div class="sg-cluster sg-cluster--between">
          <div class="sg-stack sg-stack--1">
            <h2 class="sg-section-heading">Sessions</h2>
            <p class="sg-section-copy">{pluralize(length(@detail.sessions), "active session")}</p>
          </div>
          <a class="sg-btn sg-btn--secondary sg-btn--sm" href={sessions_path(@admin_scope, @detail.user.id, @return_to)}>
            Manage sessions
          </a>
        </div>

        <div :if={@detail.sessions != []} class="sg-table-panel">
          <table class="sg-table">
            <thead>
              <tr>
                <th>Type</th>
                <th>IP address</th>
                <th>Last activity</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={session <- Enum.take(@detail.sessions, 3)}>
                <td><span class="sg-strong">{session_type(session)}</span></td>
                <td><code class="sg-code">{session.ip || "Unknown IP"}</code></td>
                <td class="sg-muted">
                  <span class="sg-summary-facts__num">{activity_value(session.last_active_at)}</span>
                  <span :if={relative_activity(session.last_active_at)} class="sg-muted sg-text-xs">
                    {relative_activity(session.last_active_at)}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.empty_state :if={@detail.sessions == []} title="No active sessions"><p class="sg-muted sg-text-sm">This user has no active sessions in the current scope.</p></.empty_state>
      </section>

      <div class="sg-detail-grid">
        <section class="sg-detail-panel sg-stack sg-stack--3">
          <h2 class="sg-section-heading">Security</h2>
          <dl class="sg-kv">
            <div>
              <dt class="sg-kv__term">MFA</dt>
              <dd class="sg-kv__value">{mfa_value(@detail.security.mfa_status)}</dd>
            </div>
            <div>
              <dt class="sg-kv__term">Passkeys</dt>
              <dd class="sg-kv__value">{pluralize(@detail.security.passkey_count, "passkey")}</dd>
            </div>
          </dl>
        </section>

        <section class="sg-detail-panel sg-stack sg-stack--3">
          <h2 class="sg-section-heading">Identities</h2>
          <p :if={!@detail.identities_available?} class="sg-section-copy">
            Linked identities are not available for this app.
          </p>
          <dl :if={@detail.identities != []} class="sg-kv">
            <div :for={identity <- @detail.identities}>
              <dt class="sg-kv__term">{identity.provider}</dt>
              <dd class="sg-kv__value">
                {Map.get(identity, :provider_email) || Map.get(identity, :provider_uid)}
              </dd>
            </div>
          </dl>
          <.empty_state :if={@detail.identities_available? and @detail.identities == []} title="No linked identities"><p class="sg-muted sg-text-sm">This user signs in without a visible external identity provider.</p></.empty_state>
        </section>
      </div>

      <section class="sg-card sg-stack sg-stack--3">
        <div class="sg-cluster sg-cluster--between">
          <div class="sg-stack sg-stack--1">
            <h2 class="sg-section-heading">Organizations</h2>
            <p class="sg-section-copy">{pluralize(length(@detail.organizations), "organization")}</p>
          </div>
          <a
            :if={length(@detail.organizations) > 3}
            class="sg-btn sg-btn--secondary sg-btn--sm"
            href={pivot_path(@admin_scope, @detail.user.id, hd(@detail.organizations), @return_to)}
          >
            View all organizations
          </a>
        </div>
        <div class="sg-list">
          <article :for={organization <- Enum.take(@detail.organizations, 3)} class="sg-list-row sg-stack sg-stack--3">
            <div class="sg-cluster sg-cluster--between">
              <div class="sg-stack sg-stack--1">
                <span class="sg-meta-label">Organization</span>
                <span class="sg-meta-value">{organization.organization_name}</span>
              </div>
              <span class="sg-status-pill">{organization.role}</span>
            </div>
            <div :if={show_pivot_link?(@admin_scope, organization)} class="sg-cluster">
              <a
                class="sg-btn sg-btn--secondary sg-btn--sm"
                href={pivot_path(@admin_scope, @detail.user.id, organization, @return_to)}
              >
                Open organization-scoped view for {organization.organization_name}
              </a>
            </div>
          </article>
          <.empty_state :if={@detail.organizations == []} title="No organizations"><p class="sg-muted sg-text-sm">This user has not joined any organizations.</p></.empty_state>
        </div>
      </section>

      <section class="sg-card sg-stack sg-stack--3">
        <div class="sg-cluster sg-cluster--between">
          <div class="sg-stack sg-stack--1">
            <h2 class="sg-section-heading">Recent audit</h2>
            <p class="sg-section-copy">
              Shows the most recent events. Open the full audit to filter and export.
            </p>
          </div>

          <a class="sg-btn sg-btn--secondary sg-btn--sm" href={full_audit_path(@admin_scope, @detail.user.id, @return_to)}>
            View full audit
          </a>
        </div>

        <div class="sg-list">
          <.audit_row :for={row <- @detail.recent_audit} row={row} />
          <.empty_state :if={@detail.recent_audit == []} title="No recent audit activity"><p class="sg-muted sg-text-sm">No scoped events are currently tied to this user.</p></.empty_state>
        </div>
      </section>

      <section :for={section <- @detail.extra_detail_sections} class="sg-card sg-stack sg-stack--2">
        <h2 class="sg-section-heading">{Map.get(section, :title) || Map.get(section, "title")}</h2>
        <p class="sg-muted sg-text-sm">{Map.get(section, :body) || Map.get(section, "body")}</p>
      </section>

      <section class="sg-danger-panel sg-stack sg-stack--3">
        <div class="sg-stack sg-stack--1">
          <h2 class="sg-section-heading">Danger zone</h2>
          <p class="sg-muted sg-text-sm">
            Support actions affect {@detail.danger_zone.impersonation_target_label} in {@detail.scope_label}.
          </p>
        </div>

        <div class="sg-cluster">
          <form
            :if={show_impersonation_start?(@current_scope)}
            method="post"
            action={impersonation_start_path(@admin_scope, @detail.user.id)}
          >
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />
            <button type="submit" class="sg-btn sg-btn--primary sg-btn--sm">Start impersonation</button>
          </form>
        </div>

        <p :if={!show_impersonation_start?(@current_scope)} class="sg-muted sg-text-sm">
          End impersonation before starting another session.
        </p>
      </section>
    </section>
    """
  end

  defp sanitize_return_to(path, admin_scope) when is_binary(path) do
    if users_index_path?(path, admin_scope) do
      path
    else
      default_return_to(admin_scope)
    end
  end

  defp sanitize_return_to(_path, admin_scope), do: default_return_to(admin_scope)

  defp default_return_to(%Scope{mode: :organization, organization_slug: slug})
       when is_binary(slug),
       do: "/admin/organizations/#{slug}/users"

  defp default_return_to(_admin_scope), do: "/admin/users"

  defp user_breadcrumbs(admin_scope, detail, return_to) do
    [
      %{label: "Overview", href: overview_path(admin_scope)},
      %{label: "Users", href: return_to},
      %{label: detail.user.email}
    ]
  end

  defp overview_path(%Scope{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}"

  defp overview_path(_admin_scope), do: "/admin"

  defp users_index_path?(path, %Scope{mode: :organization, organization_slug: slug})
       when is_binary(slug) do
    URI.parse(path).path == "/admin/organizations/#{slug}/users"
  end

  defp users_index_path?(path, _admin_scope), do: URI.parse(path).path == "/admin/users"

  defp pivot_path(_admin_scope, user_id, organization, return_to) do
    path = "/admin/organizations/#{organization.organization_slug}/users/#{user_id}"

    if is_binary(return_to) and return_to != "" do
      path <> "?return_to=" <> URI.encode_www_form(return_to)
    else
      path
    end
  end

  defp show_pivot_link?(%Scope{mode: :global, platform_admin?: true}, organization),
    do: is_binary(organization.organization_slug)

  defp show_pivot_link?(_admin_scope, _organization), do: false

  defp full_audit_path(%Scope{mode: :organization, organization_slug: slug}, user_id, return_to)
       when is_binary(slug) do
    with_return_to("/admin/organizations/#{slug}/users/#{user_id}/audit", return_to)
  end

  defp full_audit_path(_admin_scope, user_id, return_to) do
    with_return_to("/admin/users/#{user_id}/audit", return_to)
  end

  defp sessions_path(%Scope{mode: :organization, organization_slug: slug}, user_id, return_to)
       when is_binary(slug) do
    with_return_to("/admin/organizations/#{slug}/users/#{user_id}/sessions", return_to)
  end

  defp sessions_path(_admin_scope, user_id, return_to) do
    with_return_to("/admin/users/#{user_id}/sessions", return_to)
  end

  defp impersonation_start_path(%Scope{mode: :organization, organization_slug: slug}, user_id)
       when is_binary(slug) do
    "/admin/organizations/#{slug}/users/#{user_id}/impersonation"
  end

  defp impersonation_start_path(_admin_scope, user_id),
    do: "/admin/users/#{user_id}/impersonation"

  defp with_return_to(path, return_to) when is_binary(return_to) and return_to != "" do
    path <> "?return_to=" <> URI.encode_www_form(return_to)
  end

  defp with_return_to(path, _return_to), do: path

  defp show_impersonation_start?(%{impersonating_from: %_{}}), do: false
  defp show_impersonation_start?(_current_scope), do: true

  defp scope_copy(%Scope{mode: :organization, organization: %{name: name}}),
    do: "Organization-scoped user operations for #{name}"

  defp scope_copy(_admin_scope), do: "Global user operations"

  # Concise, scannable identity/security status as tone pills. Only surfaces the
  # risky states (locked/deletion) as pills — "active" states are not noise.
  defp status_pills(detail) do
    identity = detail.identity

    confirmation =
      if identity.confirmed?, do: {"Confirmed", "ok"}, else: {"Unconfirmed", "warn"}

    [confirmation, security_pill(detail.security)]
    |> maybe_append(identity.locked?, {"Locked", "risk"})
    |> maybe_append(identity.deleted?, {"Deletion scheduled", "warn"})
  end

  defp maybe_append(pills, true, pill), do: pills ++ [pill]
  defp maybe_append(pills, _falsey, _pill), do: pills

  defp security_pill(security) do
    mfa? = mfa_enabled?(security.mfa_status)
    passkeys? = (security.passkey_count || 0) > 0

    cond do
      mfa? and passkeys? -> {"MFA + passkeys", "ok"}
      mfa? -> {"MFA", "ok"}
      passkeys? -> {"Passkeys", "ok"}
      true -> {"No MFA", nil}
    end
  end

  defp mfa_enabled?(status), do: mfa_value(status) == "Enabled"

  defp mfa_value(nil), do: "Not configured"
  # Sigra.MFA.status/3 returns %{enabled: true, ...} (atom key, no trailing ?)
  defp mfa_value(%{enabled: true}), do: "Enabled"
  # Legacy shape from earlier Sigra versions — keep for backward compat
  defp mfa_value(%{enabled?: true}), do: "Enabled"
  defp mfa_value(%{enabled_at: %DateTime{}}), do: "Enabled"
  defp mfa_value(_status), do: "Not configured"

  defp session_type(%{type: type}), do: to_string(type)

  defp activity_value(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M")

  defp activity_value(_), do: "Not available"

  # Most-recent session activity across all sessions, reusing the absolute
  # formatter. Guards the empty case so Enum.max is never called on [].
  defp last_activity(sessions) when is_list(sessions) do
    sessions
    |> Enum.map(&Map.get(&1, :last_active_at))
    |> Enum.filter(&match?(%DateTime{}, &1))
    |> case do
      [] -> activity_value(nil)
      stamps -> activity_value(Enum.max(stamps, DateTime))
    end
  end

  defp last_activity(_), do: activity_value(nil)

  # Single highest-priority headline issue for the foregrounded callout.
  # Priority: locked > unconfirmed > no-MFA. Healthy accounts return nil.
  defp summary_alert(detail) do
    identity = detail.identity

    cond do
      identity.locked? ->
        {:risk, "Locked — revoke active sessions and unlock below."}

      not identity.confirmed? ->
        {:warn, "Email unconfirmed — the user cannot complete sign-in."}

      not mfa_enabled?(detail.security.mfa_status) ->
        {:warn, "No MFA configured — ask the user to set up a second factor."}

      true ->
        nil
    end
  end

  # Coarse human-readable recency cue beside the absolute timestamp.
  defp relative_activity(%DateTime{} = at) do
    diff = DateTime.diff(DateTime.utc_now(), at, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end

  defp relative_activity(_), do: nil

  defp pluralize(1, label), do: "1 #{label}"
  defp pluralize(count, label), do: "#{count} #{label}s"

  defp runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError, "Sigra admin users requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "Sigra admin users requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end
end
