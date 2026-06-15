defmodule Example.Accounts.EnterpriseConnection do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Example.Accounts.EnterpriseConnectionOIDCSettings

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @schema_prefix "auth"

  schema "enterprise_connections" do
    field :protocol, Ecto.Enum, values: [:oidc], default: :oidc

    field :status, Ecto.Enum,
      values: [:draft, :validation_failed, :active, :disabled],
      default: :draft

    field :display_name, :string
    field :login_hint_domains, {:array, :string}, default: []
    field :last_validated_at, :utc_datetime_usec
    field :last_validation_error, :string

    belongs_to :organization, Example.Accounts.Organization

    embeds_one :oidc_settings, EnterpriseConnectionOIDCSettings, on_replace: :update

    timestamps(type: :utc_datetime)
  end

  def changeset(connection, attrs) do
    attrs = normalize(attrs)

    connection
    |> cast(attrs, [
      :organization_id,
      :protocol,
      :status,
      :display_name,
      :login_hint_domains,
      :last_validated_at,
      :last_validation_error
    ])
    |> validate_required([:organization_id, :protocol, :status, :display_name])
    |> validate_length(:display_name, min: 1, max: 255)
    |> cast_embed(:oidc_settings,
      required: true,
      with: &EnterpriseConnectionOIDCSettings.changeset/2
    )
    |> assoc_constraint(:organization)
    |> unique_constraint(:display_name, name: :enterprise_connections_active_display_name_index)
  end

  defp normalize(attrs) when is_map(attrs) do
    attrs
    |> normalize_array_field("login_hint_domains")
    |> normalize_array_field(:login_hint_domains)
  end

  defp normalize(_attrs), do: %{}

  defp normalize_array_field(attrs, field) do
    case Map.get(attrs, field) do
      value when is_binary(value) ->
        Map.put(attrs, field, split_csv(value))

      _ ->
        attrs
    end
  end

  defp split_csv(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
