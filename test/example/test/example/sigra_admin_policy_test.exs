defmodule Example.SigraAdminPolicyTest do
  use Example.DataCase, async: false

  import Example.AccountsFixtures

  alias Example.SigraAdminPolicy

  test "demo admin is platform admin" do
    user = user_fixture(%{email: "admin@demo.tasklane.test"})

    assert SigraAdminPolicy.platform_admin?(%{user: user})
    assert SigraAdminPolicy.admin_org_ids(%{user: user}) == []
  end

  test "Morgan demo persona is an organization admin for her memberships" do
    user = user_fixture(%{email: "morgan@demo.tasklane.test"})
    organization = create_organization(%{name: "Acme Corp", slug: "acme-corp"})
    create_membership(user, organization, :admin)

    refute SigraAdminPolicy.platform_admin?(%{user: user})
    assert SigraAdminPolicy.admin_org_ids(%{user: user}) == [organization.id]
  end
end
