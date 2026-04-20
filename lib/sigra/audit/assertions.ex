defmodule Sigra.Audit.Assertions do
  @moduledoc """
  Plain-function helpers for asserting on persisted audit rows in tests.

  All functions take an explicit `repo` so host apps can use their own
  `Ecto.Repo` (including Sandbox ownership) without hidden globals.

  Queries always apply a deterministic `ORDER BY inserted_at DESC, id DESC`
  before `LIMIT 1` so the "latest" row is stable under concurrent inserts.

  ## Optional audit (`:audit_optional`)

  Host apps may omit `:audit_schema` in `Sigra.Config`. For tests that only
  sometimes run with audit enabled, tag examples with `@tag :audit_optional`
  and skip assertions when `audit_schema` is `nil` (see
  `test/sigra/audit/audit_assertions_test.exs`).
  """

  import Ecto.Query

  alias Sigra.Audit.Query

  @filter_fields [
    :action,
    :outcome,
    :actor_id,
    :effective_user_id,
    :target_id,
    :organization_id,
    :target_type
  ]

  @doc """
  Returns the latest audit row matching `filters`, or `nil`.

  `filters` may only contain keys from `Sigra.Audit.Query.allowed_filters/0`.
  `:order_by` and other unsupported keys must not be passed to
  `Sigra.Audit.query/1` — ordering is always applied here.

  Raises `ArgumentError` if `audit_schema` is `nil`.
  """
  @spec latest_audit_event(Ecto.Repo.t(), module(), keyword()) :: struct() | nil
  def latest_audit_event(repo, audit_schema, filters \\ [])

  def latest_audit_event(_repo, audit_schema, _filters) when is_nil(audit_schema) do
    raise ArgumentError, "audit_schema is required"
  end

  def latest_audit_event(repo, audit_schema, filters)
      when is_atom(audit_schema) and is_list(filters) do
    validate_filters!(filters)

    query =
      [audit_schema: audit_schema]
      |> Keyword.merge(filters)
      |> Sigra.Audit.query()

    query
    |> order_by([e], desc: e.inserted_at, desc: e.id)
    |> limit(1)
    |> repo.one()
  end

  @doc """
  Asserts the latest audit row matching filter fields derived from
  `required_map` matches every field in the map.

  Non-nil entries among `#{inspect(@filter_fields)}` in `required_map` are
  used as `Sigra.Audit.query/1` filters (AND). At least one such field must
  be non-nil so the row is uniquely targeted (typically `:action`).

  For `:metadata`, `expected` must be a map: every key in `expected` must
  exist in the stored metadata with the same value (atoms and strings are
  treated as equivalent keys for lookup).
  """
  @spec assert_audit_fields(Ecto.Repo.t(), module(), map()) :: :ok
  def assert_audit_fields(_repo, audit_schema, _required_map) when is_nil(audit_schema) do
    raise ArgumentError, "audit_schema is required"
  end

  def assert_audit_fields(repo, audit_schema, required_map)
      when is_atom(audit_schema) and is_map(required_map) do
    filter_kw =
      required_map
      |> Map.take(@filter_fields)
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Keyword.new()

    if filter_kw == [] do
      raise ArgumentError,
            "assert_audit_fields/3 requires at least one non-nil filter field among " <>
              inspect(@filter_fields) <>
              " (for example :action) to locate the audit row"
    end

    case latest_audit_event(repo, audit_schema, filter_kw) do
      nil ->
        raise ArgumentError,
              "assert_audit_fields/3: no audit row for filters #{inspect(filter_kw)}"

      event ->
        Enum.each(required_map, fn {field, expected} ->
          actual = Map.get(event, field)

          case field do
            :metadata ->
              unless metadata_subset?(actual, expected) do
                mismatch!(field, expected, actual)
              end

            _ ->
              unless actual == expected do
                mismatch!(field, expected, actual)
              end
          end
        end)

        :ok
    end
  end

  defp validate_filters!(filters) do
    allowed = MapSet.new(Query.allowed_filters())

    Enum.each(filters, fn {k, _} ->
      unless MapSet.member?(allowed, k) do
        raise ArgumentError,
              "Sigra.Audit.Assertions: unknown filter key #{inspect(k)}. " <>
                "Allowed keys: #{inspect(Query.allowed_filters())}"
      end
    end)
  end

  defp metadata_subset?(actual, expected) when is_map(expected) do
    Enum.all?(expected, fn {k, v} ->
      actual_v = metadata_get(actual, k)
      actual_v == v
    end)
  end

  defp metadata_subset?(_, _), do: false

  defp metadata_get(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) ->
        Map.fetch!(map, key)

      is_atom(key) and Map.has_key?(map, Atom.to_string(key)) ->
        Map.fetch!(map, Atom.to_string(key))

      is_binary(key) ->
        try do
          atom = String.to_existing_atom(key)
          Map.get(map, atom)
        rescue
          ArgumentError -> nil
        end

      true ->
        nil
    end
  end

  defp mismatch!(field, expected, actual) do
    raise ArgumentError,
          "audit field #{inspect(field)} mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"
  end
end
