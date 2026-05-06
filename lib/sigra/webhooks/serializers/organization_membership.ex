defmodule Sigra.Webhooks.Serializers.OrganizationMembership do
  @moduledoc """
  Public organization-membership serializer for webhook payloads.
  """

  @spec serialize(struct() | map(), keyword()) :: map()
  def serialize(membership, _opts \\ []) do
    %{
      "id" => Map.get(membership, :id),
      "organization_id" => Map.get(membership, :organization_id),
      "user_id" => Map.get(membership, :user_id),
      "role" => normalize_role(Map.get(membership, :role)),
      "created_at" => iso(Map.get(membership, :inserted_at)),
      "updated_at" => iso(Map.get(membership, :updated_at))
    }
    |> drop_nil_values()
  end

  defp normalize_role(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_role(value) when is_binary(value), do: value
  defp normalize_role(_value), do: nil

  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso(%NaiveDateTime{} = value), do: value |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()
  defp iso(_value), do: nil

  defp drop_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end
