defmodule Sigra.LiveView.AdminScopeTest do
  use ExUnit.Case, async: true
  import Mox

  alias Sigra.Admin.Policy
  alias Sigra.Admin.Scope
  alias Sigra.LiveView.AdminScope

  defmodule TestUser do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "users" do
      field :email, :string
    end
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

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

  defmodule TestOrganizations do
    @config %{
      repo: Sigra.MockRepo,
      schemas: %{
        organization: Sigra.LiveView.AdminScopeTest.TestOrg,
        membership: Sigra.LiveView.AdminScopeTest.TestMembership,
        invitation: Sigra.LiveView.AdminScopeTest.TestInvitation,
        user: Sigra.LiveView.AdminScopeTest.TestUser,
        scope: Sigra.LiveView.AdminScopeTest.TestScope
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

  defp build_org(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Map.merge(
      %TestOrg{id: Ecto.UUID.generate(), name: "Acme", slug: "acme", deleted_at: nil, inserted_at: now, updated_at: now},
      attrs
    )
  end

  defp fake_socket(assigns), do: %{assigns: assigns}

  defp global_opts(overrides \\ []) do
    Keyword.merge([policy: PlatformAdminPolicy, mode: :global], overrides)
  end

  defp org_opts(overrides \\ []) do
    Keyword.merge([policy: OrgAdminPolicy, organizations: TestOrganizations, mode: :organization], overrides)
  end

  setup :verify_on_exit!

  describe "admin scope resolution scenarios for LiveView parity" do
    test "platform admin may resolve global admin access" do
      socket = fake_socket(%{current_scope: build_scope()})

      assert {:cont, cont_socket} = AdminScope.on_mount(global_opts(), %{}, %{}, socket)
      assert %Scope{mode: :global, platform_admin?: true} = cont_socket.assigns[:admin_scope]
    end

    test "global denial blocks org-only admins from the live_session root route" do
      socket = fake_socket(%{current_scope: build_scope()})

      assert {:halt, halted} =
               AdminScope.on_mount(global_opts(policy: OrgAdminPolicy), %{}, %{}, socket)

      assert halted.assigns[:sigra_admin_forbidden] == true
    end

    test "platform admin may intentionally enter an organization route" do
      user = %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}
      org = build_org(%{id: "org-1"})

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)

      socket = fake_socket(%{current_scope: build_scope(user)})

      assert {:cont, cont_socket} =
               AdminScope.on_mount(org_opts(policy: PlatformAdminPolicy), %{"org" => "acme"}, %{}, socket)

      assert %Scope{mode: :organization, organization_slug: "acme"} = cont_socket.assigns[:admin_scope]
    end

    test "out-of-scope denial for live_session routes returns not_found" do
      user = %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}
      org = build_org(%{id: "org-2", slug: "other"})

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)

      socket = fake_socket(%{current_scope: build_scope(user)})

      assert {:halt, halted} =
               AdminScope.on_mount(org_opts(), %{"org" => "other"}, %{}, socket)

      assert halted.assigns[:sigra_not_found] == true
    end

    test "missing admin rights fail closed" do
      user = %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}
      org = build_org(%{id: "org-1"})

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)

      socket = fake_socket(%{current_scope: build_scope(user)})

      assert {:halt, halted_global} =
               AdminScope.on_mount(global_opts(policy: NoAdminPolicy), %{}, %{}, socket)

      assert halted_global.assigns[:sigra_admin_forbidden] == true

      assert {:halt, halted_org} =
               AdminScope.on_mount(org_opts(policy: NoAdminPolicy), %{"org" => "acme"}, %{}, socket)

      assert halted_org.assigns[:sigra_not_found] == true
    end

    test "unauthenticated live_session navigation redirects before page render" do
      socket = fake_socket(%{current_scope: nil})

      assert {:halt, halted} = AdminScope.on_mount(global_opts(), %{}, %{}, socket)
      assert halted.assigns[:sigra_redirect_to] == "/users/log_in"
    end
  end
end
