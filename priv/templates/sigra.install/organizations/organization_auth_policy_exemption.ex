defmodule <%= context_module %>.OrganizationAuthPolicyExemption do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organization_auth_policy_exemptions" do
    belongs_to :organization, <%= context_module %>.Organization
    belongs_to :user, <%= context_module %>.<%= schema_alias %>

    timestamps(type: :utc_datetime)
  end

  def changeset(exemption, attrs) do
    exemption
    |> cast(attrs, [:organization_id, :user_id])
    |> validate_required([:organization_id, :user_id])
    |> assoc_constraint(:organization)
    |> assoc_constraint(:user)
    |> unique_constraint([:organization_id, :user_id])
  end
end
