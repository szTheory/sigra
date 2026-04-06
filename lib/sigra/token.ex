defmodule Sigra.Token do
  @moduledoc """
  Signed token generation and verification.

  Sigra uses two token strategies:

  1. **Signed tokens** -- for session cookies and transport. Created via
     `Plug.Crypto.sign/4` using the host app's `secret_key_base` with
     per-purpose salts (`"sigra-session-token"`, `"sigra-email-token"`, etc.).

  2. **Hashed tokens** -- for email confirmation, password reset, and API
     keys. A random token is generated, the SHA-256 hash is stored in the
     database, and the raw token is sent to the user. Verification compares
     the hash of the submitted token against the stored hash.

  All token comparisons use constant-time comparison via
  `Plug.Crypto.secure_compare/2` to prevent timing attacks.
  """

  @doc """
  Generates a signed token for the given purpose and data.

  Uses `Plug.Crypto.sign/4` with a purpose-specific salt derived from
  the host app's `secret_key_base`.

  ## Parameters

  - `secret_key_base` - The host app's secret key base (from `endpoint.config`)
  - `purpose` - A string identifying the token's purpose (e.g., `"sigra-session-token"`)
  - `data` - The data to embed in the token (typically a user ID)
  - `opts` - Options passed to `Plug.Crypto.sign/4` (e.g., `max_age:`, `key_iterations:`)

  ## Examples

      iex> token = Sigra.Token.generate(secret, "sigra-session-token", user_id)
      iex> is_binary(token)
      true

  """
  @doc since: "0.1.0"
  @spec generate(String.t(), String.t(), term(), keyword()) :: binary()
  def generate(secret_key_base, purpose, data, opts \\ [])
      when is_binary(secret_key_base) and is_binary(purpose) do
    Plug.Crypto.sign(secret_key_base, purpose, data, opts)
  end

  @doc """
  Verifies a signed token and extracts the embedded data.

  Returns `{:ok, data}` if the token is valid and not expired, or
  `{:error, :invalid}` / `{:error, :expired}` on failure.

  ## Parameters

  - `secret_key_base` - The host app's secret key base
  - `purpose` - The purpose string used when generating the token
  - `token` - The token to verify
  - `opts` - Options passed to `Plug.Crypto.verify/4` (e.g., `max_age:`)

  ## Examples

      iex> {:ok, user_id} = Sigra.Token.verify(secret, "sigra-session-token", token, max_age: 86400)

  """
  @doc since: "0.1.0"
  @spec verify(String.t(), String.t(), binary(), keyword()) ::
          {:ok, term()} | {:error, :invalid | :expired}
  def verify(secret_key_base, purpose, token, opts \\ [])
      when is_binary(secret_key_base) and is_binary(purpose) and is_binary(token) do
    case Plug.Crypto.verify(secret_key_base, purpose, token, opts) do
      {:ok, data} -> {:ok, data}
      {:error, :expired} -> {:error, :expired}
      {:error, _} -> {:error, :invalid}
    end
  end

  @doc """
  Generates a random token and its SHA-256 hash for database storage.

  Returns `{raw_token, hashed_token}` where:

  - `raw_token` is a URL-safe base64-encoded string (sent to the user)
  - `hashed_token` is a 32-byte SHA-256 binary (stored in the database)

  ## Examples

      iex> {raw, hashed} = Sigra.Token.generate_hashed_token()
      iex> is_binary(raw) and byte_size(hashed) == 32
      true

  """
  @doc since: "0.1.0"
  @spec generate_hashed_token() :: {String.t(), binary()}
  def generate_hashed_token do
    raw = :crypto.strong_rand_bytes(32)
    hashed = :crypto.hash(:sha256, raw)
    {Base.url_encode64(raw, padding: false), hashed}
  end

  @doc """
  Hashes a raw token with SHA-256 for storage comparison.

  ## Examples

      iex> hashed = Sigra.Token.hash_token("some-raw-token")
      iex> byte_size(hashed) == 32
      true

  """
  @doc since: "0.1.0"
  @spec hash_token(binary()) :: binary()
  def hash_token(raw_token) when is_binary(raw_token) do
    :crypto.hash(:sha256, raw_token)
  end

  @doc """
  Performs a constant-time comparison of two strings.

  Delegates to `Plug.Crypto.secure_compare/2` to prevent timing attacks.

  ## Examples

      iex> Sigra.Token.secure_compare("abc", "abc")
      true

      iex> Sigra.Token.secure_compare("abc", "def")
      false

  """
  @doc since: "0.1.0"
  @spec secure_compare(binary(), binary()) :: boolean()
  def secure_compare(left, right) when is_binary(left) and is_binary(right) do
    Plug.Crypto.secure_compare(left, right)
  end
end
