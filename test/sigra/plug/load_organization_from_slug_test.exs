defmodule Sigra.Plug.LoadOrganizationFromSlugTest do
  use ExUnit.Case, async: true

  import Mox
  import Plug.Test

  alias Sigra.Plug.LoadOrganizationFromSlug

  # Inline test schemas — match existing Phase 14 plug-test pattern.
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

  defmodule TestSlugAlias do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organization_slug_aliases" do
      field :organization_id, :binary_id
      field :old_slug, :string
      field :expires_at, :utc_datetime
      timestamps(type: :utc_datetime, updated_at: false)
    end
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership]

    def put_active_organization(scope, org, membership) do
      %__MODULE__{scope | active_organization: org, membership: membership}
    end
  end

  defmodule TestOrganizations do
    @config %{
      repo: Sigra.MockRepo,
      schemas: %{
        organization: Sigra.Plug.LoadOrganizationFromSlugTest.TestOrg,
        membership: Sigra.Plug.LoadOrganizationFromSlugTest.TestMembership,
        invitation: Sigra.Plug.LoadOrganizationFromSlugTest.TestInvitation,
        user: Sigra.Plug.LoadOrganizationFromSlugTest.TestUser,
        scope: Sigra.Plug.LoadOrganizationFromSlugTest.TestScope,
        organization_slug_alias: Sigra.Plug.LoadOrganizationFromSlugTest.TestSlugAlias
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

  defmodule TestErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, :not_found, _opts) do
      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(404, "Not Found")
    end

    def auth_error(conn, _, _opts), do: Plug.Conn.send_resp(conn, 500, "")
  end

  defmodule FakeSessionStore do
    def update_active_organization(session, _org_id, _opts), do: {:ok, session}
  end

  setup :verify_on_exit!

  defp build_user, do: %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}

  defp build_org(attrs \\ %{}) do
    Map.merge(
      %TestOrg{
        id: Ecto.UUID.generate(),
        name: "Acme",
        slug: "acme",
        deleted_at: nil
      },
      attrs
    )
  end

  defp build_membership(attrs \\ %{}) do
    Map.merge(
      %TestMembership{id: Ecto.UUID.generate(), role: :member},
      attrs
    )
  end

  defp default_opts do
    [
      error_handler: TestErrorHandler,
      organizations: TestOrganizations,
      session_store: FakeSessionStore,
      scope_module: TestScope
    ]
  end

  defp build_conn(slug, scope) do
    conn(:get, "/#{slug}/dashboard", %{"org" => slug})
    |> Plug.Conn.assign(:current_scope, scope)
    |> Map.put(:params, %{"org" => slug})
  end

  describe "init/1" do
    @tag :phase16
    test "requires :error_handler, :organizations, :session_store, :scope_module" do
      assert_raise KeyError, fn ->
        LoadOrganizationFromSlug.init([])
      end
    end

    @tag :phase16
    test "defaults :scope_param to \"org\"" do
      opts = LoadOrganizationFromSlug.init(default_opts())
      assert Keyword.get(opts, :scope_param) == "org"
    end
  end

  describe "call/2" do
    @tag :phase16
    test "unknown slug returns 404 via error_handler" do
      user = build_user()
      scope = %TestScope{user: user}

      Sigra.MockRepo
      # get_organization_by_slug → nil
      |> expect(:one, fn _q -> nil end)
      # get_active_slug_alias → nil
      |> expect(:one, fn _q -> nil end)

      opts = LoadOrganizationFromSlug.init(default_opts())
      conn = build_conn("unknown-slug", scope)
      result = LoadOrganizationFromSlug.call(conn, opts)

      assert result.halted
      assert result.status == 404
    end

    @tag :phase16
    test "known slug but user is NOT a member returns 404 (enumeration prevention, D-04)" do
      user = build_user()
      scope = %TestScope{user: user}
      org = build_org()

      Sigra.MockRepo
      # get_organization_by_slug → org
      |> expect(:one, fn _q -> org end)
      # get_membership → nil
      |> expect(:one, fn _q -> nil end)
      # resolve_alias fallback: get_active_slug_alias → nil
      |> expect(:one, fn _q -> nil end)

      opts = LoadOrganizationFromSlug.init(default_opts())
      conn = build_conn("acme", scope)
      result = LoadOrganizationFromSlug.call(conn, opts)

      assert result.halted
      assert result.status == 404
    end

    @tag :phase16
    test "slug matches session pointer + user is member assigns scope without refresh" do
      user = build_user()
      org = build_org()
      membership = build_membership(%{organization_id: org.id, user_id: user.id})
      scope = %TestScope{user: user, active_organization: org, membership: membership}

      Sigra.MockRepo
      |> expect(:one, fn _q -> org end)
      |> expect(:one, fn _q -> membership end)

      opts = LoadOrganizationFromSlug.init(default_opts())
      conn = build_conn("acme", scope)
      result = LoadOrganizationFromSlug.call(conn, opts)

      refute result.halted
      assert result.assigns.current_scope.active_organization.id == org.id
      assert result.assigns.current_scope.membership.id == membership.id
    end

    @tag :phase16
    test "slug matches expired alias row → treated as not found" do
      user = build_user()
      scope = %TestScope{user: user}

      Sigra.MockRepo
      # get_organization_by_slug → nil (no live org)
      |> expect(:one, fn _q -> nil end)
      # get_active_slug_alias → nil (query filters expired rows via `expires_at > now`)
      |> expect(:one, fn _q -> nil end)

      opts = LoadOrganizationFromSlug.init(default_opts())
      conn = build_conn("old-slug", scope)
      result = LoadOrganizationFromSlug.call(conn, opts)

      assert result.halted
      assert result.status == 404
    end

    @tag :phase16
    test "slug matches non-expired alias → 301 redirect to canonical slug" do
      user = build_user()
      scope = %TestScope{user: user}

      org = build_org(%{id: Ecto.UUID.generate(), slug: "new-slug"})

      alias_row = %TestSlugAlias{
        id: Ecto.UUID.generate(),
        organization_id: org.id,
        old_slug: "old-slug",
        expires_at: DateTime.add(DateTime.utc_now(), 7, :day)
      }

      Sigra.MockRepo
      # get_organization_by_slug("old-slug") → nil
      |> expect(:one, fn _q -> nil end)
      # get_active_slug_alias → the alias row
      |> expect(:one, fn _q -> alias_row end)
      # fetch_organization(alias_row.organization_id) → {:ok, org}
      |> expect(:one, fn _q -> org end)

      opts = LoadOrganizationFromSlug.init(default_opts())
      conn = build_conn("old-slug", scope)
      result = LoadOrganizationFromSlug.call(conn, opts)

      assert result.halted
      assert result.status == 301

      location =
        result.resp_headers
        |> Enum.find(fn {k, _v} -> k == "location" end)
        |> elem(1)

      assert location =~ "new-slug"
      refute location =~ "old-slug"
    end

    @tag :phase16
    test "unauthenticated socket (nil user) returns 404 (no user enumeration)" do
      scope = %TestScope{user: nil}

      opts = LoadOrganizationFromSlug.init(default_opts())
      conn = build_conn("acme", scope)
      result = LoadOrganizationFromSlug.call(conn, opts)

      assert result.halted
      assert result.status == 404
    end

    @tag :phase16
    test "missing slug param returns 404" do
      user = build_user()
      scope = %TestScope{user: user}

      opts = LoadOrganizationFromSlug.init(default_opts())

      conn =
        conn(:get, "/dashboard", %{})
        |> Plug.Conn.assign(:current_scope, scope)
        |> Map.put(:params, %{})

      result = LoadOrganizationFromSlug.call(conn, opts)

      assert result.halted
      assert result.status == 404
    end
  end
end
