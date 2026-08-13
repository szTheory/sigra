defmodule Sigra.Test.AppSessionSchemas do
  @moduledoc false

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_app_session_users" do
      field :email, :string
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Family do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_app_session_families" do
      field :user_id, :binary_id
      field :client_ref, :string
      field :absolute_expires_at, :utc_datetime_usec
      field :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Token do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_app_session_tokens" do
      field :family_id, :binary_id
      field :kind, Ecto.Enum, values: [:access, :refresh]
      field :digest, :binary
      field :expires_at, :utc_datetime_usec
      field :consumed_at, :utc_datetime_usec
      field :superseded_at, :utc_datetime_usec
      field :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end
  end
end
