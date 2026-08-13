defmodule Sigra.Test.AppLoginSchemas do
  @moduledoc false

  defmodule Attempt do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_app_login_attempts" do
      field :digest, :binary
      field :verifier_digest, :binary
      field :profile_id, :string
      field :callback, :string
      field :user_id, :binary_id
      field :client_ref, :string
      field :expires_at, :utc_datetime_usec
      field :consumed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Challenge do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_app_login_challenges" do
      field :kind, Ecto.Enum, values: [:direct_mfa]
      field :digest, :binary
      field :profile_id, :string
      field :user_id, :binary_id
      field :client_ref, :string
      field :expires_at, :utc_datetime_usec
      field :consumed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end
  end
end
