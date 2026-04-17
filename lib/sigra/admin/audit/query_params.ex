defmodule Sigra.Admin.Audit.QueryParams do
  @moduledoc """
  Whitelist-first normalization for admin audit explorer and export filters.
  """

  alias Sigra.Admin.Scope
  alias Sigra.Audit.Cursor

  @allowed_params ~w(
    actor
    effective_user
    organization
    action
    action_prefix
    outcome
    from
    to
    cursor
    page_size
    subject_user
  )
  @default_limit 25
  @max_limit 100

  @spec normalize(map() | keyword() | nil, Scope.t()) :: {:ok, map()} | {:error, term()}
  def normalize(params, %Scope{} = admin_scope) do
    with {:ok, normalized} <- normalize_params(params || %{}),
         {:ok, normalized} <- maybe_put_cursor(normalized),
         {:ok, normalized} <- maybe_put_page_size(normalized),
         {:ok, normalized} <- maybe_put_scope(normalized, admin_scope) do
      {:ok, normalized}
    end
  end

  defp normalize_params(params) do
    params
    |> stringify_map()
    |> Map.take(@allowed_params)
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Enum.reduce_while({:ok, %{}}, fn
      {"actor", value}, {:ok, acc} -> put_uuid(acc, :actor_id, value)
      {"effective_user", value}, {:ok, acc} -> put_uuid(acc, :effective_user_id, value)
      {"organization", value}, {:ok, acc} -> put_uuid(acc, :organization_id, value)
      {"subject_user", value}, {:ok, acc} -> put_uuid(acc, :subject_user_id, value)
      {"action", value}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, :action, String.trim(value))}}
      {"action_prefix", value}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, :action_prefix, String.trim(value))}}
      {"outcome", value}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, :outcome, String.trim(value))}}
      {"from", value}, {:ok, acc} -> put_datetime(acc, :from, value)
      {"to", value}, {:ok, acc} -> put_datetime(acc, :to, value)
      {"cursor", value}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, :cursor, String.trim(value))}}
      {"page_size", value}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, :page_size, value)}}
    end)
  end

  defp maybe_put_cursor(normalized) do
    case Map.pop(normalized, :cursor) do
      {nil, normalized} ->
        {:ok, Map.put(normalized, :cursor, nil)}

      {cursor, normalized} ->
        case Cursor.decode(cursor) do
          {:ok, decoded} -> {:ok, Map.put(normalized, :cursor, decoded)}
          {:error, :invalid_cursor} -> {:error, {:cursor, :invalid}}
        end
    end
  end

  defp maybe_put_page_size(normalized) do
    case Map.pop(normalized, :page_size) do
      {nil, normalized} ->
        {:ok, Map.put(normalized, :limit, @default_limit)}

      {value, normalized} ->
        case Integer.parse(to_string(value)) do
          {limit, ""} when limit > 0 and limit <= @max_limit ->
            {:ok, Map.put(normalized, :limit, limit)}

          _ ->
            {:error, {:page_size, :invalid}}
        end
    end
  end

  defp maybe_put_scope(normalized, %Scope{mode: :organization, organization_id: org_id})
       when is_binary(org_id) do
    case Map.get(normalized, :organization_id) do
      nil ->
        {:ok, normalized |> Map.delete(:organization_id) |> Map.put(:organization_scope, {:only, org_id})}

      ^org_id ->
        {:ok, normalized |> Map.delete(:organization_id) |> Map.put(:organization_scope, {:only, org_id})}

      _other ->
        {:error, {:organization, :out_of_scope}}
    end
  end

  defp maybe_put_scope(normalized, %Scope{}), do: {:ok, normalized}

  defp put_uuid(acc, key, value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:cont, {:ok, Map.put(acc, key, uuid)}}
      :error -> {:halt, {:error, {key, :invalid}}}
    end
  end

  defp put_datetime(acc, key, value) do
    case DateTime.from_iso8601(to_string(value)) do
      {:ok, dt, _offset} -> {:cont, {:ok, Map.put(acc, key, dt)}}
      _ -> {:halt, {:error, {key, :invalid}}}
    end
  end

  defp stringify_map(params) when is_list(params), do: Map.new(params, fn {k, v} -> {to_string(k), v} end)
  defp stringify_map(params) when is_map(params), do: Map.new(params, fn {k, v} -> {to_string(k), v} end)
  defp stringify_map(_params), do: %{}

  defp blank?(value), do: value in [nil, "", []]
end
