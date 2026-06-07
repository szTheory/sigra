defmodule Example.Accounts.OrganizationAuthPolicyExemption do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @schema_prefix "auth"

  schema "organization_auth_policy_exemptions" do
    belongs_to :organization, Example.Accounts.Organization
    belongs_to :user, Example.Accounts.User

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
