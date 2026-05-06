defmodule Sigra.Admin.Webhooks.Failures do
  @moduledoc """
  Canonical query contract for the global webhook retrying and dead-letter inbox.
  """

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope

  @allowed_params ~w(q status page page_size order_by order_direction)
  @attention_statuses ["retry_scheduled", "dead_lettered"]

  defmodule Params do
    @moduledoc false
    use Ecto.Schema

    @primary_key false

    @derive {
      Flop.Schema,
      filterable: [:q, :status],
      sortable: [:inserted_at, :status, :attempt_count],
      default_limit: 25,
      max_limit: 100,
      default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
    }

    embedded_schema do
      field :q, :string
      field :status, :string
      field :inserted_at, :utc_datetime
      field :attempt_count, :integer
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

  @spec list_deliveries(map(), Scope.t(), map() | keyword() | nil) ::
          {:ok, {list(map()), Flop.Meta.t(), map()}} | {:error, Flop.Meta.t()}
  def list_deliveries(config, %Scope{} = admin_scope, params \\ %{}) do
    Authorizer.authorize_global!(admin_scope)

    with {:ok, normalized} <- normalize_params(params),
         {:ok, %Flop{} = flop} <- Flop.validate(to_flop_params(normalized), for: Params) do
      delivery_schema = Sigra.Webhooks.delivery_schema!(config)

      query =
        from(delivery in delivery_schema, as: :delivery)
        |> where([delivery: delivery], delivery.status in ^@attention_statuses)
        |> apply_filters(normalized)

      pagination_flop = %Flop{flop | filters: []}
      meta = Flop.meta(query, pagination_flop, for: Params, repo: config.repo)

      rows =
        query
        |> Flop.query(pagination_flop, for: Params)
        |> config.repo.all()
        |> attach_subscriptions(config)

      {:ok, {rows, meta, normalized}}
    end
  end

  defp apply_filters(query, normalized) do
    query
    |> maybe_filter_status(Map.get(normalized, "status"))
    |> maybe_filter_q(Map.get(normalized, "q"))
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, "retrying"), do: query

  defp maybe_filter_status(query, status) do
    where(query, [delivery: delivery], delivery.status == ^status)
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

  defp attach_subscriptions(deliveries, config) do
    subscription_schema = Sigra.Webhooks.subscription_schema!(config)
    subscription_ids = Enum.map(deliveries, & &1.webhook_subscription_id)

    subscriptions_by_id =
      from(subscription in subscription_schema, where: subscription.id in ^subscription_ids)
      |> config.repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.map(deliveries, fn delivery ->
      %{delivery: delivery, subscription: Map.get(subscriptions_by_id, delivery.webhook_subscription_id)}
    end)
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

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) do
    case Integer.parse(to_string(value)) do
      {parsed, ""} -> parsed
      _ -> value
    end
  end
end
