
defmodule SigraInstallGoldenTmp.Accounts.PlatformAdminGrant do
  @moduledoc """
  Host-owned persisted platform-admin grant.

  A grant is active while `revoked_at` is nil. Keep authorization decisions
  explicit: signup order, email domain, and account creation never create one.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @schema_prefix "auth"


  schema "sigra_platform_admin_grants" do
    belongs_to :user, SigraInstallGoldenTmp.Accounts.User
    field :revoked_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:user_id, :revoked_at])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end
