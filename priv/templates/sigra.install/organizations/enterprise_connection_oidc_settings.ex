defmodule <%= context_module %>.EnterpriseConnectionOIDCSettings do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :issuer, :string
    field :discovery_document_uri, :string
    field :client_id, :string
    field :encrypted_client_secret, <%= context_module %>.Encrypted.Binary
    field :client_authentication_method, :string, default: "client_secret_basic"
    field :scopes, {:array, :string}, default: ["openid", "profile", "email"]
  end

  def changeset(oidc_settings, attrs) do
    attrs = normalize(attrs)

    oidc_settings
    |> cast(attrs, [
      :issuer,
      :discovery_document_uri,
      :client_id,
      :encrypted_client_secret,
      :client_authentication_method,
      :scopes
    ])
    |> validate_required([:issuer, :client_id, :encrypted_client_secret, :client_authentication_method])
    |> validate_inclusion(:client_authentication_method, ["client_secret_basic", "client_secret_post"])
    |> validate_length(:scopes, min: 1)
  end

  defp normalize(attrs) when is_map(attrs) do
    case Map.get(attrs, "scopes") || Map.get(attrs, :scopes) do
      value when is_binary(value) ->
        Map.put(attrs, "scopes", split_csv(value))

      _ ->
        attrs
    end
  end

  defp normalize(_attrs), do: %{}

  defp split_csv(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
