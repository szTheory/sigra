defmodule Sigra.Account do
  @moduledoc """
  Account lifecycle orchestrator.

  Provides a unified API for email change, password change, and account deletion.
  Each operation delegates to its specialized module:

  - `Sigra.Account.EmailChange` for email change flows
  - `Sigra.Account.PasswordChange` for password management
  - `Sigra.Account.Deletion` for account deletion lifecycle

  All functions follow the library pattern: they receive `repo` as the first
  argument and options keyword list with schema references and config. The
  generated `MyApp.Auth` context delegates to these functions.

  ## Email Change (D-01 to D-10)

      Sigra.Account.request_email_change(repo, user, "new@example.com", opts)
      Sigra.Account.confirm_email_change(repo, token, opts)
      Sigra.Account.cancel_email_change(repo, user, opts)

  ## Password Change (D-34 to D-45)

      Sigra.Account.change_password(repo, user, "current", %{password: "new"}, opts)
      Sigra.Account.set_password(repo, user, %{password: "new"}, opts)
      Sigra.Account.clear_password_change_requirement(repo, user, opts)

  ## Account Deletion (D-11 to D-33)

      Sigra.Account.schedule_deletion(repo, user, opts)
      Sigra.Account.cancel_deletion(repo, user, opts)
      Sigra.Account.execute_deletion(repo, user, opts)
  """

  alias Ecto.Multi
  alias Sigra.Account.{Deletion, EmailChange, PasswordChange}

  # D-26 dispatch table (Phase 44 AUD-07 — `Ecto.Multi` + `Sigra.Audit.log_multi_safe`
  # when `:audit_schema` is set in opts; without it, domain-only — no audit insert):
  #
  #   request_email_change  -> `Multi` + `log_multi_safe("account.email_change_request", …)` + `emit_telemetry_from_changes/1`
  #   confirm_email_change  -> `Multi` + `log_multi_safe("account.email_change_confirm", …)` + telemetry
  #   cancel_email_change   -> `Multi` + `log_multi_safe("account.email_change_cancel", …)` + telemetry
  #   change_password       -> `Multi` + `log_multi_safe("account.password_change", …)` + telemetry
  #   set_password          -> `Multi` + `log_multi_safe("account.password_change", …)` + telemetry
  #   clear_password_change_requirement -> `Multi` + `log_multi_safe("account.password_change", metadata: %{forced: true}, …)` + telemetry
  #   schedule_deletion     -> `Multi` + `log_multi_safe("account.deletion_schedule", …)` + telemetry
  #   cancel_deletion       -> `Multi` + `log_multi_safe("account.deletion_cancel", …)` + telemetry
  #   execute_deletion      -> `Multi.run(Deletion.execute)` then `log_multi_safe("account.deletion_execute", …)` + telemetry
  #
  # `audit_forced_password_change/2` is **deprecated** — legacy `Sigra.Audit.log_safe/3` only.
  # Do not pair it with `clear_password_change_requirement/3` for the same completion.

  defp account_audit_opts(opts) when is_list(opts) do
    [
      repo: Keyword.get(opts, :repo),
      audit_schema: Keyword.get(opts, :audit_schema)
    ]
  end

  defp audit_enabled?(opts), do: Keyword.get(opts, :audit_schema) != nil

  defp audit_repo_opts(repo, opts) do
    account_audit_opts(opts) |> Keyword.put(:repo, repo)
  end

  defp scope_to_audit_kw(nil), do: [organization_id: nil, effective_user_id: nil]

  defp scope_to_audit_kw(%{user: u} = scope) do
    org = Map.get(scope, :active_organization)
    actor = Map.get(scope, :impersonating_from) || u

    [
      organization_id: org && org.id,
      effective_user_id: u && u.id,
      actor_id: actor && actor.id
    ]
  end

  defp scope_to_audit_kw(_), do: scope_to_audit_kw(nil)

  defp email_request_scope_kw(opts, user) do
    scope =
      case Keyword.get(opts, :scope_module) do
        nil -> nil
        mod -> Sigra.Scope.build(mod, user, active_organization: nil)
      end

    scope_to_audit_kw(scope)
  end

  defp password_change_scope_kw(opts, user), do: email_request_scope_kw(opts, user)

  defp finish_audit_multi(repo, multi) do
    case repo.transaction(multi) do
      {:ok, changes} ->
        Sigra.Audit.emit_telemetry_from_changes(changes)
        {:ok, changes}

      {:error, failed, reason, changes} ->
        {:error, failed, reason, changes}
    end
  end

  defp unexpected_account_multi!(failed, reason) do
    raise RuntimeError,
          "unexpected Sigra.Account Ecto.Multi failure #{inspect(failed)} => #{inspect(reason)}"
  end

  # --- Email Change (per D-28 context API) ---

  @doc "Request an email change. Sends verification to new address."
  @doc since: "0.8.0"
  def request_email_change(repo, user, new_email, opts) do
    if audit_enabled?(opts) do
      scope_kw = email_request_scope_kw(opts, user)

      multi =
        Multi.new()
        |> Multi.run(:domain, fn r, _ ->
          case EmailChange.request(r, user, new_email, opts) do
            {:ok, u, tok} -> {:ok, %{user: u, token: tok}}
            err -> err
          end
        end)
        |> Sigra.Audit.log_multi_safe(
          "account.email_change_request",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              actor_id: user.id,
              target_id: user.id,
              metadata: %{}
            )
          )
        )

      case finish_audit_multi(repo, multi) do
        {:ok, %{domain: %{user: u, token: tok}}} ->
          {:ok, u, tok}

        {:error, :domain, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      EmailChange.request(repo, user, new_email, opts)
    end
  end

  @doc "Confirm an email change via token from verification email."
  @doc since: "0.8.0"
  def confirm_email_change(repo, encoded_token, opts) do
    if audit_enabled?(opts) do
      multi =
        Multi.new()
        |> Multi.run(:domain, fn r, _ ->
          case EmailChange.confirm(r, encoded_token, opts) do
            {:ok, user} -> {:ok, user}
            :error -> {:error, :email_change_confirm_failed}
            {:error, %Ecto.Changeset{} = cs} -> {:error, cs}
          end
        end)
        |> Sigra.Audit.log_multi_safe(
          "account.email_change_confirm",
          Keyword.merge(audit_repo_opts(repo, opts),
            actor_resolver: fn ch -> ch.domain.id end,
            target_resolver: fn ch -> ch.domain.id end,
            organization_id_resolver: fn ch ->
              case Sigra.Scope.from_opts(opts, ch.domain) do
                nil -> nil
                s -> s.active_organization && s.active_organization.id
              end
            end,
            effective_user_id_resolver: fn ch ->
              case Sigra.Scope.from_opts(opts, ch.domain) do
                nil -> nil
                s -> s.user && s.user.id
              end
            end,
            metadata: %{}
          )
        )

      case finish_audit_multi(repo, multi) do
        {:ok, %{domain: user}} ->
          {:ok, user}

        {:error, :domain, :email_change_confirm_failed, _} ->
          :error

        {:error, :domain, %Ecto.Changeset{} = cs, _} ->
          {:error, cs}

        {:error, :domain, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      EmailChange.confirm(repo, encoded_token, opts)
    end
  end

  @doc "Cancel a pending email change."
  @doc since: "0.8.0"
  def cancel_email_change(repo, user, opts) do
    if audit_enabled?(opts) do
      scope = Sigra.Scope.from_opts(opts, user)
      scope_kw = scope_to_audit_kw(scope)

      multi =
        Multi.new()
        |> Multi.run(:domain, fn r, _ -> EmailChange.cancel(r, user, opts) end)
        |> Sigra.Audit.log_multi_safe(
          "account.email_change_cancel",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              actor_id: user.id,
              target_id: user.id,
              metadata: %{}
            )
          )
        )

      case finish_audit_multi(repo, multi) do
        {:ok, %{domain: u}} ->
          {:ok, u}

        {:error, :domain, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      EmailChange.cancel(repo, user, opts)
    end
  end

  # --- Password Change (per D-40 context API) ---

  @doc "Change password with current password verification."
  @doc since: "0.8.0"
  def change_password(repo, user, current_password, attrs, opts) do
    if audit_enabled?(opts) do
      scope_kw = password_change_scope_kw(opts, user)

      multi =
        Multi.new()
        |> Multi.run(:domain, fn r, _ ->
          PasswordChange.change(r, user, current_password, attrs, opts)
        end)
        |> Sigra.Audit.log_multi_safe(
          "account.password_change",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              actor_id: user.id,
              target_id: user.id,
              metadata: %{forced: false}
            )
          )
        )

      case finish_audit_multi(repo, multi) do
        {:ok, %{domain: u}} ->
          {:ok, u}

        {:error, :domain, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      PasswordChange.change(repo, user, current_password, attrs, opts)
    end
  end

  @doc "Set password for OAuth-only user (no current password). Requires sudo."
  @doc since: "0.8.0"
  def set_password(repo, user, attrs, opts) do
    if audit_enabled?(opts) do
      scope = Sigra.Scope.from_opts(opts, user)
      scope_kw = scope_to_audit_kw(scope)

      multi =
        Multi.new()
        |> Multi.run(:domain, fn r, _ ->
          PasswordChange.set_for_oauth_user(r, user, attrs, opts)
        end)
        |> Sigra.Audit.log_multi_safe(
          "account.password_change",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              actor_id: user.id,
              target_id: user.id,
              metadata: %{forced: false, source: "oauth_set"}
            )
          )
        )

      case finish_audit_multi(repo, multi) do
        {:ok, %{domain: u}} ->
          {:ok, u}

        {:error, :domain, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      PasswordChange.set_for_oauth_user(repo, user, attrs, opts)
    end
  end

  @doc """
  Clears the admin-enforced password change requirement after the user completes the flow.

  When `:audit_schema` is set in `opts`, the `must_change_password` update and the
  `account.password_change` audit row (`metadata: %{forced: true}`) are committed in one
  transaction. Otherwise delegates to `PasswordChange.clear_force_change/2` with no audit.
  """
  @doc since: "0.2.5"
  @spec clear_password_change_requirement(module(), map(), keyword()) ::
          {:ok, map()} | {:error, Ecto.Changeset.t()}
  def clear_password_change_requirement(repo, user, opts) do
    if audit_enabled?(opts) do
      scope_kw = password_change_scope_kw(opts, user)

      multi =
        Multi.new()
        |> Multi.run(:domain, fn r, _ -> PasswordChange.clear_force_change(r, user) end)
        |> Sigra.Audit.log_multi_safe(
          "account.password_change",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              actor_id: user.id,
              target_id: user.id,
              metadata: %{forced: true}
            )
          )
        )

      case finish_audit_multi(repo, multi) do
        {:ok, %{domain: u}} ->
          {:ok, u}

        {:error, :domain, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      PasswordChange.clear_force_change(repo, user)
    end
  end

  @doc "Check if user must change their password."
  @doc since: "0.8.0"
  defdelegate must_change_password?(user), to: PasswordChange, as: :force_change_required?

  @doc "Admin API: require user to change password on next login."
  @doc since: "0.8.0"
  defdelegate require_password_change(repo, user), to: PasswordChange, as: :require_force_change

  # --- Account Deletion (per D-28 context API) ---

  @doc "Schedule account deletion with grace period."
  @doc since: "0.8.0"
  def schedule_deletion(repo, user, opts) do
    if audit_enabled?(opts) do
      scope = Sigra.Scope.from_opts(opts, user)
      scope_kw = scope_to_audit_kw(scope)

      multi =
        Multi.new()
        |> Multi.run(:domain, fn r, _ ->
          case Deletion.schedule(r, user, opts) do
            {:ok, u, scheduled_at} -> {:ok, %{user: u, scheduled_at: scheduled_at}}
            err -> err
          end
        end)
        |> Sigra.Audit.log_multi_safe(
          "account.deletion_schedule",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              actor_id: user.id,
              target_id: user.id,
              metadata: %{}
            )
          )
        )

      case finish_audit_multi(repo, multi) do
        {:ok, %{domain: %{user: u, scheduled_at: at}}} ->
          {:ok, u, at}

        {:error, :domain, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      Deletion.schedule(repo, user, opts)
    end
  end

  @doc "Cancel scheduled deletion and reactivate account."
  @doc since: "0.8.0"
  def cancel_deletion(repo, user, opts) do
    if audit_enabled?(opts) do
      scope = Sigra.Scope.from_opts(opts, user)
      scope_kw = scope_to_audit_kw(scope)

      multi =
        Multi.new()
        |> Multi.run(:domain, fn r, _ -> Deletion.cancel(r, user, opts) end)
        |> Sigra.Audit.log_multi_safe(
          "account.deletion_cancel",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              actor_id: user.id,
              target_id: user.id,
              metadata: %{}
            )
          )
        )

      case finish_audit_multi(repo, multi) do
        {:ok, %{domain: u}} ->
          {:ok, u}

        {:error, :domain, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      Deletion.cancel(repo, user, opts)
    end
  end

  @doc "Execute deletion (called by Oban worker or manual task)."
  @doc since: "0.8.0"
  def execute_deletion(repo, user, opts) do
    user_id = user.id

    if audit_enabled?(opts) do
      scope = Sigra.Scope.from_opts(opts, user)
      scope_kw = scope_to_audit_kw(scope)

      multi =
        Multi.new()
        |> Multi.run(:deletion, fn r, _ ->
          case Deletion.execute(r, user, opts) do
            {:ok, strategy} -> {:ok, %{strategy: strategy, user_id: user_id}}
            err -> err
          end
        end)
        |> Sigra.Audit.log_multi_safe(
          "account.deletion_execute",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              audit_multi_step: :audit_deletion_execute,
              actor_resolver: fn ch -> ch.deletion.user_id end,
              target_resolver: fn ch -> ch.deletion.user_id end,
              metadata: %{}
            )
          )
        )
        |> Sigra.Audit.log_multi_safe(
          "account.deletion_executed",
          Keyword.merge(
            audit_repo_opts(repo, opts),
            Keyword.merge(scope_kw,
              audit_multi_step: :audit_deletion_executed,
              actor_resolver: fn ch -> ch.deletion.user_id end,
              target_resolver: fn ch -> ch.deletion.user_id end,
              metadata_resolver: fn ch ->
                %{
                  deleted_user_id: ch.deletion.user_id,
                  strategy: to_string(ch.deletion.strategy)
                }
              end
            )
          )
        )

      case repo.transaction(multi) do
        {:ok, %{deletion: %{strategy: strategy}} = changes} ->
          Sigra.Audit.emit_telemetry_from_changes(changes, [
            :audit_deletion_execute,
            :audit_deletion_executed
          ])

          {:ok, strategy}

        {:error, :deletion, reason, _} ->
          {:error, reason}

        {:error, failed, reason, _} ->
          unexpected_account_multi!(failed, reason)
      end
    else
      Deletion.execute(repo, user, opts)
    end
  end

  @doc "Check if deletion is scheduled."
  @doc since: "0.8.0"
  defdelegate deletion_scheduled?(user), to: Deletion, as: :scheduled?

  @doc "Get deletion status: {:scheduled, days_remaining} | :not_scheduled | :deleted"
  @doc since: "0.8.0"
  defdelegate deletion_status(user), to: Deletion, as: :status

  @doc """
  Audit a forced password change completion event.

  Called by subsystems that complete a forced-password change path
  (e.g., `Sigra.Account.PasswordChange.clear_force_change/2`). Writes
  a `account.password_change` audit row with `metadata: %{forced: true}`.

  Prefer `clear_password_change_requirement/3` when `:audit_schema` is configured so the
  domain update and audit share one transaction.
  """
  @doc since: "0.9.0"
  @deprecated "Use clear_password_change_requirement/3 when :audit_schema is configured; do not call this function for the same forced-clear completion or you may duplicate audit rows."
  @spec audit_forced_password_change(keyword(), term()) :: :ok
  def audit_forced_password_change(opts, user_id) do
    # 15-02 Category 2: user is resolved via id-only; build a minimal
    # user-map scope so downstream audit extraction still works.
    scope = user_id && Sigra.Scope.from_opts(opts, %{id: user_id})

    Sigra.Audit.log_safe(
      "account.password_change",
      scope,
      account_audit_opts(opts) ++
        [actor_id: user_id, target_id: user_id, metadata: %{forced: true}]
    )
  end
end
