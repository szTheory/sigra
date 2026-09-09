defmodule Sigra.Install.VaultPromotionTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag :install
  @moduletag timeout: 600_000
  @moduletag :scaffold

  test "mix sigra.install --passkeys emits the real vault and encrypted binary templates" do
    checkout = InstallFixture.checkout!(:passkeys_standard, "vault-promotion")
    app_dir = checkout.path
    otp_app = otp_app(app_dir)

    assert File.read!(Path.join([app_dir, "lib", otp_app, "vault.ex"])) =~
             "use Cloak.Vault"

    assert File.read!(Path.join([app_dir, "lib", otp_app, "accounts", "encrypted.ex"])) =~
             "use Cloak.Ecto.Binary"

    otp_module = Macro.camelize(otp_app)

    assert File.read!(Path.join([app_dir, "lib", otp_app, "application.ex"])) =~
             "{#{otp_module}.Vault, []}"

    {:ok, _} = InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])
  end

  defp otp_app(app_dir) do
    [_, app] = Regex.run(~r/app:\s+:(\w+)/, File.read!(Path.join(app_dir, "mix.exs")))
    app
  end
end
