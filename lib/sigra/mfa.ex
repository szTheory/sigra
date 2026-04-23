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

  alias Ecto.Multi
  alias Sigra.MFA.{BackupCodes, Credential, Lockout, Trust}

  # --- Audit integration helpers (Plan 09-03) ---
  #
  # D-26 dispatch table (Phase 44 AUD-06 — Multi + `log_multi_safe` when `:audit_schema`):
  #   enroll success          -> `Multi` + `Sigra.Audit.log_multi_safe("mfa.enroll.success", …)` (+ telemetry on `{:ok, changes}`)
  #   enroll failure          -> `insert_failed`: follow-up `repo.transaction/1` on `Multi` + `log_multi_safe("mfa.enroll.failure", …)` after enrollment `Multi` rolls back; `invalid_code` still `log_safe/3` (AUD-04-022 / EX-44-02 default)
  #   verify success (totp)   -> `Multi` + `log_multi_safe("mfa.verify.success", …)`
  #   verify success (backup) -> dual `log_multi_safe` with `:audit_mfa_verify` / `:audit_mfa_backup` + paired telemetry
  #   verify failure          -> `Multi` (`Lockout.increment` + `log_multi_safe` + optional lockout audit)
  #   verify_backup failure   -> same `Multi` + `log_multi_safe` pattern as verify failure (invalid backup / consume miss)
  #   disable                 -> `cleanup_mfa/6` Multi + `log_multi_safe("mfa.disable", …)`
  #   lockout                 -> (bundled on verify / regen failure Multis where applicable)

  defp mfa_audit_opts(%Sigra.Config{} = config) do
    audit_config = Map.get(config, :audit, [])

    [
      repo: config.repo,
      audit_schema: Keyword.get(audit_config, :audit_schema)
    ]
  end

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

        # Backup codes are effectively write-once — only `used_at` ever
        # changes when a code is consumed. The shipped schemas use
        # `timestamps(updated_at: false)`, so we only populate inserted_at.
        # Any consumer schema that DOES have updated_at will get it
        # auto-populated via its own changeset path, not this bulk insert.
        entries =
          Enum.map(codes, fn {_formatted, hashed} ->
            %{
              user_id: user.id,
              hashed_code: hashed,
              used_at: nil,
              inserted_at: now
            }
          end)

        multi =
          Multi.new()
          |> Multi.insert(:credential, credential_changeset)
          |> Multi.insert_all(:backup_codes, backup_code_schema, entries)
          |> Sigra.Audit.log_multi_safe(
            "mfa.enroll.success",
            Keyword.merge(mfa_audit_opts(config),
              actor_id: user.id,
              target_id: user.id,
              metadata: %{method: "totp"}
            )
          )

        enrollment_txn =
          try do
            {:completed, repo.transaction(multi)}
          rescue
            e ->
              if enroll_txn_postgrex_insert_failed?(e) do
                {:persist_error, insert_failed_return_changeset(backup_code_schema)}
              else
                reraise(e, __STACKTRACE__)
              end
          end

        case enrollment_txn do
          {:completed, {:ok, %{credential: db_credential} = changes}} ->
            credential = Credential.from_schema(db_credential)
            formatted_codes = Enum.map(codes, &elem(&1, 0))
            Sigra.Audit.emit_telemetry_from_changes(changes)

            {:ok, %{credential: credential, backup_codes: formatted_codes}}

          {:completed, {:error, step, changeset, _changes}} ->
            case step do
              s when s in [:credential, :backup_codes] ->
                emit_enroll_insert_failed_audit(repo, config, user)
                {:error, changeset}

              _ ->
                raise Ecto.ConstraintError,
                  type: :check,
                  constraint: "mfa_enroll_audit",
                  message:
                    "check constraint violation on MFA enrollment audit step #{inspect(step)}",
                  source: nil,
                  changeset: changeset,
                  repo: repo
            end

          {:persist_error, changeset} ->
            emit_enroll_insert_failed_audit(repo, config, user)

            {:error, changeset}
        end

      {:error, _reason} ->
        Sigra.Audit.log_safe(
          "mfa.enroll.failure",
          Sigra.Scope.from_config(config, user),
          Keyword.merge(mfa_audit_opts(config),
            actor_id: user.id,
            outcome: "failure",
            metadata: %{method: "totp", reason: "invalid_code"}
          )
        )

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
                  import Ecto.Query

                  now = DateTime.utc_now()

                  multi =
                    Multi.new()
                    |> Multi.update_all(
                      :totp_success,
                      from(c in mfa_credential_schema, where: c.id == ^credential.id),
                      set: [
                        failed_attempts: 0,
                        locked_until: nil,
                        last_verified_step: step,
                        last_used_at: now
                      ]
                    )
                    |> Sigra.Audit.log_multi_safe(
                      "mfa.verify.success",
                      Keyword.merge(mfa_audit_opts(config),
                        actor_id: user.id,
                        target_id: user.id,
                        metadata: %{method: "totp"}
                      )
                    )

                  case repo.transaction(multi) do
                    {:ok, changes} ->
                      Sigra.Audit.emit_telemetry_from_changes(changes)
                      {:ok, :verified}

                    {:error, failed, reason, _changes} ->
                      raise "Sigra.MFA.verify/4 unexpected transaction failure " <>
                              "at #{inspect(failed)}: #{inspect(reason)}"
                  end

                {:error, _reason} ->
                  threshold = Keyword.get(config.mfa, :lockout_threshold, 5)

                  failure_multi =
                    Multi.new()
                    |> Multi.run(:lockout_inc, fn r, _ ->
                      Lockout.increment(r, mfa_credential_schema, credential.id, config)
                    end)
                    |> Sigra.Audit.log_multi_safe(
                      "mfa.verify.failure",
                      Keyword.merge(mfa_audit_opts(config),
                        actor_id: user.id,
                        target_id: user.id,
                        outcome: "failure",
                        audit_multi_step: :audit_mfa_verify_failure,
                        metadata_resolver: fn ch ->
                          %{method: "totp", attempts: ch.lockout_inc.failed_attempts}
                        end
                      )
                    )
                    |> Multi.merge(fn %{lockout_inc: inc} ->
                      if inc.locked do
                        duration = Keyword.get(config.mfa, :lockout_duration, 900)

                        Sigra.Audit.log_multi_safe(
                          Multi.new(),
                          "mfa.lockout",
                          Keyword.merge(mfa_audit_opts(config),
                            actor_id: user.id,
                            target_id: user.id,
                            outcome: "failure",
                            audit_multi_step: :audit_mfa_lockout,
                            metadata: %{method: "totp", duration: duration}
                          )
                        )
                      else
                        Multi.new()
                      end
                    end)

                  case repo.transaction(failure_multi) do
                    {:ok, changes} ->
                      Sigra.Audit.emit_telemetry_from_changes(changes, [
                        :audit_mfa_verify_failure,
                        :audit_mfa_lockout
                      ])

                      %{failed_attempts: count, locked: locked} = changes.lockout_inc

                      if locked do
                        duration = Keyword.get(config.mfa, :lockout_duration, 900)
                        Sigra.Telemetry.event([:sigra, :mfa, :lockout], %{}, %{user_id: user.id})
                        {:error, :lockout, duration}
                      else
                        {:error, :invalid_code, max(threshold - count, 0)}
                      end

                    {:error, failed, reason, _changes} ->
                      raise "Sigra.MFA.verify/4 unexpected transaction failure " <>
                              "at #{inspect(failed)}: #{inspect(reason)}"
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
              backup_ok_multi =
                Multi.new()
                |> Multi.run(:consume, fn r, _ ->
                  BackupCodes.consume(r, backup_code_schema, user.id, code)
                end)
                |> Multi.run(:reset_lockout, fn r, %{consume: :consumed} ->
                  Lockout.reset(r, mfa_credential_schema, credential.id)
                  {:ok, :ok}
                end)
                |> Multi.run(:remaining, fn r, %{consume: :consumed} ->
                  {:ok, BackupCodes.remaining_count(r, backup_code_schema, user.id)}
                end)
                |> Sigra.Audit.log_multi_safe(
                  "mfa.verify.success",
                  Keyword.merge(mfa_audit_opts(config),
                    actor_id: user.id,
                    target_id: user.id,
                    audit_multi_step: :audit_mfa_verify,
                    metadata: %{method: "backup_code"}
                  )
                )
                |> Sigra.Audit.log_multi_safe(
                  "mfa.backup_code_used",
                  Keyword.merge(mfa_audit_opts(config),
                    actor_id: user.id,
                    target_id: user.id,
                    audit_multi_step: :audit_mfa_backup,
                    metadata_resolver: fn ch -> %{remaining: ch.remaining} end
                  )
                )

              case repo.transaction(backup_ok_multi) do
                {:ok, changes} ->
                  Sigra.Audit.emit_telemetry_from_changes(changes, [
                    :audit_mfa_verify,
                    :audit_mfa_backup
                  ])

                  {:ok, :consumed, changes.remaining}

                {:error, :consume, :invalid_backup_code, _changes} ->
                  threshold = Keyword.get(config.mfa, :lockout_threshold, 5)

                  failure_multi =
                    Multi.new()
                    |> Multi.run(:lockout_inc, fn r, _ ->
                      Lockout.increment(r, mfa_credential_schema, credential.id, config)
                    end)
                    |> Sigra.Audit.log_multi_safe(
                      "mfa.verify.failure",
                      Keyword.merge(mfa_audit_opts(config),
                        actor_id: user.id,
                        target_id: user.id,
                        outcome: "failure",
                        audit_multi_step: :audit_mfa_backup_verify_failure,
                        metadata_resolver: fn ch ->
                          %{method: "backup_code", attempts: ch.lockout_inc.failed_attempts}
                        end
                      )
                    )
                    |> Multi.merge(fn %{lockout_inc: inc} ->
                      if inc.locked do
                        duration = Keyword.get(config.mfa, :lockout_duration, 900)

                        Sigra.Audit.log_multi_safe(
                          Multi.new(),
                          "mfa.lockout",
                          Keyword.merge(mfa_audit_opts(config),
                            actor_id: user.id,
                            target_id: user.id,
                            outcome: "failure",
                            audit_multi_step: :audit_mfa_backup_lockout,
                            metadata: %{method: "backup_code", duration: duration}
                          )
                        )
                      else
                        Multi.new()
                      end
                    end)

                  case repo.transaction(failure_multi) do
                    {:ok, changes} ->
                      Sigra.Audit.emit_telemetry_from_changes(changes, [
                        :audit_mfa_backup_verify_failure,
                        :audit_mfa_backup_lockout
                      ])

                      %{failed_attempts: count, locked: locked} = changes.lockout_inc

                      if locked do
                        duration = Keyword.get(config.mfa, :lockout_duration, 900)
                        Sigra.Telemetry.event([:sigra, :mfa, :lockout], %{}, %{user_id: user.id})
                        {:error, :lockout, duration}
                      else
                        {:error, :invalid_backup_code, max(threshold - count, 0)}
                      end

                    {:error, failed, reason, _changes} ->
                      raise "Sigra.MFA.verify_backup/4 unexpected transaction failure " <>
                              "at #{inspect(failed)}: #{inspect(reason)}"
                  end

                {:error, failed, reason, _changes} ->
                  raise "Sigra.MFA.verify_backup/4 unexpected transaction failure " <>
                          "at #{inspect(failed)}: #{inspect(reason)}"
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

  When `:audit_schema` is set, a failed cleanup transaction returns
  `{:error, :mfa_audit_failed}` (audit insert changeset) or
  `{:error, :mfa_disable_failed}` (other `Ecto.Multi` steps). Database constraint
  violations on the audit row may still raise `Ecto.ConstraintError` (same as
  other audited MFA transactions) after the repo rolls back.
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
          case cleanup_mfa(
                 repo,
                 config.user_schema,
                 mfa_credential_schema,
                 backup_code_schema,
                 user.id,
                 {:mfa_disable, config, user, false}
               ) do
            :ok ->
              {:ok, :disabled}

            {:error, failed, reason} ->
              {:error, cleanup_disable_transaction_error(failed, reason)}
          end

        error ->
          error
      end
    end)
  end

  @doc """
  Force-disables MFA for a user without code verification (admin action).

  Same cleanup as `disable/4` but skips code verification (D-65).

  Raises `RuntimeError` when the cleanup `Ecto.Multi` returns an error tuple
  (after rollback). Database constraint violations on the audit insert may
  instead raise `Ecto.ConstraintError`, matching other audited MFA paths.

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

      case cleanup_mfa(
             repo,
             config.user_schema,
             mfa_credential_schema,
             backup_code_schema,
             user.id,
             {:mfa_disable, config, user, true}
           ) do
        :ok ->
          {:ok, :disabled}

        {:error, failed, reason} ->
          raise RuntimeError,
                "Sigra.MFA.disable!/4 cleanup transaction failed at #{inspect(failed)}: " <>
                  "#{inspect(reason)}"
      end
    end)
  end

  @doc """
  Regenerates backup codes after verifying a TOTP code (`{:totp, code}`).

  Backup codes **cannot** authorize rotation — only a valid TOTP proof is
  accepted.

  Replacement runs in a single `Repo.transaction/1` (`delete_all` + `insert_all`
  + optional audit). When `:audit_schema` is configured, an
  `mfa.backup_codes_regenerate` row is written via `Sigra.Audit.log_multi_safe/3`
  on the same `Ecto.Multi` as the replace (atomic with persistence).

  On success, lockout counters are cleared and `last_verified_step` /
  `last_used_at` are updated like `verify/4`, but this path intentionally
  **does not** emit `mfa.verify.success` — rotation is covered by
  `mfa.backup_codes_regenerate` when audit is enabled.

  ## Options

  - `:mfa_credential_schema` (required)
  - `:backup_code_schema` (required)

  ## Returns

  Same error shapes as `verify/4` for `:not_enrolled`, `:lockout`, and
  `:invalid_code` (with remaining attempts).
  """
  @doc since: "0.6.0"
  @spec regenerate_backup_codes(Sigra.Config.t(), struct(), {:totp, String.t()}, keyword()) ::
          {:ok, %{backup_codes: [String.t()]}}
          | {:error, :invalid_code, non_neg_integer()}
          | {:error, :lockout, non_neg_integer()}
          | {:error, :not_enrolled}
  def regenerate_backup_codes(%Sigra.Config{} = config, user, {:totp, code}, opts)
      when is_binary(code) do
    Sigra.Telemetry.span([:sigra, :mfa, :backup_codes, :regenerate], %{user_id: user.id}, fn ->
      repo = config.repo
      mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)
      backup_code_schema = Keyword.fetch!(opts, :backup_code_schema)
      backup_count = Keyword.get(config.mfa, :backup_code_count, 8)

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
                  now = DateTime.utc_now()

                  {multi, formatted_codes} =
                    BackupCodes.append_replace_steps(
                      Multi.new(),
                      backup_code_schema,
                      user.id,
                      backup_count,
                      now
                    )

                  import Ecto.Query

                  multi =
                    multi
                    |> Multi.run(:sync_credential, fn repo, _changes ->
                      {_, _} =
                        from(c in mfa_credential_schema, where: c.id == ^credential.id)
                        |> repo.update_all(
                          set: [
                            failed_attempts: 0,
                            locked_until: nil,
                            last_verified_step: step,
                            last_used_at: now
                          ]
                        )

                      {:ok, :updated}
                    end)
                    |> Sigra.Audit.log_multi_safe(
                      "mfa.backup_codes_regenerate",
                      Keyword.merge(
                        mfa_audit_opts(config),
                        actor_id: user.id,
                        target_id: user.id,
                        metadata: %{count: backup_count}
                      )
                    )

                  case repo.transaction(multi) do
                    {:ok, changes} ->
                      Sigra.Audit.emit_telemetry_from_changes(changes)
                      {:ok, %{backup_codes: formatted_codes}}

                    {:error, failed, reason, _changes} ->
                      raise "Sigra.MFA.regenerate_backup_codes/4 unexpected transaction failure " <>
                              "at #{inspect(failed)}: #{inspect(reason)}"
                  end

                {:error, _reason} ->
                  threshold = Keyword.get(config.mfa, :lockout_threshold, 5)

                  regen_fail_multi =
                    Multi.new()
                    |> Multi.run(:lockout_inc, fn r, _ ->
                      Lockout.increment(r, mfa_credential_schema, credential.id, config)
                    end)
                    |> Sigra.Audit.log_multi_safe(
                      "mfa.verify.failure",
                      Keyword.merge(mfa_audit_opts(config),
                        actor_id: user.id,
                        target_id: user.id,
                        outcome: "failure",
                        audit_multi_step: :audit_regen_verify_failure,
                        metadata_resolver: fn ch ->
                          %{method: "totp", attempts: ch.lockout_inc.failed_attempts}
                        end
                      )
                    )
                    |> Multi.merge(fn %{lockout_inc: inc} ->
                      if inc.locked do
                        duration = Keyword.get(config.mfa, :lockout_duration, 900)

                        Sigra.Audit.log_multi_safe(
                          Multi.new(),
                          "mfa.lockout",
                          Keyword.merge(mfa_audit_opts(config),
                            actor_id: user.id,
                            target_id: user.id,
                            outcome: "failure",
                            audit_multi_step: :audit_regen_lockout,
                            metadata: %{method: "totp", duration: duration}
                          )
                        )
                      else
                        Multi.new()
                      end
                    end)

                  case repo.transaction(regen_fail_multi) do
                    {:ok, changes} ->
                      Sigra.Audit.emit_telemetry_from_changes(changes, [
                        :audit_regen_verify_failure,
                        :audit_regen_lockout
                      ])

                      %{failed_attempts: count, locked: locked} = changes.lockout_inc

                      if locked do
                        duration = Keyword.get(config.mfa, :lockout_duration, 900)
                        Sigra.Telemetry.event([:sigra, :mfa, :lockout], %{}, %{user_id: user.id})
                        {:error, :lockout, duration}
                      else
                        {:error, :invalid_code, max(threshold - count, 0)}
                      end

                    {:error, failed, reason, _changes} ->
                      raise "Sigra.MFA.regenerate_backup_codes/4 unexpected transaction failure " <>
                              "at #{inspect(failed)}: #{inspect(reason)}"
                  end
              end
          end
      end
    end)
  end

  @doc """
  Record an `mfa.backup_codes_regenerate` audit row via `log_safe/2`.

  This is **not** the authoritative audit path when audit is enabled for
  library-driven rotation — use `regenerate_backup_codes/4`, which appends
  the same action to the rotation `Ecto.Multi`. This function remains for
  ad-hoc or legacy call sites.
  """
  @spec audit_backup_codes_regenerate(Sigra.Config.t(), struct(), non_neg_integer()) :: :ok
  def audit_backup_codes_regenerate(%Sigra.Config{} = config, user, count) do
    Sigra.Audit.log_safe(
      "mfa.backup_codes_regenerate",
      Sigra.Scope.from_config(config, user),
      Keyword.merge(mfa_audit_opts(config),
        actor_id: user.id,
        metadata: %{count: count}
      )
    )
  end

  @doc """
  Record an mfa.trust_browser audit row. Called by Sigra.MFA.Trust when
  a browser is marked trusted.
  """
  @spec audit_trust_browser(Sigra.Config.t(), struct()) :: :ok
  def audit_trust_browser(%Sigra.Config{} = config, user) do
    Sigra.Audit.log_safe(
      "mfa.trust_browser",
      Sigra.Scope.from_config(config, user),
      Keyword.merge(mfa_audit_opts(config),
        actor_id: user.id,
        metadata: %{}
      )
    )
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
  @spec status(Sigra.Config.t(), struct(), keyword()) :: map()
  def status(%Sigra.Config{} = config, user, opts \\ []) do
    # The `config.mfa` keyword list is validated by NimbleOptions and does
    # NOT accept `:mfa_credential_schema` or `:backup_code_schema` — those
    # are per-call opts, the same pattern used by confirm_enrollment/3,
    # verify/4, and disable/4. Fall back to config.mfa so callers that
    # previously used an un-validated config still work.
    mfa_credential_schema =
      Keyword.get(opts, :mfa_credential_schema) ||
        Keyword.get(config.mfa || [], :mfa_credential_schema)

    backup_code_schema =
      Keyword.get(opts, :backup_code_schema) ||
        Keyword.get(config.mfa || [], :backup_code_schema)

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

  defp cleanup_mfa(
         repo,
         user_schema,
         mfa_credential_schema,
         backup_code_schema,
         user_id,
         audit
       ) do
    import Ecto.Query

    # Delete backup codes, credential, and revoke trust cookies atomically
    # so partial cleanup cannot leave orphaned records.
    multi =
      Multi.new()
      |> Multi.delete_all(
        :backup_codes,
        from(bc in backup_code_schema, where: bc.user_id == ^user_id)
      )
      |> Multi.delete_all(
        :credential,
        from(c in mfa_credential_schema, where: c.user_id == ^user_id)
      )
      |> Multi.run(:revoke_trust, fn r, _changes ->
        Trust.revoke_all(r, user_schema, user_id)
        {:ok, :revoked}
      end)

    multi =
      case audit do
        {:mfa_disable, cfg, usr, admin} ->
          Sigra.Audit.log_multi_safe(
            multi,
            "mfa.disable",
            Keyword.merge(mfa_audit_opts(cfg),
              actor_id: usr.id,
              target_id: usr.id,
              metadata: %{admin: admin}
            )
          )

        _ ->
          multi
      end

    case repo.transaction(multi) do
      {:ok, changes} ->
        case audit do
          {:mfa_disable, _, _, _} ->
            Sigra.Audit.emit_telemetry_from_changes(changes)

          _ ->
            :ok
        end

        :ok

      {:error, failed, reason, _} ->
        {:error, failed, reason}
    end
  end

  defp cleanup_disable_transaction_error(:audit, %Ecto.Changeset{}), do: :mfa_audit_failed
  defp cleanup_disable_transaction_error(_, _), do: :mfa_disable_failed

  # Mirrors `Sigra.Audit` private `emit_log_safe_error/2` — enrollment must not
  # depend on Audit internals, but operators need the same `log_safe_error`
  # signal when the post-rollback failure-audit transaction does not commit.
  defp emit_enroll_failure_audit_error_telemetry(action, %Ecto.Changeset{} = cs) do
    error_fields = cs.errors |> Enum.map(fn {field, _} -> field end) |> Enum.uniq()

    :telemetry.execute(
      [:sigra, :audit, :log_safe_error],
      %{count: 1},
      %{action: action, reason: :invalid_changeset, error_fields: error_fields}
    )
  end

  defp enroll_txn_postgrex_insert_failed?(e) do
    with true <- is_exception(e),
         %{table: table} <- Map.get(e, :postgres) do
      table in ["user_mfa_backup_codes", "user_mfa_credentials"]
    else
      _ -> false
    end
  end

  defp failure_audit_followup_rescue?(e) do
    match?(%Ecto.ConstraintError{}, e) or
      (is_exception(e) and match?(%{table: _}, Map.get(e, :postgres)))
  end

  defp insert_failed_return_changeset(backup_code_schema) do
    backup_code_schema.__struct__()
    |> Ecto.Changeset.change(%{})
    |> Ecto.Changeset.add_error(:base, "insert_failed")
  end

  defp enroll_insert_failed_opts(config, user) do
    scope = Sigra.Scope.from_config(config, user)

    scope_opts =
      case scope do
        %{user: scope_user} = s ->
          org = Map.get(s, :active_organization)
          actor = Map.get(s, :impersonating_from) || scope_user

          [
            organization_id: org && org.id,
            effective_user_id: scope_user && scope_user.id,
            actor_id: actor && actor.id
          ]

        _ ->
          [organization_id: nil, effective_user_id: nil, actor_id: nil]
      end

    caller_opts =
      Keyword.merge(mfa_audit_opts(config),
        actor_id: user.id,
        target_id: user.id,
        outcome: "failure",
        metadata: %{method: "totp", reason: "insert_failed"}
      )

    Keyword.merge(scope_opts, caller_opts)
  end

  defp emit_enroll_insert_failed_audit(repo, config, user) do
    failure_opts = enroll_insert_failed_opts(config, user)

    failure_multi =
      Multi.new()
      |> Sigra.Audit.log_multi_safe(
        "mfa.enroll.failure",
        Keyword.merge(failure_opts, audit_multi_step: :audit_mfa_enroll_insert_failed)
      )

    try do
      case repo.transaction(failure_multi) do
        {:ok, audit_changes} ->
          Sigra.Audit.emit_telemetry_from_changes(audit_changes, [
            :audit_mfa_enroll_insert_failed
          ])

        {:error, _failed_step, failed_value, _audit_changes} ->
          case failed_value do
            %Ecto.Changeset{} = failed_cs ->
              emit_enroll_failure_audit_error_telemetry("mfa.enroll.failure", failed_cs)

            _ ->
              :ok
          end
      end
    rescue
      e ->
        if failure_audit_followup_rescue?(e) do
          :telemetry.execute(
            [:sigra, :audit, :log_safe_error],
            %{count: 1},
            %{action: "mfa.enroll.failure", reason: :constraint_violation}
          )
        else
          reraise(e, __STACKTRACE__)
        end
    end
  end
end
