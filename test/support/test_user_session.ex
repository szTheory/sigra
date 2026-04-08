defmodule Sigra.Test.UserSession do
  @moduledoc false
  # Minimal test schema mirroring the generated UserSession schema.
  # Used for Ecto store tests without requiring a real database.

  use Ecto.Schema

  schema "user_sessions" do
    field :user_id, :binary_id
    field :hashed_token, :binary
    field :type, :string
    field :ip, :string
    field :user_agent, :string
    field :geo_city, :string
    field :geo_country_code, :string
    field :last_active_at, :utc_datetime_usec
    field :sudo_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
