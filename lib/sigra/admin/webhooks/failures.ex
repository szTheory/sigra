defmodule Sigra.Admin.Webhooks.Failures do
  @moduledoc """
  Canonical query contract for the global webhook retrying and dead-letter inbox.
  """

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope

  @allowed_params ~w(q delivery_state status page page_size order_by order_direction)
  @attention_statuses ["retry_scheduled", "dead_lettered"]

  defmodule Params do
    @moduledoc false
    use Ecto.Schema

    @primary_key false

    @derive {
      Flop.Schema,
      filterable: [:q, :delivery_state],
      sortable: [:inserted_at, :attempt_count],
      default_limit: 25,
      max_limit: 100,
      default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
    }

    embedded_schema do
      field :q, :string
      field :delivery_state, :string
      field :inserted_at, :utc_datetime
      field :attempt_count, :integer
    end
  end

  @spec normalize_params(map() | keyword() | nil) :: {:ok, map()} | {:error, Flop.Meta.t()}
  def normalize_params(params) do
    raw =
      params
      |> stringify_map()
      |> Map.take(@allowed_params)

    normalized =
      %{}
      |> maybe_put_trimmed("q", Map.get(raw, "q"))
      |> maybe_put_delivery_state(raw)
      |> maybe_put("page", normalize_integer(Map.get(raw, "page")))
      |> maybe_put("page_size", normalize_integer(Map.get(raw, "page_size")))
      |> maybe_put("order_by", normalize_string(Map.get(raw, "order_by")))
      |> maybe_put("order_direction", normalize_string(Map.get(raw, "order_direction")))

    case Flop.validate(to_flop_params(normalized), for: Params) do
      {:ok, flop} -> {:ok, merge_flop_defaults(normalized, flop)}
      {:error, %Flop.Meta{} = meta} -> {:error, meta}
    end
  end

  @spec list_deliveries(map(), Scope.t(), map() | keyword() | nil) ::
          {:ok, {list(map()), Flop.Meta.t(), map()}} | {:error, Flop.Meta.t()}
  def list_deliveries(config, %Scope{} = admin_scope, params \\ %{}) do
    Authorizer.authorize_global!(admin_scope)

    with {:ok, normalized} <- normalize_params(params),
         {:ok, %Flop{} = flop} <- Flop.validate(to_flop_params(normalized), for: Params) do
      filtered_query = list_query(config, admin_scope, normalized)

      pagination_flop = %Flop{flop | filters: []}
      meta = Flop.meta(filtered_query, pagination_flop, for: Params, repo: config.repo)

      rows =
        filtered_query
        |> Flop.query(pagination_flop, for: Params)
        |> config.repo.all()
        |> attach_metadata(config)

      {:ok, {rows, meta, normalized}}
    end
  end

  @spec summary_counts(map(), Scope.t()) :: map()
  def summary_counts(config, %Scope{} = admin_scope) do
    Authorizer.authorize_global!(admin_scope)

    repo = config.repo
    base = base_query(config, admin_scope)

    %{
      total: repo.aggregate(base, :count, :id),
      retrying: repo.aggregate(maybe_filter_delivery_state(base, "retrying"), :count, :id),
      dead_lettered:
        repo.aggregate(maybe_filter_delivery_state(base, "dead_lettered"), :count, :id)
    }
  end

  defp base_query(config, _admin_scope) do
    delivery_schema = Sigra.Webhooks.delivery_schema!(config)

    from(delivery in delivery_schema, as: :delivery)
    |> where([delivery: delivery], delivery.status in ^@attention_statuses)
  end

  defp list_query(config, admin_scope, %{"delivery_state" => "dead_lettered"} = normalized) do
    base_query(config, admin_scope)
    |> maybe_include_replay_children(config)
    |> apply_filters(normalized)
  end

  defp list_query(config, admin_scope, normalized) do
    config
    |> base_query(admin_scope)
    |> apply_filters(normalized)
  end

  defp maybe_include_replay_children(query, config) do
    delivery_schema = Sigra.Webhooks.delivery_schema!(config)

    dead_letter_ids =
      from(source in delivery_schema,
        where: source.status == "dead_lettered",
        select: source.id
      )

    or_where(
      query,
      [delivery: delivery],
      delivery.replayed_from_webhook_delivery_id in subquery(dead_letter_ids)
    )
  end

  defp apply_filters(query, normalized) do
    query
    |> maybe_filter_delivery_state(Map.get(normalized, "delivery_state"))
    |> maybe_filter_q(Map.get(normalized, "q"))
  end

  defp maybe_filter_delivery_state(query, nil), do: query

  defp maybe_filter_delivery_state(query, "retrying") do
    where(query, [delivery: delivery], delivery.status == "retry_scheduled")
  end

  defp maybe_filter_delivery_state(query, "dead_lettered") do
    where(
      query,
      [delivery: delivery],
      delivery.status == "dead_lettered" or
        not is_nil(delivery.replayed_from_webhook_delivery_id)
    )
  end

  defp maybe_filter_delivery_state(query, delivery_state) do
    where(query, [delivery: delivery], delivery.status == ^delivery_state)
  end

  defp maybe_filter_q(query, nil), do: query

  defp maybe_filter_q(query, term) do
    like_term = "%" <> term <> "%"

    where(
      query,
      [delivery: delivery],
      ilike(type(delivery.delivery_id, :string), ^like_term) or
        ilike(type(delivery.endpoint_url, :string), ^like_term)
    )
  end

  defp attach_metadata(deliveries, config) do
    subscription_schema = Sigra.Webhooks.subscription_schema!(config)
    delivery_schema = Sigra.Webhooks.delivery_schema!(config)
    subscription_ids = Enum.map(deliveries, & &1.webhook_subscription_id)

    source_ids =
      deliveries
      |> Enum.map(&Map.get(&1, :replayed_from_webhook_delivery_id))
      |> Enum.reject(&is_nil/1)

    subscriptions_by_id =
      from(subscription in subscription_schema, where: subscription.id in ^subscription_ids)
      |> config.repo.all()
      |> Map.new(&{&1.id, &1})

    replay_children_by_source_id =
      from(child in delivery_schema,
        where: child.replayed_from_webhook_delivery_id in ^Enum.map(deliveries, & &1.id),
        select: {child.replayed_from_webhook_delivery_id, child}
      )
      |> config.repo.all()
      |> Map.new()

    replay_sources_by_id =
      if source_ids == [] do
        %{}
      else
        from(source in delivery_schema, where: source.id in ^source_ids)
        |> config.repo.all()
        |> Map.new(&{&1.id, &1})
      end

    Enum.map(deliveries, fn delivery ->
      subscription = Map.get(subscriptions_by_id, delivery.webhook_subscription_id)
      replay_source = Map.get(replay_sources_by_id, delivery.replayed_from_webhook_delivery_id)
      replay_child = Map.get(replay_children_by_source_id, delivery.id)
      replay_reason = replay_reason(config, delivery, subscription, replay_child, replay_source)

      %{
        delivery: delivery,
        subscription: subscription,
        replayable?: replay_reason == nil,
        replay_reason: replay_reason,
        policy_reason: policy_reason(delivery),
        policy_detail: policy_detail(delivery),
        replay_child_delivery_id: replay_child && replay_child.delivery_id,
        replay_parent_delivery_id: replay_source && replay_source.delivery_id
      }
    end)
  end

  defp policy_reason(delivery) do
    if Map.get(delivery, :last_error_category) == "local_policy_error" do
      Map.get(delivery, :terminal_reason)
    end
  end

  defp policy_detail(delivery) do
    if Map.get(delivery, :last_error_category) == "local_policy_error" do
      Map.get(delivery, :last_error_detail)
    end
  end

  defp merge_flop_defaults(normalized, %Flop{} = flop) do
    normalized
    |> Map.put_new("page", to_string(flop.page || 1))
    |> Map.put_new("page_size", to_string(flop.page_size || flop.limit))
    |> Map.put_new("order_by", normalize_order_by(flop.order_by))
    |> Map.put_new("order_direction", normalize_order_direction(flop.order_directions))
  end

  defp maybe_put_delivery_state(map, raw) do
    raw
    |> delivery_state_param()
    |> normalize_delivery_state()
    |> then(fn
      nil -> map
      delivery_state -> Map.put(map, "delivery_state", delivery_state)
    end)
  end

  defp delivery_state_param(raw) do
    Map.get(raw, "delivery_state") || Map.get(raw, "status")
  end

  defp normalize_delivery_state(nil), do: nil
  defp normalize_delivery_state(""), do: nil
  defp normalize_delivery_state("retry_scheduled"), do: "retrying"

  defp normalize_delivery_state(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      "retry_scheduled" -> "retrying"
      other -> other
    end
  end

  defp normalize_order_by([field | _rest]), do: to_string(field)
  defp normalize_order_by(field) when is_atom(field), do: to_string(field)
  defp normalize_order_by(_other), do: "inserted_at"

  defp normalize_order_direction([direction | _rest]), do: to_string(direction)
  defp normalize_order_direction(direction) when is_atom(direction), do: to_string(direction)
  defp normalize_order_direction(_other), do: "desc"

  defp to_flop_params(normalized) do
    %{}
    |> maybe_put("page", Map.get(normalized, "page"))
    |> maybe_put("page_size", Map.get(normalized, "page_size"))
    |> maybe_put_order_by(Map.get(normalized, "order_by"))
    |> maybe_put_order_direction(Map.get(normalized, "order_direction"))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, value) when value == "", do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_trimmed(map, key, value) do
    value
    |> normalize_string()
    |> then(fn
      nil -> map
      trimmed -> Map.put(map, key, trimmed)
    end)
  end

  defp maybe_put_order_by(map, nil), do: map
  defp maybe_put_order_by(map, value), do: Map.put(map, "order_by", [value])

  defp maybe_put_order_direction(map, nil), do: map
  defp maybe_put_order_direction(map, value), do: Map.put(map, "order_directions", [value])

  defp stringify_map(params) when is_list(params),
    do: Map.new(params, fn {key, value} -> {to_string(key), value} end)

  defp stringify_map(params) when is_map(params),
    do: Map.new(params, fn {key, value} -> {to_string(key), value} end)

  defp stringify_map(_params), do: %{}

  defp normalize_string(nil), do: nil

  defp normalize_string(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(nil), do: nil
  defp normalize_integer(""), do: nil

  defp normalize_integer(value) do
    case Integer.parse(to_string(value)) do
      {parsed, ""} -> parsed
      _ -> value
    end
  end

  defp replay_reason(_config, delivery, subscription, replay_child, _replay_source) do
    cond do
      Map.get(delivery, :status) != "dead_lettered" or
          is_nil(Map.get(delivery, :dead_lettered_at)) ->
        :not_dead_lettered

      Map.get(delivery, :terminal_reason) in [
        "delivery_dependency_missing",
        "orphaned_terminal_issue"
      ] ->
        :delivery_context_incomplete

      match?(%{enabled: false}, subscription) ->
        :subscription_disabled

      replay_child != nil ->
        :replay_already_exists

      true ->
        nil
    end
  end
end
