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
               "Account is temporarily locked. Please try again later."
    end

    test "returns fallback for unknown errors" do
      assert Error.safe_message(:something_unknown) == "Something went wrong. Please try again."
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
