defmodule Example.Accounts.UserAppSessionFamily do
  @moduledoc "Host-owned persistence for one opaque first-party app-session family."
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @schema_prefix "auth"

  schema "user_app_session_families" do
    field :client_ref, :string
    field :absolute_expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
    belongs_to :user, Example.Accounts.User
  end
end
