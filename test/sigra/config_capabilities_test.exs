defmodule Sigra.ConfigCapabilitiesTest do
  use ExUnit.Case, async: true

  alias Sigra.Config

  @base_opts [repo: Sigra.MockRepo, user_schema: Sigra.MockUser]

  test "auth capabilities remain enabled by default for existing adopters" do
    config = Config.new!(@base_opts)

    assert Config.mfa_enabled?(config)
    assert Config.passkeys_enabled?(config)
    assert Config.enterprise_enabled?(config)
  end

  test "auth capabilities can be disabled independently" do
    config =
      Config.new!(
        @base_opts ++
          [
            mfa: [enabled: false],
            passkeys: [enabled: false],
            enterprise: [enabled: false]
          ]
      )

    refute Config.mfa_enabled?(config)
    refute Config.passkeys_enabled?(config)
    refute Config.enterprise_enabled?(config)
  end

  test "enterprise enabled must be boolean" do
    assert_raise NimbleOptions.ValidationError, fn ->
      Config.new!(@base_opts ++ [enterprise: [enabled: "sometimes"]])
    end
  end
end
