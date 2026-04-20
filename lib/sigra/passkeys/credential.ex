defmodule Sigra.Passkeys.Credential do
  @moduledoc """
  Library struct representing a WebAuthn passkey credential.

  Maps to and from the generated host `UserPasskey` Ecto schema — the library
  never references the host schema by module name. Mirrors
  `Sigra.MFA.Credential` field-for-field per Phase 19 D-04.
  """

  @type t :: %__MODULE__{
          id: term(),
          user_id: term(),
          credential_id: binary() | nil,
          public_key: binary() | nil,
          sign_count: non_neg_integer(),
          aaguid: String.t() | nil,
          nickname: String.t() | nil,
          device_hint: String.t() | nil,
          transports: [String.t()],
          rp_id: String.t() | nil,
          last_used_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :user_id,
    :credential_id,
    :public_key,
    :aaguid,
    :nickname,
    :device_hint,
    :rp_id,
    :last_used_at,
    :inserted_at,
    :updated_at,
    sign_count: 0,
    transports: []
  ]

  @credential_fields [
    :id,
    :user_id,
    :credential_id,
    :public_key,
    :sign_count,
    :aaguid,
    :nickname,
    :device_hint,
    :transports,
    :rp_id,
    :last_used_at,
    :inserted_at,
    :updated_at
  ]

  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    fields =
      Enum.reduce(@credential_fields, [], fn field, acc ->
        case Map.fetch(schema, field) do
          {:ok, value} -> [{field, value} | acc]
          :error -> acc
        end
      end)

    struct(__MODULE__, fields)
  end

  @spec to_params(t()) :: map()
  def to_params(%__MODULE__{} = credential) do
    credential
    |> Map.from_struct()
    |> Map.drop([:id, :inserted_at, :updated_at])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
