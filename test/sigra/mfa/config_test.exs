defmodule Sigra.MFA.ConfigTest do
  use ExUnit.Case, async: true

  alias Sigra.Config

  @valid_opts [repo: SomeRepo, user_schema: SomeUser]

  describe "new!/1 with mfa options" do
    test "validates default mfa config with all 10 keys" do
      config = Config.new!(@valid_opts)

      assert config.mfa[:enabled] == true
      assert config.mfa[:totp_issuer] == nil
      assert config.mfa[:totp_drift_steps] == 1
      assert config.mfa[:backup_code_count] == 8
      assert config.mfa[:trust_enabled] == true
      assert config.mfa[:trust_ttl] == 2_592_000
      assert config.mfa[:lockout_threshold] == 5
      assert config.mfa[:lockout_duration] == 900
      assert config.mfa[:pending_timeout] == 300
      assert config.mfa[:show_trust_option] == true
    end

    test "accepts custom mfa config" do
      config =
        Config.new!(
          @valid_opts ++
            [
              mfa: [
                enabled: false,
                totp_issuer: "MyApp",
                totp_drift_steps: 2,
                backup_code_count: 10,
                trust_enabled: false,
                trust_ttl: 86_400,
                lockout_threshold: 3,
                lockout_duration: 600,
                pending_timeout: 120,
                show_trust_option: false
              ]
            ]
        )

      assert config.mfa[:enabled] == false
      assert config.mfa[:totp_issuer] == "MyApp"
      assert config.mfa[:totp_drift_steps] == 2
      assert config.mfa[:backup_code_count] == 10
      assert config.mfa[:trust_enabled] == false
      assert config.mfa[:trust_ttl] == 86_400
      assert config.mfa[:lockout_threshold] == 3
      assert config.mfa[:lockout_duration] == 600
      assert config.mfa[:pending_timeout] == 120
      assert config.mfa[:show_trust_option] == false
    end

    test "raises on invalid mfa option type" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(@valid_opts ++ [mfa: [lockout_threshold: -1]])
      end
    end

    test "raises on unknown mfa key" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(@valid_opts ++ [mfa: [unknown_key: true]])
      end
    end
  end
end
