defmodule Sigra.Error do
  @moduledoc """
  Error types and safe message mapping for Sigra authentication.

  Sigra uses structured error types for precise internal error handling,
  combined with a `safe_message/1` function that maps internal errors to
  enumeration-safe user-facing strings.

  ## Error Types

  - `Sigra.Error.InvalidCredentials` -- wrong email or password
  - `Sigra.Error.TokenExpired` -- token past its TTL
  - `Sigra.Error.TokenInvalid` -- token is malformed or tampered
  - `Sigra.Error.RateLimited` -- too many requests
  - `Sigra.Error.AccountLocked` -- account temporarily locked
  - `Sigra.Error.OAuthError` -- OAuth operation failed (provider, error_code)

  ## Enumeration Prevention

  The `safe_message/1` function ensures that user-facing messages never
  leak information about which part of authentication failed. For example,
  `:invalid_credentials` always returns `"Invalid email or password."` --
  never `"wrong password"` or `"user not found"`.
  """

  defmodule InvalidCredentials do
    @moduledoc "Raised when authentication fails due to wrong email or password."
    defexception message: "invalid credentials"
  end

  defmodule TokenExpired do
    @moduledoc "Raised when a token has exceeded its time-to-live."
    defexception [:context, message: "token has expired"]
  end

  defmodule TokenInvalid do
    @moduledoc "Raised when a token is malformed, tampered, or otherwise invalid."
    defexception [:context, message: "token is invalid"]
  end

  defmodule RateLimited do
    @moduledoc "Raised when a rate limit has been exceeded."
    defexception [:retry_after_ms, message: "rate limit exceeded"]
  end

  defmodule AccountLocked do
    @moduledoc "Raised when an account is temporarily locked due to failed attempts."
    defexception [:locked_until, message: "account is locked"]
  end

  defmodule OAuthError do
    @moduledoc "Raised when an OAuth operation fails."
    defexception [:provider, :error_code, message: "OAuth error"]

    @type error_code ::
            :state_mismatch
            | :no_email
            | :provider_error
            | :token_exchange_failed
            | :link_conflict
            | :email_mismatch
            | :authorize_failed

    @impl true
    def message(%{provider: provider, error_code: code}) when not is_nil(code) do
      "OAuth error: #{code} for provider #{provider}"
    end

    def message(%{message: message}), do: message
  end

  defmodule MFAError do
    @moduledoc """
    Raised when an MFA operation fails.

    ## Fields

    - `:error_code` - one of `:invalid_code`, `:lockout`, `:not_enrolled`,
      `:already_enrolled`, `:enrollment_required`, `:backup_exhausted`,
      `:invalid_backup_code`
    - `:message` - human-readable error message (default "MFA error")
    - `:metadata` - map with extra data (e.g., remaining_attempts, lockout_seconds)
    """
    defexception [:error_code, :metadata, message: "MFA error"]

    @type error_code ::
            :invalid_code
            | :lockout
            | :not_enrolled
            | :already_enrolled
            | :enrollment_required
            | :backup_exhausted
            | :invalid_backup_code

    @impl true
    def message(%{error_code: code, metadata: meta}) when not is_nil(code) and is_map(meta) do
      "MFA error: #{code} (#{inspect(meta)})"
    end

    def message(%{error_code: code}) when not is_nil(code) do
      "MFA error: #{code}"
    end

    def message(%{message: message}), do: message
  end

  defmodule TokenRevoked do
    @moduledoc "Raised when a revoked API token or JWT refresh token is used."
    defexception [:token_id, message: "token has been revoked"]
  end

  defmodule InsufficientScope do
    @moduledoc "Raised when a valid token lacks required scopes."
    defexception [:required_scopes, :provided_scopes, message: "insufficient scope"]
  end

  defmodule MFARequired do
    @moduledoc "Raised when JWT login requires MFA verification."
    defexception [:mfa_token, message: "MFA verification required"]
  end

  defmodule AlreadyConfirmed do
    @moduledoc "Raised when a user's email is already confirmed."
    defexception message: "email already confirmed"
  end

  defmodule Unconfirmed do
    @moduledoc "Raised when an unconfirmed user attempts a restricted action."
    defexception message: "email not confirmed"
  end

  @doc """
  Maps an internal error atom to an enumeration-safe user-facing message.

  These messages are intentionally generic to prevent user enumeration
  attacks. Internal code uses precise error atoms; the safe message is
  for display to end users.

  ## Examples

      iex> Sigra.Error.safe_message(:invalid_credentials)
      "Invalid email or password."

      iex> Sigra.Error.safe_message(:token_expired)
      "This link has expired. Please request a new one."

  """
  @doc since: "0.1.0"
  @spec safe_message(atom()) :: String.t()
  def safe_message(:invalid_credentials), do: "Invalid email or password."
  def safe_message(:token_expired), do: "This link has expired. Please request a new one."
  def safe_message(:token_invalid), do: "This link is invalid. Please request a new one."
  def safe_message(:rate_limited), do: "Too many requests. Please try again later."

  def safe_message(:account_locked),
    do: "Too many attempts. Try again in a few minutes."

  def safe_message(:account_locked_just_triggered),
    do: "Invalid email or password. Too many attempts. Try again in a few minutes."

  def safe_message(:already_confirmed), do: "Your email is already confirmed."

  def safe_message(:unconfirmed),
    do: "You must confirm your email before continuing."

  def safe_message(:confirmation_code_invalid),
    do: "Invalid confirmation code. Please try again."

  def safe_message(:reset_token_expired),
    do: "This password reset link has expired or was already used."

  def safe_message(:confirmation_token_expired),
    do: "This confirmation link has expired or was already used."

  # MFA error codes (D-89, D-90, D-91)
  def safe_message(:invalid_code), do: "Invalid verification code."
  def safe_message(:invalid_backup_code), do: "Invalid verification code."
  def safe_message(:lockout), do: "Too many failed attempts. Try again later."
  def safe_message(:not_enrolled), do: "Two-factor authentication is not enabled."
  def safe_message(:already_enrolled), do: "Two-factor authentication is already enabled."

  def safe_message(:enrollment_required),
    do: "Two-factor authentication enrollment is required."

  def safe_message(:backup_exhausted), do: "All backup codes have been used."

  def safe_message(:oauth_state_mismatch),
    do: "Authentication expired. Please try again."

  def safe_message(:oauth_no_email),
    do:
      "We need your email to create an account. Please grant email permission and try again."

  def safe_message(:oauth_provider_error),
    do:
      "Could not sign in with the selected provider. Please try again or use another method."

  def safe_message(:oauth_token_exchange_failed),
    do:
      "Could not sign in with the selected provider. Please try again or use another method."

  def safe_message(:oauth_link_conflict),
    do: "Could not complete sign in."

  def safe_message(:oauth_email_mismatch),
    do: "Could not complete sign in."

  def safe_message(:oauth_authorize_failed),
    do:
      "Could not sign in with the selected provider. Please try again or use another method."

  # API token / JWT error codes
  def safe_message(:token_revoked), do: "This token has been revoked."
  def safe_message(:insufficient_scope), do: "You do not have permission to perform this action."
  def safe_message(:mfa_required), do: "Multi-factor authentication is required."

  def safe_message(_), do: "Something went wrong. Please try again."
end
