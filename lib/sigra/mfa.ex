defmodule Sigra.MFA do
  @moduledoc """
  Core MFA orchestrator module.

  All security-critical MFA operations live here. The generated
  `MyApp.Auth` context delegates to these functions for TOTP enrollment,
  verification, backup code management, and MFA lifecycle.

  ## Usage

      # Enrollment
      {:ok, enrollment} = Sigra.MFA.enroll(config, account: "user@example.com")

      # Verification
      {:ok, :verified} = Sigra.MFA.verify(config, user, "123456")

      # Status check
      Sigra.MFA.enabled?(config, user)

  ## Security Properties

  - TOTP secrets generated via NimbleTOTP (RFC 6238 compliant)
  - Drift window: configurable +/- steps (default +/-1 = 30s each side)
  - Replay prevention via `last_verified_step` tracking (D-41)
  - Backup codes: SHA-256 hashed, atomic consumption (D-13, D-16)
  - Lockout after configurable failed attempts (D-19)
  - TOTP secrets encrypted at rest via cloak_ecto (D-09)
  """

  alias Sigra.MFA.{BackupCodes, Credential, Lockout, Trust}

  @doc """
  Generates TOTP enrollment data.

  Creates a new TOTP secret and returns the base32-encoded secret,
  otpauth URI, optional SVG QR code, and raw binary secret.

  The raw secret should be held in the encrypted session until the user
  confirms enrollment with a valid code (D-03).

  ## Options

  - `:account` - The account name for the otpauth URI (e.g., user email)

  ## Returns

      {:ok, %{
        secret: "BASE32ENCODED...",
        otpauth_uri: "otpauth://totp/...",
        svg: "<svg>...</svg>" | nil,
        raw_secret: <<binary>>
      }}

  """
  @doc since: "0.6.0"
  @spec enroll(Sigra.Config.t(), keyword()) :: {:ok, map()}
  def enroll(%Sigra.Config{} = config, opts \\ []) do
    Sigra.Telemetry.span([:sigra, :mfa, :enroll], %{}, fn ->
      raw_secret = NimbleTOTP.secret()
      base32_secret = Base.encode32(raw_secret)
      account = Keyword.get(opts, :account, "user")
      issuer = resolve_issuer(config)

      otpauth_uri = NimbleTOTP.otpauth_uri("#{issuer}:#{account}", raw_secret, issuer: issuer)

      svg = generate_qr_svg(otpauth_uri)

      {:ok,
       %{
         secret: base32_secret,
         otpauth_uri: otpauth_uri,
         svg: svg,
         raw_secret: raw_secret
       }}
    end)
  end

  @doc """
  Confirms TOTP enrollment by verifying a code against an unconfirmed secret.

  If valid, creates the MFA credential in the database with the encrypted secret,
  generates backup codes, and returns both.

  ## Parameters

  - `config` - Sigra config
  - `user` - The user struct (must have `:id`)
  - `raw_secret` - The raw TOTP secret binary (from enrollment, held in session)
  - `code` - The 6-digit TOTP code to verify
  - `opts` - Options including `:mfa_credential_schema` and `:backup_code_schema`
  """
  @doc since: "0.6.0"
  @spec confirm_enrollment(Sigra.Config.t(), struct(), binary(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :invalid_code}
  def confirm_enrollment(%Sigra.Config{} = config, user, raw_secret, code, opts) do
    drift_steps = Keyword.get(config.mfa, :totp_drift_steps, 1)

    case verify_totp(raw_secret, code, 0, drift_steps) do
      {:ok, step} ->
        repo = config.repo
        mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)
        backup_code_schema = Keyword.fetch!(opts, :backup_code_schema)
        backup_count = Keyword.get(config.mfa, :backup_code_count, 8)

        now = DateTime.utc_now()

        credential_params = %{
          user_id: user.id,
          type: "totp",
          encrypted_secret: raw_secret,
          last_verified_step: step,
          failed_attempts: 0,
          locked_until: nil,
          enabled_at: now
        }

        # Insert MFA credential and backup codes atomically so partial
        # state (credential without backup codes) cannot occur.
        credential_changeset =
          mfa_credential_schema.__struct__()
          |> Ecto.Changeset.cast(credential_params, [
            :user_id,
            :type,
            :encrypted_secret,
            :last_verified_step,
            :failed_attempts,
            :locked_until,
            :enabled_at
          ])

        codes = BackupCodes.generate(backup_count)

        entries =
          Enum.map(codes, fn {_formatted, hashed} ->
            %{
              user_id: user.id,
              hashed_code: hashed,
              used_at: nil,
              inserted_at: now,
              updated_at: now
            }
          end)

        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:credential, credential_changeset)
          |> Ecto.Multi.insert_all(:backup_codes, backup_code_schema, entries)

        case repo.transaction(multi) do
          {:ok, %{credential: db_credential}} ->
            credential = Credential.from_schema(db_credential)
            formatted_codes = Enum.map(codes, &elem(&1, 0))
            {:ok, %{credential: credential, backup_codes: formatted_codes}}

          {:error, _step, changeset, _changes} ->
            {:error, changeset}
        end

      {:error, _reason} ->
        {:error, :invalid_code}
    end
  end

  @doc """
  Verifies a TOTP code for an authenticated user.

  Fetches the MFA credential, checks lockout, verifies the code with
  drift and replay prevention. On success, resets attempt counter and
  updates `last_verified_step`.

  ## Options

  - `:mfa_credential_schema` - The generated MFA credential Ecto schema module

  ## Returns

  - `{:ok, :verified}` on success
  - `{:error, :invalid_code, remaining_attempts}` on wrong code
  - `{:error, :lockout, remaining_seconds}` when locked out
  - `{:error, :not_enrolled}` when user has no MFA credential
  """
  @doc since: "0.6.0"
  @spec verify(Sigra.Config.t(), struct(), String.t(), keyword()) ::
          {:ok, :verified}
          | {:error, :invalid_code, non_neg_integer()}
          | {:error, :lockout, non_neg_integer()}
          | {:error, :not_enrolled}
  def verify(%Sigra.Config{} = config, user, code, opts \\ []) do
    Sigra.Telemetry.span([:sigra, :mfa, :verify], %{user_id: user.id, method: :totp}, fn ->
      repo = config.repo
      mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)

      case repo.get_by(mfa_credential_schema, user_id: user.id) do
        nil ->
          {:error, :not_enrolled}

        db_credential ->
          credential = Credential.from_schema(db_credential)

          case Lockout.check(credential, config) do
            {:error, :lockout, remaining} ->
              {:error, :lockout, remaining}

            :ok ->
              drift_steps = Keyword.get(config.mfa, :totp_drift_steps, 1)
              last_step = credential.last_verified_step || 0

              case verify_totp(credential.encrypted_secret, code, last_step, drift_steps) do
                {:ok, step} ->
                  # Reset attempts and update last_verified_step
                  Lockout.reset(repo, mfa_credential_schema, credential.id)

                  import Ecto.Query

                  from(c in mfa_credential_schema,
                    where: c.id == ^credential.id,
                    update: [
                      set: [
                        last_verified_step: ^step,
                        last_used_at: ^DateTime.utc_now()
                      ]
                    ]
                  )
                  |> repo.update_all([])

                  {:ok, :verified}

                {:error, _reason} ->
                  # Increment failed attempts
                  {:ok, %{failed_attempts: count, locked: locked}} =
                    Lockout.increment(repo, mfa_credential_schema, credential.id, config)

                  threshold = Keyword.get(config.mfa, :lockout_threshold, 5)

                  if locked do
                    duration = Keyword.get(config.mfa, :lockout_duration, 900)
                    Sigra.Telemetry.event([:sigra, :mfa, :lockout], %{}, %{user_id: user.id})
                    {:error, :lockout, duration}
                  else
                    {:error, :invalid_code, max(threshold - count, 0)}
                  end
              end
          end
      end
    end)
  end

  @doc """
  Verifies a backup code for an authenticated user.

  Fetches MFA credential, checks lockout (shared counter per D-19),
  calls `BackupCodes.consume/4`. On success, resets attempt counter.

  ## Options

  - `:mfa_credential_schema` - The generated MFA credential Ecto schema module
  - `:backup_code_schema` - The generated backup code Ecto schema module
  """
  @doc since: "0.6.0"
  @spec verify_backup(Sigra.Config.t(), struct(), String.t(), keyword()) ::
          {:ok, :consumed, non_neg_integer()}
          | {:error, :invalid_backup_code, non_neg_integer()}
          | {:error, :lockout, non_neg_integer()}
          | {:error, :not_enrolled}
  def verify_backup(%Sigra.Config{} = config, user, code, opts \\ []) do
    Sigra.Telemetry.span([:sigra, :mfa, :verify], %{user_id: user.id, method: :backup_code}, fn ->
      repo = config.repo
      mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)
      backup_code_schema = Keyword.fetch!(opts, :backup_code_schema)

      case repo.get_by(mfa_credential_schema, user_id: user.id) do
        nil ->
          {:error, :not_enrolled}

        db_credential ->
          credential = Credential.from_schema(db_credential)

          case Lockout.check(credential, config) do
            {:error, :lockout, remaining} ->
              {:error, :lockout, remaining}

            :ok ->
              case BackupCodes.consume(repo, backup_code_schema, user.id, code) do
                {:ok, :consumed} ->
                  Lockout.reset(repo, mfa_credential_schema, credential.id)
                  remaining = BackupCodes.remaining_count(repo, backup_code_schema, user.id)
                  {:ok, :consumed, remaining}

                {:error, :invalid_backup_code} ->
                  {:ok, %{failed_attempts: count, locked: locked}} =
                    Lockout.increment(repo, mfa_credential_schema, credential.id, config)

                  threshold = Keyword.get(config.mfa, :lockout_threshold, 5)

                  if locked do
                    duration = Keyword.get(config.mfa, :lockout_duration, 900)
                    Sigra.Telemetry.event([:sigra, :mfa, :lockout], %{}, %{user_id: user.id})
                    {:error, :lockout, duration}
                  else
                    {:error, :invalid_backup_code, max(threshold - count, 0)}
                  end
              end
          end
      end
    end)
  end

  @doc """
  Disables MFA for a user after verifying a TOTP or backup code.

  Requires current code verification before deletion (D-59).
  Deletes MFA credential, all backup codes, and increments trust_epoch (D-60).

  ## Options

  - `:mfa_credential_schema` - The generated MFA credential Ecto schema module
  - `:backup_code_schema` - The generated backup code Ecto schema module
  """
  @doc since: "0.6.0"
  @spec disable(Sigra.Config.t(), struct(), String.t(), keyword()) ::
          {:ok, :disabled} | {:error, atom()}
  def disable(%Sigra.Config{} = config, user, code, opts \\ []) do
    Sigra.Telemetry.span([:sigra, :mfa, :disable], %{user_id: user.id, admin: false}, fn ->
      repo = config.repo
      mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)
      backup_code_schema = Keyword.fetch!(opts, :backup_code_schema)

      # Try TOTP first, then backup code
      verified =
        case verify(config, user, code, opts) do
          {:ok, :verified} -> :ok
          _ -> verify_backup_for_disable(config, user, code, opts)
        end

      case verified do
        :ok ->
          cleanup_mfa(repo, config.user_schema, mfa_credential_schema, backup_code_schema, user.id)
          {:ok, :disabled}

        error ->
          error
      end
    end)
  end

  @doc """
  Force-disables MFA for a user without code verification (admin action).

  Same cleanup as `disable/4` but skips code verification (D-65).

  ## Options

  - `:mfa_credential_schema` - The generated MFA credential Ecto schema module
  - `:backup_code_schema` - The generated backup code Ecto schema module
  """
  @doc since: "0.6.0"
  @spec disable!(Sigra.Config.t(), struct(), keyword()) :: {:ok, :disabled}
  def disable!(%Sigra.Config{} = config, user, opts \\ []) do
    Sigra.Telemetry.span([:sigra, :mfa, :disable], %{user_id: user.id, admin: true}, fn ->
      repo = config.repo
      mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)
      backup_code_schema = Keyword.fetch!(opts, :backup_code_schema)

      cleanup_mfa(repo, config.user_schema, mfa_credential_schema, backup_code_schema, user.id)
      {:ok, :disabled}
    end)
  end

  @doc """
  Checks if a user has MFA enabled.

  Returns `true` if the user has an MFA credential with `enabled_at != nil`.

  ## Options

  - `:mfa_credential_schema` - The generated MFA credential Ecto schema module
  """
  @doc since: "0.6.0"
  @spec enabled?(Sigra.Config.t(), struct()) :: boolean()
  def enabled?(%Sigra.Config{} = config, user) do
    import Ecto.Query

    mfa_credential_schema =
      Keyword.get(config.mfa, :mfa_credential_schema)

    if mfa_credential_schema do
      query =
        from(c in mfa_credential_schema,
          where: c.user_id == ^user.id and not is_nil(c.enabled_at),
          select: count(c.id)
        )

      config.repo.one(query) > 0
    else
      false
    end
  end

  @doc """
  Returns MFA status for a user.

  ## Options

  - `:mfa_credential_schema` - The generated MFA credential Ecto schema module (via config or opts)
  - `:backup_code_schema` - The generated backup code Ecto schema module (via config or opts)

  ## Returns

      %{enabled: boolean, type: "totp" | nil, backup_codes_remaining: integer}

  """
  @doc since: "0.6.0"
  @spec status(Sigra.Config.t(), struct()) :: map()
  def status(%Sigra.Config{} = config, user) do
    mfa_credential_schema = Keyword.get(config.mfa, :mfa_credential_schema)
    backup_code_schema = Keyword.get(config.mfa, :backup_code_schema)

    if mfa_credential_schema do
      case config.repo.get_by(mfa_credential_schema, user_id: user.id) do
        nil ->
          %{enabled: false, type: nil, backup_codes_remaining: 0}

        _credential ->
          remaining =
            if backup_code_schema do
              BackupCodes.remaining_count(config.repo, backup_code_schema, user.id)
            else
              0
            end

          %{enabled: true, type: "totp", backup_codes_remaining: remaining}
      end
    else
      %{enabled: false, type: nil, backup_codes_remaining: 0}
    end
  end

  # -- Internal helpers --

  @doc """
  Verifies a TOTP code against a secret with drift and replay prevention.

  This is exposed as a public function for testing purposes but is intended
  as an internal helper. Checks the code against the current time step and
  +/- drift steps. Rejects codes from steps at or below `last_verified_step`
  to prevent replay attacks (D-41).

  ## Returns

  - `{:ok, step}` if valid (step is the TOTP time step that matched)
  - `{:error, :replay}` if code matches but step <= last_verified_step
  - `{:error, :invalid_code}` if code doesn't match any step
  """
  @doc since: "0.6.0"
  @spec verify_totp(binary(), String.t(), integer(), non_neg_integer()) ::
          {:ok, integer()} | {:error, :replay | :invalid_code}
  def verify_totp(secret, code, last_verified_step, drift_steps) do
    now = System.system_time(:second)
    period = 30

    steps =
      for offset <- -drift_steps..drift_steps do
        time = now + offset * period
        step = div(time, period)
        {step, NimbleTOTP.valid?(secret, code, time: time)}
      end

    case Enum.find(steps, fn {_step, valid} -> valid end) do
      {step, true} when step > last_verified_step ->
        {:ok, step}

      {_step, true} ->
        {:error, :replay}

      nil ->
        {:error, :invalid_code}
    end
  end

  defp resolve_issuer(%Sigra.Config{} = config) do
    case Keyword.get(config.mfa, :totp_issuer) do
      nil -> humanize_otp_app(config.otp_app)
      issuer -> issuer
    end
  end

  defp humanize_otp_app(nil), do: "Sigra"

  defp humanize_otp_app(app) when is_atom(app) do
    app
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp generate_qr_svg(otpauth_uri) do
    if Code.ensure_loaded?(EQRCode) do
      otpauth_uri
      |> EQRCode.encode()
      |> EQRCode.svg(width: 200)
    else
      nil
    end
  end

  defp verify_backup_for_disable(config, user, code, opts) do
    case verify_backup(config, user, code, opts) do
      {:ok, :consumed, _remaining} -> :ok
      error -> error
    end
  end

  defp cleanup_mfa(repo, user_schema, mfa_credential_schema, backup_code_schema, user_id) do
    import Ecto.Query

    # Delete backup codes, credential, and revoke trust cookies atomically
    # so partial cleanup cannot leave orphaned records.
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.delete_all(
        :backup_codes,
        from(bc in backup_code_schema, where: bc.user_id == ^user_id)
      )
      |> Ecto.Multi.delete_all(
        :credential,
        from(c in mfa_credential_schema, where: c.user_id == ^user_id)
      )
      |> Ecto.Multi.run(:revoke_trust, fn _repo, _changes ->
        Trust.revoke_all(repo, user_schema, user_id)
        {:ok, :revoked}
      end)

    {:ok, _} = repo.transaction(multi)
    :ok
  end
end
