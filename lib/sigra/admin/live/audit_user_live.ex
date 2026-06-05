defmodule Sigra.Admin.Live.AuditUserLive do
  @moduledoc """
  Per-user admin audit explorer for global and organization-scoped routes.
  """

  use Phoenix.LiveView

  import Sigra.Admin.Components

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
        <.page_back return_to={@return_to} label="Back to user" />
        <.scope_ribbon copy={scope_copy(@admin_scope)} />
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

      <div class="sg-cluster sg-cluster--2">
        <form method="get" action={index_path(@admin_scope, @detail.user.id)}>
          <input type="hidden" name="return_to" value={@return_to} />
          <label class="sg-filter-chip">
            <input
              type="checkbox"
              name="outcome"
              value="failure"
              checked={param_value(@current_params, "outcome") == "failure"}
              class="checkbox checkbox-sm"
            />
            <span>Failures</span>
          </label>
        </form>
        <form method="get" action={index_path(@admin_scope, @detail.user.id)}>
          <input type="hidden" name="return_to" value={@return_to} />
          <label class="sg-filter-chip">
            <input
              type="checkbox"
              name="action_prefix"
              value="admin.impersonation"
              checked={param_value(@current_params, "action_prefix") == "admin.impersonation"}
              class="checkbox checkbox-sm"
            />
            <span>Impersonation</span>
          </label>
        </form>
      </div>

      <form method="get" action={index_path(@admin_scope, @detail.user.id)} class="sg-filter-panel sg-stack">
        <div class="sg-form-grid sg-form-grid--cols">
          <label class="sg-field">
            <span class="sg-field-label">Action prefix</span>
            <input
              type="text"
              name="action_prefix"
              value={param_value(@current_params, "action_prefix")}
              class="sg-input"
              placeholder="e.g. session or admin.impersonation"
            />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Outcome</span>
            <select name="outcome" class="sg-select">
              <option value="" selected={param_value(@current_params, "outcome") == ""}>Any</option>
              <option value="success" selected={param_value(@current_params, "outcome") == "success"}>
                Success
              </option>
              <option value="failure" selected={param_value(@current_params, "outcome") == "failure"}>
                Failure
              </option>
            </select>
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Actor</span>
            <input type="text" name="actor" value={param_value(@current_params, "actor")} class="sg-input" />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Occurred from</span>
            <input type="text" name="from" value={param_value(@current_params, "from")} class="sg-input" placeholder="2026-05-01" />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Occurred to</span>
            <input type="text" name="to" value={param_value(@current_params, "to")} class="sg-input" placeholder="2026-05-31" />
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

      <div :if={any_filter_active?(@current_params)} class="sg-cluster sg-cluster--start">
        <.applied_chip
          :for={chip <- applied_chips(@current_params)}
          label={chip.label}
          remove_href={remove_chip_path(@admin_scope, @detail.user.id, @current_params, @return_to, chip.key)}
        />
        <a href={clear_path(@admin_scope, @detail.user.id, @return_to)} class="sg-btn sg-btn--ghost sg-btn--sm">
          Clear all
        </a>
      </div>

      <div
        :if={@rows != []}
        id="admin-audit-user-desktop-results"
        data-testid="admin-audit-user-desktop-results"
        class="sg-table-panel sg-show-desktop"
      >
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
            <tr :for={row <- @rows} data-tone={audit_tone(row)}>
              <td class="sg-nowrap">
                <div class="sg-stack sg-stack--1">
                  <span class="sg-text-sm">{format_timestamp(row.inserted_at)}</span>
                  <code class="sg-code">{row.id}</code>
                </div>
              </td>
              <td>
                <div class="sg-stack sg-stack--1">
                  <div class="sg-cluster sg-cluster--2">
                    <span class="sg-status-pill" data-tone={audit_tone(row)}>{row.action_label}</span>
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
              <td class="sg-show-desktop sg-text-sm">
                <span :if={audit_tone(row) == "risk"} class="sg-status-pill" data-tone="risk">{row.outcome}</span>
                <span :if={audit_tone(row) != "risk"} class="sg-muted">{row.outcome}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        :if={@rows != []}
        id="admin-audit-user-mobile-results"
        data-testid="admin-audit-user-mobile-results"
        class="sg-stack sg-stack--3 sg-show-mobile"
      >
        <.audit_row :for={row <- @rows} row={row} show_detail show_codes />
      </div>

      <.empty_state :if={@rows == []} title="No audit events for this user">
        <p class="sg-muted sg-text-sm">No scoped events are currently tied to this user.</p>
        <div :if={any_filter_active?(@current_params)} class="sg-cluster sg-cluster--center">
          <a
            href={clear_path(@admin_scope, @detail.user.id, @return_to)}
            class="sg-btn sg-btn--secondary sg-btn--sm"
          >
            Clear all filters
          </a>
        </div>
      </.empty_state>

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

  # Severity tone: unified body matching audit_tone/1 in Sigra.Admin.Components (D-10).
  # Failures surface as risk, impersonation as info, routine success stays neutral.
  defp audit_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
  defp audit_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
  defp audit_tone(_row), do: nil

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

  @chip_keys ~w(actor action_prefix outcome from to)

  defp any_filter_active?(params), do: Enum.any?(@chip_keys, &present_param?(params, &1))

  defp applied_chips(params) do
    for key <- @chip_keys, present_param?(params, key) do
      %{key: key, label: chip_label(key, param_value(params, key))}
    end
  end

  defp chip_label("outcome", value), do: "Outcome: " <> humanize_outcome(value)
  defp chip_label("action_prefix", value), do: "Action: " <> value
  defp chip_label("from", value), do: "From: " <> value
  defp chip_label("to", value), do: "To: " <> value
  defp chip_label("actor", value), do: "Actor: " <> value

  defp humanize_outcome("success"), do: "Success"
  defp humanize_outcome("failure"), do: "Failure"
  defp humanize_outcome(value), do: value

  # Drop one filter key, preserve the rest + return_to, reset cursor pagination.
  defp remove_chip_path(admin_scope, user_id, params, return_to, key) do
    admin_scope
    |> index_path(user_id)
    |> append_query(
      params
      |> Map.delete(key)
      |> Map.delete("cursor")
      |> Map.put("return_to", return_to)
    )
  end

  defp present_param?(params, key), do: param_value(params, key) not in [nil, ""]

  defp format_timestamp(%DateTime{} = timestamp),
    do: Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S")

  defp format_timestamp(_timestamp), do: ""
end
