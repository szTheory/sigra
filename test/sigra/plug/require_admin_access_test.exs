defmodule Sigra.Plug.RequireAdminAccessTest do
  use ExUnit.Case, async: true

  alias Sigra.Admin.Policy
  alias Sigra.Admin.Scope

  defmodule TestUser do
    defstruct [:id]
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defmodule TestOrg do
    defstruct [:id, :slug, :name]
  end

  defmodule PlatformAdminPolicy do
    @behaviour Policy

    @impl true
    def platform_admin?(_scope), do: true

    @impl true
    def admin_org_ids(_scope), do: []
  end

  defmodule OrgAdminPolicy do
    @behaviour Policy

    @impl true
    def platform_admin?(_scope), do: false

    @impl true
    def admin_org_ids(_scope), do: ["org-1"]
  end

  defp build_scope(user \\ %TestUser{id: "user-1"}) do
    %TestScope{user: user, active_organization: nil, membership: nil, impersonating_from: nil}
  end

  describe "resolved admin scope contract" do
    test "platform admin can resolve the global route intentionally" do
      assert {:ok, %Scope{mode: :global, platform_admin?: true}} =
               Scope.resolve(build_scope(), nil, PlatformAdminPolicy)
    end

    test "global denial rejects org-only admins from the /admin route" do
      assert {:error, :forbidden} =
               Scope.resolve(build_scope(), nil, OrgAdminPolicy)
    end

    test "organization scope allows an in-scope org admin route" do
      org = %TestOrg{id: "org-1", slug: "acme", name: "Acme"}

      assert {:ok, %Scope{mode: :organization, organization_id: "org-1"}} =
               Scope.resolve(build_scope(), org, OrgAdminPolicy)
    end

    test "out-of-scope denial hides disallowed org routes behind not_found" do
      org = %TestOrg{id: "org-2", slug: "other", name: "Other"}

      assert {:error, :not_found} =
               Scope.resolve(build_scope(), org, OrgAdminPolicy)
    end

    test "unknown org slug fails closed when only a slug is available" do
      assert {:error, :not_found} =
               Scope.resolve(build_scope(), "missing-org", PlatformAdminPolicy)
    end
  end

  describe "policy helper" do
    test "collects admin org ids only for configured membership roles" do
      memberships = [
        %{organization_id: "org-1", role: :owner},
        %{organization_id: "org-2", role: :admin},
        %{organization_id: "org-3", role: :member}
      ]

      assert Policy.admin_org_ids_from_memberships(memberships) == ["org-1", "org-2"]
    end
  end
end
