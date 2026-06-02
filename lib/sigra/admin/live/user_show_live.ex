defmodule Sigra.Admin.Live.UserShowLive do
  @moduledoc """
  Admin user detail surface with scope-safe session controls.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Actions
  alias Sigra.Admin.Users.Detail

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sigra_config, runtime_config!())
     |> assign(:detail, nil)
     |> assign(:return_to, nil)
     |> assign(:confirm_action, nil)
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
     |> assign(:confirm_action, nil)
     |> assign(:page_title, detail.display_name || detail.user.email)}
  end

  @impl true
  def handle_event("open_revoke_session", %{"token" => encoded_token}, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :revoke_session,
       token: Base.url_decode64!(encoded_token, padding: false),
       copy: revoke_session_copy(socket.assigns.detail)
     })}
  end

  def handle_event("open_revoke_all_sessions", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :revoke_all_sessions,
       copy: revoke_all_sessions_copy(socket.assigns.detail)
     })}
  end

  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, :confirm_action, nil)}
  end

  def handle_event("confirm_action", _params, socket) do
    detail = socket.assigns.detail
    config = socket.assigns.sigra_config
    admin_scope = socket.assigns.admin_scope

    case socket.assigns.confirm_action do
      %{type: :revoke_session, token: token} ->
        :ok = Actions.revoke_session(config, admin_scope, detail.user.id, token)

        {:noreply,
         socket
         |> reload_detail(detail.user.id)
         |> put_flash(:info, "Session revoked.")}

      %{type: :revoke_all_sessions} ->
        {_count, nil} = Actions.revoke_all_sessions(config, admin_scope, detail.user.id)

        {:noreply,
         socket
         |> reload_detail(detail.user.id)
         |> put_flash(:info, "All active sessions revoked.")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@detail} class="space-y-6">
      <div class="sg-toolbar">
        <a class="sg-press btn btn-ghost min-h-11" href={@return_to}>Back to users</a>
        <span class="text-sm text-base-content/70">{scope_copy(@admin_scope)}</span>
      </div>

      <section class="sg-card rounded-lg border border-base-300 bg-base-100 p-5">
        <p class="sg-page-kicker">Identity &amp; Status</p>
        <div class="mt-2 flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div class="min-w-0">
            <h1 class="sg-page-title text-3xl font-semibold">{@detail.display_name || @detail.user.email}</h1>
            <p class="mt-2 text-sm text-base-content/70">{@detail.user.email}</p>
            <code class="sg-code mt-2 inline-block text-xs select-all">{@detail.user.id}</code>
          </div>
          <div class="flex flex-wrap gap-2">
            <span class="sg-status-pill" data-tone={if(@detail.identity.confirmed?, do: "ok", else: "warn")}>
              {confirmation_label(@detail.identity)}
            </span>
            <span class="sg-status-pill" data-tone={if(@detail.identity.locked?, do: "risk", else: "ok")}>
              {lock_label(@detail.identity)}
            </span>
            <span class="sg-status-pill" data-tone={if(@detail.identity.deleted?, do: "warn", else: "ok")}>
              {deletion_label(@detail.identity)}
            </span>
          </div>
        </div>
      </section>

      <section class="sg-card rounded-lg border border-base-300 bg-base-100 p-5">
        <div class="sg-toolbar">
          <div>
            <h2 class="sg-section-heading">Sessions</h2>
            <p class="sg-section-copy mt-1">
              {pluralize(length(@detail.sessions), "active session")}
            </p>
          </div>

          <button
            :if={@detail.sessions != []}
            type="button"
            phx-click="open_revoke_all_sessions"
            class="sg-press btn btn-error min-h-11"
          >
            Revoke all sessions
          </button>
        </div>

        <div class="sg-list mt-4">
          <article
            :for={session <- @detail.sessions}
            class="sg-list-row text-sm"
          >
            <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div class="grid gap-2 sm:grid-cols-3">
                <div>
                  <p class="sg-meta-label">Type</p>
                  <p class="sg-meta-value">{session_type(session)}</p>
                </div>
                <div>
                  <p class="sg-meta-label">IP address</p>
                  <p class="sg-meta-value">{session.ip || "Unknown IP"}</p>
                </div>
                <div>
                  <p class="sg-meta-label">Last activity</p>
                  <p class="sg-meta-value">{activity_value(session.last_active_at)}</p>
                </div>
              </div>

              <button
                type="button"
                phx-click="open_revoke_session"
                phx-value-token={Base.url_encode64(session.hashed_token, padding: false)}
                class="sg-press btn btn-error min-h-11 w-full sm:w-auto"
              >
                Revoke session
              </button>
            </div>
          </article>
          <div :if={@detail.sessions == []} class="sg-empty-state text-sm">
            <p class="font-semibold">No active sessions</p>
            <p class="mt-1">This user does not have a currently visible session in this scope.</p>
          </div>
        </div>
      </section>

      <div class="sg-detail-grid">
        <section class="sg-detail-panel rounded-lg border border-base-300 bg-base-100 p-5">
          <h2 class="sg-section-heading">Security</h2>
          <div class="sg-list mt-4">
            <div class="sg-list-row">
              <p class="sg-meta-label">MFA</p>
              <p class="sg-meta-value">{mfa_value(@detail.security.mfa_status)}</p>
            </div>
            <div class="sg-list-row">
              <p class="sg-meta-label">Passkeys</p>
              <p class="sg-meta-value">{pluralize(@detail.security.passkey_count, "passkey")}</p>
            </div>
          </div>
        </section>

        <section class="sg-detail-panel rounded-lg border border-base-300 bg-base-100 p-5">
          <h2 class="sg-section-heading">Identities</h2>
          <div class="sg-list mt-4 text-sm">
            <p :if={!@detail.identities_available?} class="sg-section-copy">Linked identities are not available for this app.</p>
            <div :for={identity <- @detail.identities} class="sg-list-row">
              <p class="sg-meta-label">{identity.provider}</p>
              <p class="sg-meta-value">{Map.get(identity, :provider_email) || Map.get(identity, :provider_uid)}</p>
            </div>
            <div :if={@detail.identities_available? and @detail.identities == []} class="sg-empty-state">
              <p class="font-semibold">No linked identities</p>
              <p class="mt-1">This user signs in without a visible external identity provider.</p>
            </div>
          </div>
        </section>
      </div>

      <section class="sg-card rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="sg-section-heading">Organizations</h2>
        <p class="sg-section-copy mt-1">Tenant memberships and scoped support pivots for this user.</p>
        <div class="sg-list mt-4">
          <article
            :for={organization <- @detail.organizations}
            class="sg-list-row text-sm"
          >
            <div class="sg-toolbar">
              <div>
                <p class="sg-meta-label">Organization</p>
                <p class="sg-meta-value">{organization.organization_name}</p>
              </div>
              <span class="sg-status-pill">{organization.role}</span>
            </div>
            <a
              :if={show_pivot_link?(@admin_scope, organization)}
              class="sg-press btn btn-outline min-h-11 mt-3 w-full sm:w-auto"
              href={pivot_path(@admin_scope, @detail.user.id, organization, @return_to)}
            >
              Open organization-scoped view for {organization.organization_name}
            </a>
          </article>
          <div :if={@detail.organizations == []} class="sg-empty-state text-sm">
            <p class="font-semibold">No organization memberships</p>
            <p class="mt-1">This account is not currently attached to a tenant.</p>
          </div>
        </div>
      </section>

      <section class="sg-card rounded-lg border border-base-300 bg-base-100 p-5">
        <div class="sg-toolbar">
          <div>
            <h2 class="sg-section-heading">Recent Audit</h2>
            <p class="sg-section-copy mt-1">
              Recent activity stays aligned with the full scoped audit history for this user.
            </p>
          </div>

          <a class="sg-press btn btn-outline min-h-11" href={full_audit_path(@admin_scope, @detail.user.id, @return_to)}>
            View full audit
          </a>
        </div>

        <div class="sg-list mt-4 text-sm">
          <div :for={row <- @detail.recent_audit} class="sg-list-row">
            <div class="space-y-2">
              <span :if={row.action_badge} class="badge badge-warning badge-sm">{row.action_badge}</span>
              <p class="font-semibold">{row.action_label}</p>
              <p class="text-sm text-base-content/70">{row.actor_summary}</p>
              <p class="text-xs text-base-content/60">{Calendar.strftime(row.inserted_at, "%Y-%m-%d %H:%M")}</p>
            </div>
          </div>
          <div :if={@detail.recent_audit == []} class="sg-empty-state">
            <p class="font-semibold">No recent audit activity</p>
            <p class="mt-1">No scoped events are currently tied to this user.</p>
          </div>
        </div>
      </section>

      <section class="sg-danger-panel rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="sg-section-heading">Danger Zone</h2>
        <p class="mt-2 text-sm text-base-content/70">
          Session revocation uses Sigra's canonical session APIs.
        </p>
        <p class="mt-2 text-sm text-base-content/70">
          Support actions affect {@detail.danger_zone.impersonation_target_label} in {@detail.scope_label}.
        </p>

        <form
          :if={show_impersonation_start?(@current_scope)}
          method="post"
          action={impersonation_start_path(@admin_scope, @detail.user.id)}
          class="mt-4 space-y-3"
        >
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />
          <button type="submit" class="sg-press btn btn-warning min-h-11 w-full sm:w-auto">
            Start impersonation
          </button>
        </form>

        <p :if={!show_impersonation_start?(@current_scope)} class="mt-4 text-sm text-base-content/70">
          End impersonation before starting another session.
        </p>

        <button
          :if={@detail.danger_zone.revoke_all_sessions?}
          type="button"
          phx-click="open_revoke_all_sessions"
          class="sg-press btn btn-error min-h-11 mt-4 w-full sm:w-auto"
        >
          Revoke all sessions
        </button>
      </section>

      <section :for={section <- @detail.extra_detail_sections} class="sg-card rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-xl font-semibold">{Map.get(section, :title) || Map.get(section, "title")}</h2>
        <p class="mt-2 text-sm text-base-content/70">{Map.get(section, :body) || Map.get(section, "body")}</p>
      </section>

      <dialog :if={@confirm_action} open class="modal">
        <div class="modal-box">
          <p class="text-base font-semibold">Confirm action</p>
          <p class="mt-3 text-sm">{@confirm_action.copy}</p>
          <div class="modal-action">
            <button type="button" phx-click="cancel_confirm" class="sg-press btn btn-ghost min-h-11">Cancel</button>
            <button type="button" phx-click="confirm_action" class="sg-press btn btn-error min-h-11">Confirm</button>
          </div>
        </div>
      </dialog>
    </section>
    """
  end

  defp reload_detail(socket, user_id) do
    detail = Detail.load!(socket.assigns.sigra_config, socket.assigns.admin_scope, user_id)
    assign(socket, detail: detail, confirm_action: nil)
  end

  defp sanitize_return_to(path, admin_scope) when is_binary(path) do
    if String.starts_with?(path, ["/admin/users", "/admin/organizations/"]) do
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

  defp revoke_session_copy(detail) do
    "Revoke this session for #{detail.user.email} in #{detail.scope_label}? The user will need to sign in again."
  end

  defp revoke_all_sessions_copy(detail) do
    "Revoke every active session for #{detail.user.email} in #{detail.scope_label}? This signs them out everywhere."
  end

  defp scope_copy(%Scope{mode: :organization, organization: %{name: name}}),
    do: "Organization-scoped user operations for #{name}"

  defp scope_copy(_admin_scope), do: "Global user operations"

  defp confirmation_label(identity),
    do: "Confirmation: " <> if(identity.confirmed?, do: "Confirmed", else: "Unconfirmed")

  defp lock_label(identity), do: "Lockout: " <> if(identity.locked?, do: "Locked", else: "Active")

  defp deletion_label(identity),
    do: "Deletion: " <> if(identity.deleted?, do: "Deleted", else: "Active")

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
