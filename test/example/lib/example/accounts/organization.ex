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

    has_many :memberships, Example.Accounts.OrganizationMembership
    has_many :invitations, Example.Accounts.OrganizationInvitation

    timestamps(type: :utc_datetime)
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug, :deleted_at])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:slug, min: 3, max: 63)
    |> validate_format(:slug, ~r/^[a-z][a-z0-9-]*[a-z0-9]$/, message: "must be lowercase alphanumeric with hyphens")
    |> unique_constraint(:slug)
  end
end
