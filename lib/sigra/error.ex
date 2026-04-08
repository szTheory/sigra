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

  def safe_message(_), do: "Something went wrong. Please try again."
end
