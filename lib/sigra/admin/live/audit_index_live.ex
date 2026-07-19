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
      <.scope_ribbon copy={scope_copy(@admin_scope)} />

      <header class="sg-page-header">
        <p class="sg-page-kicker">Audit evidence</p>
        <h1 class="sg-page-title">Audit</h1>
      </header>

      <nav class="sg-cluster" aria-label="Audit filter presets">
        <a
          href={preset_path(@admin_scope, @current_params, "outcome", "failure")}
          class="sg-btn sg-btn--secondary sg-btn--sm"
          aria-current={param_value(@current_params, "outcome") == "failure" && "page"}
        >
          Failures
        </a>
        <a
          href={preset_path(@admin_scope, @current_params, "action_prefix", "admin.impersonation")}
          class="sg-btn sg-btn--secondary sg-btn--sm"
          aria-current={param_value(@current_params, "action_prefix") == "admin.impersonation" && "page"}
        >
          Impersonation
        </a>
      </nav>

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
              <option value="success" selected={param_value(@current_params, "outcome") == "success"}>Success</option>
              <option value="failure" selected={param_value(@current_params, "outcome") == "failure"}>Failure</option>
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

      <section
        :if={any_filter_active?(@current_params)}
        class="sg-stack sg-stack--2"
        aria-labelledby="admin-audit-active-filters"
      >
        <h2 id="admin-audit-active-filters" class="sg-field-label">Active filters</h2>
        <div class="sg-cluster sg-cluster--start">
          <.applied_chip
            :for={chip <- applied_chips(@current_params)}
            label={chip.label}
            remove_href={remove_chip_path(@admin_scope, @current_params, chip.key)}
          />
          <a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
        </div>
      </section>

      <div
        :if={@rows != []}
        id="admin-audit-desktop-results"
        data-testid="admin-audit-desktop-results"
        class="sg-table-panel sg-show-desktop"
      >
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
            <.audit_table_row :for={row <- @rows} row={row} />
          </tbody>
        </table>
      </div>

      <div
        :if={@rows != []}
        id="admin-audit-mobile-results"
        data-testid="admin-audit-mobile-results"
        class="sg-stack sg-stack--3 sg-show-mobile"
      >
        <.audit_row :for={row <- @rows} row={row} show_detail show_codes />
      </div>

      <.audit_empty_state :if={@rows == []} title="No audit events match this view">
        <%= if any_filter_active?(@current_params) do %>
          <p class="sg-muted sg-text-sm">No audit events match the active filters. Clear one or more to widen the timeline.</p>
          <div class="sg-cluster sg-cluster--center">
            <a href={index_path(@admin_scope)} class="sg-btn sg-btn--secondary sg-btn--sm">Clear all filters</a>
          </div>
        <% else %>
          <p class="sg-muted sg-text-sm">Audit events appear here as activity is recorded. Adjust the filters above to focus on a specific actor, outcome, or time range.</p>
        <% end %>
      </.audit_empty_state>

      <.audit_pagination_nav
        meta={@meta}
        prev_href={page_path(@admin_scope, @current_params, @meta && @meta.previous_page)}
        next_href={page_path(@admin_scope, @current_params, @meta && @meta.next_page)}
      />
    </section>
    """
  end

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

  defp preset_path(admin_scope, params, key, value) do
    next_params =
      if param_value(params, key) == value,
        do: Map.delete(params, key),
        else: Map.put(params, key, value)

    admin_scope
    |> index_path()
    |> append_query(Map.delete(next_params, "cursor"))
  end

  defp present_param?(params, key), do: param_value(params, key) not in [nil, ""]

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
