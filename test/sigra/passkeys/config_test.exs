defmodule Sigra.Passkeys.ConfigTest do
  use ExUnit.Case, async: false

  alias Sigra.Passkeys

  defmodule TestUser do
    defstruct [:id]
  end

  setup do
    original_sigra_otp_app = Application.get_env(:sigra, :otp_app)
    original_runtime_config = Application.get_env(:sigra_test_app, :sigra_config)

    Passkeys.reset_cached_config()
    Application.put_env(:sigra, :otp_app, :sigra_test_app)

    on_exit(fn ->
      Passkeys.reset_cached_config()

      if is_nil(original_sigra_otp_app) do
        Application.delete_env(:sigra, :otp_app)
      else
        Application.put_env(:sigra, :otp_app, original_sigra_otp_app)
      end

      if is_nil(original_runtime_config) do
        Application.delete_env(:sigra_test_app, :sigra_config)
      else
        Application.put_env(:sigra_test_app, :sigra_config, original_runtime_config)
      end
    end)

    :ok
  end

  test "config/0 caches validated runtime passkey config until reset" do
    Application.put_env(:sigra_test_app, :sigra_config, runtime_config())

    config = Passkeys.config()

    assert config.passkeys[:rp_id] == "sigra.test"
    assert config.passkeys[:rp_name] == "Sigra"
    assert config.passkeys[:origin] == "https://sigra.test"
    assert config.passkeys[:attestation] == :none
    assert config.passkeys[:user_verification] == :preferred
    assert config.passkeys[:timeout_ms] == 60_000
    assert config.passkeys[:ceremony_rate_limit] == [limit: 5, window_ms: 60_000]
    assert config.passkeys[:passkey_primary_enabled] == false

    Application.put_env(
      :sigra_test_app,
      :sigra_config,
      runtime_config(passkeys: [rp_id: "changed.test"])
    )

    assert Passkeys.config().passkeys[:rp_id] == "sigra.test"

    Passkeys.reset_cached_config()

    assert Passkeys.config().passkeys[:rp_id] == "changed.test"
  end

  test "config/0 preserves passkey primary flag" do
    Application.put_env(
      :sigra_test_app,
      :sigra_config,
      runtime_config(passkeys: [passkey_primary_enabled: true])
    )

    assert Passkeys.config().passkeys[:passkey_primary_enabled] == true
  end

  test "config/0 rejects non-boolean passkey primary flag" do
    Application.put_env(
      :sigra_test_app,
      :sigra_config,
      runtime_config(passkeys: [passkey_primary_enabled: "true"])
    )

    assert_raise NimbleOptions.ValidationError, ~r/passkey_primary_enabled.*boolean/, fn ->
      Passkeys.config()
    end
  end

  test "config/0 raises when rp_id is missing" do
    Application.put_env(:sigra_test_app, :sigra_config, runtime_config(passkeys: [rp_id: nil]))

    assert_raise ArgumentError, ~r/passkeys\[:rp_id\].*required/, fn ->
      Passkeys.config()
    end
  end

  test "config/0 raises when origin is missing" do
    Application.put_env(:sigra_test_app, :sigra_config, runtime_config(passkeys: [origin: nil]))

    assert_raise ArgumentError, ~r/passkeys\[:origin\].*required/, fn ->
      Passkeys.config()
    end
  end

  defp runtime_config(overrides \\ []) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: TestUser,
      passkeys: [
        rp_id: "sigra.test",
        origin: "https://sigra.test"
      ]
    ]

    passkeys_overrides = Keyword.get(overrides, :passkeys, [])

    base
    |> Keyword.merge(Keyword.delete(overrides, :passkeys))
    |> Keyword.update!(:passkeys, &Keyword.merge(&1, passkeys_overrides))
  end
end
