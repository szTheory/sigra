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
      <div class="flex flex-wrap items-center justify-between gap-3">
        <a class="btn btn-ghost min-h-11" href={@return_to}>Back to users</a>
        <span class="text-sm text-base-content/70">{scope_copy(@admin_scope)}</span>
      </div>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h1 class="text-2xl font-semibold">Identity &amp; Status</h1>
        <div class="mt-4 space-y-2 text-sm">
          <p class="font-semibold">{@detail.display_name}</p>
          <p>{@detail.user.email}</p>
          <code class="text-xs select-all">{@detail.user.id}</code>
          <p>{confirmation_label(@detail.identity)}</p>
          <p>{lock_label(@detail.identity)}</p>
          <p>{deletion_label(@detail.identity)}</p>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-xl font-semibold">Sessions</h2>
            <p class="mt-1 text-sm text-base-content/70">
              {pluralize(length(@detail.sessions), "active session")}
            </p>
          </div>

          <button
            :if={@detail.sessions != []}
            type="button"
            phx-click="open_revoke_all_sessions"
            class="btn btn-error min-h-11"
          >
            Revoke all sessions
          </button>
        </div>

        <div class="mt-4 space-y-3">
          <article
            :for={session <- @detail.sessions}
            class="rounded-md border border-base-300 bg-base-200 p-4 text-sm"
          >
            <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div class="space-y-1">
                <p class="font-semibold">{session_label(session)}</p>
                <p>{session.ip || "Unknown IP"}</p>
                <p>{activity_label(session.last_active_at)}</p>
              </div>

              <button
                type="button"
                phx-click="open_revoke_session"
                phx-value-token={Base.url_encode64(session.hashed_token, padding: false)}
                class="btn btn-error min-h-11 w-full sm:w-auto"
              >
                Revoke session
              </button>
            </div>
          </article>
          <p :if={@detail.sessions == []} class="text-sm text-base-content/70">No active sessions.</p>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-xl font-semibold">Security</h2>
        <div class="mt-4 space-y-2 text-sm">
          <p>{mfa_label(@detail.security.mfa_status)}</p>
          <p>{pluralize(@detail.security.passkey_count, "passkey")}</p>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-xl font-semibold">Identities</h2>
        <div class="mt-4 space-y-2 text-sm">
          <p :if={!@detail.identities_available?}>Linked identities are not available for this app.</p>
          <div :for={identity <- @detail.identities} class="rounded-md border border-base-300 bg-base-200 p-3">
            <p class="font-semibold">{identity.provider}</p>
            <p>{Map.get(identity, :provider_email) || Map.get(identity, :provider_uid)}</p>
          </div>
          <p :if={@detail.identities_available? and @detail.identities == []}>No linked identities.</p>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-xl font-semibold">Organizations</h2>
        <div class="mt-4 space-y-3">
          <article
            :for={organization <- @detail.organizations}
            class="rounded-md border border-base-300 bg-base-200 p-4 text-sm"
          >
            <p class="font-semibold">{organization.organization_name}</p>
            <p>Role: {organization.role}</p>
            <a
              :if={show_pivot_link?(@admin_scope, organization)}
              class="btn btn-outline min-h-11 mt-3 w-full sm:w-auto"
              href={pivot_path(@admin_scope, @detail.user.id, organization, @return_to)}
            >
              Open organization-scoped view for {organization.organization_name}
            </a>
          </article>
          <p :if={@detail.organizations == []} class="text-sm text-base-content/70">No organization memberships.</p>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-xl font-semibold">Recent Audit</h2>
        <div class="mt-4 space-y-2 text-sm">
          <div :for={event <- @detail.recent_audit} class="rounded-md border border-base-300 bg-base-200 p-3">
            <p class="font-semibold">{event.action}</p>
            <p>{Calendar.strftime(event.inserted_at, "%Y-%m-%d %H:%M")}</p>
          </div>
          <p :if={@detail.recent_audit == []}>No recent audit activity.</p>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-xl font-semibold">Danger Zone</h2>
        <p class="mt-2 text-sm text-base-content/70">
          Session revocation uses Sigra's canonical session APIs.
        </p>
        <button
          :if={@detail.danger_zone.revoke_all_sessions?}
          type="button"
          phx-click="open_revoke_all_sessions"
          class="btn btn-error min-h-11 mt-4 w-full sm:w-auto"
        >
          Revoke all sessions
        </button>
      </section>

      <section :for={section <- @detail.extra_detail_sections} class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-xl font-semibold">{Map.get(section, :title) || Map.get(section, "title")}</h2>
        <p class="mt-2 text-sm text-base-content/70">{Map.get(section, :body) || Map.get(section, "body")}</p>
      </section>

      <dialog :if={@confirm_action} open class="modal">
        <div class="modal-box">
          <p class="text-base font-semibold">Confirm action</p>
          <p class="mt-3 text-sm">{@confirm_action.copy}</p>
          <div class="modal-action">
            <button type="button" phx-click="cancel_confirm" class="btn btn-ghost min-h-11">Cancel</button>
            <button type="button" phx-click="confirm_action" class="btn btn-error min-h-11">Confirm</button>
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

  defp mfa_label(nil), do: "MFA: Not configured"
  defp mfa_label(%{enabled?: true}), do: "MFA: Enabled"
  defp mfa_label(%{enabled_at: %DateTime{}}), do: "MFA: Enabled"
  defp mfa_label(_status), do: "MFA: Not configured"

  defp session_label(%{type: type}), do: "Session type: " <> to_string(type)

  defp activity_label(%DateTime{} = at),
    do: "Last activity: " <> Calendar.strftime(at, "%Y-%m-%d %H:%M")

  defp activity_label(_), do: "Last activity: Not available"

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
