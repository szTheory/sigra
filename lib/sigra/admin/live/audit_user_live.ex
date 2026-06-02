defmodule Sigra.Admin.Live.AuditUserLive do
  @moduledoc """
  Per-user admin audit explorer for global and organization-scoped routes.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Audit.Explorer
  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Detail

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sigra_config, runtime_config!())
     |> assign(:detail, nil)
     |> assign(:rows, [])
     |> assign(:meta, nil)
     |> assign(:current_params, %{})
     |> assign(:return_to, nil)
     |> assign(:page_title, "User audit")}
  end

  @impl true
  def handle_params(%{"id" => user_id} = params, _uri, socket) do
    admin_scope = socket.assigns.admin_scope
    config = socket.assigns.sigra_config
    detail = Detail.load!(config, admin_scope, user_id)
    return_to = sanitize_return_to(Map.get(params, "return_to"), admin_scope, user_id)

    case Explorer.list_subject_events(config, admin_scope, user_id, params) do
      {:ok, {rows, meta, current_params}} ->
        {:noreply,
         socket
         |> assign(:detail, detail)
         |> assign(:rows, rows)
         |> assign(:meta, meta)
         |> assign(:current_params, current_params)
         |> assign(:return_to, return_to)
         |> assign(:page_title, "#{detail.display_name || detail.user.email} audit")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "We couldn't load this user's audit history. Refresh the page, then try again."
         )
         |> assign(:detail, detail)
         |> assign(:rows, [])
         |> assign(:meta, nil)
         |> assign(:current_params, %{})
         |> assign(:return_to, return_to)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@detail} class="sg-stack sg-stack--6">
      <div class="sg-cluster sg-cluster--between">
        <a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>
          <span aria-hidden="true">&larr;</span> Back to user
        </a>
        <span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>
      </div>

      <header class="sg-page-header">
        <p class="sg-page-kicker">User audit evidence</p>
        <h1 class="sg-page-title">{@detail.display_name || @detail.user.email}</h1>
        <p class="sg-page-copy">
          Filter this user's scoped event history, distinguish support actions from user actions, and export evidence.
        </p>
        <div class="sg-cluster sg-cluster--2">
          <span class="sg-status-pill">{@detail.user.email}</span>
          <code class="sg-code">{@detail.user.id}</code>
        </div>
      </header>

      <form method="get" action={index_path(@admin_scope, @detail.user.id)} class="sg-filter-panel sg-stack">
        <div class="sg-form-grid sg-form-grid--cols">
          <label class="sg-field">
            <span class="sg-field-label">Action prefix</span>
            <input type="text" name="action_prefix" value={param_value(@current_params, "action_prefix")} class="sg-input" />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Outcome</span>
            <input type="text" name="outcome" value={param_value(@current_params, "outcome")} class="sg-input" />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Actor</span>
            <input type="text" name="actor" value={param_value(@current_params, "actor")} class="sg-input" />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Occurred after</span>
            <input type="text" name="from" value={param_value(@current_params, "from")} class="sg-input" placeholder="2026-05-01" />
          </label>
        </div>

        <div class="sg-cluster">
          <button type="submit" class="sg-btn sg-btn--primary">Apply filters</button>
          <a href={clear_path(@admin_scope, @detail.user.id, @return_to)} class="sg-btn sg-btn--ghost">Clear</a>
          <a href={export_path(@admin_scope, @detail.user.id, export_params(@current_params, @return_to))} class="sg-btn sg-btn--secondary">
            Export CSV
          </a>
        </div>

        <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />
        <input type="hidden" name="page_size" value={param_value(@current_params, "page_size", "25")} />
        <input type="hidden" name="order_by" value={param_value(@current_params, "order_by", "inserted_at")} />
        <input type="hidden" name="order_direction" value={param_value(@current_params, "order_direction", "desc")} />
      </form>

      <div :if={@rows != []} class="sg-table-panel">
        <table class="sg-table">
          <thead>
            <tr>
              <th><a href={sort_path(@admin_scope, @detail.user.id, @current_params, "inserted_at")}>Occurred</a></th>
              <th>Event</th>
              <th>Actor</th>
              <th class="sg-show-desktop">Outcome</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows} data-tone={row_tone(row)}>
              <td class="sg-nowrap">
                <div class="sg-stack sg-stack--1">
                  <span class="sg-text-sm">{format_timestamp(row.inserted_at)}</span>
                  <code class="sg-code">{row.id}</code>
                </div>
              </td>
              <td>
                <div class="sg-stack sg-stack--1">
                  <div class="sg-cluster sg-cluster--2">
                    <span class="sg-status-pill" data-tone={row_tone(row)}>{row.action_label}</span>
                    <span :if={row.action_badge} class="sg-status-pill" data-tone="info">{row.action_badge}</span>
                  </div>
                  <code class="sg-code">{row.action}</code>
                </div>
              </td>
              <td>
                <div class="sg-stack sg-stack--1 sg-text-sm">
                  <span>{row.actor_summary}</span>
                  <span :if={row.action_badge} class="sg-muted">Actor: {row.actor_label}</span>
                  <span :if={row.action_badge} class="sg-muted">Effective user: {row.effective_user_label}</span>
                </div>
              </td>
              <td class="sg-show-desktop sg-text-sm">{row.outcome}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@rows == []} class="sg-empty-state">
        <p class="sg-empty-state__title">No audit events match this user view</p>
        <p class="sg-muted sg-text-sm">Try a different filter or clear one or more params to widen the result set.</p>
      </div>

      <nav :if={@meta} class="sg-cluster sg-cluster--between">
        <a
          class={["sg-btn sg-btn--secondary sg-btn--icon", if(@meta.previous_page, do: "", else: "is-disabled")]}
          href={page_path(@admin_scope, @detail.user.id, @current_params, @meta.previous_page)}
          aria-disabled={to_string(is_nil(@meta.previous_page))}
          aria-label="Previous page"
        >
          <span aria-hidden="true">&larr;</span>
          <span class="sr-only">Previous page</span>
        </a>
        <span class="sg-muted sg-text-sm">Page {@meta.current_page || 1}</span>
        <a
          class={["sg-btn sg-btn--secondary sg-btn--icon", if(@meta.next_page, do: "", else: "is-disabled")]}
          href={page_path(@admin_scope, @detail.user.id, @current_params, @meta.next_page)}
          aria-disabled={to_string(is_nil(@meta.next_page))}
          aria-label="Next page"
        >
          <span aria-hidden="true">&rarr;</span>
          <span class="sr-only">Next page</span>
        </a>
      </nav>
    </section>
    """
  end

  # Severity tone mirrors the global explorer: failures risk, impersonation info,
  # routine success neutral.
  defp row_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
  defp row_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
  defp row_tone(_row), do: nil

  defp runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError,
              "Sigra admin user audit explorer requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "Sigra admin user audit explorer requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end

  defp sanitize_return_to(path, admin_scope, user_id) when is_binary(path) do
    if String.starts_with?(path, ["/admin/users", "/admin/organizations/"]) do
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

  defp index_path(%Scope{mode: :organization, organization_slug: slug}, user_id)
       when is_binary(slug),
       do: "/admin/organizations/#{slug}/users/#{user_id}/audit"

  defp index_path(_admin_scope, user_id), do: "/admin/users/#{user_id}/audit"

  defp clear_path(admin_scope, user_id, return_to) do
    append_query(index_path(admin_scope, user_id), %{"return_to" => return_to})
  end

  defp export_path(%Scope{mode: :organization, organization_slug: slug}, user_id, params)
       when is_binary(slug) do
    append_query("/admin/organizations/#{slug}/users/#{user_id}/audit/export.csv", params)
  end

  defp export_path(_admin_scope, user_id, params) do
    append_query("/admin/users/#{user_id}/audit/export.csv", params)
  end

  defp sort_path(admin_scope, user_id, params, field) do
    next_direction =
      if Map.get(params, "order_by") == field and Map.get(params, "order_direction") == "desc",
        do: "asc",
        else: "desc"

    admin_scope
    |> index_path(user_id)
    |> append_query(
      params
      |> Map.put("order_by", field)
      |> Map.put("order_direction", next_direction)
      |> Map.delete("cursor")
    )
  end

  defp page_path(_admin_scope, _user_id, _params, nil), do: "#"

  defp page_path(admin_scope, user_id, params, cursor) do
    admin_scope
    |> index_path(user_id)
    |> append_query(Map.put(params, "cursor", cursor))
  end

  defp append_query(path, params) do
    cleaned =
      params
      |> Enum.reject(fn {_key, value} -> value in [nil, "", false] end)
      |> Enum.into(%{})

    case cleaned do
      empty when map_size(empty) == 0 -> path
      _ -> path <> "?" <> URI.encode_query(cleaned)
    end
  end

  defp scope_copy(%Scope{mode: :organization, organization: %{name: name}}),
    do: "Organization-scoped audit explorer for #{name}"

  defp scope_copy(_admin_scope), do: "Global audit explorer"

  defp export_params(current_params, return_to) do
    current_params
    |> Map.put_new("return_to", return_to)
  end

  defp param_value(params, key, default \\ ""), do: Map.get(params, key, default)

  defp format_timestamp(%DateTime{} = timestamp),
    do: Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S")

  defp format_timestamp(_timestamp), do: ""
end
