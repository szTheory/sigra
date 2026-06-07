<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= context_module %>.OrganizationAuthPolicy do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

<%= if auth_prefix do %>  @schema_prefix "<%= auth_prefix %>"
<% end %>

  schema "organization_auth_policies" do
    field :enforcement_mode, Ecto.Enum, values: [:optional, :sso_required], default: :optional

    belongs_to :organization, <%= context_module %>.Organization

    timestamps(type: :utc_datetime)
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [:organization_id, :enforcement_mode])
    |> validate_required([:organization_id, :enforcement_mode])
    |> assoc_constraint(:organization)
    |> unique_constraint(:organization_id)
  end
end
