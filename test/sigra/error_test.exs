defmodule Sigra.ErrorTest do
  use ExUnit.Case, async: true

  alias Sigra.Error

  describe "safe_message/1" do
    test "returns generic message for :invalid_credentials" do
      assert Error.safe_message(:invalid_credentials) == "Invalid email or password."
    end

    test "returns user-friendly message for :token_expired" do
      assert Error.safe_message(:token_expired) ==
               "This link has expired. Please request a new one."
    end

    test "returns user-friendly message for :token_invalid" do
      assert Error.safe_message(:token_invalid) ==
               "This link is invalid. Please request a new one."
    end

    test "returns user-friendly message for :rate_limited" do
      assert Error.safe_message(:rate_limited) == "Too many requests. Please try again later."
    end

    test "returns user-friendly message for :account_locked" do
      assert Error.safe_message(:account_locked) ==
               "Too many attempts. Try again in a few minutes."
    end

    test "returns fallback for unknown errors" do
      assert Error.safe_message(:something_unknown) == "Something went wrong. Please try again."
    end

    # Phase 3: Confirmation/reset error messages
    test "returns message for :already_confirmed" do
      assert Error.safe_message(:already_confirmed) == "Your email is already confirmed."
    end

    test "returns message for :unconfirmed" do
      assert Error.safe_message(:unconfirmed) ==
               "You must confirm your email before continuing."
    end

    test "returns message for :confirmation_code_invalid" do
      assert Error.safe_message(:confirmation_code_invalid) ==
               "Invalid confirmation code. Please try again."
    end

    test "returns message for :reset_token_expired" do
      assert Error.safe_message(:reset_token_expired) ==
               "This password reset link has expired or was already used."
    end

    test "returns message for :confirmation_token_expired" do
      assert Error.safe_message(:confirmation_token_expired) ==
               "This confirmation link has expired or was already used."
    end
  end

  describe "AlreadyConfirmed exception" do
    test "is a defexception with default message" do
      error = %Error.AlreadyConfirmed{}
      assert error.message == "email already confirmed"
    end

    test "can be raised" do
      assert_raise Error.AlreadyConfirmed, fn ->
        raise Error.AlreadyConfirmed
      end
    end
  end

  describe "Unconfirmed exception" do
    test "is a defexception with default message" do
      error = %Error.Unconfirmed{}
      assert error.message == "email not confirmed"
    end

    test "can be raised" do
      assert_raise Error.Unconfirmed, fn ->
        raise Error.Unconfirmed
      end
    end
  end

  describe "InvalidCredentials exception" do
    test "is a defexception with default message" do
      error = %Error.InvalidCredentials{}
      assert error.message == "invalid credentials"
    end

    test "can be raised" do
      assert_raise Error.InvalidCredentials, fn ->
        raise Error.InvalidCredentials
      end
    end
  end

  describe "TokenExpired exception" do
    test "is a defexception with default message" do
      error = %Error.TokenExpired{}
      assert error.message == "token has expired"
    end

    test "has context field" do
      error = %Error.TokenExpired{context: :confirm}
      assert error.context == :confirm
    end
  end

  describe "TokenInvalid exception" do
    test "is a defexception with default message" do
      error = %Error.TokenInvalid{}
      assert error.message == "token is invalid"
    end

    test "has context field" do
      error = %Error.TokenInvalid{context: :reset_password}
      assert error.context == :reset_password
    end
  end

  describe "RateLimited exception" do
    test "is a defexception with retry_after_ms field" do
      error = %Error.RateLimited{retry_after_ms: 30_000}
      assert error.retry_after_ms == 30_000
    end

    test "has default message" do
      error = %Error.RateLimited{}
      assert error.message == "rate limit exceeded"
    end
  end

  describe "AccountLocked exception" do
    test "is a defexception with locked_until field" do
      locked_until = ~U[2026-04-06 12:00:00Z]
      error = %Error.AccountLocked{locked_until: locked_until}
      assert error.locked_until == locked_until
    end

    test "has default message" do
      error = %Error.AccountLocked{}
      assert error.message == "account is locked"
    end
  end
end
