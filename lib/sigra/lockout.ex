defmodule Sigra.Lockout do
  @moduledoc """
  Account lockout logic for brute force prevention.

  Checks and manages lockout state based on failed login attempts.
  The lockout counter tracks failed password attempts only. After
  reaching the threshold, the account is temporarily locked for a
  configurable duration and auto-unlocks when the duration expires.

  ## Security Properties

  - Lockout check happens before password hash verification (saves CPU).
  - Messages are enumeration-safe (generic text via `Sigra.Error.safe_message/1`).
  - Counter resets on successful login.
  - Auto-unlocks after duration expires.
  - Hooks via telemetry only (`[:sigra, :security, :lockout]`).

  ## Options

  All functions accept the following options:

    * `:threshold` - Number of failed attempts before lockout. Default: `5`.
    * `:duration` - Lockout duration in seconds. Default: `900` (15 minutes).

  ## Examples

      case Sigra.Lockout.check(user) do
        :ok -> # proceed to password verification
        {:error, :account_locked, remaining} -> # account is locked
      end

  """

  @default_threshold 5
  @default_duration 900

  @doc """
  Check if user is locked out.

  Returns `:ok` or `{:error, :account_locked, remaining_seconds}`.

  Returns `:ok` for `nil` users (non-existent account) to support
  enumeration-safe flows where a dummy hash is performed regardless.

  ## Examples

      iex> Sigra.Lockout.check(nil)
      :ok

      iex> Sigra.Lockout.check(%{failed_login_attempts: 3, locked_at: nil})
      :ok

  """
  @doc since: "0.4.0"
  @spec check(struct() | nil, keyword()) :: :ok | {:error, :account_locked, non_neg_integer()}
  def check(user, opts \\ [])
  def check(nil, _opts), do: :ok

  def check(user, opts) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    duration = Keyword.get(opts, :duration, @default_duration)

    cond do
      user.failed_login_attempts < threshold -> :ok
      is_nil(user.locked_at) -> :ok
      lockout_expired?(user.locked_at, duration) -> :ok
      true -> {:error, :account_locked, remaining_seconds(user.locked_at, duration)}
    end
  end

  @doc """
  Increment failed login attempts. Sets `locked_at` when threshold reached.

  Must be called within a transaction or after failed password verification.
  Only sets `locked_at` when `failed_login_attempts` reaches the threshold,
  not before.

  ## Examples

      updated_user = Sigra.Lockout.increment!(MyApp.Repo, user)

  """
  @doc since: "0.4.0"
  @spec increment!(module(), struct(), keyword()) :: struct()
  def increment!(repo, user, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    new_count = (user.failed_login_attempts || 0) + 1

    changes =
      if new_count >= threshold && is_nil(user.locked_at) do
        %{failed_login_attempts: new_count, locked_at: DateTime.utc_now()}
      else
        %{failed_login_attempts: new_count}
      end

    user
    |> Ecto.Changeset.change(changes)
    |> repo.update!()
  end

  @doc """
  Reset lockout state after successful login.

  Sets `failed_login_attempts` to 0 and `locked_at` to `nil`.

  ## Examples

      updated_user = Sigra.Lockout.reset!(MyApp.Repo, user)

  """
  @doc since: "0.4.0"
  @spec reset!(module(), struct()) :: struct()
  def reset!(repo, user) do
    user
    |> Ecto.Changeset.change(%{failed_login_attempts: 0, locked_at: nil})
    |> repo.update!()
  end

  @doc """
  Record a lockout event in the audit log (standalone, D-28).

  Invoked by Sigra.Auth after a lockout is triggered. Exposed as a
  no-op-safe helper so callers don't need to build Sigra.Audit opts
  manually. Uses Sigra.Audit.log_safe which skips when audit_schema
  is nil.
  """
  @doc since: "0.9.0"
  @spec audit_lockout(keyword()) :: :ok
  def audit_lockout(opts) when is_list(opts) do
    Sigra.Audit.log_safe(
      "security.lockout",
      nil,
      Keyword.merge(opts,
        outcome: "failure",
        metadata: Keyword.get(opts, :metadata, %{})
      )
    )
  end

  @doc """
  Check if user is currently locked.

  Returns `true` when within lockout window, `false` otherwise.
  Returns `false` for `nil` users.

  ## Examples

      iex> Sigra.Lockout.locked?(nil)
      false

  """
  @doc since: "0.4.0"
  @spec locked?(struct() | nil, keyword()) :: boolean()
  def locked?(user, opts \\ [])
  def locked?(nil, _opts), do: false

  def locked?(user, opts) do
    case check(user, opts) do
      :ok -> false
      {:error, :account_locked, _} -> true
    end
  end

  @doc """
  Return lock status with remaining seconds.

  Returns `{:locked, remaining_seconds}` or `:unlocked`.
  Returns `:unlocked` for `nil` users.

  ## Examples

      case Sigra.Lockout.lock_status(user) do
        :unlocked -> # user can log in
        {:locked, seconds} -> # locked for N more seconds
      end

  """
  @doc since: "0.4.0"
  @spec lock_status(struct() | nil, keyword()) :: :unlocked | {:locked, non_neg_integer()}
  def lock_status(user, opts \\ [])
  def lock_status(nil, _opts), do: :unlocked

  def lock_status(user, opts) do
    case check(user, opts) do
      :ok -> :unlocked
      {:error, :account_locked, remaining} -> {:locked, remaining}
    end
  end

  defp lockout_expired?(locked_at, duration) do
    DateTime.diff(DateTime.utc_now(), locked_at, :second) > duration
  end

  defp remaining_seconds(locked_at, duration) do
    elapsed = DateTime.diff(DateTime.utc_now(), locked_at, :second)
    max(duration - elapsed, 0)
  end
end
