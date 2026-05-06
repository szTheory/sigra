defmodule Sigra.Webhooks.Serializers.User do
  @moduledoc """
  Public user serializer for webhook payloads.
  """

  @spec serialize(struct() | map(), keyword()) :: map()
  def serialize(user, _opts \\ []) do
    %{
      "id" => Map.get(user, :id),
      "email" => Map.get(user, :email),
      "display_name" => Map.get(user, :display_name),
      "confirmed_at" => iso(Map.get(user, :confirmed_at)),
      "deleted_at" => iso(Map.get(user, :deleted_at)),
      "created_at" => iso(Map.get(user, :inserted_at)),
      "updated_at" => iso(Map.get(user, :updated_at))
    }
    |> drop_nil_values()
  end

  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso(%NaiveDateTime{} = value), do: value |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()
  defp iso(_value), do: nil

  defp drop_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end
