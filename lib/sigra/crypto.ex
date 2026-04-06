defmodule Sigra.Crypto do
  @moduledoc """
  Password hashing, verification, and hash upgrade operations.

  This module wraps the configured `Sigra.Hasher` implementation
  (default: `Sigra.Hashers.Argon2`) to provide a stable API for
  password operations. Application code should always use this module
  rather than calling hashing libraries directly.

  ## Three-Way Verification

  `verify_with_upgrade/2,3` returns one of three results:

  - `{:ok, :valid}` -- password correct, hash is current
  - `{:ok, :valid, new_hash}` -- password correct, hash needs upgrade
  - `{:error, :invalid}` -- password incorrect

  This enables transparent migration from bcrypt to Argon2id and
  automatic rehashing when Argon2 parameters are strengthened.

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

  @doc """
  Verifies a password and detects whether the hash needs upgrading.

  Returns one of three results:

  - `{:ok, :valid}` -- password matches, hash is current
  - `{:ok, :valid, new_hash}` -- password matches, caller should persist `new_hash`
  - `{:error, :invalid}` -- password does not match

  Hash upgrade is triggered when:
  - The hash is bcrypt (`$2b$` or `$2a$` prefix) -- migrates to Argon2id
  - The hash is Argon2id with stale parameters -- rehashes with current params

  When `hashed_password` is `nil`, runs timing protection and returns
  `{:error, :invalid}`.

  ## Options

  - `:hasher` - Module implementing `Sigra.Hasher`. Default: `Sigra.Hashers.Argon2`
  - `:m_cost` - Argon2 memory cost parameter for rehash detection
  - `:t_cost` - Argon2 time cost parameter for rehash detection
  - `:parallelism` - Argon2 parallelism parameter for rehash detection

  ## Examples

      iex> hashed = Sigra.Crypto.hash_password("secret")
      iex> Sigra.Crypto.verify_with_upgrade("secret", hashed)
      {:ok, :valid}

      iex> Sigra.Crypto.verify_with_upgrade("wrong", hashed)
      {:error, :invalid}

  """
  @doc since: "0.2.0"
  @spec verify_with_upgrade(String.t(), String.t() | nil, keyword()) ::
          {:ok, :valid} | {:ok, :valid, String.t()} | {:error, :invalid}
  def verify_with_upgrade(password, hashed_password, opts \\ [])

  def verify_with_upgrade(_password, nil, opts) do
    no_user_verify(opts)
    {:error, :invalid}
  end

  def verify_with_upgrade(password, hashed_password, opts) when is_binary(password) do
    cond do
      bcrypt_hash?(hashed_password) ->
        if bcrypt_verify(password, hashed_password) do
          new_hash = hash_password(password, opts)
          {:ok, :valid, new_hash}
        else
          {:error, :invalid}
        end

      argon2_hash?(hashed_password) ->
        if verify_password(password, hashed_password, opts) do
          if needs_rehash?(hashed_password, opts) do
            new_hash = hash_password(password, opts)
            {:ok, :valid, new_hash}
          else
            {:ok, :valid}
          end
        else
          {:error, :invalid}
        end

      true ->
        no_user_verify(opts)
        {:error, :invalid}
    end
  end

  @doc """
  Checks whether an Argon2id hash needs rehashing due to parameter changes.

  Parses the hash string to extract `m`, `t`, and `p` parameters and compares
  them against the current configuration. Returns `true` if any parameter
  differs or if the hash cannot be parsed.

  Non-Argon2 hashes always return `true`.

  ## Options

  - `:m_cost` - Expected memory cost as power of 2. Default: from `:argon2_elixir` config or 16.
  - `:t_cost` - Expected time cost (iterations). Default: from `:argon2_elixir` config or 3.
  - `:parallelism` - Expected parallelism. Default: from `:argon2_elixir` config or 4.

  ## Examples

      iex> hashed = Sigra.Crypto.hash_password("test")
      iex> Sigra.Crypto.needs_rehash?(hashed)
      false

      iex> Sigra.Crypto.needs_rehash?("$2b$12$...")
      true

  """
  @doc since: "0.2.0"
  @spec needs_rehash?(String.t(), keyword()) :: boolean()
  def needs_rehash?(hashed_password, opts \\ []) do
    case parse_argon2_params(hashed_password) do
      {:ok, %{m: m, t: t, p: p}} ->
        current_m =
          Keyword.get(opts, :m_cost, Application.get_env(:argon2_elixir, :m_cost, 16))

        current_t =
          Keyword.get(opts, :t_cost, Application.get_env(:argon2_elixir, :t_cost, 3))

        current_p =
          Keyword.get(opts, :parallelism, Application.get_env(:argon2_elixir, :parallelism, 4))

        configured_m = :math.pow(2, current_m) |> round()
        m != configured_m or t != current_t or p != current_p

      :error ->
        true
    end
  end

  @doc """
  Returns `true` if the hash string has a bcrypt prefix (`$2b$` or `$2a$`).
  """
  @doc since: "0.2.0"
  @spec bcrypt_hash?(String.t()) :: boolean()
  def bcrypt_hash?(hash) when is_binary(hash) do
    String.starts_with?(hash, "$2b$") or String.starts_with?(hash, "$2a$")
  end

  @doc """
  Returns `true` if the hash string has an Argon2 prefix (`$argon2`).
  """
  @doc since: "0.2.0"
  @spec argon2_hash?(String.t()) :: boolean()
  def argon2_hash?(hash) when is_binary(hash) do
    String.starts_with?(hash, "$argon2")
  end

  # -- Private helpers --

  defp bcrypt_verify(password, hashed_password) do
    if Code.ensure_loaded?(Bcrypt) do
      Sigra.Hashers.Bcrypt.verify_password(password, hashed_password)
    else
      # bcrypt_elixir not available -- cannot verify bcrypt hashes
      # Run timing protection and return false
      no_user_verify()
      false
    end
  end

  defp parse_argon2_params(hash) do
    case Regex.run(~r/\$argon2\w+\$v=\d+\$m=(\d+),t=(\d+),p=(\d+)\$/, hash) do
      [_, m, t, p] ->
        {:ok,
         %{
           m: String.to_integer(m),
           t: String.to_integer(t),
           p: String.to_integer(p)
         }}

      _ ->
        :error
    end
  end
end
