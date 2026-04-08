defmodule Sigra.TestUserToken do
  @moduledoc false
  # Minimal user token schema for testing JWT refresh tokens.

  use Ecto.Schema

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end
end
