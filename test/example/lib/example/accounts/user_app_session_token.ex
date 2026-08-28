defmodule Example.Accounts.UserAppSessionToken do
  @moduledoc "Digest-only opaque credentials belonging to one app-session family."
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @schema_prefix "auth"

  schema "user_app_session_tokens" do
    field :kind, Ecto.Enum, values: [:access, :refresh]
    field :digest, :binary
    field :expires_at, :utc_datetime_usec
    field :consumed_at, :utc_datetime_usec
    field :superseded_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
    belongs_to :family, Example.Accounts.UserAppSessionFamily
  end
end
