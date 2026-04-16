defmodule Sigra.Admin.Live.UsersIndexLive do
  @moduledoc """
  Admin user index for global and organization-scoped user operations.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Hooks
  alias Sigra.Admin.Users.Query

  @quick_filter_keys ~w(confirmed mfa passkeys locked deleted)
  @more_filter_keys ~w(provider registered_from registered_to organization)

  @impl true
  def mount(_params, _session, socket) do
    config = runtime_config!()
    hooks = Hooks.resolve(config)

    {:ok,
     socket
     |> assign(:sigra_config, config)
     |> assign(:hooks_module, hooks)
     |> assign(:quick_filter_keys, @quick_filter_keys)
     |> assign(:more_filter_keys, @more_filter_keys)
     |> assign(:filters_open?, false)
     |> assign(:page_title, "Users")
     |> assign(:rows, [])
     |> assign(:summary_counts, %{})
     |> assign(:meta, nil)
     |> assign(:current_params, %{})}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    admin_scope = socket.assigns.admin_scope
    config = socket.assigns.sigra_config

    with {:ok, {rows, meta, normalized}} <- Query.list_users(config, admin_scope, params) do
      {:noreply,
       socket
       |> assign(:rows, rows)
       |> assign(:meta, meta)
       |> assign(:summary_counts, Query.summary_counts(config, admin_scope))
       |> assign(:current_params, normalized)
       |> assign(:filters_open?, filters_open?(normalized))
       |> assign(:page_title, page_title(admin_scope))}
    else
      {:error, _meta} ->
        {:noreply,
         socket
         |> put_flash(:error, "We couldn't load this user data. Refresh the page, then try again.")
         |> assign(:rows, [])
         |> assign(:meta, nil)
         |> assign(:summary_counts, %{})
         |> assign(:current_params, %{})}
    end
  end

  @impl true
  def handle_event("toggle_filters", _params, socket) do
    {:noreply, update(socket, :filters_open?, &(!&1))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <header class="space-y-3">
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold">{page_heading(@admin_scope)}</h1>
          <p class="text-sm text-base-content/70">{scope_copy(@admin_scope)}</p>
        </div>

        <div class="flex flex-wrap gap-2">
          <.summary_chip label="Total" value={Map.get(@summary_counts, :total, 0)} />
          <.summary_chip label="Confirmed" value={Map.get(@summary_counts, :confirmed, 0)} />
          <.summary_chip label="MFA" value={Map.get(@summary_counts, :mfa, 0)} />
          <.summary_chip label="Passkeys" value={Map.get(@summary_counts, :passkeys, 0)} />
          <.summary_chip label="Locked" value={Map.get(@summary_counts, :locked, 0)} />
          <.summary_chip label="Deleted" value={Map.get(@summary_counts, :deleted, 0)} />
        </div>
      </header>

      <form method="get" action={index_path(@admin_scope)} class="space-y-4 rounded-lg border border-base-300 bg-base-200 p-4">
        <div class="grid gap-3 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-end">
          <label class="form-control w-full">
            <span class="label-text text-sm font-semibold">Search</span>
            <input
              type="text"
              name="q"
              value={param_value(@current_params, "q")}
              placeholder="Email, user id, or name"
              class="input input-bordered w-full"
            />
          </label>

          <div class="flex gap-2">
            <button type="submit" class="btn btn-primary">Search</button>
            <a href={index_path(@admin_scope)} class="btn btn-ghost">Clear</a>
          </div>
        </div>

        <div class="flex flex-wrap gap-2">
          <.quick_filter :for={key <- @quick_filter_keys} key={key} params={@current_params} />
        </div>

        <div class="space-y-3 rounded-md border border-base-300 bg-base-100 p-3">
          <button
            type="button"
            phx-click="toggle_filters"
            class="btn btn-sm btn-ghost px-0"
            aria-expanded={to_string(@filters_open?)}
          >
            More filters
          </button>

          <div :if={@filters_open?} class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
            <label class="form-control">
              <span class="label-text text-sm font-semibold">Organization</span>
              <input
                type="text"
                name="organization"
                value={param_value(@current_params, "organization")}
                class="input input-bordered w-full"
              />
            </label>

            <label class="form-control">
              <span class="label-text text-sm font-semibold">Provider</span>
              <select name="provider" class="select select-bordered w-full">
                <option value="">Any</option>
                <option value="local" selected={param_value(@current_params, "provider") == "local"}>Local</option>
                <option value="google" selected={param_value(@current_params, "provider") == "google"}>Google</option>
                <option value="github" selected={param_value(@current_params, "provider") == "github"}>GitHub</option>
              </select>
            </label>

            <label class="form-control">
              <span class="label-text text-sm font-semibold">Registered from</span>
              <input
                type="date"
                name="registered_from"
                value={param_value(@current_params, "registered_from")}
                class="input input-bordered w-full"
              />
            </label>

            <label class="form-control">
              <span class="label-text text-sm font-semibold">Registered to</span>
              <input
                type="date"
                name="registered_to"
                value={param_value(@current_params, "registered_to")}
                class="input input-bordered w-full"
              />
            </label>
          </div>
        </div>

        <input type="hidden" name="page_size" value={param_value(@current_params, "page_size", "25")} />
        <input type="hidden" name="order_by" value={param_value(@current_params, "order_by", "inserted_at")} />
        <input type="hidden" name="order_direction" value={param_value(@current_params, "order_direction", "desc")} />
      </form>

      <div
        id="admin-users-desktop-results"
        data-testid="admin-users-desktop-results"
        class="hidden overflow-x-auto lg:block"
      >
        <table class="table w-full">
          <thead>
            <tr>
              <th><a href={sort_path(@admin_scope, @current_params, "inserted_at")}>User</a></th>
              <th>Status</th>
              <th>Organizations</th>
              <th>Activity</th>
              <th class="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <td class="align-top">
                <div class="space-y-1">
                  <p class="font-semibold">{primary_name(row)}</p>
                  <p class="text-sm text-base-content/70">{row.user.email}</p>
                  <code class="text-xs select-all">{row.user.id}</code>
                </div>
              </td>
              <td class="align-top">
                <div class="space-y-1 text-sm">
                  <p>{confirmation_label(row)}</p>
                  <p>{mfa_label(row)}</p>
                  <p>{lock_label(row)}</p>
                  <p>{deletion_label(row)}</p>
                  <p :for={badge <- row.extra_badges}>{badge_text(badge)}</p>
                </div>
              </td>
              <td class="align-top">
                <div class="space-y-1 text-sm">
                  <p>{row.organization_summary}</p>
                  <p>{pluralize(row.organization_count, "organization")}</p>
                </div>
              </td>
              <td class="align-top">
                <div class="space-y-1 text-sm">
                  <p>{activity_label(row)}</p>
                  <p>{registered_label(row)}</p>
                  <p :for={column <- row.extra_columns}>{column_text(column, row.user)}</p>
                </div>
              </td>
              <td class="align-top text-right">
                <a class="btn btn-sm btn-primary" href={open_user_path(@admin_scope, row.user.id, @current_params)}>
                  Open user
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        id="admin-users-mobile-results"
        data-testid="admin-users-mobile-results"
        class="space-y-3 lg:hidden"
      >
        <article :for={row <- @rows} class="rounded-lg border border-base-300 bg-base-200 p-4">
          <div class="space-y-1">
            <p class="font-semibold">{primary_name(row)}</p>
            <p class="text-sm text-base-content/70">{row.user.email}</p>
            <code class="text-xs select-all">{row.user.id}</code>
          </div>

          <div class="mt-3 space-y-1 text-sm">
            <p>{confirmation_label(row)}</p>
            <p>{mfa_label(row)}</p>
            <p>{lock_label(row)}</p>
            <p>{deletion_label(row)}</p>
            <p>{row.organization_summary}</p>
            <p>{activity_label(row)}</p>
            <p>{registered_label(row)}</p>
            <p :for={badge <- row.extra_badges}>{badge_text(badge)}</p>
            <p :for={column <- row.extra_columns}>{column_text(column, row.user)}</p>
          </div>

          <div class="mt-4">
            <a class="btn btn-sm btn-primary w-full" href={open_user_path(@admin_scope, row.user.id, @current_params)}>
              Open user
            </a>
          </div>
        </article>
      </div>

      <div :if={@rows == []} class="rounded-lg border border-dashed border-base-300 bg-base-100 p-6 text-sm text-base-content/70">
        <p class="font-semibold">No users match this view</p>
        <p class="mt-1">Try a different search or clear one or more filters to widen the result set.</p>
      </div>

      <nav :if={@meta} class="flex items-center justify-between">
        <a
          class={["btn btn-sm", if(@meta.previous_page, do: "", else: "btn-disabled")]}
          href={page_path(@admin_scope, @current_params, @meta.previous_page)}
          aria-disabled={to_string(is_nil(@meta.previous_page))}
        >
          Previous page
        </a>
        <span class="text-sm text-base-content/70">Page {(@meta.current_page || 1)}</span>
        <a
          class={["btn btn-sm", if(@meta.next_page, do: "", else: "btn-disabled")]}
          href={page_path(@admin_scope, @current_params, @meta.next_page)}
          aria-disabled={to_string(is_nil(@meta.next_page))}
        >
          Next page
        </a>
      </nav>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp summary_chip(assigns) do
    ~H"""
    <div class="rounded-md border border-base-300 bg-base-100 px-3 py-2 text-sm">
      <span class="font-semibold">{@label}</span>
      <span class="ml-2 text-base-content/70">{@value}</span>
    </div>
    """
  end

  attr :key, :string, required: true
  attr :params, :map, required: true

  defp quick_filter(assigns) do
    ~H"""
    <label class="label cursor-pointer gap-2 rounded-md border border-base-300 bg-base-100 px-3 py-2">
      <input
        type="checkbox"
        name={@key}
        value="true"
        checked={param_true?(@params, @key)}
        class="checkbox checkbox-sm"
      />
      <span class="label-text capitalize">{String.replace(@key, "_", " ")}</span>
    </label>
    """
  end

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

  defp page_title(%Scope{mode: :global}), do: "Users"
  defp page_title(%Scope{organization: %{name: name}}), do: "#{name} Users"
  defp page_title(_), do: "Users"

  defp page_heading(%Scope{mode: :global}), do: "Users"
  defp page_heading(%Scope{organization: %{name: name}}), do: "#{name} users"
  defp page_heading(_), do: "Users"

  defp scope_copy(%Scope{mode: :global}), do: "Global user operations"
  defp scope_copy(%Scope{organization: %{name: name}}), do: "Organization-scoped user operations for #{name}"
  defp scope_copy(_), do: "User operations"

  defp filters_open?(params), do: Enum.any?(@more_filter_keys, &present_param?(params, &1))

  defp present_param?(params, key), do: param_value(params, key) not in [nil, ""]

  defp param_value(params, key, default \\ ""), do: Map.get(params, key, default)

  defp param_true?(params, key), do: Map.get(params, key) == "true"

  defp sort_path(admin_scope, params, field) do
    next_direction =
      if Map.get(params, "order_by") == field and Map.get(params, "order_direction") == "asc",
        do: "desc",
        else: "asc"

    admin_scope
    |> index_path()
    |> append_query(
      params
      |> Map.put("order_by", field)
      |> Map.put("order_direction", next_direction)
      |> Map.put("page", "1")
    )
  end

  defp page_path(_admin_scope, _params, nil), do: "#"

  defp page_path(admin_scope, params, page) do
    admin_scope
    |> index_path()
    |> append_query(Map.put(params, "page", to_string(page)))
  end

  defp open_user_path(admin_scope, user_id, params) do
    base =
      case admin_scope do
        %Scope{mode: :organization, organization_slug: slug} when is_binary(slug) ->
          "/admin/organizations/#{slug}/users/#{user_id}"

        _ ->
          "/admin/users/#{user_id}"
      end

    return_to =
      admin_scope
      |> index_path()
      |> append_query(params)

    base <> "?return_to=" <> URI.encode_www_form(return_to)
  end

  defp index_path(%Scope{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/users"

  defp index_path(_admin_scope), do: "/admin/users"

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

  defp confirmation_label(row),
    do: "Confirmation: " <> if(row.user.confirmed_at, do: "Confirmed", else: "Unconfirmed")

  defp primary_name(row) do
    Map.get(row.user, :display_name) || row.display_name || row.user.email
  end

  defp mfa_label(row) do
    "Security: " <>
      cond do
        row.has_mfa and row.passkey_count > 0 -> "MFA and passkeys enabled"
        row.has_mfa -> "MFA enabled"
        row.passkey_count > 0 -> "Passkeys enabled"
        true -> "No MFA or passkeys"
      end
  end

  defp lock_label(row), do: "Lockout: " <> if(row.user.locked_at, do: "Locked", else: "Active")
  defp deletion_label(row), do: "Deletion: " <> if(row.user.deleted_at, do: "Deleted", else: "Active")

  defp activity_label(row) do
    case row.last_active_at do
      %DateTime{} = at -> "Last activity: " <> Calendar.strftime(at, "%Y-%m-%d %H:%M")
      _ -> "Last activity: Not available"
    end
  end

  defp registered_label(row) do
    "Registered: " <> Calendar.strftime(row.user.inserted_at, "%Y-%m-%d")
  end

  defp badge_text(%{label: label}) when is_binary(label), do: label
  defp badge_text(badge) when is_binary(badge), do: badge
  defp badge_text(_badge), do: ""

  defp column_text(%{label: label, value: value}, _user) when is_binary(label) and is_binary(value),
    do: "#{label}: #{value}"

  defp column_text(%{label: label, field: field}, user) when is_binary(label) and is_atom(field),
    do: "#{label}: #{Map.get(user, field)}"

  defp column_text(_column, _user), do: ""

  defp pluralize(1, singular), do: "1 #{singular}"
  defp pluralize(count, singular), do: "#{count} #{singular}s"
end
