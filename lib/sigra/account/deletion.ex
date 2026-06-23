defmodule Sigra.Account.Deletion do
  @moduledoc """
  Account deletion lifecycle: schedule, cancel, execute.

  Implements configurable account deletion with three strategies:
  - `:soft_delete` - Mark as deleted, preserve data (default)
  - `:hard_delete` - Cascade delete all Sigra tables, remove user row
  - `:anonymize` - Replace PII with anonymous values, preserve row

  ## Security Properties

  - Grace period (D-14): configurable delay before finalization (default 14 days)
  - Immediate deactivation (D-13): all sessions/tokens revoked on schedule
  - Pending email change auto-cancelled (D-24)
  - MFA data cleared at finalization only (D-13)
  - Cooldown rate limiting (D-22): 24h after cancellation
  - Telemetry events for audit trail (D-26)
  """

  alias Ecto.Multi
  alias Sigra.{Hooks, Telemetry}
  require Logger

  @default_grace_period_days 14

  @doc """
  Schedule account deletion with grace period.

  Immediately deactivates the account (revokes sessions/tokens), sets
  deletion timestamps, and preserves the original email for potential
  restoration.

  ## Options

  - `:changeset_fn` - `(user, attrs -> Ecto.Changeset.t())` for user updates
  - `:session_store` - SessionStore for session revocation
  - `:token_query_fn` - `(user, contexts -> Ecto.Queryable.t())` for token cleanup
  - `:config` - Config with `:deletion` section (strategy, grace_period_days, etc.)

  ## Returns

  - `{:ok, user, scheduled_deletion_at}` on success
  - `{:error, :already_scheduled}` if deletion already scheduled
  """
  @doc since: "0.8.0"
  @spec schedule(module(), map(), keyword()) ::
          {:ok, map(), DateTime.t()} | {:error, :already_scheduled}
  def schedule(repo, user, opts) do
    if user.deleted_at != nil do
      {:error, :already_scheduled}
    else
      do_schedule(repo, user, opts)
    end
  end

  @doc """
  Cancel scheduled deletion and reactivate account.

  Clears deletion timestamps and original_email. The user must
  re-authenticate to log in (all sessions were revoked on scheduling).

  ## Options

  - `:changeset_fn` - `(user, attrs -> Ecto.Changeset.t())` for user updates

  ## Returns

  - `{:ok, user}` on success
  - `{:error, :not_scheduled}` if no deletion is scheduled
  """
  @doc since: "0.8.0"
  @spec cancel(module(), map(), keyword()) :: {:ok, map()} | {:error, :not_scheduled}
  def cancel(repo, user, opts) do
    if not scheduled?(user) do
      {:error, :not_scheduled}
    else
      do_cancel(repo, user, opts)
    end
  end

  @doc """
  Execute deletion based on configured strategy.

  Called by the Oban worker when the grace period expires, or
  immediately for zero-grace-period configurations.

  ## Strategies

  - `:soft_delete` - No additional action (deleted_at already set)
  - `:hard_delete` - Cascade delete Sigra tables, delete user row
  - `:anonymize` - Replace email with `deleted_{id}@deleted.invalid`,
    clear hashed_password, null optional PII fields

  All strategies clear MFA data (TOTP secrets, backup codes) per D-13.

  ## Options

  - `:changeset_fn` - `(user, attrs -> Ecto.Changeset.t())` for user updates
  - `:token_query_fn` - `(user, contexts -> Ecto.Queryable.t())` for token cleanup
  - `:config` - Config with `:deletion` section

  ## Returns

  - `{:ok, strategy}` on success
  - `{:error, :not_scheduled}` if user is not scheduled for deletion
  """
  @doc since: "0.8.0"
  @spec execute(module(), map(), keyword()) ::
          {:ok, atom()} | {:error, :not_scheduled}
  def execute(repo, user, opts) do
    if not scheduled?(user) do
      {:error, :not_scheduled}
    else
      do_execute(repo, user, opts)
    end
  end

  @doc """
  Check if deletion is scheduled.

  Returns `true` when both `deleted_at` and `scheduled_deletion_at`
  are set (account is in grace period).
  """
  @doc since: "0.8.0"
  @spec scheduled?(map()) :: boolean()
  def scheduled?(user) do
    not is_nil(user.deleted_at) and not is_nil(user.scheduled_deletion_at)
  end

  @doc """
  Get deletion status.

  Returns:
  - `{:scheduled, days_remaining}` when in grace period
  - `:not_scheduled` when no deletion is pending
  - `:deleted` when finalized (deleted_at set but no scheduled_deletion_at)
  """
  @doc since: "0.8.0"
  @spec status(map()) :: {:scheduled, non_neg_integer()} | :not_scheduled | :deleted
  def status(user) do
    cond do
      not is_nil(user.deleted_at) and not is_nil(user.scheduled_deletion_at) ->
        days = DateTime.diff(user.scheduled_deletion_at, DateTime.utc_now(), :day)
        {:scheduled, max(days, 0)}

      not is_nil(user.deleted_at) ->
        :deleted

      true ->
        :not_scheduled
    end
  end

  @doc """
  Check if a cancellation is within the cooldown period.

  Used to enforce the 24h cooldown after cancelling deletion (D-22).
  Prevents abuse of the request/cancel cycle.

  ## Parameters

  - `cancelled_at` - The DateTime when deletion was cancelled
  - `cooldown_hours` - Number of hours in the cooldown window
  """
  @doc since: "0.8.0"
  @spec within_cooldown?(DateTime.t(), non_neg_integer()) :: boolean()
  def within_cooldown?(cancelled_at, cooldown_hours) do
    hours_since = DateTime.diff(DateTime.utc_now(), cancelled_at, :hour)
    hours_since < cooldown_hours
  end

  # --- Private ---

  defp do_schedule(repo, user, opts) do
    Telemetry.span([:sigra, :account, :deletion_scheduled], %{user_id: user.id}, fn ->
      changeset_fn = Keyword.fetch!(opts, :changeset_fn)
      token_query_fn = Keyword.fetch!(opts, :token_query_fn)
      config = Keyword.get(opts, :config, [])

      grace_period_days =
        get_in(config, [:deletion, :grace_period_days]) || @default_grace_period_days

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      scheduled_deletion_at =
        DateTime.add(now, grace_period_days * 86400, :second) |> DateTime.truncate(:second)

      user_changeset =
        changeset_fn.(user, %{
          deleted_at: now,
          scheduled_deletion_at: scheduled_deletion_at,
          original_email: user.email,
          pending_email: nil
        })

      multi =
        Multi.new()
        |> Multi.update(:user, user_changeset)
        |> Multi.delete_all(:tokens, token_query_fn.(user, :all))
        |> Hooks.maybe_run_hook(:delete, %{user: user, strategy: get_strategy(config)}, config)

      case repo.transaction(multi) do
        {:ok, %{user: updated_user}} ->
          # Revoke all sessions after transaction commit
          revoke_sessions(user, opts)
          maybe_enqueue_deletion_job(repo, updated_user, scheduled_deletion_at, opts)

          Telemetry.event(
            [:sigra, :account, :deletion_scheduled],
            %{},
            %{user_id: user.id, scheduled_at: scheduled_deletion_at}
          )

          {:ok, updated_user, scheduled_deletion_at}

        {:error, :user, changeset, _} ->
          {:error, changeset}
      end
    end)
  end

  defp do_cancel(repo, user, opts) do
    Telemetry.span([:sigra, :account, :deletion_cancelled], %{user_id: user.id}, fn ->
      changeset_fn = Keyword.fetch!(opts, :changeset_fn)

      user_changeset =
        changeset_fn.(user, %{
          deleted_at: nil,
          scheduled_deletion_at: nil,
          original_email: nil
        })

      multi =
        Multi.new()
        |> Multi.update(:user, user_changeset)

      case repo.transaction(multi) do
        {:ok, %{user: updated_user}} -> {:ok, updated_user}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    end)
  end

  defp do_execute(repo, user, opts) do
    strategy = get_strategy(Keyword.get(opts, :config, []))

    Telemetry.span([:sigra, :account, :deleted], %{user_id: user.id, strategy: strategy}, fn ->
      multi = build_execute_multi(strategy, user, opts)

      case repo.transaction(multi) do
        {:ok, _changes} ->
          Telemetry.event(
            [:sigra, :account, :deleted],
            %{},
            %{user_id: user.id, strategy: strategy}
          )

          {:ok, strategy}

        {:error, _step, reason, _changes} ->
          {:error, reason}
      end
    end)
  end

  defp build_execute_multi(:soft_delete, user, opts) do
    changeset_fn = Keyword.fetch!(opts, :changeset_fn)

    user_changeset =
      changeset_fn.(user, %{
        original_email: nil,
        pending_email: nil,
        scheduled_deletion_at: nil
      })

    Multi.new()
    |> Multi.update(:user, user_changeset)
  end

  defp build_execute_multi(:hard_delete, user, opts) do
    token_query_fn = Keyword.fetch!(opts, :token_query_fn)

    Multi.new()
    |> Multi.delete_all(:tokens, token_query_fn.(user, :all))
    |> Multi.delete(:delete_user, user)
  end

  defp build_execute_multi(:anonymize, user, opts) do
    changeset_fn = Keyword.fetch!(opts, :changeset_fn)

    anonymized_email = "deleted_#{user.id}@deleted.invalid"

    user_changeset =
      changeset_fn.(user, %{
        email: anonymized_email,
        hashed_password: nil,
        pending_email: nil,
        original_email: nil,
        scheduled_deletion_at: nil
      })

    Multi.new()
    |> Multi.update(:user, user_changeset)
  end

  defp maybe_enqueue_deletion_job(repo, user, scheduled_at, opts) do
    with true <- Sigra.OptionalDeps.oban_available?(),
         true <- Code.ensure_loaded?(Sigra.Workers.AccountDeletion),
         {:ok, args} <- deletion_job_args(repo, user, opts),
         {:ok, changeset} <-
           build_deletion_job_changeset(args, scheduled_at),
         {:ok, _job} <- repo.insert(changeset) do
      :ok
    else
      false ->
        :ok

      {:error, :missing_job_context} ->
        :ok

      {:error, reason} ->
        Logger.warning("Sigra account deletion job was not enqueued: #{inspect(reason)}")
        :ok
    end
  rescue
    error ->
      Logger.warning("Sigra account deletion job enqueue crashed: #{Exception.message(error)}")
      :ok
  end

  defp deletion_job_args(repo, user, opts) do
    case Keyword.get(opts, :user_schema) do
      nil ->
        {:error, :missing_job_context}

      user_schema ->
        scope = Keyword.get(opts, :scope)

        args = %{
          "organization_id" => scope_organization_id(scope),
          "actor_id" => scope_actor_id(scope, user),
          "user_id" => user.id,
          "strategy" => get_strategy(Keyword.get(opts, :config, [])) |> Atom.to_string(),
          "repo" => Atom.to_string(repo),
          "user_schema" => Atom.to_string(user_schema),
          "scope_module" => stringify_module(Keyword.get(opts, :scope_module)),
          "organization_schema" => stringify_module(Keyword.get(opts, :organization_schema)),
          "audit_schema" => stringify_module(Keyword.get(opts, :audit_schema)),
          "user_token_schema" => stringify_module(Keyword.get(opts, :user_token_schema)),
          "session_store" => stringify_module(Keyword.get(opts, :session_store)),
          "identity_schema" => stringify_module(Keyword.get(opts, :identity_schema)),
          "api_token_schema" => stringify_module(Keyword.get(opts, :api_token_schema)),
          "mfa_credential_schema" => stringify_module(Keyword.get(opts, :mfa_credential_schema)),
          "backup_code_schema" => stringify_module(Keyword.get(opts, :backup_code_schema))
        }

        {:ok, args}
    end
  end

  defp build_deletion_job_changeset(args, scheduled_at) do
    Sigra.Workers.new(
      Sigra.Workers.AccountDeletion,
      args,
      scheduled_at: scheduled_at,
      replace: [scheduled: [:scheduled_at, :args]]
    )
    |> then(&{:ok, &1})
  rescue
    error -> {:error, error}
  end

  defp scope_actor_id(%{impersonating_from: %{id: actor_id}}, _user), do: actor_id
  defp scope_actor_id(%{user: %{id: actor_id}}, _user), do: actor_id
  defp scope_actor_id(_, user), do: user.id

  defp scope_organization_id(%{active_organization: %{id: org_id}}), do: org_id
  defp scope_organization_id(_), do: nil

  defp stringify_module(nil), do: nil
  defp stringify_module(module) when is_atom(module), do: Atom.to_string(module)

  defp get_strategy(config) do
    # Config may be a Sigra.Config struct (keyword list values),
    # a plain map (from Oban worker), or a keyword list.
    # get_in/2 handles all these shapes via Access behaviour.
    case get_in(config, [:deletion, :strategy]) do
      strategy when strategy in [:soft_delete, :hard_delete, :anonymize] -> strategy
      _ -> :soft_delete
    end
  end

  defp revoke_sessions(user, opts) do
    session_store = Keyword.get(opts, :session_store)

    if session_store do
      # Thread `:repo` + `:session_schema` (via `:session_store_opts`) so the
      # Ecto store can run the delete. Deletion revokes ALL sessions, so there
      # is no `except_token` to preserve.
      session_store.delete_all_for_user(user.id, Keyword.get(opts, :session_store_opts, []))
    end
  end
end
