defmodule Sigra.MFA.ErrorTest do
  use ExUnit.Case, async: true

  alias Sigra.Error
  alias Sigra.Error.MFAError

  describe "MFAError" do
    test "can be raised with error_code" do
      error = %MFAError{error_code: :invalid_code}
      assert error.error_code == :invalid_code
      assert error.message == "MFA error"
    end

    test "supports metadata" do
      error = %MFAError{
        error_code: :lockout,
        metadata: %{remaining_seconds: 600}
      }

      assert error.metadata.remaining_seconds == 600
    end

    test "supports custom message" do
      error = %MFAError{error_code: :invalid_code, message: "custom"}
      assert error.message == "custom"
    end
  end

  describe "safe_message/1 for MFA error codes" do
    test "maps :invalid_code to generic message" do
      assert Error.safe_message(:invalid_code) == "Invalid verification code."
    end

    test "maps :invalid_backup_code to same message as :invalid_code (D-90)" do
      assert Error.safe_message(:invalid_backup_code) == "Invalid verification code."
    end

    test "maps :lockout to lockout message" do
      assert Error.safe_message(:lockout) == "Too many failed attempts. Try again later."
    end

    test "maps :not_enrolled to not-enabled message" do
      assert Error.safe_message(:not_enrolled) == "Two-factor authentication is not enabled."
    end

    test "maps :already_enrolled to already-enabled message" do
      assert Error.safe_message(:already_enrolled) ==
               "Two-factor authentication is already enabled."
    end

    test "maps :enrollment_required to enrollment message" do
      assert Error.safe_message(:enrollment_required) ==
               "Two-factor authentication enrollment is required."
    end

    test "maps :backup_exhausted to exhausted message" do
      assert Error.safe_message(:backup_exhausted) == "All backup codes have been used."
    end
  end
end
