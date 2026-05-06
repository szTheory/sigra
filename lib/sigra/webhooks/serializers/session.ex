defmodule Sigra.Webhooks.Serializers.Session do
  @moduledoc """
  Public session serializer for webhook payloads.
  """

  @spec serialize(struct() | map(), keyword()) :: map()
  def serialize(session, _opts \\ []) do
    %{
      "id" => Map.get(session, :id),
      "user_id" => Map.get(session, :user_id),
      "organization_id" => Map.get(session, :organization_id),
      "type" => normalize_type(Map.get(session, :type)),
      "revoked_at" => iso(Map.get(session, :revoked_at)),
      "sudo_at" => iso(Map.get(session, :sudo_at)),
      "last_active_at" => iso(Map.get(session, :last_active_at)),
      "created_at" => iso(Map.get(session, :inserted_at))
    }
    |> drop_nil_values()
  end

  defp normalize_type(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_type(value) when is_binary(value), do: value
  defp normalize_type(_value), do: nil

  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso(%NaiveDateTime{} = value), do: value |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()
  defp iso(_value), do: nil

  defp drop_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end
