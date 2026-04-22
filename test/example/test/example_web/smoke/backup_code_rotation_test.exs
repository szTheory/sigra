defmodule Example.BackupCodeRotationTest do
  @moduledoc """
  GA-01 / SEED-7: backup codes rotate atomically; old plaintext hashes no longer verify.
  """
  use Example.DataCase, async: true
  import Example.AccountsFixtures
  @moduletag :example_app

  alias Example.Accounts
  alias Sigra.Testing

  test "backup code consumed before rotation fails after rotation with same plaintext" do
    {:ok, user} = Accounts.register_user(valid_user_attributes())
    config = Accounts.sigra_config()

    %{secret: secret, backup_codes: backup_codes} =
      Testing.setup_totp(user,
        config: config,
        mfa_credential_schema: Example.Accounts.UserMFACredential,
        backup_code_schema: Example.Accounts.UserBackupCode
      )

    target_code = Enum.at(backup_codes, 4)
    assert {:ok, :consumed, _} = Accounts.mfa_verify_backup(user, target_code, [])

    totp = Testing.generate_totp_code(secret)

    assert {:ok, %{backup_codes: _new}} =
             Accounts.mfa_regenerate_backup_codes(user, {:totp, totp}, [])

    assert {:error, :invalid_backup_code, _} =
             Accounts.mfa_verify_backup(user, target_code, [])
  end

  test "invalid TOTP does not change remaining backup code count" do
    {:ok, user} = Accounts.register_user(valid_user_attributes())
    config = Accounts.sigra_config()

    Testing.setup_totp(user,
      config: config,
      mfa_credential_schema: Example.Accounts.UserMFACredential,
      backup_code_schema: Example.Accounts.UserBackupCode
    )

    before = Accounts.mfa_status(user).backup_codes_remaining

    assert {:error, :invalid_code, _} =
             Accounts.mfa_regenerate_backup_codes(user, {:totp, "000000"}, [])

    assert Accounts.mfa_status(user).backup_codes_remaining == before
  end
end
