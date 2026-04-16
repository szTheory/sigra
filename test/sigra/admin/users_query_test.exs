defmodule Sigra.Admin.UsersQueryTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL
  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Query

  @repo Sigra.Test.PostgresRepo
  @now ~U[2026-04-16 12:00:00Z]

  defmodule Accounts do
    def admin_user_hooks, do: Sigra.Admin.UsersQueryTest.Hooks
  end

  defmodule Hooks do
    @behaviour Sigra.Admin.Users.Hooks

    @impl true
    def display_name_field, do: :display_name

    @impl true
    def display_name(user), do: user.display_name || user.email

    @impl true
    def extra_search_fields, do: [:support_name]

    @impl true
    def extra_list_badges(_user), do: []

    @impl true
    def extra_list_columns, do: []

    @impl true
    def extra_detail_sections(_user), do: []

    @impl true
    def copy_overrides, do: %{}
  end

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_query_users" do
      field :email, :string
      field :display_name, :string
      field :support_name, :string
      field :confirmed_at, :utc_datetime
      field :locked_at, :utc_datetime
      field :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end

  defmodule Organization do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_query_organizations" do
      field :name, :string
      field :slug, :string

      timestamps(type: :utc_datetime)
    end
  end

  defmodule OrganizationMembership do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_query_organization_memberships" do
      field :role, :string
      belongs_to :organization, Organization, type: :binary_id
      belongs_to :user, User, type: :binary_id

      timestamps(type: :utc_datetime)
    end
  end

  defmodule UserSession do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_query_user_sessions" do
      field :last_active_at, :utc_datetime
      belongs_to :user, User, type: :binary_id

      timestamps(type: :utc_datetime)
    end
  end

  defmodule UserMFACredential do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_query_user_mfa_credentials" do
      field :enabled_at, :utc_datetime
      belongs_to :user, User, type: :binary_id

      timestamps(type: :utc_datetime)
    end
  end

  defmodule UserPasskey do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_query_user_passkeys" do
      field :credential_id, :binary
      belongs_to :user, User, type: :binary_id

      timestamps(type: :utc_datetime)
    end
  end

  defmodule UserIdentity do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_query_user_identities" do
      field :provider, :string
      belongs_to :user, User, type: :binary_id

      timestamps(type: :utc_datetime)
    end
  end

  setup_all do
    start_supervised!({@repo, @repo.default_config()})

    ddl = [
      """
      CREATE TABLE IF NOT EXISTS admin_query_users (
        id uuid PRIMARY KEY,
        email text NOT NULL,
        display_name text,
        support_name text,
        confirmed_at timestamp,
        locked_at timestamp,
        deleted_at timestamp,
        inserted_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS admin_query_organizations (
        id uuid PRIMARY KEY,
        name text NOT NULL,
        slug text NOT NULL,
        inserted_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS admin_query_organization_memberships (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        organization_id uuid NOT NULL,
        role text NOT NULL,
        inserted_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS admin_query_user_sessions (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        last_active_at timestamp,
        inserted_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS admin_query_user_mfa_credentials (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        enabled_at timestamp,
        inserted_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS admin_query_user_passkeys (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        credential_id bytea NOT NULL,
        inserted_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS admin_query_user_identities (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        provider text NOT NULL,
        inserted_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
      )
      """
    ]

    Enum.each(ddl, &SQL.query!(@repo, &1, []))
    :ok
  end

  setup do
    Enum.each(
      [
        "admin_query_user_identities",
        "admin_query_user_passkeys",
        "admin_query_user_mfa_credentials",
        "admin_query_user_sessions",
        "admin_query_organization_memberships",
        "admin_query_organizations",
        "admin_query_users"
      ],
      &SQL.query!(@repo, "TRUNCATE TABLE #{&1} RESTART IDENTITY CASCADE", [])
    )

    org1 = insert_org("Acme Support", "acme")
    org2 = insert_org("Beta Industries", "beta")

    alice =
      insert_user(%{
        email: "alice@example.com",
        display_name: "Alice Example",
        support_name: "Ace",
        confirmed_at: ~U[2026-01-05 10:00:00Z],
        inserted_at: ~U[2026-01-01 00:00:00Z]
      })

    bob =
      insert_user(%{
        email: "bob@example.com",
        display_name: "Bobby Tables",
        support_name: "Support Bob",
        locked_at: ~U[2026-02-01 12:00:00Z],
        inserted_at: ~U[2026-02-01 00:00:00Z]
      })

    carol =
      insert_user(%{
        email: "carol@example.com",
        display_name: "Carol Admin",
        support_name: "Carry",
        confirmed_at: ~U[2026-03-05 09:00:00Z],
        deleted_at: ~U[2026-04-01 08:00:00Z],
        inserted_at: ~U[2026-03-01 00:00:00Z]
      })

    insert_membership(alice, org1)
    insert_membership(bob, org2)
    insert_membership(carol, org1)
    insert_membership(carol, org2)

    insert_session(alice, ~U[2026-04-15 00:00:00Z])
    insert_session(carol, ~U[2026-04-14 00:00:00Z])
    insert_mfa(alice)
    insert_passkey(alice)
    insert_identity(alice, "google")
    insert_identity(bob, "github")

    config = %{
      repo: @repo,
      user_schema: User,
      accounts_module: Accounts,
      membership_schema: OrganizationMembership,
      organization_schema: Organization,
      session: [session_schema: UserSession],
      mfa: [mfa_credential_schema: UserMFACredential],
      passkeys: [user_passkey_schema: UserPasskey],
      oauth: [user_identity_schema: UserIdentity]
    }

    org_scope =
      %Scope{
        mode: :organization,
        scope: %{user: %{id: Ecto.UUID.generate()}},
        organization: %{id: org1.id, slug: org1.slug, name: org1.name},
        organization_id: org1.id,
        organization_slug: org1.slug,
        platform_admin?: false,
        admin_org_ids: [org1.id]
      }

    global_scope =
      %Scope{
        mode: :global,
        scope: %{user: %{id: Ecto.UUID.generate()}},
        organization: nil,
        organization_id: nil,
        organization_slug: nil,
        platform_admin?: true,
        admin_org_ids: [org1.id, org2.id]
      }

    {:ok,
     %{
       config: config,
       org1: org1,
       org2: org2,
       alice: alice,
       bob: bob,
       carol: carol,
       global_scope: global_scope,
       org_scope: org_scope
     }}
  end

  describe "Phase 28 query contracts" do
    test "search supports email, id, display name, and organization membership lookups", ctx do
      assert {:ok, {[row], _meta, _params}} =
               Query.list_users(ctx.config, ctx.global_scope, %{"q" => "alice@example.com"})

      assert row.user.id == ctx.alice.id

      assert {:ok, {[row], _meta, _params}} =
               Query.list_users(ctx.config, ctx.global_scope, %{"q" => ctx.bob.id})

      assert row.user.id == ctx.bob.id

      assert {:ok, {[row], _meta, _params}} =
               Query.list_users(ctx.config, ctx.global_scope, %{"q" => "Carry"})

      assert row.user.id == ctx.carol.id

      assert {:ok, {rows, _meta, _params}} =
               Query.list_users(ctx.config, ctx.global_scope, %{"organization" => "Acme"})

      assert Enum.map(rows, & &1.user.id) |> Enum.sort() ==
               Enum.sort([ctx.alice.id, ctx.carol.id])
    end

    test "filters include confirmed, mfa, passkeys, locked, deleted, provider, registered_from, and registered_to",
         ctx do
      assert_ids(ctx, %{"confirmed" => "true"}, [ctx.alice.id, ctx.carol.id])
      assert_ids(ctx, %{"confirmed" => "false"}, [ctx.bob.id])
      assert_ids(ctx, %{"mfa" => "true"}, [ctx.alice.id])
      assert_ids(ctx, %{"passkeys" => "true"}, [ctx.alice.id])
      assert_ids(ctx, %{"locked" => "true"}, [ctx.bob.id])
      assert_ids(ctx, %{"deleted" => "true"}, [ctx.carol.id])
      assert_ids(ctx, %{"provider" => "google"}, [ctx.alice.id])
      assert_ids(ctx, %{"provider" => "local"}, [ctx.carol.id])
      assert_ids(ctx, %{"registered_from" => "2026-02-01"}, [ctx.bob.id, ctx.carol.id])
      assert_ids(ctx, %{"registered_to" => "2026-01-15"}, [ctx.alice.id])

      local_only_config = Map.delete(ctx.config, :oauth)

      assert {:ok, {rows, _meta, _params}} =
               Query.list_users(local_only_config, ctx.global_scope, %{"provider" => "local"})

      assert Enum.map(rows, & &1.user.id) |> Enum.sort() ==
               Enum.sort([ctx.alice.id, ctx.bob.id, ctx.carol.id])

      assert {:ok, {[], _meta, _params}} =
               Query.list_users(local_only_config, ctx.global_scope, %{"provider" => "github"})
    end

    test "URL-addressable filtering and pagination remain scope-safe for global and organization admins",
         ctx do
      assert {:ok, normalized} = Query.normalize_params(%{})
      assert is_map(normalized)

      assert {:ok, {_rows, meta, _params}} =
               Query.list_users(ctx.config, ctx.global_scope, %{})

      assert meta.current_page == 1

      assert {:ok, normalized} =
               Query.normalize_params(%{
                 "page" => "2",
                 "page_size" => "1",
                 "order_by" => "inserted_at",
                 "order_direction" => "asc",
                 "confirmed" => "true"
               })

      assert normalized["page"] == "2"
      assert normalized["page_size"] == "1"
      assert normalized["order_by"] == "inserted_at"
      assert normalized["order_direction"] == "asc"

      assert {:ok, {rows, meta, _params}} =
               Query.list_users(ctx.config, ctx.org_scope, %{
                 "page_size" => "10",
                 "organization" => "beta"
               })

      assert meta.total_count == 0
      assert rows == []

      assert {:ok, {rows, meta, _params}} =
               Query.list_users(ctx.config, ctx.org_scope, %{
                 "page_size" => "1",
                 "order_by" => "inserted_at",
                 "order_direction" => "asc"
               })

      assert meta.total_count == 2
      assert length(rows) == 1
      assert Enum.all?(rows, &(&1.user.id in [ctx.alice.id, ctx.carol.id]))

      counts = Query.summary_counts(ctx.config, ctx.org_scope)
      assert counts.total == 2
      assert counts.confirmed == 2
      assert counts.deleted == 1
    end
  end

  defp assert_ids(ctx, params, expected_ids) do
    assert {:ok, {rows, _meta, _params}} = Query.list_users(ctx.config, ctx.global_scope, params)
    assert Enum.map(rows, & &1.user.id) |> Enum.sort() == Enum.sort(expected_ids)
  end

  defp insert_user(attrs) do
    id = Ecto.UUID.generate()

    struct!(User, %{
      id: id,
      email: attrs.email,
      display_name: Map.get(attrs, :display_name),
      support_name: Map.get(attrs, :support_name),
      confirmed_at: Map.get(attrs, :confirmed_at),
      locked_at: Map.get(attrs, :locked_at),
      deleted_at: Map.get(attrs, :deleted_at),
      inserted_at: attrs.inserted_at,
      updated_at: attrs.inserted_at
    })
    |> @repo.insert!()
  end

  defp insert_org(name, slug) do
    struct!(Organization, %{
      id: Ecto.UUID.generate(),
      name: name,
      slug: slug,
      inserted_at: @now,
      updated_at: @now
    })
    |> @repo.insert!()
  end

  defp insert_membership(user, org) do
    struct!(OrganizationMembership, %{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      organization_id: org.id,
      role: "member",
      inserted_at: @now,
      updated_at: @now
    })
    |> @repo.insert!()
  end

  defp insert_session(user, last_active_at) do
    struct!(UserSession, %{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      last_active_at: last_active_at,
      inserted_at: @now,
      updated_at: @now
    })
    |> @repo.insert!()
  end

  defp insert_mfa(user) do
    struct!(UserMFACredential, %{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      enabled_at: @now,
      inserted_at: @now,
      updated_at: @now
    })
    |> @repo.insert!()
  end

  defp insert_passkey(user) do
    struct!(UserPasskey, %{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      credential_id: "passkey-" <> user.id,
      inserted_at: @now,
      updated_at: @now
    })
    |> @repo.insert!()
  end

  defp insert_identity(user, provider) do
    struct!(UserIdentity, %{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      provider: provider,
      inserted_at: @now,
      updated_at: @now
    })
    |> @repo.insert!()
  end
end
