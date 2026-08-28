defmodule Example.Accounts.UserAppLoginAttempt do
  @moduledoc "Digest-only bounded state for hosted authorization codes."
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @schema_prefix "auth"

  schema "user_app_login_attempts" do
    field :kind, Ecto.Enum, values: [:hosted_code, :hosted_cancel, :direct_mfa]
    field :digest, :binary
    field :approval_digest, :binary
    field :verifier_digest, :binary
    field :profile_id, :string
    field :client_ref, :string
    field :callback, :string
    field :audit_correlation, :string
    field :expires_at, :utc_datetime_usec
    field :consumed_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
    belongs_to :user, Example.Accounts.User
  end
end
