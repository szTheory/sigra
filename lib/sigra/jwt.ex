defmodule Sigra.JWT do
  @moduledoc """
  JWT access token generation, verification, and refresh token management.

  Provides the opt-in JWT authentication path for Sigra. All functions guard
  against Joken absence at runtime -- if Joken is not loaded, a clear error
  is raised with installation instructions.

  ## Access Tokens

  JWT access tokens contain standard claims (`sub`, `iat`, `exp`, `jti`, `iss`)
  plus Sigra-specific claims (`scopes`, `epoch`). Custom claims can be added
  via the `Sigra.JWT.ClaimsBuilder` behaviour.

  ## Refresh Tokens

  Refresh tokens are opaque, hashed tokens (not JWTs) stored in the database
  with family-based reuse detection. See `Sigra.JWT.RefreshToken` for details.

  ## Epoch Check

  Every `verify_access/2` call checks the `epoch` claim against the user's
  `token_epoch` field. This catches password changes, account deletion, and
  "sign out everywhere" operations with a single DB read per request.

  ## Configuration

  JWT support must be explicitly enabled:

      config = Sigra.Config.new!(
        repo: MyApp.Repo,
        user_schema: MyApp.User,
        secret_key_base: "...",
        jwt: [
          enabled: true,
          algorithm: "HS256",
          issuer: "my_app",
          access_ttl: 900,
          refresh_ttl: 2_592_000,
          claims_builder: MyApp.JWTClaimsBuilder
        ]
      )
  """

  alias Sigra.JWT.{RefreshToken, Signer}
  alias Sigra.Telemetry

  @doc """
  Generates a JWT access token and optionally a refresh token.

  Returns `{:ok, %{access_token: jwt, refresh_token: opaque, expires_in: ttl}}`
  on success. If refresh tokens are disabled, `refresh_token` will be `nil`.

  ## Options

  - `:user_token_schema` - Required when refresh is enabled. The Ecto schema
    module for user tokens.

  ## Examples

      {:ok, tokens} = Sigra.JWT.generate_tokens(config, user, ["read:users"])
      tokens.access_token  # => "eyJ..."
      tokens.refresh_token # => "abc123..."
      tokens.expires_in    # => 900
  """
  @spec generate_tokens(Sigra.Config.t(), struct(), list(String.t()), keyword()) ::
          {:ok, map()} | {:error, term()}
  def generate_tokens(config, user, scopes, opts \\ []) do
    Signer.ensure_joken!()
    jwt_config = config.jwt

    unless Keyword.get(jwt_config, :enabled, false) do
      raise RuntimeError, "JWT support is not enabled. Set jwt: [enabled: true] in config."
    end

    Telemetry.span([:sigra, :jwt, :generate], %{user_id: user.id}, fn ->
      signer = Signer.create_signer(config)
      access_ttl = Keyword.get(jwt_config, :access_ttl, 900)
      now = DateTime.utc_now() |> DateTime.to_unix()

      claims = build_claims(config, user, scopes, now, access_ttl)

      {:ok, jwt, _full_claims} = Joken.generate_and_sign(%{}, claims, signer)

      refresh_token =
        if Keyword.get(jwt_config, :refresh, true) do
          {raw, _record} = RefreshToken.create(config, user, scopes, opts)
          raw
        else
          nil
        end

      {:ok,
       %{
         access_token: jwt,
         refresh_token: refresh_token,
         expires_in: access_ttl
       }}
    end)
  end

  @doc """
  Verifies a JWT access token.

  Checks signature validity, expiration, and (if enabled) the epoch claim
  against the user's current `token_epoch` value.

  Returns `{:ok, claims}` on success.

  ## Error Returns

  - `{:error, :invalid_token}` - Signature invalid or token malformed
  - `{:error, :token_expired}` - Token has expired
  - `{:error, :epoch_mismatch}` - User's token_epoch doesn't match claim
  """
  @spec verify_access(Sigra.Config.t(), String.t()) ::
          {:ok, map()} | {:error, :invalid_token | :token_expired | :epoch_mismatch}
  def verify_access(config, jwt_string) do
    Signer.ensure_joken!()

    Telemetry.span([:sigra, :jwt, :verify], %{}, fn ->
      signer = Signer.create_signer(config)

      case Joken.verify(jwt_string, signer) do
        {:ok, claims} ->
          cond do
            claims_expired?(claims) ->
              {:error, :token_expired}

            Keyword.get(config.jwt, :verify_epoch, true) ->
              verify_epoch(config, claims)

            true ->
              {:ok, claims}
          end

        {:error, _reason} ->
          {:error, :invalid_token}
      end
    end)
  end

  @doc """
  Refreshes an access token using a refresh token.

  Rotates the refresh token (old token is superseded, new one created in the
  same family) and generates a new access token with the same scopes.

  ## Options

  - `:user_token_schema` - Required. The Ecto schema module for user tokens.

  ## Error Returns

  - `{:error, :invalid_token}` - Refresh token not found
  - `{:error, :token_expired}` - Refresh token has expired
  - `{:error, :reuse_detected}` - Superseded token reused; entire family revoked
  """
  @spec refresh(Sigra.Config.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :invalid_token | :token_expired | :reuse_detected}
  def refresh(config, raw_refresh_token, opts \\ []) do
    Signer.ensure_joken!()

    Telemetry.span([:sigra, :jwt, :refresh], %{}, fn ->
      case RefreshToken.rotate(config, raw_refresh_token, opts) do
        {:ok, new_raw, new_record, scopes} ->
          signer = Signer.create_signer(config)
          jwt_config = config.jwt
          access_ttl = Keyword.get(jwt_config, :access_ttl, 900)
          now = DateTime.utc_now() |> DateTime.to_unix()

          # We need the user for claims; fetch from DB
          user = config.repo.get!(config.user_schema, new_record.user_id)
          claims = build_claims(config, user, scopes, now, access_ttl)

          {:ok, jwt, _full_claims} = Joken.generate_and_sign(%{}, claims, signer)

          {:ok,
           %{
             access_token: jwt,
             refresh_token: new_raw,
             expires_in: access_ttl
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @doc """
  Revokes a specific refresh token.

  ## Options

  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @spec revoke_refresh(Sigra.Config.t(), String.t(), keyword()) ::
          :ok | {:error, :invalid_token}
  def revoke_refresh(config, raw_refresh_token, opts \\ []) do
    RefreshToken.revoke(config, raw_refresh_token, opts)
  end

  @doc """
  Revokes all refresh tokens for a user.

  Called during password change to invalidate all existing refresh tokens.

  ## Options

  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @spec revoke_all_refresh(Sigra.Config.t(), term(), keyword()) ::
          {:ok, non_neg_integer()}
  def revoke_all_refresh(config, user_id, opts \\ []) do
    RefreshToken.revoke_all_for_user(config, user_id, opts)
  end

  # -- Private --

  defp build_claims(config, user, scopes, now, access_ttl) do
    jwt_config = config.jwt

    base_claims = %{
      "sub" => to_string(user.id),
      "iat" => now,
      "exp" => now + access_ttl,
      "jti" => Ecto.UUID.generate(),
      "iss" => Keyword.get(jwt_config, :issuer) || to_string(config.otp_app),
      "scopes" => scopes,
      "epoch" => Map.get(user, :token_epoch, 0)
    }

    case Keyword.get(jwt_config, :claims_builder) do
      nil ->
        base_claims

      builder when is_atom(builder) ->
        extra = builder.extra_claims(user)
        Map.merge(base_claims, extra)
    end
  end

  defp claims_expired?(claims) do
    case claims["exp"] do
      nil -> false
      exp -> DateTime.utc_now() |> DateTime.to_unix() > exp
    end
  end

  defp verify_epoch(config, claims) do
    user_id = claims["sub"]

    case config.repo.get(config.user_schema, user_id) do
      nil ->
        {:error, :invalid_token}

      user ->
        user_epoch = Map.get(user, :token_epoch, 0)
        claim_epoch = claims["epoch"] || 0

        if user_epoch == claim_epoch do
          {:ok, claims}
        else
          {:error, :epoch_mismatch}
        end
    end
  end
end
