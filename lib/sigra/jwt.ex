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

  When **`:audit_schema`** is set under **`:audit`**, **`refresh/3`** commits
  **`user_tokens`** rotation (or reuse-driven family revocation) and the
  matching **`api.jwt_refresh`** / **`api.jwt_refresh_reuse`** audit row in
  **one** transaction. Hosts should rely on that path for durable audit and
  **avoid** calling **`Sigra.APIToken.audit_jwt_refresh/2`** afterward, which
  would risk **double-audit** rows.

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

  alias Ecto.Multi
  alias Sigra.{APIToken, Audit}
  alias Sigra.JWT.{RefreshToken, Signer, Validator}
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
      signer = configured_signer(config)
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

  Checks the configured signer, protected type, registered claims, audience,
  optional not-before time, and (if enabled) the epoch claim against the user's
  current `token_epoch` value.

  Returns `{:ok, claims}` on success.

  ## Error Returns

  - `{:error, :invalid_token}` - Signature invalid or token malformed
  - `{:error, :epoch_mismatch}` - User's token_epoch doesn't match claim
  """
  @spec verify_access(Sigra.Config.t(), String.t()) ::
          {:ok, map()} | {:error, :invalid_token | :epoch_mismatch}
  def verify_access(config, jwt_string) do
    Signer.ensure_joken!()

    Telemetry.span([:sigra, :jwt, :verify], %{}, fn ->
      signer = Signer.create_signer(config)

      case Validator.verify_and_validate(jwt_string, signer, config) do
        {:ok, claims} ->
          if Keyword.get(config.jwt, :verify_epoch, true) do
            verify_epoch(config, claims)
          else
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
    (only after reuse handling **commits** successfully when auditing is on)
  - `{:error, :jwt_refresh_aborted}` - When **`:audit_schema`** is set, refresh
    token rotation (or reuse revocation) and audit could not commit together
    (audit insert failure, constraint violation, etc.). This is an intentional
    exception to **D-AUD-06** “audit-only may return `:ok` on insert failure”:
    co-fated refresh rolls back persistence and surfaces this atom instead of
    returning new tokens without a matching audit row.
  """
  @spec refresh(Sigra.Config.t(), String.t(), keyword()) ::
          {:ok, map()}
          | {:error,
             :invalid_token
             | :token_expired
             | :reuse_detected
             | :jwt_refresh_aborted}
  def refresh(config, raw_refresh_token, opts \\ []) do
    Signer.ensure_joken!()

    Telemetry.span([:sigra, :jwt, :refresh], %{}, fn ->
      refresh_with_locked_lifecycle(config, raw_refresh_token, opts)
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

  defp jwt_audit_schema_set?(config) do
    Keyword.get(Map.get(config, :audit, []), :audit_schema) != nil
  end

  defp refresh_with_locked_lifecycle(config, raw_refresh_token, opts) do
    multi =
      Multi.new()
      |> RefreshToken.build_locked_classify_multi(config, raw_refresh_token, opts)
      |> Multi.merge(fn %{jwt_refresh_classification: {action, token_record, metadata}} ->
        Process.put({__MODULE__, :refresh_lifecycle_action}, action)

        action
        |> build_refresh_mutation_multi(config, token_record, metadata, opts)
        |> append_refresh_audit(config, token_record.user_id, action)
      end)

    try do
      case config.repo.transaction(multi) do
        {:ok, %{jwt_refresh_classification: {:rotate, _token, _metadata}} = changes} ->
          Audit.emit_telemetry_from_changes(changes, [:audit_api_token_jwt_refresh])
          {new_raw, new_record, scopes} = changes.jwt_refresh_new_token
          finalize_refresh_response(config, new_record, scopes, new_raw)

        {:ok, %{jwt_refresh_classification: {:reuse, token_record, metadata}} = changes} ->
          Audit.emit_telemetry_from_changes(changes, [:audit_api_token_jwt_refresh_reuse])
          emit_reuse_detected(token_record.user_id, metadata["family_id"])
          {:error, :reuse_detected}

        {:error, :jwt_refresh_classification, reason, _changes}
        when reason in [:invalid_token, :token_expired] ->
          {:error, reason}

        {:error, step, _reason, changes} ->
          emit_refresh_abort(changes, nil, step)
          {:error, :jwt_refresh_aborted}
      end
    rescue
      e ->
        emit_refresh_abort(
          %{},
          e,
          Process.get({__MODULE__, :refresh_lifecycle_action})
        )

        {:error, :jwt_refresh_aborted}
    after
      Process.delete({__MODULE__, :refresh_lifecycle_action})
    end
  end

  defp build_refresh_mutation_multi(:rotate, config, token_record, metadata, opts) do
    RefreshToken.build_rotate_persist_multi(Multi.new(), token_record, metadata, config, opts)
  end

  defp build_refresh_mutation_multi(:reuse, config, _token_record, metadata, opts) do
    RefreshToken.build_revoke_family_multi(Multi.new(), config, metadata["family_id"], opts)
  end

  defp append_refresh_audit(multi, config, user_id, action) do
    if jwt_audit_schema_set?(config) do
      {audit_action, audit_kind} =
        case action do
          :rotate -> {"api.jwt_refresh", :refresh}
          :reuse -> {"api.jwt_refresh_reuse", :reuse}
        end

      APIToken.append_api_token_jwt_audit_to_multi(
        multi,
        audit_action,
        APIToken.jwt_refresh_audit_multi_opts(config, user_id, audit_kind)
      )
    else
      multi
    end
  end

  defp emit_reuse_detected(user_id, family_id) do
    Telemetry.event(
      [:sigra, :jwt, :refresh_reuse_detected],
      %{count: 1},
      %{user_id: user_id, family_id: family_id}
    )
  end

  defp emit_refresh_abort(changes, exception, failed_step) do
    action =
      case {failed_step, changes[:jwt_refresh_classification]} do
        {:audit_api_token_jwt_refresh_reuse, _} -> "api.jwt_refresh_reuse"
        {:jwt_reuse_revoke_family, _} -> "api.jwt_refresh_reuse"
        {:reuse, _} -> "api.jwt_refresh_reuse"
        {_, {:reuse, _, _}} -> "api.jwt_refresh_reuse"
        _ -> "api.jwt_refresh"
      end

    reason =
      if match?(%Ecto.ConstraintError{}, exception),
        do: :constraint_violation,
        else: :database_error

    :telemetry.execute(
      [:sigra, :audit, :log_safe_error],
      %{count: 1},
      %{action: action, reason: reason}
    )
  end

  defp finalize_refresh_response(config, new_record, scopes, new_raw) do
    signer = configured_signer(config)
    jwt_config = config.jwt
    access_ttl = Keyword.get(jwt_config, :access_ttl, 900)
    now = DateTime.utc_now() |> DateTime.to_unix()
    user = config.repo.get!(config.user_schema, new_record.user_id)
    claims = build_claims(config, user, scopes, now, access_ttl)
    {:ok, jwt, _full_claims} = Joken.generate_and_sign(%{}, claims, signer)

    {:ok,
     %{
       access_token: jwt,
       refresh_token: new_raw,
       expires_in: access_ttl
     }}
  end

  defp build_claims(config, user, scopes, now, access_ttl) do
    jwt_config = config.jwt

    base_claims = %{
      "sub" => to_string(user.id),
      "iat" => now,
      "exp" => now + access_ttl,
      "jti" => Ecto.UUID.generate(),
      "iss" => Keyword.get(jwt_config, :issuer) || to_string(config.otp_app),
      "aud" => Keyword.fetch!(jwt_config, :audience),
      "scopes" => scopes,
      "epoch" => Map.get(user, :token_epoch, 0)
    }

    case Keyword.get(jwt_config, :claims_builder) do
      nil ->
        base_claims

      builder when is_atom(builder) ->
        extra = builder.extra_claims(user)
        Map.merge(extra, base_claims)
    end
  end

  defp configured_signer(config) do
    signer = Signer.create_signer(config)
    typ = Keyword.fetch!(config.jwt, :typ)
    %{signer | jws: JOSE.JWS.from_map(%{"alg" => signer.alg, "typ" => typ})}
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
