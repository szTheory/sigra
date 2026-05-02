defmodule Example.Accounts.ServiceAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "service_accounts" do
    field :name, :string
    field :scopes, {:array, :string}, default: []
    field :role, :string
    field :token_epoch, :integer, default: 0
    field :revoked_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec

    belongs_to :organization, Example.Accounts.Organization
    belongs_to :created_by, Example.Accounts.User, foreign_key: :created_by_user_id

    has_many :credentials, Example.Accounts.ServiceAccountCredential

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(service_account, attrs) do
    service_account
    |> cast(attrs, [
      :name,
      :scopes,
      :role,
      :organization_id,
      :created_by_user_id,
      :token_epoch,
      :revoked_at,
      :last_used_at
    ])
    |> validate_required([:name, :organization_id])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint([:organization_id, :name],
      name: :service_accounts_organization_id_name_index,
      message: "A service account with that name already exists in this organization."
    )
  end
end
