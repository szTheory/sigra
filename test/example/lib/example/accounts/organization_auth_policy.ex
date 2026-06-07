defmodule Example.Accounts.OrganizationAuthPolicy do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @schema_prefix "auth"

  schema "organization_auth_policies" do
    field :enforcement_mode, Ecto.Enum, values: [:optional, :sso_required], default: :optional

    belongs_to :organization, Example.Accounts.Organization

    has_many :exemptions, Example.Accounts.OrganizationAuthPolicyExemption,
      foreign_key: :organization_id,
      references: :organization_id

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
