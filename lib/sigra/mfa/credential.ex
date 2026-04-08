defmodule Sigra.MFA.Credential do
  @moduledoc """
  Library struct representing an MFA credential (e.g., TOTP enrollment).

  Maps to and from the generated `UserMfaCredential` Ecto schema in the host app.
  Contains all fields needed for TOTP verification, lockout tracking, and replay
  prevention.

  ## Fields

  - `:id` - Database primary key
  - `:user_id` - The owning user's ID
  - `:type` - MFA type as string (e.g., "totp")
  - `:encrypted_secret` - Encrypted TOTP secret (via cloak_ecto)
  - `:last_used_at` - Last successful verification timestamp
  - `:last_verified_step` - Last accepted TOTP time step (replay prevention, D-41)
  - `:failed_attempts` - Failed MFA attempt counter (D-31)
  - `:locked_until` - Lockout expiry timestamp (nil if not locked)
  - `:enabled_at` - When MFA was enabled
  - `:inserted_at` - Record creation timestamp
  - `:updated_at` - Record update timestamp
  """

  @doc since: "0.6.0"

  @type t :: %__MODULE__{
          id: term(),
          user_id: term(),
          type: String.t() | nil,
          encrypted_secret: binary() | nil,
          last_used_at: DateTime.t() | nil,
          last_verified_step: integer() | nil,
          failed_attempts: non_neg_integer(),
          locked_until: DateTime.t() | nil,
          enabled_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :user_id,
    :type,
    :encrypted_secret,
    :last_used_at,
    :last_verified_step,
    :locked_until,
    :enabled_at,
    :inserted_at,
    :updated_at,
    failed_attempts: 0
  ]

  @credential_fields [
    :id,
    :user_id,
    :type,
    :encrypted_secret,
    :last_used_at,
    :last_verified_step,
    :failed_attempts,
    :locked_until,
    :enabled_at,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates a `Credential` struct from an Ecto schema struct or map.

  Maps fields by name from the source to the Credential struct.
  Unknown fields in the source are ignored.

  ## Examples

      iex> Sigra.MFA.Credential.from_schema(%{type: "totp", user_id: 42})
      %Sigra.MFA.Credential{type: "totp", user_id: 42, failed_attempts: 0}

  """
  @doc since: "0.6.0"
  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    fields =
      @credential_fields
      |> Enum.reduce([], fn field, acc ->
        case Map.fetch(schema, field) do
          {:ok, value} -> [{field, value} | acc]
          :error -> acc
        end
      end)

    struct(__MODULE__, fields)
  end

  @doc """
  Converts a `Credential` struct to a map suitable for Ecto changeset params.

  Drops `:id`, `:inserted_at`, and `:updated_at` (managed by Ecto) and
  removes nil values.

  ## Examples

      iex> credential = %Sigra.MFA.Credential{user_id: 42, type: "totp"}
      iex> params = Sigra.MFA.Credential.to_params(credential)
      iex> params.user_id
      42

  """
  @doc since: "0.6.0"
  @spec to_params(t()) :: map()
  def to_params(%__MODULE__{} = credential) do
    credential
    |> Map.from_struct()
    |> Map.drop([:id, :inserted_at, :updated_at])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
