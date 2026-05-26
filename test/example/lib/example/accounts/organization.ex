defmodule Example.Accounts.Organization do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :deleted_at, :utc_datetime
    # Phase 18 D-01: personal-workspace flag. Library-managed, NOT exposed via cast/3.
    field :personal, :boolean, default: false

    # Phase 18 D-00: sticky origin owner. Library sets via put_change/3 in
    # Sigra.Organizations.create_organization/3; NEVER exposed via cast/3.
    belongs_to :owner, Example.Accounts.User, foreign_key: :owner_user_id

    has_many :memberships, Example.Accounts.OrganizationMembership
    has_many :invitations, Example.Accounts.OrganizationInvitation
    has_one :auth_policy, Example.Accounts.OrganizationAuthPolicy
    has_many :auth_policy_exemptions, Example.Accounts.OrganizationAuthPolicyExemption

    timestamps(type: :utc_datetime)
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug, :deleted_at])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:slug, min: 3, max: 63)
    |> validate_format(:slug, ~r/^[a-z][a-z0-9-]*[a-z0-9]$/,
      message: "must be lowercase alphanumeric with hyphens"
    )
    |> unique_constraint(:slug, name: :organizations_slug_active_index)
  end
end
