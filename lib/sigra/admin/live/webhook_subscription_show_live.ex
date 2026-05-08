defmodule Sigra.Admin.Live.WebhookSubscriptionShowLive do
  @moduledoc """
  Global admin webhook subscription detail surface.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Webhooks.Detail

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> Map.get(session, "current_scope") end)
     |> assign_new(:admin_scope, fn -> Map.get(session, "admin_scope") end)
     |> assign(:sigra_config, runtime_config!())
     |> assign(:detail, nil)
     |> assign(:return_to, "/admin/webhooks")
     |> assign(:revealed_secret, nil)
     |> assign(:confirm_action, nil)
     |> assign(:page_title, "Webhook subscription")}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    detail =
      Detail.load_subscription!(socket.assigns.sigra_config, socket.assigns.admin_scope, id)

    {:noreply,
     socket
     |> assign(:detail, detail)
     |> assign(:return_to, sanitize_return_to(Map.get(params, "return_to")))
     |> assign(:revealed_secret, nil)
     |> assign(:confirm_action, nil)}
  end

  @impl true
  def handle_event("reveal_secret", _params, socket) do
    {:ok, %{signing_secret: secret}} =
      Sigra.Admin.Webhooks.Actions.reveal_secret(
        socket.assigns.sigra_config,
        socket.assigns.admin_scope,
        socket.assigns.detail.subscription.id
      )

    {:noreply, assign(socket, :revealed_secret, secret)}
  end

  def handle_event("open_disable", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :disable,
       copy: "Disable this subscription? Future deliveries will stop until you re-enable it."
     })}
  end

  def handle_event("open_enable", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :enable,
       copy: "Enable this subscription for future deliveries?"
     })}
  end

  def handle_event("open_rotate", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :rotate,
       copy:
         "Rotate the signing secret for this subscription? Sigra will sign future deliveries with the new secret immediately. Update your receiver before saving, because sender-side overlap is not available in v1.22."
     })}
  end

  def handle_event("open_prepare", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :prepare,
       copy: "Prepare a new secret? Sigra will keep signing with the current secret until you explicitly start overlap."
     })}
  end

  def handle_event("open_discard_prepared", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :discard_prepared,
       copy: "Discard the staged secret and return to a stable single-secret state?"
     })}
  end

  def handle_event("open_start_overlap", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :start_overlap,
       copy: "Start overlap now? Sigra will sign each delivery with both the current and next secret."
     })}
  end

  def handle_event("open_complete_rotation", _params, socket) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :complete_rotation,
       copy: "Complete the rotation? Only do this after a real overlap-window delivery has verified successfully."
     })}
  end

  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, :confirm_action, nil)}
  end

  def handle_event("confirm_action", _params, socket) do
    subscription_id = socket.assigns.detail.subscription.id
    config = socket.assigns.sigra_config
    admin_scope = socket.assigns.admin_scope

    {message, socket} =
      case socket.assigns.confirm_action do
        %{type: :disable} ->
          {:ok, _subscription} =
            Sigra.Admin.Webhooks.Actions.disable(config, admin_scope, subscription_id)

          {"Webhook subscription disabled.", reload_detail(socket, subscription_id)}

        %{type: :enable} ->
          {:ok, _subscription} =
            Sigra.Admin.Webhooks.Actions.enable(config, admin_scope, subscription_id)

          {"Webhook subscription enabled.", reload_detail(socket, subscription_id)}

        %{type: :rotate} ->
          {:ok, _subscription} =
            Sigra.Admin.Webhooks.Actions.rotate_secret(config, admin_scope, subscription_id)

          {"Signing secret rotated. Update your receiver before the next delivery.",
           reload_detail(socket, subscription_id)}

        %{type: :prepare} ->
          {:ok, _subscription} =
            Sigra.Admin.Webhooks.Actions.prepare_secret(config, admin_scope, subscription_id)

          {"Prepared a staged secret. Update the receiver, then start overlap.",
           reload_detail(socket, subscription_id)}

        %{type: :discard_prepared} ->
          {:ok, _subscription} =
            Sigra.Admin.Webhooks.Actions.discard_prepared_secret(config, admin_scope, subscription_id)

          {"Discarded the staged secret and returned to a stable single-secret state.",
           reload_detail(socket, subscription_id)}

        %{type: :start_overlap} ->
          retire_after_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

          {:ok, _subscription} =
            Sigra.Admin.Webhooks.Actions.start_secret_overlap(
              config,
              admin_scope,
              subscription_id,
              retire_after_at: retire_after_at
            )

          {"Overlap started. Sigra now signs deliveries with both secrets.",
           reload_detail(socket, subscription_id)}

        %{type: :complete_rotation} ->
          {:ok, _subscription} =
            Sigra.Admin.Webhooks.Actions.complete_secret_rotation(config, admin_scope, subscription_id)

          {"Rotation completed. Verify a post-retirement delivery with the new active secret.",
           reload_detail(socket, subscription_id)}
      end

    {:noreply, socket |> assign(:confirm_action, nil) |> put_flash(:info, message)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@detail} class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <a class="btn btn-ghost min-h-11" href={@return_to}>Back to subscriptions</a>
        <span class="text-sm text-base-content/70">Global webhook administration</span>
      </div>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h1 class="text-2xl font-semibold">{@detail.subscription.description || "Webhook subscription"}</h1>
        <p class="mt-1 text-sm text-base-content/70">{@detail.subscription.endpoint_url}</p>
        <div class="mt-4 flex flex-wrap gap-2">
          <span class={if @detail.subscription.enabled, do: "badge badge-success badge-soft", else: "badge badge-ghost"}>
            {if @detail.subscription.enabled, do: "Enabled", else: "Disabled"}
          </span>
          <span class="badge badge-ghost">{length(@detail.subscription.event_types)} events</span>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-200 p-5">
        <h2 class="text-lg font-semibold">Setup</h2>
        <p class="mt-2 text-sm text-base-content/70">
          Sigra sends signed auth events. Your host app owns the receiver endpoint, verification, dedupe, and downstream automation.
        </p>
        <ul class="mt-4 space-y-2 text-sm">
          <li>Verify against the raw request body.</li>
          <li>Use delivery_id for dedupe.</li>
          <li>Keep current and previous receiver secrets locally during overlap.</li>
          <li>Prepare, start overlap, then complete rotation only after real delivery proof.</li>
        </ul>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold">Signing secret</h2>
            <p class="mt-1 text-sm text-base-content/70">Shown only after an explicit admin action. Treat it like a password.</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button type="button" phx-click="reveal_secret" class="btn btn-outline min-h-11">Reveal secret</button>
            <button :if={@revealed_secret} type="button" class="btn btn-outline min-h-11">Copy secret</button>
          </div>
        </div>

        <div :if={@revealed_secret} class="mt-4 rounded-md border border-base-300 bg-base-200 p-4">
          <code class="text-sm select-all">{@revealed_secret}</code>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold">Rotation lifecycle</h2>
            <p class="mt-1 text-sm text-base-content/70">The detail view shows the persisted lifecycle state, what Sigra signs with now, and the next safe operator step.</p>
          </div>
          <span class="badge badge-ghost">{rotation_state_label(@detail.rotation.state)}</span>
        </div>

        <div class="mt-4 space-y-2 text-sm">
          <p>{@detail.rotation.signing_mode}</p>
          <p>Next step: {@detail.rotation.next_step}</p>
          <p>Current fingerprint: {fingerprint_label(@detail.rotation.active_fingerprint)}</p>
          <p :if={@detail.rotation.next_fingerprint}>
            Prepared fingerprint: {fingerprint_label(@detail.rotation.next_fingerprint)}
          </p>
        </div>

        <div class="mt-4 flex flex-wrap gap-2">
          <button
            :if={@detail.rotation.state in [:stable, :completed]}
            type="button"
            phx-click="open_prepare"
            class="btn btn-primary min-h-11"
          >
            Prepare next secret
          </button>
          <button
            :if={@detail.rotation.state == :prepared}
            type="button"
            phx-click="open_discard_prepared"
            class="btn btn-outline min-h-11"
          >
            Discard prepared secret
          </button>
          <button
            :if={@detail.rotation.state == :prepared}
            type="button"
            phx-click="open_start_overlap"
            class="btn btn-primary min-h-11"
          >
            Start overlap
          </button>
          <button
            :if={@detail.rotation.state == :overlap_active}
            type="button"
            phx-click="open_complete_rotation"
            class="btn btn-primary min-h-11"
          >
            Complete rotation
          </button>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold">Subscription status</h2>
            <p class="mt-1 text-sm text-base-content/70">Use explicit controls to enable or disable future deliveries.</p>
          </div>
          <button
            type="button"
            phx-click={if @detail.subscription.enabled, do: "open_disable", else: "open_enable"}
            class={if @detail.subscription.enabled, do: "btn btn-outline min-h-11", else: "btn btn-primary min-h-11"}
          >
            {if @detail.subscription.enabled, do: "Disable subscription", else: "Enable subscription"}
          </button>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 p-5">
        <h2 class="text-lg font-semibold">Recent deliveries</h2>
        <p class="mt-2 text-sm text-base-content/70">Replay lineage lives on delivery detail.</p>
        <div class="mt-4 space-y-3">
          <article :for={delivery <- @detail.recent_deliveries} class="rounded-md border border-base-300 bg-base-200 p-4">
            <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div class="space-y-1 text-sm">
                <p class="font-semibold">{human_status(delivery.status)}</p>
                <p>Delivery ID: {delivery.delivery_id}</p>
                <p :if={delivery.replayed_from_webhook_delivery_id}>Replay child</p>
                <p :if={!delivery.replayed_from_webhook_delivery_id && delivery.status == "dead_lettered"}>Original failed delivery</p>
                <p :if={delivery.last_http_status}>Last HTTP status: {delivery.last_http_status}</p>
                <p :if={delivery.next_attempt_at}>
                  Next attempt: {Calendar.strftime(delivery.next_attempt_at, "%Y-%m-%d %H:%M")}
                </p>
                <p :if={delivery.terminal_reason}>Terminal reason: {delivery.terminal_reason}</p>
              </div>

              <a class="btn btn-primary min-h-11 w-full sm:w-auto" href={delivery_path(delivery.delivery_id, @return_to)}>
                Open delivery
              </a>
            </div>
          </article>

          <p :if={@detail.recent_deliveries == []} class="text-sm text-base-content/70">
            No deliveries for this subscription yet. Trigger a real Sigra auth event after you finish receiver setup.
          </p>
        </div>
      </section>

      <dialog :if={@confirm_action} open class="modal">
        <div class="modal-box">
          <p class="text-base font-semibold">Confirm action</p>
          <p class="mt-3 text-sm">{@confirm_action.copy}</p>
          <div class="modal-action">
            <button type="button" phx-click="cancel_confirm" class="btn btn-ghost min-h-11">Cancel</button>
            <button type="button" phx-click="confirm_action" class="btn btn-error min-h-11">Confirm</button>
          </div>
        </div>
      </dialog>
    </section>
    """
  end

  defp reload_detail(socket, subscription_id) do
    detail =
      Detail.load_subscription!(
        socket.assigns.sigra_config,
        socket.assigns.admin_scope,
        subscription_id
      )

    assign(socket, detail: detail, revealed_secret: nil)
  end

  defp delivery_path(delivery_id, return_to) do
    "/admin/webhooks/deliveries/#{delivery_id}?return_to=" <> URI.encode_www_form(return_to)
  end

  defp sanitize_return_to(path) when is_binary(path) do
    if String.starts_with?(path, ["/admin/webhooks", "/admin/webhooks/failures"]) do
      path
    else
      "/admin/webhooks"
    end
  end

  defp sanitize_return_to(_path), do: "/admin/webhooks"

  defp human_status("retry_scheduled"), do: "Retrying"
  defp human_status("dead_lettered"), do: "Dead lettered"
  defp human_status("delivered"), do: "Delivered"
  defp human_status(other), do: Phoenix.Naming.humanize(other)

  defp rotation_state_label(:stable), do: "Stable"
  defp rotation_state_label(:prepared), do: "Prepared"
  defp rotation_state_label(:overlap_active), do: "Overlap active"
  defp rotation_state_label(:completed), do: "Completed"
  defp rotation_state_label(other), do: Phoenix.Naming.humanize(other)

  defp fingerprint_label(nil), do: "Unavailable"
  defp fingerprint_label(fingerprint), do: fingerprint

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
