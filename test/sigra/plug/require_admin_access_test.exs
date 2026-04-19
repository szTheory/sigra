defmodule Sigra.Plug.RequireAdminAccessTest do
  use ExUnit.Case, async: true
  import Mox
  import Plug.Test

  alias Sigra.Admin.Policy
  alias Sigra.Admin.Scope
  alias Sigra.Plug.RequireAdminAccess

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
        organization: Sigra.Plug.RequireAdminAccessTest.TestOrg,
        membership: Sigra.Plug.RequireAdminAccessTest.TestMembership,
        invitation: Sigra.Plug.RequireAdminAccessTest.TestInvitation,
        user: Sigra.Plug.RequireAdminAccessTest.TestUser,
        scope: Sigra.Plug.RequireAdminAccessTest.TestScope
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

  defmodule FakeErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, opts) do
      Process.put(:admin_error_calls, Process.get(:admin_error_calls, []) ++ [{type, opts}])

      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(403, to_string(type))
    end
  end

  defp build_scope(user \\ %TestUser{id: "user-1"}) do
    %TestScope{user: user, active_organization: nil, membership: nil, impersonating_from: nil}
  end

  defp build_org(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Map.merge(
      %TestOrg{
        id: Ecto.UUID.generate(),
        name: "Acme",
        slug: "acme",
        deleted_at: nil,
        inserted_at: now,
        updated_at: now
      },
      attrs
    )
  end

  defp build_conn(path, scope, params \\ %{}) do
    conn(:get, path)
    |> Map.put(:params, params)
    |> Plug.Conn.assign(:current_scope, scope)
  end

  defp org_opts(overrides \\ []) do
    RequireAdminAccess.init(
      Keyword.merge(
        [
          error_handler: FakeErrorHandler,
          policy: OrgAdminPolicy,
          organizations: TestOrganizations,
          mode: :organization
        ],
        overrides
      )
    )
  end

  defp global_opts(overrides \\ []) do
    RequireAdminAccess.init(
      Keyword.merge(
        [
          error_handler: FakeErrorHandler,
          policy: PlatformAdminPolicy,
          mode: :global
        ],
        overrides
      )
    )
  end

  setup :verify_on_exit!

  setup do
    Process.delete(:admin_error_calls)
    :ok
  end

  describe "init/1" do
    test "requires organizations for organization mode" do
      assert_raise KeyError, fn ->
        RequireAdminAccess.init(
          error_handler: FakeErrorHandler,
          policy: OrgAdminPolicy,
          mode: :organization
        )
      end
    end
  end

  describe "call/2" do
    test "platform admin can resolve the global route intentionally" do
      conn = build_conn("/admin", build_scope())

      result = RequireAdminAccess.call(conn, global_opts())

      assert %Scope{mode: :global, platform_admin?: true} = result.assigns[:admin_scope]
      refute result.halted
    end

    test "global denial rejects org-only admins from the /admin route" do
      conn = build_conn("/admin", build_scope())
      result = RequireAdminAccess.call(conn, global_opts(policy: OrgAdminPolicy))

      assert result.halted
      assert [{:insufficient_scope, _opts}] = Process.get(:admin_error_calls)
    end

    test "organization scope allows an in-scope org admin route" do
      user = %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}
      org = build_org(%{id: "org-1"})

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)

      conn = build_conn("/admin/organizations/acme", build_scope(user), %{"org" => "acme"})
      result = RequireAdminAccess.call(conn, org_opts())

      assert %Scope{mode: :organization, organization_id: "org-1"} = result.assigns[:admin_scope]
      refute result.halted
    end

    test "out-of-scope denial hides disallowed org routes behind not_found" do
      user = %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}
      org = build_org(%{id: "org-2", slug: "other"})

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)

      conn = build_conn("/admin/organizations/other", build_scope(user), %{"org" => "other"})
      result = RequireAdminAccess.call(conn, org_opts())

      assert result.halted
      assert [{:not_found, _opts}] = Process.get(:admin_error_calls)
    end

    test "unknown organization route returns not_found before any page render" do
      user = %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}

      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      conn = build_conn("/admin/organizations/missing", build_scope(user), %{"org" => "missing"})
      result = RequireAdminAccess.call(conn, org_opts())

      assert result.halted
      assert [{:not_found, _opts}] = Process.get(:admin_error_calls)
    end

    test "unauthenticated requests halt through the error handler" do
      conn = build_conn("/admin", nil)
      result = RequireAdminAccess.call(conn, global_opts())

      assert result.halted
      assert [{:unauthenticated, _opts}] = Process.get(:admin_error_calls)
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
