defmodule Sigra.Admin.Webhooks.Query do
  @moduledoc """
  Canonical query contract for the admin webhook subscription index.
  """

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope

  @allowed_params ~w(q status enabled page page_size order_by order_direction)

  defmodule Params do
    @moduledoc false
    use Ecto.Schema

    @primary_key false

    @derive {
      Flop.Schema,
      filterable: [:q, :status, :enabled],
      sortable: [:inserted_at, :endpoint_url, :enabled],
      default_limit: 25,
      max_limit: 100,
      default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
    }

    embedded_schema do
      field :q, :string
      field :status, :string
      field :enabled, :boolean
      field :inserted_at, :utc_datetime
      field :endpoint_url, :string
    end
  end

  @spec normalize_params(map() | keyword() | nil) :: {:ok, map()} | {:error, Flop.Meta.t()}
  def normalize_params(params) do
    params
    |> stringify_map()
    |> Map.take(@allowed_params)
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Map.new(fn
      {"q", value} -> {"q", String.trim(to_string(value))}
      {"status", value} -> {"status", String.trim(to_string(value))}
      {"enabled", value} -> {"enabled", normalize_boolean(value)}
      {"page", value} -> {"page", normalize_integer(value)}
      {"page_size", value} -> {"page_size", normalize_integer(value)}
      {"order_by", value} -> {"order_by", normalize_string(value)}
      {"order_direction", value} -> {"order_direction", normalize_string(value)}
    end)
    |> then(fn normalized ->
      case Flop.validate(to_flop_params(normalized), for: Params) do
        {:ok, flop} -> {:ok, merge_flop_defaults(normalized, flop)}
        {:error, %Flop.Meta{} = meta} -> {:error, meta}
      end
    end)
  end

  @spec list_subscriptions(map(), Scope.t(), map() | keyword() | nil) ::
          {:ok, {list(map()), Flop.Meta.t(), map()}} | {:error, Flop.Meta.t()}
  def list_subscriptions(config, %Scope{} = admin_scope, params \\ %{}) do
    Authorizer.authorize_global!(admin_scope)

    with {:ok, normalized} <- normalize_params(params),
         {:ok, %Flop{} = flop} <- Flop.validate(to_flop_params(normalized), for: Params) do
      subscription_schema = Sigra.Webhooks.subscription_schema!(config)

      query =
        from(subscription in subscription_schema, as: :subscription)
        |> apply_filters(normalized)

      pagination_flop = %Flop{flop | filters: []}
      meta = Flop.meta(query, pagination_flop, for: Params, repo: config.repo)

      rows =
        query
        |> Flop.query(pagination_flop, for: Params)
        |> config.repo.all()
        |> attach_latest_deliveries(config)
        |> maybe_filter_status(Map.get(normalized, "status"))
        |> Enum.map(&row_from_result/1)

      {:ok, {rows, meta, normalized}}
    end
  end

  defp apply_filters(query, normalized) do
    query
    |> maybe_filter_q(Map.get(normalized, "q"))
    |> maybe_filter_enabled(Map.get(normalized, "enabled"))
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

  defp maybe_filter_status(rows, nil), do: rows

  defp maybe_filter_status(rows, "retrying") do
    Enum.filter(rows, fn %{latest_delivery: delivery} ->
      delivery && delivery.status in ["retry_scheduled", "dead_lettered"]
    end)
  end

  defp maybe_filter_status(rows, status) do
    Enum.filter(rows, fn %{latest_delivery: delivery} ->
      delivery && delivery.status == status
    end)
  end

  defp maybe_filter_enabled(query, nil), do: query

  defp maybe_filter_enabled(query, enabled) when is_boolean(enabled) do
    where(query, [subscription: subscription], subscription.enabled == ^enabled)
  end

  defp attach_latest_deliveries(subscriptions, config) do
    delivery_schema = Sigra.Webhooks.delivery_schema!(config)
    subscription_ids = Enum.map(subscriptions, & &1.id)

    latest_by_subscription =
      from(delivery in delivery_schema,
        where: delivery.webhook_subscription_id in ^subscription_ids,
        order_by: [
          asc: delivery.webhook_subscription_id,
          desc: delivery.inserted_at,
          desc: delivery.id
        ],
        distinct: delivery.webhook_subscription_id
      )
      |> config.repo.all()
      |> Map.new(&{&1.webhook_subscription_id, &1})

    Enum.map(subscriptions, fn subscription ->
      %{
        subscription: subscription,
        latest_delivery: Map.get(latest_by_subscription, subscription.id)
      }
    end)
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
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_order_by(map, nil), do: map
  defp maybe_put_order_by(map, value), do: Map.put(map, "order_by", [value])

  defp maybe_put_order_direction(map, nil), do: map
  defp maybe_put_order_direction(map, value), do: Map.put(map, "order_directions", [value])

  defp stringify_map(params) when is_list(params),
    do: Map.new(params, fn {key, value} -> {to_string(key), value} end)

  defp stringify_map(params) when is_map(params),
    do: Map.new(params, fn {key, value} -> {to_string(key), value} end)

  defp stringify_map(_params), do: %{}

  defp blank?(value), do: value in [nil, "", []]

  defp normalize_string(value), do: value |> to_string() |> String.trim()

  defp normalize_boolean(value) when value in [true, false], do: value
  defp normalize_boolean("true"), do: true
  defp normalize_boolean("false"), do: false
  defp normalize_boolean(value), do: value

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) do
    case Integer.parse(to_string(value)) do
      {parsed, ""} -> parsed
      _ -> value
    end
  end
end
