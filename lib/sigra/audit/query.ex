defmodule Sigra.Audit.Query do
  @moduledoc """
  Composable Ecto query builder for `audit_events`.

  Supported filters (D-12):

    * `:actor_id`
    * `:action`
    * `:action_prefix` — SQL LIKE with escaped prefix
    * `:outcome`
    * `:from` / `:to` — `DateTime` bounds on `inserted_at`
    * `:target_id`
    * `:target_type`

  Pagination uses the or-expanded `(inserted_at, id)` tiebreak so it is
  portable across PostgreSQL, MySQL, and SQLite (RESEARCH A3).
  """
  import Ecto.Query

  @allowed_filters [
    :actor_id,
    :action,
    :action_prefix,
    :outcome,
    :from,
    :to,
    :target_id,
    :target_type,
    :organization_id,
    :effective_user_id,
    :organization_scope
  ]

  @doc """
  Returns the canonical list of filter keys accepted by `build/2`.

  Unknown keys raise `ArgumentError` (D-15 breaking change in v1.1).
  """
  @spec allowed_filters() :: [atom()]
  def allowed_filters, do: @allowed_filters

  @spec build(module(), keyword()) :: Ecto.Query.t()
  def build(audit_schema, filters \\ []) do
    Enum.each(filters, fn {k, _} ->
      unless k in @allowed_filters do
        raise ArgumentError,
              "Sigra.Audit.Query: unknown filter key #{inspect(k)}. " <>
                "Allowed keys: #{inspect(@allowed_filters)}"
      end
    end)

    Enum.reduce(filters, from(e in audit_schema), &apply_filter/2)
  end

  defp apply_filter({:actor_id, id}, q), do: where(q, [e], e.actor_id == ^id)
  defp apply_filter({:action, a}, q), do: where(q, [e], e.action == ^a)

  defp apply_filter({:action_prefix, p}, q) when is_binary(p) do
    pattern = escape_like(p) <> "%"
    where(q, [e], like(e.action, ^pattern))
  end

  defp apply_filter({:outcome, o}, q), do: where(q, [e], e.outcome == ^o)

  defp apply_filter({:from, %DateTime{} = t}, q),
    do: where(q, [e], e.inserted_at >= ^t)

  defp apply_filter({:to, %DateTime{} = t}, q),
    do: where(q, [e], e.inserted_at <= ^t)

  defp apply_filter({:target_id, id}, q), do: where(q, [e], e.target_id == ^id)
  defp apply_filter({:target_type, t}, q), do: where(q, [e], e.target_type == ^t)

  # D-15: Phase 15 new filters — organization_id, effective_user_id, organization_scope
  defp apply_filter({:organization_id, nil}, q),
    do: where(q, [e], is_nil(e.organization_id))

  defp apply_filter({:organization_id, id}, q),
    do: where(q, [e], e.organization_id == ^id)

  defp apply_filter({:effective_user_id, nil}, q),
    do: where(q, [e], is_nil(e.effective_user_id))

  defp apply_filter({:effective_user_id, id}, q),
    do: where(q, [e], e.effective_user_id == ^id)

  defp apply_filter({:organization_scope, {:only, org_id}}, q),
    do: where(q, [e], e.organization_id == ^org_id)

  # TODO(v1.2): Postgres may not use the (organization_id, inserted_at) composite
  # index for the IS NULL branch. Revisit with partial index on
  # WHERE organization_id IS NULL or a UNION ALL rewrite.
  defp apply_filter({:organization_scope, {:including_global, org_id}}, q),
    do: where(q, [e], e.organization_id == ^org_id or is_nil(e.organization_id))

  defp apply_filter({key, _value}, _q) do
    raise ArgumentError,
          "Sigra.Audit.Query: unknown filter key #{inspect(key)}. " <>
            "Allowed keys: #{inspect(@allowed_filters)}"
  end

  @doc """
  Applies cursor + limit + desc ordering using or-expanded tiebreak
  (portable across PostgreSQL, MySQL, and SQLite).
  """
  @spec paginate(Ecto.Query.t(), nil | {DateTime.t(), binary()}, pos_integer()) ::
          Ecto.Query.t()
  def paginate(query, nil, limit) do
    query
    |> order_by([e], desc: e.inserted_at, desc: e.id)
    |> limit(^(limit + 1))
  end

  def paginate(query, {%DateTime{} = cursor_ts, cursor_id}, limit) do
    query
    |> where(
      [e],
      e.inserted_at < ^cursor_ts or
        (e.inserted_at == ^cursor_ts and e.id < ^cursor_id)
    )
    |> order_by([e], desc: e.inserted_at, desc: e.id)
    |> limit(^(limit + 1))
  end

  defp escape_like(s) do
    String.replace(s, ["\\", "%", "_"], fn c -> "\\" <> c end)
  end
end
