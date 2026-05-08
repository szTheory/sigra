defmodule Sigra.Admin.Webhooks.Query do
  @moduledoc """
  Canonical query contract for the admin webhook subscription index.
  """

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope

  @allowed_params ~w(q delivery_state status enabled page page_size order_by order_direction)

  defmodule Params do
    @moduledoc false
    use Ecto.Schema

    @primary_key false

    @derive {
      Flop.Schema,
      filterable: [:q, :delivery_state, :enabled],
      sortable: [:inserted_at, :endpoint_url, :enabled],
      default_limit: 25,
      max_limit: 100,
      default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
    }

    embedded_schema do
      field :q, :string
      field :delivery_state, :string
      field :enabled, :boolean
      field :inserted_at, :utc_datetime
      field :endpoint_url, :string
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
      |> maybe_put("enabled", normalize_boolean(Map.get(raw, "enabled")))
      |> maybe_put("page", normalize_integer(Map.get(raw, "page")))
      |> maybe_put("page_size", normalize_integer(Map.get(raw, "page_size")))
      |> maybe_put("order_by", normalize_string(Map.get(raw, "order_by")))
      |> maybe_put("order_direction", normalize_string(Map.get(raw, "order_direction")))

    case Flop.validate(to_flop_params(normalized), for: Params) do
      {:ok, flop} -> {:ok, merge_flop_defaults(normalized, flop)}
      {:error, %Flop.Meta{} = meta} -> {:error, meta}
    end
  end

  @spec list_subscriptions(map(), Scope.t(), map() | keyword() | nil) ::
          {:ok, {list(map()), Flop.Meta.t(), map()}} | {:error, Flop.Meta.t()}
  def list_subscriptions(config, %Scope{} = admin_scope, params \\ %{}) do
    Authorizer.authorize_global!(admin_scope)

    with {:ok, normalized} <- normalize_params(params),
         {:ok, %Flop{} = flop} <- Flop.validate(to_flop_params(normalized), for: Params) do
      filtered_query =
        config
        |> base_query(admin_scope)
        |> apply_filters(normalized)

      pagination_flop = %Flop{flop | filters: []}
      meta = Flop.meta(filtered_query, pagination_flop, for: Params, repo: config.repo)

      rows =
        filtered_query
        |> Flop.query(pagination_flop, for: Params)
        |> select_row()
        |> config.repo.all()
        |> Enum.map(&row_from_result/1)

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
      enabled: repo.aggregate(where(base, [subscription: subscription], subscription.enabled), :count, :id),
      disabled:
        repo.aggregate(
          where(base, [subscription: subscription], not subscription.enabled),
          :count,
          :id
        ),
      retrying: repo.aggregate(maybe_filter_delivery_state(base, "retrying"), :count, :id),
      dead_lettered:
        repo.aggregate(maybe_filter_delivery_state(base, "dead_lettered"), :count, :id)
    }
  end

  defp base_query(config, _admin_scope) do
    subscription_schema = Sigra.Webhooks.subscription_schema!(config)
    latest_delivery = latest_delivery_subquery(config)

    from(subscription in subscription_schema, as: :subscription)
    |> join(:left, [subscription: subscription], latest in subquery(latest_delivery),
      as: :latest_delivery,
      on: latest.webhook_subscription_id == subscription.id
    )
  end

  defp latest_delivery_subquery(config) do
    delivery_schema = Sigra.Webhooks.delivery_schema!(config)

    from(delivery in delivery_schema,
      order_by: [
        asc: delivery.webhook_subscription_id,
        desc: delivery.inserted_at,
        desc: delivery.id
      ],
      distinct: delivery.webhook_subscription_id
    )
  end

  defp apply_filters(query, normalized) do
    query
    |> maybe_filter_q(Map.get(normalized, "q"))
    |> maybe_filter_enabled(Map.get(normalized, "enabled"))
    |> maybe_filter_delivery_state(Map.get(normalized, "delivery_state"))
  end

  defp maybe_filter_q(query, nil), do: query

  defp maybe_filter_q(query, term) do
    like_term = "%" <> term <> "%"

    where(
      query,
      [subscription: subscription],
      ilike(subscription.endpoint_url, ^like_term) or
        ilike(type(subscription.description, :string), ^like_term)
    )
  end

  defp maybe_filter_enabled(query, nil), do: query

  defp maybe_filter_enabled(query, enabled) when is_boolean(enabled) do
    where(query, [subscription: subscription], subscription.enabled == ^enabled)
  end

  defp maybe_filter_delivery_state(query, nil), do: query

  defp maybe_filter_delivery_state(query, "retrying") do
    where(query, [latest_delivery: latest_delivery], latest_delivery.status == "retry_scheduled")
  end

  defp maybe_filter_delivery_state(query, delivery_state) do
    where(query, [latest_delivery: latest_delivery], latest_delivery.status == ^delivery_state)
  end

  defp select_row(query) do
    select(query, [subscription: subscription, latest_delivery: latest_delivery], %{
      subscription: subscription,
      latest_delivery: latest_delivery
    })
  end

  defp row_from_result(%{subscription: subscription, latest_delivery: latest_delivery}) do
    %{
      subscription: subscription,
      latest_delivery: latest_delivery,
      delivery_summary: %{
        status: latest_delivery && latest_delivery.status,
        attempt_count: latest_delivery && latest_delivery.attempt_count,
        last_http_status: latest_delivery && latest_delivery.last_http_status,
        next_attempt_at: latest_delivery && latest_delivery.next_attempt_at,
        terminal_reason: latest_delivery && latest_delivery.terminal_reason
      }
    }
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

  defp normalize_boolean(value) when value in [true, false], do: value
  defp normalize_boolean("true"), do: true
  defp normalize_boolean("false"), do: false
  defp normalize_boolean(nil), do: nil
  defp normalize_boolean(""), do: nil
  defp normalize_boolean(value), do: value

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(nil), do: nil
  defp normalize_integer(""), do: nil

  defp normalize_integer(value) do
    case Integer.parse(to_string(value)) do
      {parsed, ""} -> parsed
      _ -> value
    end
  end
end
