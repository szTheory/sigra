defmodule Sigra.Hashers.Argon2 do
  @moduledoc """
  Argon2id password hasher implementation.

  Uses `argon2_elixir` which wraps the reference C implementation of
  Argon2id -- the OWASP-recommended password hashing algorithm. Argon2id
  is memory-hard and resistant to GPU/ASIC attacks.

  ## Configuration

  Argon2 parameters can be configured via application config:

      config :argon2_elixir,
        t_cost: 3,
        m_cost: 16,
        parallelism: 2

  For testing, use minimal cost parameters:

      config :argon2_elixir, t_cost: 1, m_cost: 8
  """

  @behaviour Sigra.Hasher

  @impl Sigra.Hasher
  def hash_password(password) when is_binary(password) do
    Argon2.hash_pwd_salt(password)
  end

  @impl Sigra.Hasher
  def verify_password(password, hashed_password)
      when is_binary(password) and is_binary(hashed_password) do
    Argon2.verify_pass(password, hashed_password)
  end

  @impl Sigra.Hasher
  def no_user_verify do
    Argon2.no_user_verify()
    :ok
  end
end
