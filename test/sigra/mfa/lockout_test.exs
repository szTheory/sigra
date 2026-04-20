defmodule Sigra.MFA.LockoutTest do
  use ExUnit.Case, async: true

  alias Sigra.MFA.Lockout

  @default_config [
    mfa: [lockout_threshold: 5, lockout_duration: 900]
  ]

  defp config(overrides \\ []) do
    mfa_opts = Keyword.merge(@default_config[:mfa], overrides)
    struct!(Sigra.Config, repo: SomeRepo, user_schema: SomeUser, mfa: mfa_opts)
  end

  describe "check/2" do
    test "returns :ok when failed_attempts below threshold" do
      credential = %Sigra.MFA.Credential{
        failed_attempts: 3,
        locked_until: nil
      }

      assert :ok = Lockout.check(credential, config())
    end

    test "returns :ok when failed_attempts is 0" do
      credential = %Sigra.MFA.Credential{
        failed_attempts: 0,
        locked_until: nil
      }

      assert :ok = Lockout.check(credential, config())
    end

    test "returns {:error, :lockout, remaining_seconds} when locked" do
      locked_until = DateTime.add(DateTime.utc_now(), 600, :second)

      credential = %Sigra.MFA.Credential{
        failed_attempts: 5,
        locked_until: locked_until
      }

      assert {:error, :lockout, remaining} = Lockout.check(credential, config())
      assert remaining > 0
      assert remaining <= 600
    end

    test "returns :ok when lockout has expired" do
      locked_until = DateTime.add(DateTime.utc_now(), -10, :second)

      credential = %Sigra.MFA.Credential{
        failed_attempts: 5,
        locked_until: locked_until
      }

      assert :ok = Lockout.check(credential, config())
    end

    test "returns :ok when locked_until is nil even with high attempts" do
      credential = %Sigra.MFA.Credential{
        failed_attempts: 10,
        locked_until: nil
      }

      assert :ok = Lockout.check(credential, config())
    end

    test "respects custom threshold from config" do
      credential = %Sigra.MFA.Credential{
        failed_attempts: 3,
        locked_until: DateTime.add(DateTime.utc_now(), 600, :second)
      }

      assert {:error, :lockout, _remaining} =
               Lockout.check(credential, config(lockout_threshold: 3))
    end
  end
end
