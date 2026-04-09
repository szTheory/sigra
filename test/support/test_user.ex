defmodule Sigra.TestUser do
  @moduledoc false
  # Minimal user schema for testing.
  # Uses embedded_schema to get Ecto.Changeset compatibility without a DB table.

  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  embedded_schema do
    field :email, :string
    field :token_epoch, :integer
    field :role, :string
    field :hashed_password, :string
    field :pending_email, :string
    field :confirmed_at, :utc_datetime
    field :must_change_password, :boolean, default: false
    field :deleted_at, :utc_datetime
    field :scheduled_deletion_at, :utc_datetime
    field :original_email, :string
    field :password_changed_at, :utc_datetime
  end
end
