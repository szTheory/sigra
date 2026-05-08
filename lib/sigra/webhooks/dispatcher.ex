defmodule Sigra.Webhooks.Dispatcher do
  @moduledoc """
  Library-owned durable webhook persistence builders.

  This module owns selection of matching subscriptions plus atomic
  persistence of one public webhook event row and one pending delivery row
  per matching enabled subscription. Callers own the outer transaction.
  """

  alias Ecto.Multi
  alias Sigra.Webhooks
  alias Sigra.Webhooks.{EventCatalog, Payload}

  @type changes_ref :: {:changes_key, atom()} | (map() -> term()) | term()

  @doc """
  Returns enabled subscriptions whose explicit `event_types` include
  `event_type`.
  """
  @spec matching_subscriptions(Sigra.Config.t(), String.t()) :: [struct()]
  def matching_subscriptions(%Sigra.Config{} = config, event_type) when is_binary(event_type) do
    config
    |> Webhooks.list_subscriptions()
    |> Enum.filter(fn subscription ->
      Map.get(subscription, :enabled, false) and
        event_type in Map.get(subscription, :event_types, [])
    end)
  end

  @doc """
  Builds a pure `Ecto.Multi` that persists the public event row and its
  pending delivery rows.
  """
  @spec dispatch_multi(Sigra.Config.t(), String.t(), changes_ref(), keyword()) :: Multi.t()
  def dispatch_multi(%Sigra.Config{} = config, event_type, object_ref, opts \\ [])
      when is_binary(event_type) and is_list(opts) do
    validate_event_type!(event_type)

    if Webhooks.enabled?(config) do
      {subscriptions_step, event_step, deliveries_step, jobs_step} = step_names(event_type, opts)

      Multi.new()
      |> Multi.run(subscriptions_step, fn _repo, _changes ->
        {:ok, matching_subscriptions(config, event_type)}
      end)
      |> Multi.run(event_step, fn repo, changes ->
        insert_event(repo, config, event_type, object_ref, changes, opts)
      end)
      |> Multi.run(deliveries_step, fn repo, changes ->
        subscriptions = Map.fetch!(changes, subscriptions_step)
        event = Map.fetch!(changes, event_step)
        insert_deliveries(repo, config, subscriptions, event)
      end)
      |> Webhooks.append_delivery_jobs_multi(config, deliveries_step, jobs_step: jobs_step)
    else
      Multi.new()
    end
  end

  defp validate_event_type!(event_type) do
    unless EventCatalog.valid?(event_type) do
      raise ArgumentError, "unsupported webhook event type #{inspect(event_type)}"
    end

    :ok
  end

  defp step_names(event_type, opts) do
    step_id = Keyword.get(opts, :step_id, event_type)

    {
      {:webhook_subscriptions, step_id},
      {:webhook_event, step_id},
      {:webhook_deliveries, step_id},
      {:webhook_delivery_jobs, step_id}
    }
  end

  defp insert_event(repo, config, event_type, object_ref, changes, opts) do
    with {:ok, object} <- resolve_object(object_ref, changes),
         {:ok, context} <- resolve_context(changes, opts),
         {:ok, occurred_at} <- resolve_occurred_at(changes, opts) do
      event_schema = Webhooks.event_schema!(config)
      event_id = resolve_value(Keyword.get(opts, :event_id, Ecto.UUID.generate()), changes)
      changes_hint = resolve_changes(Keyword.get(opts, :changes, []), changes)

      payload =
        Payload.build(event_type, object,
          id: event_id,
          occurred_at: occurred_at,
          changes: changes_hint,
          context: context
        )

      attrs = %{
        event_id: event_id,
        type: event_type,
        schema_version: payload["schema_version"],
        occurred_at: normalize_datetime(occurred_at),
        payload: payload,
        actor_id: get_in(context, [:actor, :id]),
        actor_type: get_in(context, [:actor, :type]),
        organization_id: get_in(context, [:organization, :id]),
        request_id: get_in(context, [:request, :id])
      }

      repo.insert(event_schema.changeset(struct(event_schema), attrs))
    end
  end

  defp insert_deliveries(repo, config, subscriptions, event) do
    Enum.reduce_while(subscriptions, {:ok, []}, fn subscription, {:ok, deliveries} ->
      case insert_delivery(repo, config, subscription, event) do
        {:ok, delivery} -> {:cont, {:ok, [delivery | deliveries]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, deliveries} -> {:ok, Enum.reverse(deliveries)}
      other -> other
    end
  end

  @doc """
  Inserts one canonical pending delivery row for a subscription/event pair.
  """
  @spec insert_delivery(module(), Sigra.Config.t(), struct() | map(), struct() | map(), map()) ::
          {:ok, struct()} | {:error, term()}
  def insert_delivery(repo, %Sigra.Config{} = config, subscription, event, attrs \\ %{})
      when is_map(attrs) do
    delivery_schema = Webhooks.delivery_schema!(config)
    attrs = build_delivery_attrs(subscription, event, attrs)

    repo.insert(delivery_schema.changeset(struct(delivery_schema), attrs))
  end

  @doc """
  Builds the canonical pending delivery row attributes for persistence.
  """
  @spec build_delivery_attrs(struct() | map(), struct() | map(), map()) :: map()
  def build_delivery_attrs(subscription, event, attrs \\ %{}) when is_map(attrs) do
    Map.merge(
      %{
        delivery_id: Ecto.UUID.generate(),
        status: "pending",
        attempt_count: 0,
        endpoint_url: Map.fetch!(subscription, :endpoint_url),
        dispatched_at: nil,
        last_attempted_at: nil,
        next_attempt_at: nil,
        last_http_status: nil,
        last_error_category: nil,
        last_error_detail: nil,
        dead_lettered_at: nil,
        terminal_reason: nil,
        webhook_subscription_id: Map.fetch!(subscription, :id),
        webhook_event_id: Map.fetch!(event, :id)
      },
      attrs
    )
  end

  defp resolve_object({:changes_key, key}, changes) when is_atom(key) do
    case Map.fetch(changes, key) do
      {:ok, nil} -> {:error, :missing_webhook_object}
      {:ok, object} -> {:ok, object}
      :error -> {:error, :missing_webhook_object}
    end
  end

  defp resolve_object(fun, changes) when is_function(fun, 1) do
    case fun.(changes) do
      nil -> {:error, :missing_webhook_object}
      object -> {:ok, object}
    end
  end

  defp resolve_object(nil, _changes), do: {:error, :missing_webhook_object}
  defp resolve_object(object, _changes), do: {:ok, object}

  defp resolve_context(changes, opts) do
    context =
      opts
      |> Keyword.get(:context, %{})
      |> resolve_value(changes)

    if is_map(context), do: {:ok, context}, else: {:ok, %{}}
  end

  defp resolve_occurred_at(changes, opts) do
    occurred_at =
      opts
      |> Keyword.get(:occurred_at, DateTime.utc_now())
      |> resolve_value(changes)
      |> normalize_datetime()

    case occurred_at do
      %DateTime{} = datetime -> {:ok, datetime}
      _other -> {:error, :invalid_webhook_occurred_at}
    end
  end

  defp resolve_changes(changes_ref, changes) do
    case resolve_value(changes_ref, changes) do
      list when is_list(list) -> list
      _other -> []
    end
  end

  defp resolve_value({:changes_key, key}, changes) when is_atom(key), do: Map.get(changes, key)
  defp resolve_value(fun, changes) when is_function(fun, 1), do: fun.(changes)
  defp resolve_value(value, _changes), do: value

  defp normalize_datetime(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp normalize_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> DateTime.from_naive!("Etc/UTC")
  end

  defp normalize_datetime(_other), do: nil
end
