defmodule Sigra.Identity do
  @moduledoc """
  Library struct representing an OAuth identity (provider account linked to a user).

  Maps to and from the generated `UserIdentity` Ecto schema in the host app.
  Contains all D-25 fields: provider info, encrypted tokens, profile data, and metadata.

  ## Fields

  - `:id` - Database primary key
  - `:user_id` - The owning user's ID
  - `:provider` - Provider name as lowercase string (e.g., "google", "github")
  - `:provider_uid` - Unique identifier from the provider
  - `:encrypted_access_token` - Encrypted OAuth access token
  - `:encrypted_refresh_token` - Encrypted OAuth refresh token
  - `:token_expires_at` - When the access token expires
  - `:provider_email` - Email from the provider (may differ from user's primary email)
  - `:provider_name` - Display name from the provider
  - `:provider_avatar_url` - Avatar URL from the provider
  - `:metadata` - Normalized subset of provider response (locale, verified_email, etc.)
  - `:last_used_at` - Last OAuth login or token refresh
  - `:inserted_at` - Record creation timestamp
  - `:updated_at` - Record update timestamp
  """

  @doc since: "0.1.0"

  @type t :: %__MODULE__{
          id: term(),
          user_id: term(),
          provider: String.t() | nil,
          provider_uid: String.t() | nil,
          encrypted_access_token: binary() | nil,
          encrypted_refresh_token: binary() | nil,
          token_expires_at: DateTime.t() | nil,
          provider_email: String.t() | nil,
          provider_name: String.t() | nil,
          provider_avatar_url: String.t() | nil,
          metadata: map(),
          last_used_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :user_id,
    :provider,
    :provider_uid,
    :encrypted_access_token,
    :encrypted_refresh_token,
    :token_expires_at,
    :provider_email,
    :provider_name,
    :provider_avatar_url,
    :last_used_at,
    :inserted_at,
    :updated_at,
    metadata: %{}
  ]

  @identity_fields [
    :id,
    :user_id,
    :provider,
    :provider_uid,
    :encrypted_access_token,
    :encrypted_refresh_token,
    :token_expires_at,
    :provider_email,
    :provider_name,
    :provider_avatar_url,
    :metadata,
    :last_used_at,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates an `Identity` struct from an Ecto schema struct or map.

  Maps fields by name from the source to the Identity struct.
  Unknown fields in the source are ignored.

  ## Examples

      iex> Sigra.Identity.from_schema(%{provider: "google", provider_uid: "123"})
      %Sigra.Identity{provider: "google", provider_uid: "123", metadata: %{}}

  """
  @doc since: "0.1.0"
  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    fields =
      @identity_fields
      |> Enum.map(fn field -> {field, Map.get(schema, field)} end)

    struct(__MODULE__, fields)
  end

  @doc """
  Converts an `Identity` struct to a map suitable for Ecto changeset params.

  Normalizes the provider name to lowercase (D-30), drops `:id`, `:inserted_at`,
  and `:updated_at` (managed by Ecto), and removes nil values.

  ## Examples

      iex> identity = %Sigra.Identity{provider: "Google", provider_uid: "123"}
      iex> Sigra.Identity.to_params(identity)
      %{provider: "google", provider_uid: "123", metadata: %{}}

  """
  @doc since: "0.1.0"
  @spec to_params(t()) :: map()
  def to_params(%__MODULE__{} = identity) do
    identity
    |> Map.from_struct()
    |> Map.update(:provider, nil, &normalize_provider/1)
    |> Map.drop([:id, :inserted_at, :updated_at])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @spec normalize_provider(nil) :: nil
  @spec normalize_provider(atom()) :: String.t()
  @spec normalize_provider(String.t()) :: String.t()
  defp normalize_provider(nil), do: nil
  defp normalize_provider(p) when is_atom(p), do: p |> to_string() |> String.downcase()
  defp normalize_provider(p) when is_binary(p), do: String.downcase(p)
end
