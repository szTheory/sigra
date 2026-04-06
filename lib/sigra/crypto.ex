defmodule Sigra.Crypto do
  @moduledoc """
  Password hashing and verification operations.

  This module wraps the configured `Sigra.Hasher` implementation
  (default: `Sigra.Hashers.Argon2`) to provide a stable API for
  password operations. Application code should always use this module
  rather than calling hashing libraries directly.

  ## Enumeration Prevention

  The `no_user_verify/1` function runs a dummy hash operation when a
  user is not found, preventing timing-based user enumeration attacks.
  """

  @default_hasher Sigra.Hashers.Argon2

  @doc """
  Hashes a plaintext password using the configured hasher.

  Returns the hashed password string (e.g., `"$argon2id$..."`).

  ## Options

  - `:hasher` - Module implementing `Sigra.Hasher`. Default: `Sigra.Hashers.Argon2`

  ## Examples

      iex> hashed = Sigra.Crypto.hash_password("supersecret123")
      iex> String.starts_with?(hashed, "$argon2id$")
      true

  """
  @doc since: "0.1.0"
  @spec hash_password(String.t(), keyword()) :: String.t()
  def hash_password(password, opts \\ []) when is_binary(password) do
    hasher = Keyword.get(opts, :hasher, @default_hasher)
    hasher.hash_password(password)
  end

  @doc """
  Verifies a plaintext password against a hashed password.

  Returns `true` if the password matches, `false` otherwise.
  Uses constant-time comparison internally (provided by the hasher).

  ## Options

  - `:hasher` - Module implementing `Sigra.Hasher`. Default: `Sigra.Hashers.Argon2`

  ## Examples

      iex> hashed = Sigra.Crypto.hash_password("supersecret123")
      iex> Sigra.Crypto.verify_password("supersecret123", hashed)
      true

      iex> Sigra.Crypto.verify_password("wrong", hashed)
      false

  """
  @doc since: "0.1.0"
  @spec verify_password(String.t(), String.t(), keyword()) :: boolean()
  def verify_password(password, hashed_password, opts \\ [])
      when is_binary(password) and is_binary(hashed_password) do
    hasher = Keyword.get(opts, :hasher, @default_hasher)
    hasher.verify_password(password, hashed_password)
  end

  @doc """
  Runs a dummy hash to prevent timing-based user enumeration.

  When a login attempt references a non-existent user, call this function
  to ensure the response time is similar to a real password verification.
  Always returns `false`.

  ## Options

  - `:hasher` - Module implementing `Sigra.Hasher`. Default: `Sigra.Hashers.Argon2`

  ## Examples

      iex> Sigra.Crypto.no_user_verify()
      false

  """
  @doc since: "0.1.0"
  @spec no_user_verify(keyword()) :: false
  def no_user_verify(opts \\ []) do
    hasher = Keyword.get(opts, :hasher, @default_hasher)
    hasher.no_user_verify()
    false
  end
end
