defmodule Sigra.Webhooks.Serializers.ServiceAccount do
  @moduledoc """
  Public service-account serializer for webhook payloads.
  """

  @spec serialize(struct() | map(), keyword()) :: map()
  def serialize(service_account, _opts \\ []) do
    %{
      "id" => Map.get(service_account, :id),
      "organization_id" => Map.get(service_account, :organization_id),
      "name" => Map.get(service_account, :name),
      "scopes" => normalize_scopes(Map.get(service_account, :scopes)),
      "revoked_at" => iso(Map.get(service_account, :revoked_at)),
      "created_at" => iso(Map.get(service_account, :inserted_at)),
      "updated_at" => iso(Map.get(service_account, :updated_at))
    }
    |> drop_nil_values()
  end

  defp normalize_scopes(value) when is_list(value), do: value
  defp normalize_scopes(_value), do: nil

  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso(%NaiveDateTime{} = value), do: value |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()
  defp iso(_value), do: nil

  defp drop_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end
