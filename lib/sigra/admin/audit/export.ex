defmodule Sigra.Admin.Audit.Export do
  @moduledoc """
  Shared scope-safe CSV export orchestration for admin audit explorer routes.
  """

  import Ecto.Query

  alias Sigra.Admin.Audit.CSVExport
  alias Sigra.Admin.Audit.Query
  alias Sigra.Admin.Audit.QueryParams
  alias Sigra.Admin.Scope

  @allowed_order_fields ~w(inserted_at occurred_at)
  @default_order_by "inserted_at"
  @default_order_direction "desc"

  @spec csv(map(), Scope.t(), map() | keyword() | nil) :: {:ok, String.t()} | {:error, term()}
  def csv(config, %Scope{} = admin_scope, params \\ %{}) do
    export(config, admin_scope, params, [])
  end

  @spec subject_csv(map(), Scope.t(), binary(), map() | keyword() | nil) ::
          {:ok, String.t()} | {:error, term()}
  def subject_csv(config, %Scope{} = admin_scope, user_id, params \\ %{})
      when is_binary(user_id) do
    export(config, admin_scope, params, subject_user_id: user_id)
  end

  defp export(config, %Scope{} = admin_scope, params, extra_filters) do
    params = stringify_map(params)
    filter_params = Map.drop(params, ["order_by", "order_direction", "return_to"])

    with {:ok, normalized} <- QueryParams.normalize(filter_params, admin_scope) do
      order_by = normalize_order_field(Map.get(params, "order_by"))
      order_direction = normalize_order_direction(Map.get(params, "order_direction"))
      limit = normalized.limit
      cursor = normalized.cursor
      filters = build_filters(normalized, admin_scope, extra_filters)
      audit_schema = audit_schema!(config)

      events =
        audit_schema
        |> Query.build(filters)
        |> apply_order(order_by, order_direction)
        |> apply_cursor(order_by, order_direction, cursor)
        |> limit(^limit)
        |> config.repo.all()

      users_by_id = load_users(config, events)
      orgs_by_id = load_organizations(config, events)
      csv_opts = csv_row_opts(admin_scope, extra_filters)

      rows =
        Enum.map(events, &CSVExport.row(&1, users_by_id, orgs_by_id, csv_opts))

      {:ok, CSVExport.dump(rows)}
    else
      {:error, {:organization, :out_of_scope}} ->
        {:ok, CSVExport.dump([])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_order(query, "occurred_at", "asc"),
    do: order_by(query, [event], asc: event.occurred_at, asc: event.id)

  defp apply_order(query, "occurred_at", _direction),
    do: order_by(query, [event], desc: event.occurred_at, desc: event.id)

  defp apply_order(query, _field, "asc"),
    do: order_by(query, [event], asc: event.inserted_at, asc: event.id)

  defp apply_order(query, _field, _direction),
    do: order_by(query, [event], desc: event.inserted_at, desc: event.id)

  defp apply_cursor(query, _field, _direction, nil), do: query

  defp apply_cursor(query, "occurred_at", "asc", {%DateTime{} = cursor_ts, cursor_id}) do
    where(
      query,
      [event],
      event.occurred_at > ^cursor_ts or
        (event.occurred_at == ^cursor_ts and event.id > ^cursor_id)
    )
  end

  defp apply_cursor(query, "occurred_at", _direction, {%DateTime{} = cursor_ts, cursor_id}) do
    where(
      query,
      [event],
      event.occurred_at < ^cursor_ts or
        (event.occurred_at == ^cursor_ts and event.id < ^cursor_id)
    )
  end

  defp apply_cursor(query, _field, "asc", {%DateTime{} = cursor_ts, cursor_id}) do
    where(
      query,
      [event],
      event.inserted_at > ^cursor_ts or
        (event.inserted_at == ^cursor_ts and event.id > ^cursor_id)
    )
  end

  defp apply_cursor(query, _field, _direction, {%DateTime{} = cursor_ts, cursor_id}) do
    where(
      query,
      [event],
      event.inserted_at < ^cursor_ts or
        (event.inserted_at == ^cursor_ts and event.id < ^cursor_id)
    )
  end

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

  defp load_organizations(config, events) do
    ids =
      events
      |> Enum.map(& &1.organization_id)
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    organization_schema = organization_schema(config)

    if ids == [] or is_nil(organization_schema) do
      %{}
    else
      from(organization in organization_schema, where: organization.id in ^ids)
      |> config.repo.all()
      |> Map.new(&{&1.id, &1})
    end
  end

  defp organization_schema(config) do
    Map.get(config, :organization_schema) ||
      optional_schema(accounts_module(config), :Organization)
  end

  defp accounts_module(%{accounts_module: module}) when is_atom(module), do: module
  defp accounts_module(%{accounts: module}) when is_atom(module), do: module

  defp accounts_module(%{user_schema: module}) when is_atom(module) do
    module |> Module.split() |> Enum.drop(-1) |> Module.safe_concat()
  rescue
    ArgumentError -> nil
  end

  defp accounts_module(_config), do: nil
  defp optional_schema(nil, _name), do: nil

  defp optional_schema(module, name) do
    schema = Module.concat(module, name)
    if Code.ensure_loaded?(schema), do: schema, else: nil
  end

  defp audit_schema!(%{audit: audit}) when is_list(audit),
    do: Keyword.fetch!(audit, :audit_schema)

  defp audit_schema!(config) do
    raise ArgumentError,
          "Sigra admin audit export requires :audit_schema in config: #{inspect(config)}"
  end

  defp normalize_order_field(value) when value in @allowed_order_fields, do: value
  defp normalize_order_field(_value), do: @default_order_by
  defp normalize_order_direction("asc"), do: "asc"
  defp normalize_order_direction("desc"), do: "desc"
  defp normalize_order_direction(_value), do: @default_order_direction

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

  defp stringify_map(params) when is_list(params),
    do: Map.new(params, fn {k, v} -> {to_string(k), v} end)

  defp stringify_map(params) when is_map(params),
    do: Map.new(params, fn {k, v} -> {to_string(k), v} end)

  defp stringify_map(_params), do: %{}

  # When exporting a subject user's audit from an organization admin route,
  # rows that predate org attribution (nil organization_id) still need a
  # stable organization_label column so CSV evidence matches the org lens.
  defp csv_row_opts(
         %Scope{mode: :organization, organization: %{id: _} = org},
         extra_filters
       )
       when is_map(org) and is_list(extra_filters) do
    if Keyword.has_key?(extra_filters, :subject_user_id) do
      [scope_organization: org]
    else
      []
    end
  end

  defp csv_row_opts(_admin_scope, _extra_filters), do: []
end
