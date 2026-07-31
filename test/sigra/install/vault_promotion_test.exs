defmodule Sigra.Install.VaultPromotionTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag :install
  @moduletag timeout: 600_000
  @moduletag :scaffold

  test "mix sigra.install --passkeys emits the real vault and encrypted binary templates" do
    {:ok, %{app_dir: app_dir}} =
      InstallFixture.setup_tmp_app_without_install(app_name: "install_passkeys_vault")

    {:ok, _} = InstallFixture.run_sigra_install(app_dir, ["--passkeys"])

    assert File.read!(Path.join([app_dir, "lib", "install_passkeys_vault", "vault.ex"])) =~
             "use Cloak.Vault"

    assert File.read!(
             Path.join([app_dir, "lib", "install_passkeys_vault", "accounts", "encrypted.ex"])
           ) =~ "use Cloak.Ecto.Binary"

    assert File.read!(Path.join([app_dir, "lib", "install_passkeys_vault", "application.ex"])) =~
             "{InstallPasskeysVault.Vault, []}"

    {:ok, _} = InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])
  end
end
