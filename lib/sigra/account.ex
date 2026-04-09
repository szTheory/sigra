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

  ## Account Deletion (D-11 to D-33)

      Sigra.Account.schedule_deletion(repo, user, opts)
      Sigra.Account.cancel_deletion(repo, user, opts)
      Sigra.Account.execute_deletion(repo, user, opts)
  """

  alias Sigra.Account.{Deletion, EmailChange, PasswordChange}

  # --- Audit integration helpers (Plan 09-03) ---
  #
  # D-26 dispatch table for account.* operations:
  #
  #   request_email_change  -> Sigra.Audit.log_safe("account.email_change_request")
  #   confirm_email_change  -> Sigra.Audit.log_safe("account.email_change_confirm")
  #   cancel_email_change   -> Sigra.Audit.log_safe("account.email_change_cancel")
  #   change_password       -> Sigra.Audit.log_safe("account.password_change",
  #                             metadata: %{forced: false})
  #   forced password chg   -> Sigra.Audit.log_safe("account.password_change",
  #                             metadata: %{forced: true})
  #   schedule_deletion     -> Sigra.Audit.log_safe("account.deletion_schedule")
  #   cancel_deletion       -> Sigra.Audit.log_safe("account.deletion_cancel")
  #   execute_deletion      -> Sigra.Audit.log_safe("account.deletion_execute")
  #
  # Metadata: strings, IDs, flags only. NEVER passwords, hashes, or tokens.
  defp account_audit_opts(opts) when is_list(opts) do
    [
      repo: Keyword.get(opts, :repo),
      audit_schema: Keyword.get(opts, :audit_schema)
    ]
  end

  # --- Email Change (per D-28 context API) ---

  @doc "Request an email change. Sends verification to new address."
  @doc since: "0.8.0"
  def request_email_change(repo, user, new_email, opts) do
    result = EmailChange.request(repo, user, new_email, opts)

    case result do
      {:ok, _} ->
        Sigra.Audit.log_safe("account.email_change_request",
          (account_audit_opts(opts) |> Keyword.put(:repo, repo)) ++
            [actor_id: user.id, metadata: %{}]
        )

      _ ->
        :ok
    end

    result
  end

  @doc "Confirm an email change via token from verification email."
  @doc since: "0.8.0"
  def confirm_email_change(repo, encoded_token, opts) do
    result = EmailChange.confirm(repo, encoded_token, opts)

    case result do
      {:ok, user} ->
        Sigra.Audit.log_safe("account.email_change_confirm",
          (account_audit_opts(opts) |> Keyword.put(:repo, repo)) ++
            [actor_id: user.id, metadata: %{}]
        )

      _ ->
        :ok
    end

    result
  end

  @doc "Cancel a pending email change."
  @doc since: "0.8.0"
  def cancel_email_change(repo, user, opts) do
    result = EmailChange.cancel(repo, user, opts)

    case result do
      {:ok, _} ->
        Sigra.Audit.log_safe("account.email_change_cancel",
          (account_audit_opts(opts) |> Keyword.put(:repo, repo)) ++
            [actor_id: user.id, metadata: %{}]
        )

      _ ->
        :ok
    end

    result
  end

  # --- Password Change (per D-40 context API) ---

  @doc "Change password with current password verification."
  @doc since: "0.8.0"
  def change_password(repo, user, current_password, attrs, opts) do
    result = PasswordChange.change(repo, user, current_password, attrs, opts)

    case result do
      {:ok, _} ->
        # D-26: account.password_change. NEVER include password/hash in
        # metadata (D-23 enforced by Sigra.Audit.Changeset).
        Sigra.Audit.log_safe("account.password_change",
          (account_audit_opts(opts) |> Keyword.put(:repo, repo)) ++
            [actor_id: user.id, metadata: %{forced: false}]
        )

      _ ->
        :ok
    end

    result
  end

  @doc "Set password for OAuth-only user (no current password). Requires sudo."
  @doc since: "0.8.0"
  def set_password(repo, user, attrs, opts) do
    result = PasswordChange.set_for_oauth_user(repo, user, attrs, opts)

    case result do
      {:ok, _} ->
        Sigra.Audit.log_safe("account.password_change",
          (account_audit_opts(opts) |> Keyword.put(:repo, repo)) ++
            [actor_id: user.id, metadata: %{forced: false, source: "oauth_set"}]
        )

      _ ->
        :ok
    end

    result
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
    result = Deletion.schedule(repo, user, opts)

    case result do
      {:ok, _} ->
        Sigra.Audit.log_safe("account.deletion_schedule",
          (account_audit_opts(opts) |> Keyword.put(:repo, repo)) ++
            [actor_id: user.id, metadata: %{}]
        )

      _ ->
        :ok
    end

    result
  end

  @doc "Cancel scheduled deletion and reactivate account."
  @doc since: "0.8.0"
  def cancel_deletion(repo, user, opts) do
    result = Deletion.cancel(repo, user, opts)

    case result do
      {:ok, _} ->
        Sigra.Audit.log_safe("account.deletion_cancel",
          (account_audit_opts(opts) |> Keyword.put(:repo, repo)) ++
            [actor_id: user.id, metadata: %{}]
        )

      _ ->
        :ok
    end

    result
  end

  @doc "Execute deletion (called by Oban worker or manual task)."
  @doc since: "0.8.0"
  def execute_deletion(repo, user, opts) do
    # D-11 / D-26: the execute_deletion audit row may reference a user_id
    # that no longer exists after hard delete — this is intentional and
    # preserves the forensic trail.
    user_id = user.id

    Sigra.Audit.log_safe("account.deletion_execute",
      (account_audit_opts(opts) |> Keyword.put(:repo, repo)) ++
        [actor_id: user_id, metadata: %{}]
    )

    Deletion.execute(repo, user, opts)
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
  """
  @doc since: "0.9.0"
  @spec audit_forced_password_change(keyword(), term()) :: :ok
  def audit_forced_password_change(opts, user_id) do
    Sigra.Audit.log_safe("account.password_change",
      account_audit_opts(opts) ++
        [actor_id: user_id, metadata: %{forced: true}]
    )
  end
end
