defmodule Sigra.Hasher do
  @moduledoc """
  Behaviour for password hashing implementations.

  Sigra uses this behaviour to abstract the password hashing algorithm,
  allowing transparent migration between hashing algorithms (e.g., bcrypt
  to Argon2id) and easy testing via Mox.

  ## Default Implementation

  `Sigra.Hashers.Argon2` -- uses Argon2id, the OWASP-recommended algorithm.

  ## Mox Usage

      Mox.defmock(MockHasher, for: Sigra.Hasher)
  """

  @doc "Hashes a plaintext password and returns the hashed string."
  @doc since: "0.1.0"
  @callback hash_password(password :: String.t()) :: String.t()

  @doc "Verifies a plaintext password against a hashed password."
  @doc since: "0.1.0"
  @callback verify_password(password :: String.t(), hashed_password :: String.t()) :: boolean()

  @doc """
  Runs a dummy hash operation to prevent timing-based user enumeration.

  This must take approximately the same time as a real hash verification
  to prevent attackers from distinguishing between "user exists" and
  "user does not exist" based on response time.
  """
  @doc since: "0.1.0"
  @callback no_user_verify() :: :ok
end
