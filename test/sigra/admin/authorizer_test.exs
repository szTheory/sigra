defmodule Sigra.Admin.AuthorizerTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Authorizer.UnauthorizedError
  alias Sigra.Admin.Scope

  defmodule TestScope do
    defstruct [:user]
  end

  defmodule TestOrg do
    defstruct [:id, :slug, :name]
  end

  defmodule TestRecord do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "test_records" do
      field :organization_id, :binary_id
      field :name, :string
    end
  end

  defp global_admin_scope do
    %Scope{
      mode: :global,
      scope: %TestScope{user: %{id: "user-1"}},
      organization: nil,
      organization_id: nil,
      organization_slug: nil,
      platform_admin?: true,
      admin_org_ids: []
    }
  end

  defp org_admin_scope do
    org = %TestOrg{id: "org-1", slug: "acme", name: "Acme"}

    %Scope{
      mode: :organization,
      scope: %TestScope{user: %{id: "user-2"}},
      organization: org,
      organization_id: org.id,
      organization_slug: org.slug,
      platform_admin?: false,
      admin_org_ids: [org.id]
    }
  end

  describe "authorize_global!/1" do
    test "global admin may run global admin operations" do
      assert :ok = Authorizer.authorize_global!(global_admin_scope())
    end

    test "org admin is denied for global admin operations" do
      assert_raise UnauthorizedError, ~r/global admin access is required/, fn ->
        Authorizer.authorize_global!(org_admin_scope())
      end
    end
  end

  describe "authorize_organization!/2" do
    test "global admin may intentionally access an organization-bound operation" do
      assert :ok = Authorizer.authorize_organization!(global_admin_scope(), "org-9")
    end

    test "org admin may access the current organization operation" do
      assert :ok = Authorizer.authorize_organization!(org_admin_scope(), "org-1")
    end

    test "org admin is denied for out-of-scope organization operations" do
      assert_raise UnauthorizedError, ~r/does not allow access/, fn ->
        Authorizer.authorize_organization!(org_admin_scope(), "org-2")
      end
    end

    test "org-bound operations fail closed on unknown org context" do
      assert_raise UnauthorizedError, ~r/organization context is required/, fn ->
        Authorizer.authorize_organization!(global_admin_scope(), nil)
      end
    end
  end

  describe "scope_query/2" do
    test "scope_query returns a global admin query unchanged" do
      query = from(record in TestRecord, where: record.name == "hello")
      scoped = Authorizer.scope_query(query, global_admin_scope())

      assert scoped.from == query.from
      assert scoped.wheres == query.wheres
    end

    test "scope_query uses Sigra.Organizations.Query.for_org for org admin" do
      scoped = Authorizer.scope_query(TestRecord, org_admin_scope())

      assert [%Ecto.Query.BooleanExpr{}] = scoped.wheres
      assert Enum.any?(scoped.wheres, &inspect(&1.expr) =~ "organization_id")
    end

    test "scope_query fails closed for org admin without a resolved organization" do
      broken_scope = %Scope{org_admin_scope() | organization_id: nil}

      assert_raise UnauthorizedError, ~r/require a resolved organization/, fn ->
        Authorizer.scope_query(TestRecord, broken_scope)
      end
    end
  end

  describe "authorize_impersonation_target!/2" do
    test "global admin may impersonate any target user" do
      target = %{id: "user-9", organization_ids: ["org-1", "org-2"]}

      assert :ok = Authorizer.authorize_impersonation_target!(global_admin_scope(), target)
    end

    test "org admin may impersonate a user reachable in the resolved organization scope" do
      target = %{id: "user-9", organization_ids: ["org-1", "org-2"]}

      assert :ok = Authorizer.authorize_impersonation_target!(org_admin_scope(), target)
    end

    test "org admin is denied for a target user outside the resolved organization scope" do
      target = %{id: "user-9", organization_ids: ["org-2"]}

      assert_raise UnauthorizedError, ~r/impersonate the requested user/, fn ->
        Authorizer.authorize_impersonation_target!(org_admin_scope(), target)
      end
    end

    test "org admin is denied when target exposes no organization association at all" do
      target = %{id: "user-9"}

      assert_raise UnauthorizedError, ~r/impersonate the requested user/, fn ->
        Authorizer.authorize_impersonation_target!(org_admin_scope(), target)
      end
    end

    test "org admin is denied when memberships list does not include the resolved org" do
      target = %{
        id: "user-9",
        memberships: [%{organization_id: "org-2"}, %{organization_id: "org-7"}]
      }

      assert_raise UnauthorizedError, ~r/impersonate the requested user/, fn ->
        Authorizer.authorize_impersonation_target!(org_admin_scope(), target)
      end
    end

    test "org admin may impersonate when memberships list includes the resolved org" do
      target = %{
        id: "user-9",
        memberships: [%{organization_id: "org-1"}, %{organization_id: "org-9"}]
      }

      assert :ok = Authorizer.authorize_impersonation_target!(org_admin_scope(), target)
    end
  end

  describe "negative-case boundary enforcement (Phase 31 direct-path truth per D-07/D-13)" do
    test "authorize_organization!/2 denies even when an org admin targets an org by id map with a different id" do
      other_org = %TestOrg{id: "org-9", slug: "widgets", name: "Widgets"}

      assert_raise UnauthorizedError, ~r/does not allow access/, fn ->
        Authorizer.authorize_organization!(org_admin_scope(), other_org)
      end
    end

    test "authorize_organization!/2 fails closed when organization map has no id" do
      orphan_org = %{slug: "orphan", name: "Orphan"}

      assert_raise UnauthorizedError, ~r/organization context is required/, fn ->
        Authorizer.authorize_organization!(org_admin_scope(), orphan_org)
      end
    end

    test "scope_query/2 never widens when admin_org_ids include stale values but organization_id is nil" do
      stale_scope = %Scope{org_admin_scope() | organization_id: nil, admin_org_ids: ["org-1"]}

      assert_raise UnauthorizedError, ~r/require a resolved organization/, fn ->
        Authorizer.scope_query(TestRecord, stale_scope)
      end
    end

    test "scope_query/2 preserves the caller-supplied where clauses when scoping for org admin" do
      query = from(record in TestRecord, where: record.name == "sentinel")
      scoped = Authorizer.scope_query(query, org_admin_scope())

      # The original where clause survives alongside the organization narrowing.
      assert length(scoped.wheres) >= 2

      assert Enum.any?(scoped.wheres, fn expr -> inspect(expr.expr) =~ "sentinel" end)
      assert Enum.any?(scoped.wheres, fn expr -> inspect(expr.expr) =~ "organization_id" end)
    end
  end
end
