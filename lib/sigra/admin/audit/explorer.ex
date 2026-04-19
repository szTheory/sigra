defmodule Sigra.Admin.Audit.Explorer do
  @moduledoc """
  Shared scope-safe list orchestration for admin audit explorer routes.
  """

  import Ecto.Query

  alias Sigra.Admin.Audit.Presenter
  alias Sigra.Admin.Audit.Query
  alias Sigra.Admin.Audit.QueryParams
  alias Sigra.Admin.Scope
  alias Sigra.Audit.Cursor

  @allowed_order_fields ~w(inserted_at occurred_at)
  @default_order_by "inserted_at"
  @default_order_direction "desc"

  @spec list_events(map(), Scope.t(), map() | keyword() | nil) ::
          {:ok, {[map()], map(), map()}} | {:error, term()}
  def list_events(config, %Scope{} = admin_scope, params \\ %{}) do
    list(config, admin_scope, params, [])
  end

  @spec list_subject_events(map(), Scope.t(), binary(), map() | keyword() | nil) ::
          {:ok, {[map()], map(), map()}} | {:error, term()}
  def list_subject_events(config, %Scope{} = admin_scope, user_id, params \\ %{})
      when is_binary(user_id) do
    list(config, admin_scope, params, subject_user_id: user_id)
  end

  defp paginate(query, _order_by, "desc", nil, limit), do: Query.paginate(query, nil, limit)
  defp paginate(query, _order_by, "desc", cursor, limit), do: Query.paginate(query, cursor, limit)

  defp paginate(query, order_by, "asc", cursor, limit) do
    field = String.to_existing_atom(order_by)

    query
    |> maybe_apply_ascending_cursor(field, cursor)
    |> order_by([event], asc: field(event, ^field), asc: event.id)
    |> limit(^(limit + 1))
  end

  defp maybe_apply_ascending_cursor(query, _field, nil), do: query

  defp maybe_apply_ascending_cursor(query, field, {%DateTime{} = cursor_ts, cursor_id}) do
    where(
      query,
      [event],
      field(event, ^field) > ^cursor_ts or
        (field(event, ^field) == ^cursor_ts and event.id > ^cursor_id)
    )
  end

  defp split_page(events, limit) do
    page_events = Enum.take(events, limit)

    next_cursor =
      case Enum.at(events, limit) do
        nil -> nil
        _extra -> cursor_for(List.last(page_events))
      end

    {page_events, next_cursor}
  end

  defp cursor_for(nil), do: nil
  defp cursor_for(event), do: {event.inserted_at, event.id}
  defp encode_cursor(nil), do: nil
  defp encode_cursor({%DateTime{} = inserted_at, id}), do: Cursor.encode(inserted_at, id)

  defp load_users(config, events) do
    ids =
      events
      |> Enum.flat_map(fn event -> [event.actor_id, event.effective_user_id, event.target_id] end)
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    if ids == [] do
      %{}
    else
      from(user in config.user_schema, where: user.id in ^ids)
      |> config.repo.all()
      |> Map.new(&{&1.id, &1})
    end
  end

  defp audit_schema!(%{audit: audit}) when is_list(audit),
    do: Keyword.fetch!(audit, :audit_schema)

  defp audit_schema!(config) do
    raise ArgumentError,
          "Sigra admin audit explorer requires :audit_schema in config: #{inspect(config)}"
  end

  defp normalize_order_field(value) when value in @allowed_order_fields, do: value
  defp normalize_order_field(_value), do: @default_order_by
  defp normalize_order_direction("asc"), do: "asc"
  defp normalize_order_direction("desc"), do: "desc"
  defp normalize_order_direction(_value), do: @default_order_direction

  defp sanitize_params(params) do
    params
    |> Enum.reject(fn {_key, value} -> value in [nil, "", false] end)
    |> Enum.into(%{})
  end

  defp stringify_map(params) when is_list(params),
    do: Map.new(params, fn {k, v} -> {to_string(k), v} end)

  defp stringify_map(params) when is_map(params),
    do: Map.new(params, fn {k, v} -> {to_string(k), v} end)

  defp stringify_map(_params), do: %{}

  defp list(config, %Scope{} = admin_scope, params, extra_filters) do
    params = stringify_map(params)
    filter_params = Map.drop(params, ["order_by", "order_direction", "return_to"])

    with {:ok, normalized} <- QueryParams.normalize(filter_params, admin_scope) do
      order_by = normalize_order_field(Map.get(params, "order_by"))
      order_direction = normalize_order_direction(Map.get(params, "order_direction"))
      limit = normalized.limit
      cursor = normalized.cursor
      filters = build_filters(normalized, admin_scope, extra_filters)
      audit_schema = audit_schema!(config)

      query =
        audit_schema
        |> Query.build(filters)
        |> paginate(order_by, order_direction, cursor, limit)

      events = config.repo.all(query)
      {page_events, next_cursor} = split_page(events, limit)
      users_by_id = load_users(config, page_events)
      rows = Presenter.present(page_events, users_by_id)

      current_params =
        params
        |> sanitize_params()
        |> Map.put("order_by", order_by)
        |> Map.put("order_direction", order_direction)

      meta = %{
        current_page: if(cursor, do: 2, else: 1),
        previous_page: nil,
        next_page: encode_cursor(next_cursor)
      }

      {:ok, {rows, meta, current_params}}
    else
      {:error, {:organization, :out_of_scope}} ->
        {:ok,
         {[], %{current_page: 1, previous_page: nil, next_page: nil}, sanitize_params(params)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_filters(
         normalized,
         %Scope{mode: :organization, organization_id: org_id},
         extra_filters
       )
       when is_binary(org_id) do
    normalized
    |> Map.drop([:cursor, :limit, :organization_scope])
    |> Map.put(:organization_scope, organization_scope(extra_filters, org_id))
    |> Map.to_list()
    |> Keyword.merge(extra_filters)
  end

  defp build_filters(normalized, _admin_scope, extra_filters) do
    normalized
    |> Map.drop([:cursor, :limit])
    |> Map.to_list()
    |> Keyword.merge(extra_filters)
  end

  defp organization_scope(extra_filters, org_id) do
    if Keyword.has_key?(extra_filters, :subject_user_id) do
      {:including_global, org_id}
    else
      {:only, org_id}
    end
  end
end
