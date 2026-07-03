defmodule Sigra.Admin.Live.UserSessionsLive do
  @moduledoc "Per-user admin session management with scope-safe revoke controls."

  use Phoenix.LiveView

  import Sigra.Admin.Components

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Actions
  alias Sigra.Admin.Users.Detail

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sigra_config, runtime_config!())
     |> assign(:detail, nil)
     |> assign(:confirm_action, nil)
     |> assign(:admin_breadcrumbs, nil)
     |> assign(:page_title, "Sessions")}
  end

  @impl true
  def handle_params(%{"id" => user_id} = params, _uri, socket) do
    admin_scope = socket.assigns.admin_scope
    config = socket.assigns.sigra_config
    detail = Detail.load!(config, admin_scope, user_id)
    return_to = sanitize_return_to(Map.get(params, "return_to"), admin_scope, user_id)

    {:noreply,
     socket
     |> assign(:detail, detail)
     |> assign(:admin_breadcrumbs, sessions_breadcrumbs(admin_scope, detail, return_to))
     |> assign(:page_title, "#{detail.display_name || detail.user.email} sessions")}
  end

  @impl true
  def handle_event("open_revoke_session", %{"token" => encoded_token}, socket) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, token} ->
        {:noreply,
         assign(socket, :confirm_action, %{
           type: :revoke_session,
           token: token,
           title: "Revoke this session?",
           copy: revoke_session_copy(socket.assigns.detail),
           confirm_label: "Revoke",
           cancel_label: "Cancel"
         })}

      :error ->
        {:noreply, put_flash(socket, :error, "Invalid session reference.")}
    end
  end

  def handle_event("open_revoke_all_sessions", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :revoke_all_sessions,
       title: "Revoke all sessions?",
       copy: revoke_all_sessions_copy(socket.assigns.detail),
       confirm_label: "Revoke",
       cancel_label: "Cancel"
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
    <section :if={@detail} class="sg-stack sg-stack--6">
      <.scope_ribbon copy={scope_copy(@admin_scope)} />

      <header class="sg-page-header">
        <p class="sg-page-kicker">Sessions</p>
        <h1 class="sg-page-title">{@detail.display_name || @detail.user.email}</h1>
        <p class="sg-page-copy">{pluralize(length(@detail.sessions), "active session")}</p>
      </header>

      <section class="sg-card sg-stack sg-stack--3">
        <div class="sg-cluster sg-cluster--between">
          <h2 class="sg-section-heading">Sessions</h2>
          <button
            :if={@detail.sessions != []}
            type="button"
            phx-click="open_revoke_all_sessions"
            class="sg-btn sg-btn--danger sg-btn--sm"
          >
            Revoke all sessions
          </button>
        </div>

        <div :if={@detail.sessions != []} class="sg-table-panel">
          <table class="sg-table">
            <thead>
              <tr>
                <th>Type</th>
                <th>IP address</th>
                <th>Last activity</th>
                <th class="sg-cell-right">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={session <- @detail.sessions}>
                <td><span class="sg-strong">{session_type(session)}</span></td>
                <td><code class="sg-code">{session.ip || "Unknown IP"}</code></td>
                <td class="sg-muted">
                  <span class="sg-summary-facts__num">{activity_value(session.last_active_at)}</span>
                  <span :if={relative_activity(session.last_active_at)} class="sg-muted sg-text-xs">
                    {relative_activity(session.last_active_at)}
                  </span>
                </td>
                <td class="sg-cell-right">
                  <button
                    type="button"
                    phx-click="open_revoke_session"
                    phx-value-token={Base.url_encode64(session.hashed_token, padding: false)}
                    class="sg-btn sg-btn--danger sg-btn--sm"
                  >
                    Revoke session
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.empty_state :if={@detail.sessions == []} title="No active sessions">
          <p class="sg-muted sg-text-sm">This user has no active sessions in the current scope.</p>
        </.empty_state>
      </section>

      <div
        :if={@confirm_action}
        id="user-session-confirm-overlay"
        phx-hook="ConfirmDialog"
        class="sg-confirm-overlay"
        role="presentation"
      >
        <section
          class="sg-confirm-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="user-session-confirm-title"
        >
          <p id="user-session-confirm-title" class="sg-section-heading">{@confirm_action.title}</p>
          <p class="sg-text-sm" style="margin-top: var(--sg-space-3);">{@confirm_action.copy}</p>
          <div class="sg-confirm-dialog__actions">
            <button
              type="button"
              phx-click="cancel_confirm"
              data-sg-confirm-cancel
              class="sg-btn sg-btn--ghost sg-btn--sm"
            >
              {@confirm_action.cancel_label}
            </button>
            <button type="button" phx-click="confirm_action" class="sg-btn sg-btn--danger sg-btn--sm">
              {@confirm_action.confirm_label}
            </button>
          </div>
        </section>
      </div>
    </section>
    """
  end

  defp reload_detail(socket, user_id) do
    detail = Detail.load!(socket.assigns.sigra_config, socket.assigns.admin_scope, user_id)
    assign(socket, detail: detail, confirm_action: nil)
  end

  defp revoke_session_copy(_detail) do
    "The user will be signed out of this session immediately. If this session was compromised, they must sign in again with verified credentials to re-establish access."
  end

  defp revoke_all_sessions_copy(_detail) do
    "The user will be signed out of all active sessions immediately. If any sessions were compromised, they must sign in again with verified credentials to re-establish access."
  end

  defp scope_copy(%Scope{mode: :organization, organization: %{name: name}}),
    do: "Organization-scoped user operations for #{name}"

  defp scope_copy(_admin_scope), do: "Global user operations"

  defp sanitize_return_to(path, admin_scope, user_id) when is_binary(path) do
    if users_index_path?(path, admin_scope) do
      path
    else
      default_return_to(admin_scope, user_id)
    end
  end

  defp sanitize_return_to(_path, admin_scope, user_id),
    do: default_return_to(admin_scope, user_id)

  defp default_return_to(%Scope{mode: :organization, organization_slug: slug}, user_id)
       when is_binary(slug),
       do: "/admin/organizations/#{slug}/users/#{user_id}"

  defp default_return_to(_admin_scope, user_id), do: "/admin/users/#{user_id}"

  defp sessions_breadcrumbs(admin_scope, detail, return_to) do
    users_return_to = users_index_return_to(return_to, admin_scope)

    [
      %{label: "Overview", href: overview_path(admin_scope)},
      %{label: "Users", href: users_return_to},
      %{
        label: detail.user.email,
        href: user_detail_path(admin_scope, detail.user.id, users_return_to)
      },
      %{label: "Sessions"}
    ]
  end

  defp overview_path(%Scope{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}"

  defp overview_path(_admin_scope), do: "/admin"

  defp users_index_return_to(return_to, admin_scope) do
    if users_index_path?(return_to, admin_scope) do
      return_to
    else
      default_users_return_to(admin_scope)
    end
  end

  defp users_index_path?(path, %Scope{mode: :organization, organization_slug: slug})
       when is_binary(path) and is_binary(slug) do
    URI.parse(path).path == "/admin/organizations/#{slug}/users"
  end

  defp users_index_path?(path, _admin_scope) when is_binary(path),
    do: URI.parse(path).path == "/admin/users"

  defp users_index_path?(_path, _admin_scope), do: false

  defp default_users_return_to(%Scope{mode: :organization, organization_slug: slug})
       when is_binary(slug),
       do: "/admin/organizations/#{slug}/users"

  defp default_users_return_to(_admin_scope), do: "/admin/users"

  defp user_detail_path(%Scope{mode: :organization, organization_slug: slug}, user_id, return_to)
       when is_binary(slug) do
    with_return_to("/admin/organizations/#{slug}/users/#{user_id}", return_to)
  end

  defp user_detail_path(_admin_scope, user_id, return_to) do
    with_return_to("/admin/users/#{user_id}", return_to)
  end

  defp with_return_to(path, return_to) when is_binary(return_to) and return_to != "" do
    path <> "?return_to=" <> URI.encode_www_form(return_to)
  end

  defp with_return_to(path, _return_to), do: path

  defp runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError,
              "Sigra admin user sessions requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "Sigra admin user sessions requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end
end
