defmodule Sigra.Admin.Live.WebhookDeliveryFailuresLive do
  @moduledoc """
  Global admin webhook failure inbox.
  """

  use Phoenix.LiveView

  alias Sigra.Admin.Webhooks.Failures

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
     |> assign(:page_title, "Webhook failures")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    config = socket.assigns.sigra_config
    admin_scope = socket.assigns.admin_scope

    case Failures.list_deliveries(config, admin_scope, params) do
      {:ok, {rows, meta, normalized}} ->
        {:noreply,
         assign(socket,
           rows: rows,
           meta: meta,
           current_params: normalized,
           summary_counts: Failures.summary_counts(config, admin_scope)
         )}

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
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <header class="space-y-2">
        <h1 class="text-2xl font-semibold">Webhook failures</h1>
        <p class="text-sm text-base-content/70">Triage retrying and dead-lettered deliveries across subscriptions.</p>
      </header>

      <div class="flex flex-wrap gap-2">
        <.summary_chip label="Backlog" value={Map.get(@summary_counts, :total, 0)} />
        <.summary_chip label="Retrying" value={Map.get(@summary_counts, :retrying, 0)} />
        <.summary_chip label="Dead lettered" value={Map.get(@summary_counts, :dead_lettered, 0)} />
      </div>

      <div class="flex flex-wrap gap-2">
        <a class="btn btn-outline min-h-11" href={index_path(%{"delivery_state" => "retrying"})}>Retrying</a>
        <a class="btn btn-outline min-h-11" href={index_path(%{"delivery_state" => "dead_lettered"})}>Dead lettered</a>
      </div>

      <form method="get" action={index_path()} class="space-y-4 rounded-lg border border-base-300 bg-base-200 p-4">
        <div class="grid gap-3 lg:grid-cols-[minmax(0,1fr)_minmax(0,220px)_auto] lg:items-end">
          <label class="form-control">
            <span class="label-text text-sm font-semibold">Search</span>
            <input type="text" name="q" value={Map.get(@current_params, "q", "")} class="input input-bordered w-full" />
          </label>

          <label class="form-control">
            <span class="label-text text-sm font-semibold">Delivery state</span>
            <select name="delivery_state" class="select select-bordered w-full">
              <option value="">Retrying and dead-lettered</option>
              <option value="retrying" selected={Map.get(@current_params, "delivery_state", "") == "retrying"}>Retrying</option>
              <option value="dead_lettered" selected={Map.get(@current_params, "delivery_state", "") == "dead_lettered"}>Dead lettered</option>
            </select>
          </label>

          <div class="grid grid-cols-2 gap-2 lg:flex">
            <button type="submit" class="btn btn-primary min-h-11">Apply filters</button>
            <a href={index_path()} class="btn btn-ghost min-h-11">Clear</a>
          </div>
        </div>
      </form>

      <div class="space-y-3">
        <article :for={row <- @rows} class="rounded-lg border border-base-300 bg-base-100 p-4">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="space-y-1 text-sm">
              <p class="font-semibold">{row.subscription && row.subscription.description || row.delivery.endpoint_url}</p>
              <p>Delivery ID: {row.delivery.delivery_id}</p>
              <p>{row.delivery.endpoint_url}</p>
              <p>{human_status(row.delivery.status)}</p>
              <div :if={row.policy_reason} class="rounded-md border border-base-300 bg-base-200 p-3 space-y-2">
                <span class="badge badge-error badge-soft">Blocked by local policy</span>
                <p>
                  Policy reason:
                  <span class="font-mono text-sm">{row.policy_reason}</span>
                  {" - "}
                  {policy_detail(row.policy_detail)}
                </p>
              </div>
              <p :if={row.delivery.next_attempt_at}>
                Next attempt: {Calendar.strftime(row.delivery.next_attempt_at, "%Y-%m-%d %H:%M")}
              </p>
              <p :if={row.delivery.terminal_reason}>Terminal reason: {row.delivery.terminal_reason}</p>
              <p>{replay_badge(row)}</p>
            </div>

            <div class="flex w-full flex-col gap-2 sm:w-auto">
              <a class="btn btn-primary min-h-11 w-full sm:w-auto" href={delivery_path(row.delivery.delivery_id)}>
                Open delivery
              </a>
              <a :if={row.replayable?} class="btn btn-outline min-h-11 w-full sm:w-auto" href={delivery_path(row.delivery.delivery_id)}>
                Replay
              </a>
              <a :if={row.replay_child_delivery_id} class="btn btn-ghost min-h-11 w-full sm:w-auto" href={delivery_path(row.replay_child_delivery_id)}>
                Open replay child
              </a>
            </div>
          </div>
        </article>
      </div>

      <div :if={@rows == []} class="rounded-lg border border-dashed border-base-300 bg-base-100 p-6 text-sm text-base-content/70">
        <p class="font-semibold">No active delivery failures</p>
        <p class="mt-1">
          Retrying and dead-lettered deliveries will appear here when a receiver or local webhook invariant needs attention.
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

  defp index_path(params \\ %{}), do: append_query("/admin/webhooks/failures", params)

  defp delivery_path(delivery_id) do
    return_to = index_path()
    "/admin/webhooks/deliveries/#{delivery_id}?return_to=" <> URI.encode_www_form(return_to)
  end

  defp human_status("retry_scheduled"), do: "Retrying"
  defp human_status("dead_lettered"), do: "Dead lettered"
  defp human_status("pending"), do: "Pending"
  defp human_status(other), do: Phoenix.Naming.humanize(other)

  defp replay_badge(%{replayable?: true}), do: "Replay available"
  defp replay_badge(%{replay_reason: :replay_already_exists}), do: "Already replayed"
  defp replay_badge(%{replay_reason: :not_dead_lettered}), do: "Replay unavailable: this delivery is still in flight."
  defp replay_badge(%{replay_reason: :delivery_context_incomplete}), do: "Replay unavailable: delivery context is incomplete."
  defp replay_badge(%{replay_reason: :subscription_disabled}), do: "Replay unavailable: subscription is disabled."
  defp replay_badge(_row), do: "Replay unavailable"

  defp policy_detail(detail) when detail in [nil, ""], do: "No additional policy detail recorded."
  defp policy_detail(detail), do: detail

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
