defmodule Sigra.Admin.OrganizationsDetailTest do
  use Sigra.Test.PostgresCase, async: false

  alias Ecto.Adapters.SQL
  alias Sigra.Admin.Organizations.Detail
  alias Sigra.Admin.Scope

  @repo Sigra.Test.PostgresRepo
  @now ~U[2026-04-16 12:00:00Z]

  # Test Accounts module whose namespace resolves OrganizationInvitation via the
  # production optional_schema/2 path. Note it does NOT namespace
  # OrganizationMembership — membership_schema is passed explicitly in config.
  defmodule Accounts do
    defmodule OrganizationInvitation do
      use Ecto.Schema

      @primary_key {:id, :binary_id, autogenerate: false}
      schema "admin_org_detail_invitations" do
        field :email, :string
        field :role, :string
        field :accepted_at, :utc_datetime
        field :revoked_at, :utc_datetime
        field :expires_at, :utc_datetime
        field :organization_id, :binary_id

        timestamps(type: :utc_datetime)
      end
    end
  end

  # An accounts module with NO OrganizationInvitation child — exercises the
  # graceful-absence path (pending_invitations returns []).
  defmodule BareAccounts do
  end

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_org_detail_users" do
      field :email, :string
      field :display_name, :string
      field :confirmed_at, :utc_datetime
      field :locked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end

  defmodule Organization do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_org_detail_organizations" do
      field :name, :string
      field :slug, :string

      timestamps(type: :utc_datetime)
    end
  end

  defmodule OrganizationMembership do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_org_detail_memberships" do
      field :role, :string
      field :organization_id, :binary_id
      field :user_id, :binary_id

      timestamps(type: :utc_datetime)
    end
  end

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      ddl = [
        """
        CREATE TABLE IF NOT EXISTS admin_org_detail_users (
          id uuid PRIMARY KEY,
          email text NOT NULL,
          display_name text,
          confirmed_at timestamp,
          locked_at timestamp,
          inserted_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS admin_org_detail_organizations (
          id uuid PRIMARY KEY,
          name text NOT NULL,
          slug text NOT NULL,
          inserted_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS admin_org_detail_memberships (
          id uuid PRIMARY KEY,
          user_id uuid NOT NULL,
          organization_id uuid NOT NULL,
          role text NOT NULL,
          inserted_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS admin_org_detail_invitations (
          id uuid PRIMARY KEY,
          email text NOT NULL,
          role text NOT NULL,
          accepted_at timestamp,
          revoked_at timestamp,
          expires_at timestamp,
          organization_id uuid NOT NULL,
          inserted_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
        """
      ]

      Enum.each(ddl, &SQL.query!(repo, &1, []))
    end)

    :ok
  end

  setup do
    org1 = insert_org("Acme Support", "acme")
    org2 = insert_org("Beta Industries", "beta")

    owner =
      insert_user(%{
        email: "owner@example.com",
        display_name: "Olivia Owner",
        confirmed_at: ~U[2026-01-05 10:00:00Z]
      })

    admin =
      insert_user(%{
        email: "admin@example.com",
        display_name: "Aaron Admin",
        confirmed_at: ~U[2026-01-06 10:00:00Z]
      })

    member =
      insert_user(%{
        email: "member@example.com",
        display_name: "Mona Member",
        locked_at: ~U[2026-02-01 12:00:00Z]
      })

    other =
      insert_user(%{
        email: "other@example.com",
        display_name: "Otto Other",
        confirmed_at: ~U[2026-01-07 10:00:00Z]
      })

    insert_membership(owner, org1, "owner")
    insert_membership(admin, org1, "admin")
    insert_membership(member, org1, "member")
    # other user belongs ONLY to org2 — must never appear in org1 roster.
    insert_membership(other, org2, "member")

    # org1 invitations: pending+future, pending+expired, accepted, revoked
    pending_future =
      insert_invitation(org1, "future@example.com", "member",
        expires_at: ~U[2099-01-01 00:00:00Z]
      )

    pending_expired =
      insert_invitation(org1, "expired@example.com", "admin",
        expires_at: ~U[2020-01-01 00:00:00Z]
      )

    insert_invitation(org1, "accepted@example.com", "member", accepted_at: @now)
    insert_invitation(org1, "revoked@example.com", "member", revoked_at: @now)
    # org2 pending invitation — must never appear in org1 results.
    insert_invitation(org2, "org2pending@example.com", "member",
      expires_at: ~U[2099-01-01 00:00:00Z]
    )

    config = %{
      repo: @repo,
      user_schema: User,
      accounts_module: Accounts,
      membership_schema: OrganizationMembership
    }

    # Config whose accounts module has no OrganizationInvitation child.
    bare_config = %{config | accounts_module: BareAccounts}

    org1_scope = org_scope(org1)
    org2_scope = org_scope(org2)

    {:ok,
     %{
       config: config,
       bare_config: bare_config,
       org1: org1,
       org2: org2,
       owner: owner,
       admin: admin,
       member: member,
       other: other,
       pending_future: pending_future,
       pending_expired: pending_expired,
       org1_scope: org1_scope,
       org2_scope: org2_scope
     }}
  end

  describe "member_roster/2" do
    test "returns only the scoped org's members and excludes other orgs (fails closed)", ctx do
      rows = Detail.member_roster(ctx.config, ctx.org1_scope)

      user_ids = Enum.map(rows, & &1.user.id) |> Enum.sort()

      assert user_ids == Enum.sort([ctx.owner.id, ctx.admin.id, ctx.member.id])
      refute ctx.other.id in user_ids
    end

    test "carries confirmed?/locked? flags derived from the user row", ctx do
      rows = Detail.member_roster(ctx.config, ctx.org1_scope)
      by_id = Map.new(rows, &{&1.user.id, &1})

      assert by_id[ctx.owner.id].confirmed? == true
      assert by_id[ctx.owner.id].locked? == false
      assert by_id[ctx.member.id].confirmed? == false
      assert by_id[ctx.member.id].locked? == true
    end

    test "orders owners -> admins -> members", ctx do
      rows = Detail.member_roster(ctx.config, ctx.org1_scope)
      roles = Enum.map(rows, & &1.role)

      assert roles == ["owner", "admin", "member"]
    end

    test "exposes display_name falling back to email", ctx do
      rows = Detail.member_roster(ctx.config, ctx.org1_scope)
      by_id = Map.new(rows, &{&1.user.id, &1})

      assert by_id[ctx.owner.id].display_name == "Olivia Owner"
    end

    test "returns [] for an org with no members", ctx do
      empty_org = insert_org("Empty Org", "empty")
      assert Detail.member_roster(ctx.config, org_scope(empty_org)) == []
    end

    test "returns [] when no membership schema can be resolved", ctx do
      config =
        Map.delete(ctx.config, :membership_schema) |> Map.put(:accounts_module, BareAccounts)

      assert Detail.member_roster(config, ctx.org1_scope) == []
    end
  end

  describe "pending_invitations/2" do
    test "returns only pending rows (excludes accepted and revoked)", ctx do
      rows = Detail.pending_invitations(ctx.config, ctx.org1_scope)
      emails = Enum.map(rows, & &1.email) |> Enum.sort()

      assert emails == Enum.sort(["future@example.com", "expired@example.com"])
    end

    test "excludes other orgs' pending invitations (fails closed)", ctx do
      rows = Detail.pending_invitations(ctx.config, ctx.org1_scope)
      emails = Enum.map(rows, & &1.email)

      refute "org2pending@example.com" in emails
    end

    test "flags expired? against now: true when past, false when future", ctx do
      rows = Detail.pending_invitations(ctx.config, ctx.org1_scope)
      by_email = Map.new(rows, &{&1.email, &1})

      assert by_email["expired@example.com"].expired? == true
      assert by_email["future@example.com"].expired? == false
    end

    test "returns [] for an org with no invitations", ctx do
      empty_org = insert_org("No Invites Org", "no-invites")
      assert Detail.pending_invitations(ctx.config, org_scope(empty_org)) == []
    end

    test "returns [] when accounts module does not namespace an invitation schema", ctx do
      assert Detail.pending_invitations(ctx.bare_config, ctx.org1_scope) == []
    end
  end

  defp org_scope(org) do
    %Scope{
      mode: :organization,
      scope: %{user: %{id: Ecto.UUID.generate()}},
      organization: %{id: org.id, slug: org.slug, name: org.name},
      organization_id: org.id,
      organization_slug: org.slug,
      platform_admin?: false,
      admin_org_ids: [org.id]
    }
  end

  defp insert_user(attrs) do
    struct!(User, %{
      id: Ecto.UUID.generate(),
      email: attrs.email,
      display_name: Map.get(attrs, :display_name),
      confirmed_at: Map.get(attrs, :confirmed_at),
      locked_at: Map.get(attrs, :locked_at),
      inserted_at: @now,
      updated_at: @now
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

  defp insert_membership(user, org, role) do
    struct!(OrganizationMembership, %{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      organization_id: org.id,
      role: role,
      inserted_at: @now,
      updated_at: @now
    })
    |> @repo.insert!()
  end

  defp insert_invitation(org, email, role, opts) do
    struct!(Accounts.OrganizationInvitation, %{
      id: Ecto.UUID.generate(),
      email: email,
      role: role,
      organization_id: org.id,
      accepted_at: Keyword.get(opts, :accepted_at),
      revoked_at: Keyword.get(opts, :revoked_at),
      expires_at: Keyword.get(opts, :expires_at),
      inserted_at: @now,
      updated_at: @now
    })
    |> @repo.insert!()
  end
end
