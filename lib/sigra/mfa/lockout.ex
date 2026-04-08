defmodule Sigra.MFA.Lockout do
  @moduledoc """
  MFA-specific lockout logic, mirroring `Sigra.Lockout` pattern.

  Checks and manages MFA lockout state based on failed verification attempts
  on the MFA credential record. After reaching the configured threshold,
  the MFA credential is temporarily locked for a configurable duration.

  ## Security Properties

  - Lockout counter is per-user on MFA credential, not per-session (D-31)
  - Atomic increment via `update_all` prevents race conditions (Pitfall 4)
  - Shared counter for TOTP and backup code attempts (D-19)
  - Auto-unlocks after duration expires
  """

  import Ecto.Query

  @doc """
  Check if an MFA credential is locked out.

  Returns `:ok` if the credential is not locked, or
  `{:error, :lockout, remaining_seconds}` if currently locked.

  Uses `mfa.lockout_threshold` and `mfa.lockout_duration` from config.
  """
  @doc since: "0.6.0"
  @spec check(Sigra.MFA.Credential.t(), Sigra.Config.t()) ::
          :ok | {:error, :lockout, non_neg_integer()}
  def check(%Sigra.MFA.Credential{} = credential, %Sigra.Config{} = config) do
    threshold = Keyword.get(config.mfa, :lockout_threshold, 5)

    cond do
      credential.failed_attempts < threshold ->
        :ok

      is_nil(credential.locked_until) ->
        :ok

      lockout_expired?(credential.locked_until) ->
        :ok

      true ->
        {:error, :lockout, remaining_seconds(credential.locked_until)}
    end
  end

  @doc """
  Atomically increment failed MFA attempts on a credential.

  If the new count meets or exceeds the threshold, also sets `locked_until`.
  Returns `{:ok, %{failed_attempts: n, locked: boolean}}`.

  ## Parameters

  - `repo` - The Ecto repo module
  - `mfa_credential_schema` - The generated MFA credential Ecto schema module
  - `credential_id` - The credential's database ID
  - `config` - Sigra config with MFA settings
  """
  @doc since: "0.6.0"
  @spec increment(module(), module(), term(), Sigra.Config.t()) ::
          {:ok, %{failed_attempts: non_neg_integer(), locked: boolean()}}
  def increment(repo, mfa_credential_schema, credential_id, %Sigra.Config{} = config) do
    threshold = Keyword.get(config.mfa, :lockout_threshold, 5)
    duration = Keyword.get(config.mfa, :lockout_duration, 900)

    # Atomic increment
    {1, [result]} =
      from(c in mfa_credential_schema,
        where: c.id == ^credential_id,
        update: [inc: [failed_attempts: 1]],
        select: c.failed_attempts
      )
      |> repo.update_all([])

    # The returned value is the value AFTER increment (Ecto update_all with inc returns new value)
    new_count = result

    locked =
      if new_count >= threshold do
        locked_until = DateTime.add(DateTime.utc_now(), duration, :second)

        from(c in mfa_credential_schema,
          where: c.id == ^credential_id,
          update: [set: [locked_until: ^locked_until]]
        )
        |> repo.update_all([])

        true
      else
        false
      end

    {:ok, %{failed_attempts: new_count, locked: locked}}
  end

  @doc """
  Reset MFA lockout state on a credential.

  Sets `failed_attempts = 0` and `locked_until = nil`.
  """
  @doc since: "0.6.0"
  @spec reset(module(), module(), term()) :: :ok
  def reset(repo, mfa_credential_schema, credential_id) do
    from(c in mfa_credential_schema,
      where: c.id == ^credential_id,
      update: [set: [failed_attempts: 0, locked_until: nil]]
    )
    |> repo.update_all([])

    :ok
  end

  defp lockout_expired?(locked_until) do
    DateTime.compare(DateTime.utc_now(), locked_until) != :lt
  end

  defp remaining_seconds(locked_until) do
    diff = DateTime.diff(locked_until, DateTime.utc_now(), :second)
    max(diff, 0)
  end
end
