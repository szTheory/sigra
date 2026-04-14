defmodule Example.Accounts.OrganizationInvitation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organization_invitations" do
    field :email, :string
    field :role, Ecto.Enum, values: [:owner, :admin, :member]
    field :hashed_token, :binary
    field :accepted_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :organization, Example.Accounts.Organization
    belongs_to :invited_by, Example.Accounts.User
    belongs_to :accepted_by, Example.Accounts.User
    belongs_to :revoked_by, Example.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [
      :email,
      :role,
      :expires_at,
      :hashed_token,
      :accepted_at,
      :revoked_at,
      :organization_id,
      :invited_by_id,
      :accepted_by_id,
      :revoked_by_id
    ])
    |> validate_required([:email, :role, :expires_at, :organization_id])
    |> assoc_constraint(:organization)
    |> unique_constraint([:organization_id, :email],
      name: :organization_invitations_pending_index
    )
  end
end
