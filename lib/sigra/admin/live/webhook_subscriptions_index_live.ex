defmodule Sigra.Admin.Live.WebhookSubscriptionsIndexLive do
  @moduledoc """
  Global admin webhook subscription management surface.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Webhooks.Query

  @delivery_state_options [
    {"Any", ""},
    {"Retrying", "retrying"},
    {"Dead lettered", "dead_lettered"}
  ]

  @enabled_options [
    {"Any", ""},
    {"Enabled", "true"},
    {"Disabled", "false"}
  ]

  @presets [
    {"user_lifecycle", "User lifecycle"},
    {"sessions", "Sessions"},
    {"organization_membership", "Organization membership"},
    {"service_accounts", "Service accounts"},
    {"all", "All current Sigra webhook events"}
  ]

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> Map.get(session, "current_scope") end)
     |> assign_new(:admin_scope, fn -> Map.get(session, "admin_scope") end)
     |> assign(:sigra_config, runtime_config!())
     |> assign(:rows, [])
     |> assign(:meta, nil)
     |> assign(:current_params, %{})
     |> assign(:summary_counts, %{})
     |> assign(:delivery_state_options, @delivery_state_options)
     |> assign(:enabled_options, @enabled_options)
     |> assign(:presets, @presets)
     |> assign(:show_form?, false)
     |> assign(:editing_subscription, nil)
     |> assign(:form_state, default_form_state())
     |> assign(:page_title, "Webhook subscriptions")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    config = socket.assigns.sigra_config
    admin_scope = socket.assigns.admin_scope

    with {:ok, {rows, meta, normalized}} <- Query.list_subscriptions(config, admin_scope, params) do
      {:noreply,
       socket
       |> assign(:rows, rows)
       |> assign(:meta, meta)
       |> assign(:current_params, normalized)
       |> assign(:summary_counts, Query.summary_counts(config, admin_scope))}
    else
      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "We couldn't load this webhook view. Refresh the page, then try again."
         )
         |> assign(:rows, [])
         |> assign(:meta, nil)
         |> assign(:current_params, %{})
         |> assign(:summary_counts, %{})}
    end
  end

  @impl true
  def handle_event("open_create", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form?, true)
     |> assign(:editing_subscription, nil)
     |> assign(:form_state, default_form_state())}
  end

  def handle_event("open_edit", %{"id" => id}, socket) do
    subscription = config_subscription!(socket.assigns.sigra_config, id)

    {:noreply,
     socket
     |> assign(:show_form?, true)
     |> assign(:editing_subscription, subscription)
     |> assign(:form_state, %{
       "endpoint_url" => subscription.endpoint_url,
       "description" => subscription.description || "",
       "enabled" => subscription.enabled,
       "event_types" => subscription.event_types
     })}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form?, false)
     |> assign(:editing_subscription, nil)
     |> assign(:form_state, default_form_state())}
  end

  def handle_event("apply_preset", %{"preset" => preset}, socket) do
    {:noreply,
     update(socket, :form_state, fn form_state ->
       Map.put(form_state, "event_types", preset_event_types(preset))
     end)}
  end

  def handle_event("save_subscription", %{"subscription" => attrs}, socket) do
    attrs = normalize_subscription_attrs(attrs, socket.assigns.editing_subscription)

    result =
      case socket.assigns.editing_subscription do
        nil ->
          Sigra.Admin.Webhooks.Actions.create(
            socket.assigns.sigra_config,
            socket.assigns.admin_scope,
            attrs
          )

        subscription ->
          Sigra.Admin.Webhooks.Actions.update(
            socket.assigns.sigra_config,
            socket.assigns.admin_scope,
            subscription.id,
            attrs
          )
      end

    case result do
      {:ok, _subscription} ->
        message =
          if socket.assigns.editing_subscription do
            "Webhook subscription updated."
          else
            "Webhook subscription created."
          end

        {:noreply,
         socket
         |> assign(:show_form?, false)
         |> assign(:editing_subscription, nil)
         |> assign(:form_state, default_form_state())
         |> put_flash(:info, message)
         |> push_patch(to: subscriptions_index_path(socket.assigns.current_params))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:show_form?, true)
         |> assign(:form_state, merge_changeset_errors(attrs, changeset))
         |> put_flash(
           :error,
           "Enter a valid webhook URL. Production subscriptions must use HTTPS."
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <header class="space-y-3">
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold">Webhook subscriptions</h1>
          <p class="text-sm text-base-content/70">
            Manage signed outbound auth-event deliveries for this admin scope.
          </p>
        </div>

        <div class="flex flex-wrap gap-2">
          <.summary_chip label="Total" value={Map.get(@summary_counts, :total, 0)} />
          <.summary_chip label="Enabled" value={Map.get(@summary_counts, :enabled, 0)} />
          <.summary_chip label="Disabled" value={Map.get(@summary_counts, :disabled, 0)} />
          <.summary_chip label="Retrying" value={Map.get(@summary_counts, :retrying, 0)} />
          <.summary_chip label="Dead lettered" value={Map.get(@summary_counts, :dead_lettered, 0)} />
        </div>

        <div class="flex flex-wrap gap-2">
          <button type="button" phx-click="open_create" class="btn btn-primary min-h-11">
            Create subscription
          </button>
          <a href={failures_index_path()} class="btn btn-outline min-h-11">
            View failures and retrying deliveries
          </a>
        </div>
      </header>

      <form method="get" action={subscriptions_index_path()} class="space-y-4 rounded-lg border border-base-300 bg-base-200 p-4">
        <div class="grid gap-3 lg:grid-cols-[minmax(0,1fr)_minmax(0,180px)_minmax(0,220px)_auto] lg:items-end">
          <label class="form-control">
            <span class="label-text text-sm font-semibold">Search</span>
            <input
              type="text"
              name="q"
              value={Map.get(@current_params, "q", "")}
              placeholder="Description or endpoint URL"
              class="input input-bordered w-full"
            />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Enabled</span>
            <select name="enabled" class="select select-bordered w-full">
              <option :for={{value, label} <- Enum.map(@enabled_options, fn {label, value} -> {value, label} end)} value={value} selected={enabled_param_value(@current_params) == value}>
                {label}
              </option>
            </select>
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Delivery state</span>
            <select name="delivery_state" class="select select-bordered w-full">
              <option :for={{value, label} <- Enum.map(@delivery_state_options, fn {label, value} -> {value, label} end)} value={value} selected={Map.get(@current_params, "delivery_state", "") == value}>
                {label}
              </option>
            </select>
          </label>

          <div class="grid grid-cols-2 gap-2 lg:flex">
            <button type="submit" class="btn btn-primary min-h-11">Apply filters</button>
            <a href={subscriptions_index_path()} class="btn btn-ghost min-h-11">Clear</a>
          </div>
        </div>

        <input type="hidden" name="page_size" value={Map.get(@current_params, "page_size", "25")} />
        <input type="hidden" name="order_by" value={Map.get(@current_params, "order_by", "inserted_at")} />
        <input type="hidden" name="order_direction" value={Map.get(@current_params, "order_direction", "desc")} />
      </form>

      <section :if={@show_form?} class="rounded-lg border border-base-300 bg-base-100 p-5">
        <div class="flex items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold">
              {if @editing_subscription, do: "Edit webhook subscription", else: "Create webhook subscription"}
            </h2>
            <p class="mt-1 text-sm text-base-content/70">
              Sigra sends signed auth events. Your host app owns the receiver endpoint, verification, dedupe, and downstream automation.
            </p>
          </div>

          <button type="button" phx-click="cancel_form" class="btn btn-ghost min-h-11">
            {if @editing_subscription, do: "Keep editing", else: "Close form"}
          </button>
        </div>

        <form id="webhook-subscription-form" phx-submit="save_subscription" class="mt-4 space-y-4">
          <label class="form-control">
            <span class="label-text text-sm font-semibold">Endpoint URL</span>
            <input
              type="text"
              name="subscription[endpoint_url]"
              value={Map.get(@form_state, "endpoint_url", "")}
              class="input input-bordered w-full"
            />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Description (optional)</span>
            <input
              type="text"
              name="subscription[description]"
              value={Map.get(@form_state, "description", "")}
              class="input input-bordered w-full"
            />
          </label>

          <label class="label min-h-11 cursor-pointer justify-start gap-3 rounded-md border border-base-300 bg-base-200 px-4 py-3">
            <input
              type="hidden"
              name="subscription[enabled]"
              value="false"
            />
            <input
              type="checkbox"
              name="subscription[enabled]"
              value="true"
              checked={Map.get(@form_state, "enabled", true)}
              class="checkbox"
            />
            <span class="label-text font-semibold">Subscription enabled</span>
          </label>

          <section class="space-y-3">
            <div>
              <h3 class="text-lg font-semibold">Event scope</h3>
              <p class="text-sm text-base-content/70">Start with a preset, then save an explicit event list.</p>
            </div>

            <div class="space-y-2">
              <p class="text-sm font-semibold">Start with a preset</p>
              <div class="flex flex-wrap gap-2">
                <button
                  :for={{preset, label} <- @presets}
                  type="button"
                  phx-click="apply_preset"
                  phx-value-preset={preset}
                  class="btn btn-outline min-h-11"
                >
                  {label}
                </button>
              </div>
            </div>

            <div class="space-y-2">
              <p class="text-sm font-semibold">Included event types</p>
              <div class="grid gap-2 md:grid-cols-2">
                <label :for={event_type <- all_event_types()} class="label min-h-11 cursor-pointer justify-start gap-3 rounded-md border border-base-300 bg-base-200 px-4 py-3">
                  <input
                    type="checkbox"
                    name="subscription[event_types][]"
                    value={event_type}
                    checked={event_type in Map.get(@form_state, "event_types", [])}
                    class="checkbox"
                  />
                  <span class="label-text">{event_type}</span>
                </label>
              </div>
            </div>
          </section>

          <div class="flex flex-wrap gap-2">
            <button type="submit" class="btn btn-primary min-h-11">
              {if @editing_subscription, do: "Save subscription", else: "Create subscription"}
            </button>
            <button type="button" phx-click="cancel_form" class="btn btn-ghost min-h-11">
              {if @editing_subscription, do: "Keep editing", else: "Close form"}
            </button>
          </div>
        </form>
      </section>

      <div class="hidden lg:block">
        <table class="table w-full">
          <thead>
            <tr>
              <th>Subscription</th>
              <th>Configuration</th>
              <th>Event scope</th>
              <th>Recent delivery</th>
              <th class="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <td class="align-top">
                <div class="space-y-1">
                  <p class="font-semibold">{row.subscription.description || row.subscription.endpoint_url}</p>
                  <p class="text-sm text-base-content/70">{row.subscription.endpoint_url}</p>
                </div>
              </td>
              <td class="align-top">
                <div class="space-y-1 text-sm">
                  <span class={status_badge_class(row.subscription.enabled)}>{enabled_label(row.subscription.enabled)}</span>
                  <span :if={row.latest_delivery} class={delivery_badge_class(row.latest_delivery.status)}>
                    {delivery_status_label(row.latest_delivery.status)}
                  </span>
                </div>
              </td>
              <td class="align-top text-sm">
                {length(row.subscription.event_types)} events
              </td>
              <td class="align-top text-sm">
                <div :if={row.latest_delivery} class="space-y-1">
                  <p>{delivery_status_detail(row.latest_delivery)}</p>
                  <p :if={row.latest_delivery.last_http_status}>HTTP {row.latest_delivery.last_http_status}</p>
                </div>
                <p :if={!row.latest_delivery}>No deliveries yet</p>
              </td>
              <td class="align-top text-right">
                <div class="flex justify-end gap-2">
                  <button type="button" phx-click="open_edit" phx-value-id={row.subscription.id} class="btn btn-ghost btn-sm min-h-11">
                    Edit
                  </button>
                  <a class="btn btn-primary btn-sm min-h-11" href={subscription_show_path(row.subscription.id, @current_params)}>
                    Open subscription
                  </a>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="space-y-3 lg:hidden">
        <article :for={row <- @rows} class="rounded-lg border border-base-300 bg-base-200 p-4">
          <div class="space-y-1">
            <p class="font-semibold">{row.subscription.description || row.subscription.endpoint_url}</p>
            <p class="text-sm text-base-content/70">{row.subscription.endpoint_url}</p>
            <p class="text-sm">{length(row.subscription.event_types)} events</p>
            <p class="text-sm">{enabled_label(row.subscription.enabled)}</p>
            <p :if={row.latest_delivery} class="text-sm">{delivery_status_detail(row.latest_delivery)}</p>
          </div>

          <div class="mt-4">
            <a class="btn btn-primary min-h-11 w-full" href={subscription_show_path(row.subscription.id, @current_params)}>
              Open subscription
            </a>
          </div>
        </article>
      </div>

      <div :if={@rows == []} class="rounded-lg border border-dashed border-base-300 bg-base-100 p-6 text-sm text-base-content/70">
        <p class="font-semibold">No webhook subscriptions yet</p>
        <p class="mt-1">
          Create a subscription to send signed Sigra auth events to your receiver. You'll pick the endpoint, event scope, and signing secret here.
        </p>
      </div>
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

  defp subscriptions_index_path(params \\ %{}), do: append_query("/admin/webhooks", params)

  defp failures_index_path, do: "/admin/webhooks/failures"

  defp subscription_show_path(id, params) do
    return_to = subscriptions_index_path(params)
    "/admin/webhooks/subscriptions/#{id}?return_to=" <> URI.encode_www_form(return_to)
  end

  defp default_form_state do
    %{"endpoint_url" => "", "description" => "", "enabled" => true, "event_types" => []}
  end

  defp all_event_types, do: Sigra.Webhooks.public_event_types()

  defp preset_event_types("user_lifecycle"), do: ["user.created", "user.updated", "user.deleted"]
  defp preset_event_types("sessions"), do: ["session.created", "session.revoked"]

  defp preset_event_types("organization_membership") do
    [
      "organization_membership.created",
      "organization_membership.updated",
      "organization_membership.deleted"
    ]
  end

  defp preset_event_types("service_accounts"),
    do: ["service_account.created", "service_account.revoked"]

  defp preset_event_types("all"), do: all_event_types()
  defp preset_event_types(_other), do: []

  defp normalize_subscription_attrs(attrs, editing_subscription) do
    event_types =
      attrs
      |> Map.get("event_types", [])
      |> List.wrap()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    base = %{
      endpoint_url: String.trim(Map.get(attrs, "endpoint_url", "")),
      description: blank_to_nil(Map.get(attrs, "description", "")),
      enabled: truthy?(Map.get(attrs, "enabled", false)),
      event_types: event_types
    }

    if editing_subscription do
      base
    else
      Map.put(base, :signing_secret, random_secret())
    end
  end

  defp merge_changeset_errors(attrs, _changeset) do
    %{
      "endpoint_url" => Map.get(attrs, "endpoint_url", ""),
      "description" => Map.get(attrs, "description", ""),
      "enabled" => truthy?(Map.get(attrs, "enabled", false)),
      "event_types" => attrs |> Map.get("event_types", []) |> List.wrap()
    }
  end

  defp delivery_status_detail(delivery) do
    case delivery.status do
      "retry_scheduled" -> "Retrying"
      "dead_lettered" -> "Dead lettered"
      "delivered" -> "Delivered"
      other -> Phoenix.Naming.humanize(other)
    end
  end

  defp delivery_status_label(status), do: delivery_status_detail(%{status: status})

  defp delivery_badge_class("delivered"), do: "badge badge-success badge-soft"
  defp delivery_badge_class("retry_scheduled"), do: "badge badge-warning badge-soft"
  defp delivery_badge_class("dead_lettered"), do: "badge badge-error badge-soft"
  defp delivery_badge_class(_status), do: "badge badge-ghost"

  defp status_badge_class(true), do: "badge badge-success badge-soft"
  defp status_badge_class(false), do: "badge badge-ghost"
  defp enabled_label(true), do: "Enabled"
  defp enabled_label(false), do: "Disabled"

  defp enabled_param_value(params) do
    case Map.get(params, "enabled") do
      true -> "true"
      false -> "false"
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  defp config_subscription!(config, id) do
    config
    |> Sigra.Webhooks.subscription_schema!()
    |> config.repo.get!(id)
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

  defp truthy?(value) when value in [true, "true", "on", 1, "1"], do: true
  defp truthy?(_value), do: false
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
  defp random_secret, do: :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

  defp runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError, "Sigra admin webhooks requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "Sigra admin webhooks requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end
end
