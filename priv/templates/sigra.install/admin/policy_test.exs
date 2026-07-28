defmodule <%= app_module %>.SigraAdminPolicyTest do
  use <%= app_module %>.DataCase, async: true

  import <%= context_module %>Fixtures

  alias <%= context_module %>.{Scope, User}
  alias <%= app_module %>.{Repo, SigraAdminAccess, SigraAdminPolicy}

  test "platform access is denied until explicitly granted and denied after revoke" do
    user =
      user_fixture()
      |> User.confirm_changeset()
      |> Repo.update!()

    scope = Scope.for_user(user)

    refute SigraAdminPolicy.platform_admin?(scope)

    assert {:ok, _grant, :granted} = SigraAdminAccess.grant(user)
    assert SigraAdminPolicy.platform_admin?(scope)
    assert {:ok, _grant, :already_granted} = SigraAdminAccess.grant(user)

    assert {:ok, _grant, :revoked} = SigraAdminAccess.revoke(user)
    refute SigraAdminPolicy.platform_admin?(scope)
    assert {:ok, _grant, :already_revoked} = SigraAdminAccess.revoke(user)
  end
end
