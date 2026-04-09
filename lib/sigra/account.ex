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

  # --- Email Change (per D-28 context API) ---

  @doc "Request an email change. Sends verification to new address."
  @doc since: "0.8.0"
  defdelegate request_email_change(repo, user, new_email, opts), to: EmailChange, as: :request

  @doc "Confirm an email change via token from verification email."
  @doc since: "0.8.0"
  defdelegate confirm_email_change(repo, encoded_token, opts), to: EmailChange, as: :confirm

  @doc "Cancel a pending email change."
  @doc since: "0.8.0"
  defdelegate cancel_email_change(repo, user, opts), to: EmailChange, as: :cancel

  # --- Password Change (per D-40 context API) ---

  @doc "Change password with current password verification."
  @doc since: "0.8.0"
  defdelegate change_password(repo, user, current_password, attrs, opts),
    to: PasswordChange,
    as: :change

  @doc "Set password for OAuth-only user (no current password). Requires sudo."
  @doc since: "0.8.0"
  defdelegate set_password(repo, user, attrs, opts), to: PasswordChange, as: :set_for_oauth_user

  @doc "Check if user must change their password."
  @doc since: "0.8.0"
  defdelegate must_change_password?(user), to: PasswordChange, as: :force_change_required?

  @doc "Admin API: require user to change password on next login."
  @doc since: "0.8.0"
  defdelegate require_password_change(repo, user), to: PasswordChange, as: :require_force_change

  # --- Account Deletion (per D-28 context API) ---

  @doc "Schedule account deletion with grace period."
  @doc since: "0.8.0"
  defdelegate schedule_deletion(repo, user, opts), to: Deletion, as: :schedule

  @doc "Cancel scheduled deletion and reactivate account."
  @doc since: "0.8.0"
  defdelegate cancel_deletion(repo, user, opts), to: Deletion, as: :cancel

  @doc "Execute deletion (called by Oban worker or manual task)."
  @doc since: "0.8.0"
  defdelegate execute_deletion(repo, user, opts), to: Deletion, as: :execute

  @doc "Check if deletion is scheduled."
  @doc since: "0.8.0"
  defdelegate deletion_scheduled?(user), to: Deletion, as: :scheduled?

  @doc "Get deletion status: {:scheduled, days_remaining} | :not_scheduled | :deleted"
  @doc since: "0.8.0"
  defdelegate deletion_status(user), to: Deletion, as: :status
end
