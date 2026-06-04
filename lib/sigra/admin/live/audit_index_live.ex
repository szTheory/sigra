defmodule Sigra.Admin.Live.AuditIndexLive do
  @moduledoc """
  Global and organization-scoped audit explorer.
  """

  use Phoenix.LiveView

  import Sigra.Admin.Components

  alias Sigra.Admin.Audit.Explorer
  alias Sigra.Admin.Scope

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sigra_config, runtime_config!())
     |> assign(:rows, [])
     |> assign(:meta, nil)
     |> assign(:current_params, %{})
     |> assign(:page_title, "Audit")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case Explorer.list_events(socket.assigns.sigra_config, socket.assigns.admin_scope, params) do
      {:ok, {rows, meta, current_params}} ->
        {:noreply,
         socket
         |> assign(:rows, rows)
         |> assign(:meta, meta)
         |> assign(:current_params, current_params)
         |> assign(:page_title, page_title(socket.assigns.admin_scope))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "We couldn't load this audit view. Refresh the page, then try again."
         )
         |> assign(:rows, [])
         |> assign(:meta, nil)
         |> assign(:current_params, %{})}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="sg-stack sg-stack--6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Audit evidence</p>
        <h1 class="sg-page-title">Audit</h1>
      </header>
      <.scope_ribbon copy={scope_copy(@admin_scope)} />

      <form method="get" action={index_path(@admin_scope)} class="sg-filter-panel sg-stack">
        <div class="sg-form-grid sg-form-grid--cols">
          <label class="sg-field">
            <span class="sg-field-label">Actor</span>
            <input type="text" name="actor" value={param_value(@current_params, "actor")} class="sg-input" />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Effective user</span>
            <input type="text" name="effective_user" value={param_value(@current_params, "effective_user")} class="sg-input" />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Action prefix</span>
            <input
              type="text"
              name="action_prefix"
              value={param_value(@current_params, "action_prefix")}
              class="sg-input"
              placeholder="e.g. auth or admin.impersonation"
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
            <span class="sg-field-label">Occurred from</span>
            <input type="date" name="from" value={param_value(@current_params, "from")} class="sg-input" />
          </label>

          <label class="sg-field">
            <span class="sg-field-label">Occurred to</span>
            <input type="date" name="to" value={param_value(@current_params, "to")} class="sg-input" />
          </label>
        </div>

        <div class="sg-cluster">
          <button type="submit" class="sg-btn sg-btn--primary">Apply filters</button>
          <a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost">Clear</a>
          <a href={export_path(@admin_scope, @current_params)} class="sg-btn sg-btn--secondary">Export CSV</a>
        </div>

        <input type="hidden" name="page_size" value={param_value(@current_params, "page_size", "25")} />
        <input type="hidden" name="order_by" value={param_value(@current_params, "order_by", "inserted_at")} />
        <input type="hidden" name="order_direction" value={param_value(@current_params, "order_direction", "desc")} />
      </form>

      <div :if={any_filter_active?(@current_params)} class="sg-cluster sg-cluster--start">
        <.applied_chip
          :for={chip <- applied_chips(@current_params)}
          label={chip.label}
          remove_href={remove_chip_path(@admin_scope, @current_params, chip.key)}
        />
        <a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
      </div>

      <div :if={@rows != []} class="sg-table-panel">
        <table class="sg-table">
          <thead>
            <tr>
              <th><a href={sort_path(@admin_scope, @current_params, "inserted_at")}>Occurred</a></th>
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
              <td class="sg-show-desktop sg-text-sm">
                <span :if={row_tone(row) == "risk"} class="sg-status-pill" data-tone="risk">{row.outcome}</span>
                <span :if={row_tone(row) != "risk"} class="sg-muted">{row.outcome}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.empty_state :if={@rows == []} title="No audit events match this view">
        <%= if any_filter_active?(@current_params) do %>
          <p class="sg-muted sg-text-sm">No audit events match the active filters. Clear one or more to widen the timeline.</p>
          <div class="sg-cluster sg-cluster--center">
            <a href={index_path(@admin_scope)} class="sg-btn sg-btn--secondary sg-btn--sm">Clear all filters</a>
          </div>
        <% else %>
          <p class="sg-muted sg-text-sm">Audit events appear here as activity is recorded. Adjust the filters above to focus on a specific actor, outcome, or time range.</p>
        <% end %>
      </.empty_state>

      <nav :if={@meta} class="sg-cluster sg-cluster--between">
        <a
          class={["sg-btn sg-btn--secondary sg-btn--icon", if(@meta.previous_page, do: "", else: "is-disabled")]}
          href={page_path(@admin_scope, @current_params, @meta.previous_page)}
          aria-disabled={to_string(is_nil(@meta.previous_page))}
          aria-label="Previous page"
        >
          <span aria-hidden="true">&larr;</span>
          <span class="sr-only">Previous page</span>
        </a>
        <span class="sg-muted sg-text-sm">Page {@meta.current_page || 1}</span>
        <a
          class={["sg-btn sg-btn--secondary sg-btn--icon", if(@meta.next_page, do: "", else: "is-disabled")]}
          href={page_path(@admin_scope, @current_params, @meta.next_page)}
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

  # Severity tone: failures pop as risk, impersonation as info, routine success
  # stays calm (neutral zebra). Keeps the timeline scannable, not a wall.
  defp row_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
  defp row_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
  defp row_tone(_row), do: nil

  defp runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError,
              "Sigra admin audit explorer requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "Sigra admin audit explorer requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end

  defp page_title(%Scope{mode: :organization, organization: %{name: name}}), do: "#{name} Audit"
  defp page_title(_admin_scope), do: "Audit"

  defp scope_copy(%Scope{mode: :organization, organization: %{name: name}}),
    do: "Organization-scoped audit explorer for #{name}"

  defp scope_copy(_admin_scope), do: "Global audit explorer"

  defp param_value(params, key, default \\ ""), do: Map.get(params, key, default)

  @chip_keys ~w(actor effective_user action_prefix outcome from to)

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
  defp chip_label("effective_user", value), do: "Effective user: " <> value

  defp humanize_outcome("success"), do: "Success"
  defp humanize_outcome("failure"), do: "Failure"
  defp humanize_outcome(value), do: value

  defp remove_chip_path(admin_scope, params, key) do
    admin_scope
    |> index_path()
    |> append_query(params |> Map.delete(key) |> Map.delete("cursor"))
  end

  defp present_param?(params, key), do: param_value(params, key) not in [nil, ""]

  defp format_timestamp(%DateTime{} = timestamp),
    do: Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S")

  defp format_timestamp(_timestamp), do: ""

  defp sort_path(admin_scope, params, field) do
    next_direction =
      if Map.get(params, "order_by") == field and Map.get(params, "order_direction") == "desc",
        do: "asc",
        else: "desc"

    admin_scope
    |> index_path()
    |> append_query(
      params
      |> Map.put("order_by", field)
      |> Map.put("order_direction", next_direction)
      |> Map.delete("cursor")
    )
  end

  defp page_path(_admin_scope, _params, nil), do: "#"

  defp page_path(admin_scope, params, cursor) do
    admin_scope
    |> index_path()
    |> append_query(Map.put(params, "cursor", cursor))
  end

  defp index_path(%Scope{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/audit"

  defp index_path(_admin_scope), do: "/admin/audit"

  defp export_path(%Scope{mode: :organization, organization_slug: slug}, params)
       when is_binary(slug) do
    append_query("/admin/organizations/#{slug}/audit/export.csv", params)
  end

  defp export_path(_admin_scope, params), do: append_query("/admin/audit/export.csv", params)

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
end
