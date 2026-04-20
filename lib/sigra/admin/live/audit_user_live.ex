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
    <section :if={@detail} class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <a class="btn btn-ghost min-h-11" href={@return_to}>Back to user</a>
        <span class="text-sm text-base-content/70">{scope_copy(@admin_scope)}</span>
      </div>

      <header class="space-y-1 rounded-lg border border-base-300 bg-base-100 p-5">
        <h1 class="text-2xl font-semibold">{@detail.display_name || @detail.user.email}</h1>
        <p class="text-sm text-base-content/70">{@detail.user.email}</p>
        <code class="text-xs select-all">{@detail.user.id}</code>
      </header>

      <form method="get" action={index_path(@admin_scope, @detail.user.id)} class="space-y-4 rounded-lg border border-base-300 bg-base-200 p-4">
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <label class="form-control">
            <span class="label-text text-sm font-semibold">Action prefix</span>
            <input type="text" name="action_prefix" value={param_value(@current_params, "action_prefix")} class="input input-bordered w-full" />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Outcome</span>
            <input type="text" name="outcome" value={param_value(@current_params, "outcome")} class="input input-bordered w-full" />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Actor</span>
            <input type="text" name="actor" value={param_value(@current_params, "actor")} class="input input-bordered w-full" />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Occurred after</span>
            <input type="text" name="from" value={param_value(@current_params, "from")} class="input input-bordered w-full" />
          </label>
        </div>

        <div class="flex flex-wrap gap-2">
          <button type="submit" class="btn btn-primary min-h-11">Apply filters</button>
          <a href={clear_path(@admin_scope, @detail.user.id, @return_to)} class="btn btn-ghost min-h-11">Clear</a>
          <a href={export_path(@admin_scope, @detail.user.id, export_params(@current_params, @return_to))} class="btn btn-outline min-h-11">
            Export CSV
          </a>
        </div>

        <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />
        <input type="hidden" name="page_size" value={param_value(@current_params, "page_size", "25")} />
        <input type="hidden" name="order_by" value={param_value(@current_params, "order_by", "inserted_at")} />
        <input type="hidden" name="order_direction" value={param_value(@current_params, "order_direction", "desc")} />
      </form>

      <div class="overflow-x-auto">
        <table class="table w-full">
          <thead>
            <tr>
              <th><a href={sort_path(@admin_scope, @detail.user.id, @current_params, "inserted_at")}>Occurred</a></th>
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
                  <code class="text-xs">{row.id}</code>
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

      <div :if={@rows == []} class="rounded-lg border border-dashed border-base-300 bg-base-100 p-6 text-sm text-base-content/70">
        <p class="font-semibold">No audit events match this user view</p>
        <p class="mt-1">Try a different filter or clear one or more params to widen the result set.</p>
      </div>

      <nav :if={@meta} class="flex items-center justify-between gap-3">
        <a
          class={[
            "btn btn-outline min-h-11 min-w-11 px-3",
            if(@meta.previous_page, do: "", else: "btn-disabled")
          ]}
          href={page_path(@admin_scope, @detail.user.id, @current_params, @meta.previous_page)}
          aria-disabled={to_string(is_nil(@meta.previous_page))}
          aria-label="Previous page"
        >
          <span aria-hidden="true">&larr;</span>
          <span class="sr-only">Previous page</span>
        </a>
        <span class="text-sm text-base-content/70">Page {(@meta.current_page || 1)}</span>
        <a
          class={[
            "btn btn-outline min-h-11 min-w-11 px-3",
            if(@meta.next_page, do: "", else: "btn-disabled")
          ]}
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
