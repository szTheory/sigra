defmodule Sigra.Organizations.QueryTest do
  use ExUnit.Case, async: true

  alias Sigra.Organizations.Query

  # Inline test schemas — no DB required
  defmodule OrgScoped do
    use Ecto.Schema

    schema "posts" do
      field :organization_id, :binary_id
      field :title, :string
    end
  end

  defmodule NotOrgScoped do
    use Ecto.Schema

    schema "tags" do
      field :name, :string
    end
  end

  describe "for_org/2" do
    test "scopes query with scope map containing active_organization" do
      org_id = Ecto.UUID.generate()
      scope = %{active_organization: %{id: org_id}}

      query = Query.for_org(OrgScoped, scope)

      assert %Ecto.Query{} = query
      assert inspect(query) =~ "organization_id"
    end

    test "scopes query with binary org_id" do
      org_id = Ecto.UUID.generate()

      query = Query.for_org(OrgScoped, org_id)

      assert %Ecto.Query{} = query
      assert inspect(query) =~ "organization_id"
    end

    test "raises on schema without organization_id field" do
      org_id = Ecto.UUID.generate()

      assert_raise ArgumentError, ~r/does not have an :organization_id field/, fn ->
        Query.for_org(NotOrgScoped, org_id)
      end
    end

    test "raises when active_organization is nil" do
      scope = %{active_organization: nil}

      assert_raise ArgumentError, ~r/active organization/, fn ->
        Query.for_org(OrgScoped, scope)
      end
    end

    test "raises on non-schema-based query" do
      org_id = Ecto.UUID.generate()

      assert_raise ArgumentError, ~r/requires a schema-based query/, fn ->
        Query.for_org("raw_table", org_id)
      end
    end
  end

  describe "maybe_enforce_org_scope/4" do
    setup do
      config = %{enforced_schemas: [OrgScoped]}
      {:ok, config: config}
    end

    test "skips with skip_org_check: true", %{config: config} do
      query = Ecto.Queryable.to_query(OrgScoped)
      opts = [skip_org_check: true]

      assert {^query, ^opts} = Query.maybe_enforce_org_scope(:all, query, opts, config)
    end

    test "skips preloads", %{config: config} do
      query = Ecto.Queryable.to_query(OrgScoped)
      opts = [ecto_query: :preload]

      assert {^query, ^opts} = Query.maybe_enforce_org_scope(:all, query, opts, config)
    end

    test "skips schema_migration", %{config: config} do
      query = Ecto.Queryable.to_query(OrgScoped)
      opts = [ecto_query: :schema_migration]

      assert {^query, ^opts} = Query.maybe_enforce_org_scope(:all, query, opts, config)
    end

    test "passes non-enforced schemas through", %{config: _config} do
      config = %{enforced_schemas: []}
      query = Ecto.Queryable.to_query(OrgScoped)
      opts = []

      assert {^query, ^opts} = Query.maybe_enforce_org_scope(:all, query, opts, config)
    end

    test "passes through for non-query operations (insert)", %{config: config} do
      query = Ecto.Queryable.to_query(OrgScoped)
      opts = []

      assert {^query, ^opts} = Query.maybe_enforce_org_scope(:insert, query, opts, config)
    end

    test "raises on enforced schema without org filter", %{config: config} do
      query = Ecto.Queryable.to_query(OrgScoped)
      opts = []

      assert_raise ArgumentError, ~r/organization_id/, fn ->
        Query.maybe_enforce_org_scope(:all, query, opts, config)
      end
    end

    test "passes through when query already has org_id filter", %{config: config} do
      import Ecto.Query
      org_id = Ecto.UUID.generate()

      query =
        OrgScoped
        |> where([r], r.organization_id == ^org_id)

      opts = []

      assert {_query, ^opts} = Query.maybe_enforce_org_scope(:all, query, opts, config)
    end
  end
end
