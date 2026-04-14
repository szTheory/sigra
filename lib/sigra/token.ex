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

  @invite_purpose "sigra-org-invite-token"

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
  Generates a signed invitation envelope binding email into the HMAC payload.

  Returns `{encoded_signed_token, hashed_token_for_storage}`.

  ## Why this diverges from `sigra-confirm-token`

  Confirmation tokens sign the raw token only — the holder of the link IS
  the user being confirmed, so identity is bound by convention at DB
  compare time. Invitations are the exception: the holder of the link is
  NOT yet the authenticated principal, so identity must be bound
  cryptographically. This closes the Jetstream #907 / Keycloak
  CVE-2026-1529 class of invite-hijack bugs by construction.

  Payload shape uses STRING keys (`"t"`, `"e"`) to avoid atom-table growth
  on decode.
  """
  @doc since: "0.4.0"
  @spec generate_invite_envelope(String.t(), String.t()) :: {String.t(), binary()}
  def generate_invite_envelope(secret_key_base, email)
      when is_binary(secret_key_base) and is_binary(email) do
    {raw, _raw_bytes_hash} = generate_hashed_token()
    # Re-hash the base64 raw string so the stored hash matches
    # `hash_token(raw)` computed by `verify_invite_envelope/3`.
    hashed = hash_token(raw)
    payload = %{"t" => raw, "e" => String.downcase(email)}
    signed = Plug.Crypto.sign(secret_key_base, @invite_purpose, payload)
    {Base.url_encode64(signed, padding: false), hashed}
  end

  @doc """
  Verifies an invitation envelope and returns the raw token, bound email,
  and hashed-token-for-DB-lookup.

  Fails `{:error, :invalid}` if HMAC verify fails, base64 decode fails, or
  the payload shape is wrong. Fails `{:error, :expired}` if the envelope is
  older than `max_age_seconds`.

  Distinguishing `:invalid` from other errors MUST NOT leak information to
  the attacker — callers should treat both `:invalid` and `:expired` as
  "invitation link is not valid" with the same user-facing copy.
  """
  @doc since: "0.4.0"
  @spec verify_invite_envelope(String.t(), String.t(), pos_integer()) ::
          {:ok, %{raw_token: binary(), bound_email: String.t(), hashed_token: binary()}}
          | {:error, :invalid | :expired}
  def verify_invite_envelope(secret_key_base, encoded, max_age_seconds)
      when is_binary(secret_key_base) and is_binary(encoded) and is_integer(max_age_seconds) do
    with {:ok, signed} <- url_decode(encoded),
         {:ok, %{"t" => raw, "e" => email}} when is_binary(raw) and is_binary(email) <-
           Plug.Crypto.verify(secret_key_base, @invite_purpose, signed, max_age: max_age_seconds) do
      {:ok, %{raw_token: raw, bound_email: email, hashed_token: hash_token(raw)}}
    else
      {:ok, _other_shape} -> {:error, :invalid}
      {:error, :expired} -> {:error, :expired}
      _ -> {:error, :invalid}
    end
  end

  defp url_decode(encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, :invalid}
    end
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
