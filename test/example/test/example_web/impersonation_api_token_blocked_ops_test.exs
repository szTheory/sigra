defmodule ExampleWeb.ImpersonationAPITokenBlockedOpsTest do
  use Example.DataCase, async: true

  alias Example.Accounts
  alias Example.AccountsFixtures

  describe "API token mutations while impersonating" do
    setup do
      admin = AccountsFixtures.user_fixture(%{email: "platform-admin-api-token@example.com"})
      user = AccountsFixtures.user_fixture()
      scope = %{user: user, impersonating_from: admin}

      %{admin: admin, user: user, scope: scope}
    end

    test "rejects API token creation with an explicit impersonation reason", %{
      user: user,
      scope: scope
    } do
      assert {:error, :impersonation_forbidden, message} =
               Accounts.create_api_token(user, %{name: "CLI", scopes: ["read"]}, scope: scope)

      assert message =~ "impersonat"
    end

    test "rejects revoke-one and revoke-all through the same guarded seam", %{
      user: user,
      scope: scope
    } do
      {:ok, _raw, token} = Accounts.create_api_token(user, %{name: "CLI", scopes: ["read"]})

      assert {:error, :impersonation_forbidden, message} =
               Accounts.revoke_api_token(user, token.id, scope: scope)

      assert message =~ "impersonat"

      assert {:error, :impersonation_forbidden, message} =
               Accounts.revoke_all_api_tokens(user, scope: scope)

      assert message =~ "impersonat"
    end
  end
end
