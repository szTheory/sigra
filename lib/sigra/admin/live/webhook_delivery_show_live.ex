defmodule Sigra.Admin.Live.WebhookDeliveryShowLive do
  @moduledoc """
  Shared admin webhook delivery detail surface.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Webhooks.{Actions, Detail}

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> Map.get(session, "current_scope") end)
     |> assign_new(:admin_scope, fn -> Map.get(session, "admin_scope") end)
     |> assign(:sigra_config, runtime_config!())
     |> assign(:detail, nil)
     |> assign(:event, nil)
     |> assign(:replay_confirm_open, false)
     |> assign(:replay_delivery_id, nil)
     |> assign(:return_to, "/admin/webhooks/failures")
     |> assign(:page_title, "Webhook delivery")}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    detail = Detail.load_delivery!(socket.assigns.sigra_config, socket.assigns.admin_scope, id)
    event = load_event(socket.assigns.sigra_config, detail.delivery.webhook_event_id)

    {:noreply,
     socket
     |> assign(:detail, detail)
     |> assign(:event, event)
     |> assign(:replay_confirm_open, false)
     |> assign(:replay_delivery_id, nil)
     |> assign(:return_to, sanitize_return_to(Map.get(params, "return_to")))}
  end

  @impl true
  def handle_event("open_replay", _params, socket),
    do: {:noreply, assign(socket, :replay_confirm_open, true)}

  def handle_event("cancel_replay", _params, socket),
    do: {:noreply, assign(socket, :replay_confirm_open, false)}

  def handle_event("confirm_replay", _params, socket) do
    delivery_id = socket.assigns.detail.delivery.delivery_id

    case Actions.replay_delivery(
           socket.assigns.sigra_config,
           socket.assigns.admin_scope,
           delivery_id,
           source: "admin.delivery_detail"
         ) do
      {:ok, %{replay_delivery: replay_delivery}} ->
        detail = Detail.load_delivery!(socket.assigns.sigra_config, socket.assigns.admin_scope, delivery_id)
        event = load_event(socket.assigns.sigra_config, detail.delivery.webhook_event_id)

        {:noreply,
         socket
         |> assign(:detail, detail)
         |> assign(:event, event)
         |> assign(:replay_confirm_open, false)
         |> assign(:replay_delivery_id, replay_delivery.delivery_id)
         |> put_flash(:info, "Replay queued as a new delivery lifecycle.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:replay_confirm_open, false)
         |> put_flash(:error, "Replay could not be started for this delivery.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@detail} class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <a class="btn btn-ghost min-h-11" href={@return_to}>
          {if String.contains?(@return_to, "/failures"), do: "Back to failures", else: "Back to subscription"}
        </a>
        <span class="text-sm text-base-content/70">Shared delivery drill-down</span>
      </div>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h1 class="text-2xl font-semibold">Webhook delivery</h1>
        <div class="mt-4 space-y-2 text-sm">
          <h2 class="text-lg font-semibold">Current status</h2>
          <p>{human_status(@detail.delivery.status)}</p>
          <p>Delivery ID: {@detail.delivery.delivery_id}</p>
          <p :if={@event}>Event ID: {@event.event_id}</p>
          <p>Endpoint: {@detail.delivery.endpoint_url}</p>
          <p :if={@detail.delivery.last_http_status}>Last HTTP status: {@detail.delivery.last_http_status}</p>
          <p :if={@detail.delivery.next_attempt_at}>
            Next attempt: {Calendar.strftime(@detail.delivery.next_attempt_at, "%Y-%m-%d %H:%M")}
          </p>
          <p :if={@detail.delivery.terminal_reason}>Terminal reason: {@detail.delivery.terminal_reason}</p>
        </div>
      </section>

      <section
        :if={@detail.policy.blocked?}
        class="rounded-lg border border-base-300 bg-base-100 p-5"
      >
        <h2 class="text-lg font-semibold">Endpoint policy result</h2>
        <p class="mt-2 text-sm">
          Sigra blocked this delivery before any outbound request was attempted.
        </p>

        <div class="mt-4 rounded-md border border-base-300 bg-base-200 p-4 text-sm space-y-3">
          <div>
            <p class="font-semibold">Reason code</p>
            <p class="font-mono text-sm">{@detail.policy.reason}</p>
          </div>
          <div>
            <p class="font-semibold">Operator detail</p>
            <p>{policy_detail(@detail.policy.detail)}</p>
          </div>
          <p>This denial came from Sigra's local webhook endpoint policy, not from the remote receiver.</p>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-lg font-semibold">Replay delivery</h2>
        <p class="mt-2 text-sm">{replay_copy(@detail.replay)}</p>

        <button
          :if={@detail.replay.eligible?}
          type="button"
          phx-click="open_replay"
          class="btn btn-primary min-h-11 mt-4"
        >
          Replay delivery
        </button>

        <div :if={@replay_confirm_open} class="mt-4 rounded-md border border-base-300 bg-base-200 p-4 text-sm space-y-3">
          <p class="font-semibold">Replay this dead-lettered delivery?</p>
          <p>Sigra will create a new child delivery and keep the original failed row immutable.</p>
          <div class="flex flex-wrap gap-2">
            <button type="button" phx-click="confirm_replay" class="btn btn-primary min-h-11">Confirm replay</button>
            <button type="button" phx-click="cancel_replay" class="btn btn-ghost min-h-11">Cancel</button>
          </div>
        </div>

        <p :if={@replay_delivery_id} class="mt-4 text-sm">Replay child: {@replay_delivery_id}</p>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-lg font-semibold">Attempt timeline</h2>
        <div class="mt-4 space-y-3">
          <article :for={attempt <- @detail.attempts} class="rounded-md border border-base-300 bg-base-200 p-4 text-sm">
            <p class="font-semibold">Attempt {attempt.attempt_number}</p>
            <p>Started: {Calendar.strftime(attempt.started_at, "%Y-%m-%d %H:%M")}</p>
            <p :if={attempt.response_status}>HTTP {attempt.response_status}</p>
            <p :if={attempt.error_category}>Error category: {attempt.error_category}</p>
            <p :if={attempt.terminal_reason}>Terminal reason: {attempt.terminal_reason}</p>
          </article>

          <p :if={@detail.attempts == []} class="text-sm text-base-content/70">No attempts recorded yet.</p>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-lg font-semibold">Replay lineage</h2>
        <div class="mt-4 space-y-3 text-sm">
          <div :if={@detail.replay_parent}>
            <p class="font-semibold">Original delivery</p>
            <p>{@detail.replay_parent.delivery_id}</p>
          </div>
          <div :if={@detail.replay_root}>
            <p class="font-semibold">Root delivery</p>
            <p>{@detail.replay_root.delivery_id}</p>
          </div>
          <article :for={child <- @detail.replay_children} class="rounded-md border border-base-300 bg-base-200 p-4">
            <p class="font-semibold">Replay child</p>
            <p>{child.delivery_id}</p>
            <a class="btn btn-outline btn-sm mt-3" href={delivery_path(child.delivery_id, @return_to)}>Open replay child</a>
          </article>
        </div>
      </section>
    </section>
    """
  end

  defp load_event(config, event_id) do
    config
    |> Sigra.Webhooks.event_schema!()
    |> config.repo.get!(event_id)
  end

  defp sanitize_return_to(path) when is_binary(path) do
    if String.starts_with?(path, ["/admin/webhooks/failures", "/admin/webhooks/subscriptions/"]) do
      path
    else
      "/admin/webhooks/failures"
    end
  end

  defp sanitize_return_to(_path), do: "/admin/webhooks/failures"

  defp delivery_path(delivery_id, return_to) do
    "/admin/webhooks/deliveries/#{delivery_id}?return_to=" <> URI.encode_www_form(return_to)
  end

  defp human_status("retry_scheduled"), do: "Retrying"
  defp human_status("dead_lettered"), do: "Dead lettered"
  defp human_status("delivered"), do: "Delivered"
  defp human_status(other), do: Phoenix.Naming.humanize(other)

  defp replay_copy(%{eligible?: true}), do: "Replay is available for this dead-lettered delivery."
  defp replay_copy(%{reason: :not_dead_lettered}), do: "Replay unavailable: this delivery is still in flight."
  defp replay_copy(%{reason: :delivery_context_incomplete}), do: "Replay unavailable: delivery context is incomplete."
  defp replay_copy(%{reason: :subscription_disabled}), do: "Replay unavailable: the subscription is disabled."
  defp replay_copy(%{reason: :replay_already_exists}), do: "Replay unavailable: a replay child already exists."
  defp replay_copy(_replay), do: "Replay unavailable for this delivery."

  defp policy_detail(detail) when detail in [nil, ""], do: "No additional policy detail recorded."
  defp policy_detail(detail), do: detail

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
