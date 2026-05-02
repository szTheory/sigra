defmodule <%= context_module %>.ServiceAccountCredential do
  use Ecto.Schema
  import Ecto.Changeset
<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
<% end %>
  schema "service_account_credentials" do
    field :client_id, :string
    field :hashed_client_secret, :binary
    field :expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :service_account, <%= context_module %>.ServiceAccount

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:client_id, :hashed_client_secret, :expires_at, :last_used_at, :revoked_at, :service_account_id])
    |> validate_required([:client_id, :hashed_client_secret, :service_account_id])
    |> unique_constraint(:client_id)
  end
end
