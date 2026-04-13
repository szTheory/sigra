defmodule Sigra.LiveView.OrganizationScopeTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.LiveView.OrganizationScope

  # Reuse the plug test's inline schemas via module aliasing is messy; define
  # minimal ones here so this file is fully self-contained (AAA-style).
  defmodule TestOrg do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organizations" do
      field :name, :string
      field :slug, :string
      field :deleted_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end
  end

  defmodule TestMembership do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organization_memberships" do
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
      field :organization_id, :binary_id
      field :user_id, :binary_id
      timestamps(type: :utc_datetime)
    end
  end

  defmodule TestInvitation do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organization_invitations" do
      field :email, :string
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
      field :organization_id, :binary_id
      timestamps(type: :utc_datetime)
    end
  end

  defmodule TestUser do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "users" do
      field :email, :string
    end
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership]

    def put_active_organization(%__MODULE__{} = scope, org, membership) do
      %{scope | active_organization: org, membership: membership}
    end
  end

  defmodule TestOrganizations do
    @config %{
      repo: Sigra.MockRepo,
      schemas: %{
        organization: Sigra.LiveView.OrganizationScopeTest.TestOrg,
        membership: Sigra.LiveView.OrganizationScopeTest.TestMembership,
        invitation: Sigra.LiveView.OrganizationScopeTest.TestInvitation,
        user: Sigra.LiveView.OrganizationScopeTest.TestUser,
        scope: Sigra.LiveView.OrganizationScopeTest.TestScope
      },
      roles: [:owner, :admin, :member],
      owner_role: :owner,
      reserved_slugs: [],
      additional_reserved_slugs: [],
      slug_format: ~r/^[a-z][a-z0-9-]*[a-z0-9]$/,
      slug_length: {3, 63},
      enforce_org_scope: [],
      audit_schema: nil,
      hooks: []
    }

    def __sigra_org_config__, do: @config
  end

  setup :verify_on_exit!

  defp build_user, do: %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}

  defp build_org(attrs \\ %{}) do
    Map.merge(
      %TestOrg{id: Ecto.UUID.generate(), name: "Acme", slug: "acme", deleted_at: nil},
      attrs
    )
  end

  defp build_membership(attrs \\ %{}),
    do: Map.merge(%TestMembership{id: Ecto.UUID.generate(), role: :member}, attrs)

  # A fake LiveView socket — we only need the .assigns map the on_mount touches.
  defp fake_socket(assigns), do: %{assigns: assigns}

  defp default_opts,
    do: [organizations: TestOrganizations, scope_module: TestScope]

  describe "on_mount/4" do
    @tag :phase16
    test "rebinds current_scope when slug + membership resolve" do
      user = build_user()
      org = build_org()
      membership = build_membership(%{organization_id: org.id, user_id: user.id})
      scope = %TestScope{user: user}

      Sigra.MockRepo
      |> expect(:one, fn _q -> org end)
      |> expect(:one, fn _q -> membership end)

      socket = fake_socket(%{current_scope: scope})

      assert {:cont, new_socket} =
               OrganizationScope.on_mount(default_opts(), %{"org" => "acme"}, %{}, socket)

      new_scope = new_socket.assigns[:current_scope]
      assert new_scope.active_organization.id == org.id
      assert new_scope.membership.id == membership.id
    end

    @tag :phase16
    test "unauthenticated socket (scope.user == nil) halts with redirect flag" do
      scope = %TestScope{user: nil}
      socket = fake_socket(%{current_scope: scope})

      assert {:halt, halted} =
               OrganizationScope.on_mount(default_opts(), %{"org" => "acme"}, %{}, socket)

      assert halted.assigns[:sigra_redirect_to] == "/users/log_in"
    end

    @tag :phase16
    test "nil scope halts with redirect flag" do
      socket = fake_socket(%{current_scope: nil})

      assert {:halt, halted} =
               OrganizationScope.on_mount(default_opts(), %{"org" => "acme"}, %{}, socket)

      assert halted.assigns[:sigra_redirect_to]
    end

    @tag :phase16
    test "missing :org param halts with sigra_not_found flag" do
      user = build_user()
      scope = %TestScope{user: user}
      socket = fake_socket(%{current_scope: scope})

      assert {:halt, halted} =
               OrganizationScope.on_mount(default_opts(), %{}, %{}, socket)

      assert halted.assigns[:sigra_not_found] == true
    end

    @tag :phase16
    test "unknown slug halts with sigra_not_found flag (D-04 enumeration prevention)" do
      user = build_user()
      scope = %TestScope{user: user}

      Sigra.MockRepo
      |> expect(:one, fn _q -> nil end)

      socket = fake_socket(%{current_scope: scope})

      assert {:halt, halted} =
               OrganizationScope.on_mount(default_opts(), %{"org" => "nope"}, %{}, socket)

      assert halted.assigns[:sigra_not_found] == true
    end

    @tag :phase16
    test "known slug but not-a-member halts with sigra_not_found flag (same as unknown)" do
      user = build_user()
      org = build_org()
      scope = %TestScope{user: user}

      Sigra.MockRepo
      |> expect(:one, fn _q -> org end)
      |> expect(:one, fn _q -> nil end)

      socket = fake_socket(%{current_scope: scope})

      assert {:halt, halted} =
               OrganizationScope.on_mount(default_opts(), %{"org" => "acme"}, %{}, socket)

      assert halted.assigns[:sigra_not_found] == true
    end
  end
end
