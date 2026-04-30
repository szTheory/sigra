defmodule Sigra.Hashers.Bcrypt do
  @moduledoc """
  Bcrypt password hasher for migration from bcrypt to Argon2id.

  This module implements the `Sigra.Hasher` behaviour using `bcrypt_elixir`.
  It is intended for transparent hash migration: when a user logs in with
  a bcrypt-hashed password, it is verified and then re-hashed with Argon2id.

  `bcrypt_elixir` is an optional dependency. If it is not loaded, calling
  `hash_password/1` or `verify_password/2` will raise a descriptive error.
  The `no_user_verify/0` function gracefully falls back to Argon2 timing
  when bcrypt is unavailable.

  ## Installation

  Add to your `mix.exs` dependencies:

      {:bcrypt_elixir, "~> 3.3"}

  """

  @behaviour Sigra.Hasher

  alias Sigra.OptionalDeps

  @impl Sigra.Hasher
  def hash_password(password) when is_binary(password) do
    ensure_available!()
    Bcrypt.hash_pwd_salt(password)
  end

  @impl Sigra.Hasher
  def verify_password(password, hashed_password)
      when is_binary(password) and is_binary(hashed_password) do
    ensure_available!(password_hash: hashed_password)
    Bcrypt.verify_pass(password, hashed_password)
  end

  @impl Sigra.Hasher
  def no_user_verify do
    if dependency_loaded?() do
      Bcrypt.no_user_verify()
    else
      # Fall back to Argon2 timing if bcrypt not available
      Sigra.Hashers.Argon2.no_user_verify()
    end
  end

  defp ensure_available!(context \\ []) do
    OptionalDeps.ensure_available!(:bcrypt_migration, Keyword.put_new(context, :has_bcrypt_hash?, true))
  end

  defp dependency_loaded? do
    spec = OptionalDeps.feature_spec!(:bcrypt_migration)
    Enum.any?(spec.dependency_modules, &Code.ensure_loaded?/1)
  end
end
