defmodule Sigra.JWT.Signer do
  @moduledoc """
  JWT key loading and signer creation.

  Derives signing keys from the application's `secret_key_base` for HS256,
  or loads PEM keys for RS256/ES256. All functions guard against the
  registry-backed optional dependency contract for Joken.
  """

  @compile {:no_warn_undefined, [Joken, Joken.Signer]}

  alias Sigra.OptionalDeps

  @doc """
  Ensures Joken is available at runtime.

  Raises a tagged Sigra optional-dependency error if Joken is not loaded.
  Called before any JWT operation.
  """
  @spec ensure_joken!() :: :ok
  def ensure_joken! do
    OptionalDeps.ensure_available!(:jwt, jwt: [enabled: true])
  end

  @doc """
  Creates a `Joken.Signer` for the configured algorithm.

  For HS256, derives the signing key from `secret_key_base` using
  HMAC-SHA256 with the salt `"sigra-jwt-signing-key"`.

  For RS256/ES256, loads the PEM private key from configuration.

  ## Parameters

  - `config` - A `Sigra.Config.t()` struct with JWT configuration.

  ## Raises

  - `RuntimeError` if Joken is not loaded
  - `RuntimeError` if `secret_key_base` is nil for HS256
  - `KeyError` if `private_key` is missing for RS256/ES256
  """
  @spec create_signer(Sigra.Config.t()) :: struct()
  def create_signer(config) do
    ensure_joken!()
    jwt_config = config.jwt
    algorithm = Keyword.get(jwt_config, :algorithm, "HS256")

    case algorithm do
      "HS256" ->
        secret = config_secret_key_base(config)
        key = :crypto.mac(:hmac, :sha256, secret, "sigra-jwt-signing-key")
        Joken.Signer.create("HS256", key)

      "RS256" ->
        pem = Keyword.fetch!(jwt_config, :private_key)
        Joken.Signer.create("RS256", %{"pem" => pem})

      "ES256" ->
        pem = Keyword.fetch!(jwt_config, :private_key)
        Joken.Signer.create("ES256", %{"pem" => pem})
    end
  end

  defp config_secret_key_base(config) do
    config.secret_key_base ||
      raise RuntimeError, "secret_key_base is required for JWT HS256 signing"
  end
end
