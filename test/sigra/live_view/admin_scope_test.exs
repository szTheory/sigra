defmodule Sigra.LiveView.AdminScopeTest do
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

  defmodule NoAdminPolicy do
    @behaviour Policy

    @impl true
    def platform_admin?(_scope), do: false

    @impl true
    def admin_org_ids(_scope), do: []
  end

  defp build_scope(user \\ %TestUser{id: "user-1"}) do
    %TestScope{user: user, active_organization: nil, membership: nil, impersonating_from: nil}
  end

  describe "admin scope resolution scenarios for LiveView parity" do
    test "platform admin may resolve global admin access" do
      assert {:ok, %Scope{mode: :global, platform_admin?: true}} =
               Scope.resolve(build_scope(), nil, PlatformAdminPolicy)
    end

    test "global denial blocks org-only admins from the live_session root route" do
      assert {:error, :forbidden} =
               Scope.resolve(build_scope(), nil, OrgAdminPolicy)
    end

    test "platform admin may intentionally enter an organization route" do
      org = %TestOrg{id: "org-1", slug: "acme", name: "Acme"}

      assert {:ok, %Scope{mode: :organization, organization_slug: "acme"}} =
               Scope.resolve(build_scope(), org, PlatformAdminPolicy)
    end

    test "out-of-scope denial for live_session routes returns not_found" do
      org = %TestOrg{id: "org-2", slug: "other", name: "Other"}

      assert {:error, :not_found} =
               Scope.resolve(build_scope(), org, OrgAdminPolicy)
    end

    test "missing admin rights fail closed" do
      org = %TestOrg{id: "org-1", slug: "acme", name: "Acme"}

      assert {:error, :forbidden} =
               Scope.resolve(build_scope(), nil, NoAdminPolicy)

      assert {:error, :not_found} =
               Scope.resolve(build_scope(), org, NoAdminPolicy)
    end
  end
end
