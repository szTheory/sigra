defmodule Sigra.Organizations.Query do
  @moduledoc """
  Tenant-scoping query helpers for organization-aware schemas.

  `for_org/2` is the primary enforcement layer against cross-tenant data
  leaks (Pitfall O-1). `maybe_enforce_org_scope/4` provides defense-in-depth
  via the generated Repo's `prepare_query/3` callback (D-14).
  """

  import Ecto.Query

  require Logger

  @doc """
  Scopes a queryable to a specific organization.

  Accepts either a map with an `active_organization` key that has an `id`
  field (such as a `%Scope{}`), or a raw binary organization ID. Raises
  `ArgumentError` if the schema does not have an `:organization_id` field.

  ## Examples

      Sigra.Organizations.Query.for_org(Post, scope)
      Sigra.Organizations.Query.for_org(Post, "org-uuid-here")

  """
  @spec for_org(Ecto.Queryable.t(), map() | binary()) :: Ecto.Query.t()
  def for_org(queryable, %{active_organization: %{id: org_id}}) when is_binary(org_id) do
    for_org(queryable, org_id)
  end

  def for_org(_queryable, %{active_organization: nil}) do
    raise ArgumentError,
      "for_org/2 requires a scope with an active organization, but active_organization is nil"
  end

  def for_org(queryable, org_id) when is_binary(org_id) do
    query = Ecto.Queryable.to_query(queryable)
    schema = extract_schema(query)

    unless :organization_id in schema.__schema__(:fields) do
      raise ArgumentError,
        "#{inspect(schema)} does not have an :organization_id field. " <>
          "for_org/2 can only scope schemas with an :organization_id column."
    end

    where(query, [r], r.organization_id == ^org_id)
  end

  @doc """
  Defense-in-depth tenant enforcement for `prepare_query/3` delegation.

  Checks that queries on enforced schemas include an `organization_id`
  WHERE clause. Called from the generated Repo's `prepare_query/3` callback.

  Skips enforcement for:
  - `skip_org_check: true` in opts (explicit escape hatch)
  - `:ecto_query` values `:preload` or `:schema_migration`
  - Non-query operations (`:insert`, `:insert_all`, `:delete`, `:delete_all`, `:update`, `:update_all`)
  - Schemas not in the enforced list

  Returns `{query, opts}` (the `prepare_query/3` return shape).
  """
  @spec maybe_enforce_org_scope(atom(), Ecto.Query.t(), keyword(), map()) ::
          {Ecto.Query.t(), keyword()}
  def maybe_enforce_org_scope(operation, query, opts, config) do
    cond do
      opts[:skip_org_check] == true ->
        {query, opts}

      opts[:ecto_query] in [:preload, :schema_migration] ->
        {query, opts}

      operation not in [:all, :one] ->
        {query, opts}

      true ->
        enforce_if_needed(query, opts, config)
    end
  end

  # -- Private --

  defp enforce_if_needed(query, opts, config) do
    enforced = Map.get(config, :enforced_schemas, [])

    case extract_schema_safe(query) do
      nil ->
        {query, opts}

      schema ->
        if schema in enforced do
          if has_org_id_filter?(query) do
            {query, opts}
          else
            raise ArgumentError,
              "Query on #{inspect(schema)} is missing an organization_id filter. " <>
                "Use Sigra.Organizations.Query.for_org/2 to scope the query, or " <>
                "pass skip_org_check: true to bypass enforcement."
          end
        else
          {query, opts}
        end
    end
  end

  defp extract_schema(query) do
    case query.from.source do
      {_table, schema} when is_atom(schema) and not is_nil(schema) ->
        schema

      _ ->
        raise ArgumentError,
          "for_org/2 requires a schema-based query, but got a query without a schema source."
    end
  end

  defp extract_schema_safe(query) do
    case query.from.source do
      {_table, schema} when is_atom(schema) and not is_nil(schema) -> schema
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp has_org_id_filter?(query) do
    Enum.any?(query.wheres, fn %Ecto.Query.BooleanExpr{expr: expr} ->
      expr_pins_org_id?(expr)
    end)
  rescue
    error ->
      # Fail CLOSED: if the AST cannot be walked, treat as missing filter.
      # Previously this returned true (fail open), which is a security risk
      # for a defense-in-depth tenant scope check.
      Logger.error(
        "Sigra.Organizations.Query: could not inspect WHERE clauses for org_id filter. " <>
          "Failing closed. error=#{inspect(error)}"
      )

      false
  end

  # Walk the expression AST and return true only when we find an equality
  # between `r.organization_id` and a PINNED value (`^org_id`) or a literal.
  # We deliberately reject:
  #   - `r.organization_id == r2.organization_id` (column-to-column join)
  #   - `is_nil(r.organization_id)` (does not constrain to a tenant)
  #   - references to `organization_id` on the SELECT or JOIN side only.
  defp expr_pins_org_id?({:==, _, [lhs, rhs]}) do
    (org_id_column?(lhs) and pinned_or_literal?(rhs)) or
      (org_id_column?(rhs) and pinned_or_literal?(lhs))
  end

  defp expr_pins_org_id?({:and, _, [lhs, rhs]}) do
    expr_pins_org_id?(lhs) or expr_pins_org_id?(rhs)
  end

  defp expr_pins_org_id?({:or, _, [lhs, rhs]}) do
    # OR must pin org_id on BOTH sides — otherwise one branch escapes tenancy.
    expr_pins_org_id?(lhs) and expr_pins_org_id?(rhs)
  end

  defp expr_pins_org_id?({_op, _, args}) when is_list(args) do
    Enum.any?(args, &expr_pins_org_id?/1)
  end

  defp expr_pins_org_id?(_), do: false

  # A reference to `r.organization_id` from any binding (source or join).
  defp org_id_column?({{:., _, [{:&, _, _}, :organization_id]}, _, _}), do: true
  defp org_id_column?(_), do: false

  # A pinned parameter (`^value`) or a literal binary/integer.
  defp pinned_or_literal?({:^, _, _}), do: true
  defp pinned_or_literal?(value) when is_binary(value), do: true
  defp pinned_or_literal?(value) when is_integer(value), do: true
  defp pinned_or_literal?(_), do: false
end
