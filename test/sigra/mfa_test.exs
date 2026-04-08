defmodule Sigra.MFATest do
  use ExUnit.Case, async: true

  alias Sigra.MFA

  describe "enroll/2" do
    test "returns {:ok, map} with secret, otpauth_uri, svg, and raw_secret" do
      config = build_config()

      assert {:ok, enrollment} = MFA.enroll(config)
      assert is_binary(enrollment.secret)
      assert is_binary(enrollment.otpauth_uri)
      assert is_binary(enrollment.raw_secret)
      # svg may be nil if eqrcode not loaded, or a string if available
      assert is_nil(enrollment.svg) or is_binary(enrollment.svg)
    end

    test "otpauth_uri contains issuer and account" do
      config = build_config(mfa: [totp_issuer: "TestApp"])

      {:ok, enrollment} = MFA.enroll(config, account: "user@example.com")

      assert enrollment.otpauth_uri =~ "TestApp"
      assert enrollment.otpauth_uri =~ "user@example.com"
    end

    test "secret is base32 encoded" do
      config = build_config()

      {:ok, enrollment} = MFA.enroll(config)

      # Base32 decode should work
      assert {:ok, _binary} = Base.decode32(enrollment.secret)
    end

    test "falls back to humanized otp_app for issuer when totp_issuer is nil" do
      config = build_config(otp_app: :my_cool_app, mfa: [totp_issuer: nil])

      {:ok, enrollment} = MFA.enroll(config, account: "user@example.com")

      assert enrollment.otpauth_uri =~ "My Cool App"
    end
  end

  describe "verify_totp/4" do
    test "returns {:ok, step} for valid code" do
      raw_secret = NimbleTOTP.secret()
      now = System.system_time(:second)
      code = NimbleTOTP.verification_code(raw_secret, time: now)

      assert {:ok, step} = MFA.verify_totp(raw_secret, code, 0, 1)
      assert is_integer(step)
      assert step > 0
    end

    test "returns {:error, :invalid_code} for invalid code" do
      raw_secret = NimbleTOTP.secret()

      assert {:error, :invalid_code} = MFA.verify_totp(raw_secret, "000000", 0, 1)
    end

    test "returns {:error, :replay} for same step as last_verified_step" do
      raw_secret = NimbleTOTP.secret()
      now = System.system_time(:second)
      current_step = div(now, 30)
      code = NimbleTOTP.verification_code(raw_secret, time: now)

      # First verify should succeed
      assert {:ok, ^current_step} = MFA.verify_totp(raw_secret, code, 0, 1)

      # Same code with last_verified_step = current_step should be replay
      assert {:error, :replay} = MFA.verify_totp(raw_secret, code, current_step, 1)
    end

    test "accepts codes within drift window" do
      raw_secret = NimbleTOTP.secret()
      now = System.system_time(:second)
      # Generate code for 30 seconds ago (previous step)
      code = NimbleTOTP.verification_code(raw_secret, time: now - 30)

      # With drift_steps=1, previous step should be accepted
      assert {:ok, _step} = MFA.verify_totp(raw_secret, code, 0, 1)
    end

    test "rejects codes outside drift window" do
      raw_secret = NimbleTOTP.secret()
      now = System.system_time(:second)
      # Generate code for 90 seconds ago (3 steps back)
      code = NimbleTOTP.verification_code(raw_secret, time: now - 90)

      # With drift_steps=1, 3 steps back should be rejected
      assert {:error, :invalid_code} = MFA.verify_totp(raw_secret, code, 0, 1)
    end
  end

  describe "module exports" do
    test "enroll/2 exists" do
      assert function_exported?(MFA, :enroll, 2)
    end

    test "confirm_enrollment/5 exists" do
      assert function_exported?(MFA, :confirm_enrollment, 5)
    end

    test "verify/4 exists" do
      assert function_exported?(MFA, :verify, 4)
    end

    test "verify_backup/4 exists" do
      assert function_exported?(MFA, :verify_backup, 4)
    end

    test "disable/4 exists" do
      assert function_exported?(MFA, :disable, 4)
    end

    test "disable!/3 exists" do
      assert function_exported?(MFA, :disable!, 3)
    end

    test "enabled?/2 exists" do
      assert function_exported?(MFA, :enabled?, 2)
    end

    test "status/2 exists" do
      assert function_exported?(MFA, :status, 2)
    end
  end

  defp build_config(overrides \\ []) do
    defaults = [
      repo: SomeRepo,
      user_schema: SomeUser,
      otp_app: :sigra,
      mfa: [
        enabled: true,
        totp_issuer: nil,
        totp_drift_steps: 1,
        backup_code_count: 8,
        trust_enabled: true,
        trust_ttl: 2_592_000,
        lockout_threshold: 5,
        lockout_duration: 900,
        pending_timeout: 300,
        show_trust_option: true
      ]
    ]

    merged = Keyword.merge(defaults, overrides, fn
      :mfa, v1, v2 -> Keyword.merge(v1, v2)
      _k, _v1, v2 -> v2
    end)

    Sigra.Config.new!(merged)
  end
end
