defmodule Sigra.Admin.Live.AuditIndexLive do
  @moduledoc """
  Global and organization-scoped audit explorer.
  """

  use Phoenix.LiveView

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
    <section class="space-y-6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Audit evidence</p>
        <h1 class="sg-page-title text-3xl font-semibold">Audit</h1>
        <p class="sg-page-copy text-sm text-base-content/70">{scope_copy(@admin_scope)}</p>
      </header>

      <form method="get" action={index_path(@admin_scope)} class="sg-filter-panel space-y-4 rounded-lg border border-base-300 bg-base-200 p-4">
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <label class="form-control">
            <span class="label-text text-sm font-semibold">Actor</span>
            <input type="text" name="actor" value={param_value(@current_params, "actor")} class="sg-input input input-bordered w-full" />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Effective user</span>
            <input type="text" name="effective_user" value={param_value(@current_params, "effective_user")} class="sg-input input input-bordered w-full" />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Action prefix</span>
            <input type="text" name="action_prefix" value={param_value(@current_params, "action_prefix")} class="sg-input input input-bordered w-full" />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Outcome</span>
            <input type="text" name="outcome" value={param_value(@current_params, "outcome")} class="sg-input input input-bordered w-full" />
          </label>
        </div>

        <div class="flex flex-wrap gap-2">
          <button type="submit" class="sg-press btn btn-primary min-h-11">Apply filters</button>
          <a href={index_path(@admin_scope)} class="sg-press btn btn-ghost min-h-11">Clear</a>
          <a href={export_path(@admin_scope, @current_params)} class="sg-press btn btn-outline min-h-11">
            Export CSV
          </a>
        </div>

        <input type="hidden" name="page_size" value={param_value(@current_params, "page_size", "25")} />
        <input type="hidden" name="order_by" value={param_value(@current_params, "order_by", "inserted_at")} />
        <input type="hidden" name="order_direction" value={param_value(@current_params, "order_direction", "desc")} />
      </form>

      <div class="sg-table-panel overflow-x-auto">
        <table class="table w-full">
          <thead>
            <tr>
              <th><a href={sort_path(@admin_scope, @current_params, "inserted_at")}>Occurred</a></th>
              <th>Action</th>
              <th>Actor</th>
              <th class="hidden md:table-cell">Outcome</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <td class="align-top">
                <div class="space-y-1">
                  <p>{format_timestamp(row.inserted_at)}</p>
                  <code class="sg-code text-xs">{row.id}</code>
                </div>
              </td>
              <td class="align-top">
                <div class="space-y-1">
                  <span :if={row.action_badge} class="badge badge-warning badge-sm">{row.action_badge}</span>
                  <p class="font-semibold">{row.action_label}</p>
                  <p class="text-sm text-base-content/70">{row.action}</p>
                </div>
              </td>
              <td class="align-top">
                <div class="space-y-1">
                  <p>{row.actor_summary}</p>
                  <p :if={row.action_badge} class="text-sm text-base-content/70">Actor: {row.actor_label}</p>
                  <p :if={row.action_badge} class="text-sm text-base-content/70">
                    Effective user: {row.effective_user_label}
                  </p>
                </div>
              </td>
              <td class="hidden align-top md:table-cell">{row.outcome}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@rows == []} class="sg-card rounded-lg border border-dashed border-base-300 bg-base-100 p-6 text-sm text-base-content/70">
        <p class="font-semibold">No audit events match this view</p>
        <p class="mt-1">Try a different filter or clear one or more params to widen the result set.</p>
      </div>

      <nav :if={@meta} class="flex items-center justify-between gap-3">
        <a
          class={[
            "sg-press btn btn-outline min-h-11 min-w-11 px-3",
            if(@meta.previous_page, do: "", else: "btn-disabled")
          ]}
          href={page_path(@admin_scope, @current_params, @meta.previous_page)}
          aria-disabled={to_string(is_nil(@meta.previous_page))}
          aria-label="Previous page"
        >
          <span aria-hidden="true">&larr;</span>
          <span class="sr-only">Previous page</span>
        </a>
        <span class="text-sm text-base-content/70">Page {(@meta.current_page || 1)}</span>
        <a
          class={[
            "sg-press btn btn-outline min-h-11 min-w-11 px-3",
            if(@meta.next_page, do: "", else: "btn-disabled")
          ]}
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
