defmodule Sigra.Organizations.SchemaTest do
  @moduledoc """
  Unit tests validating that the organization schema templates produce
  correct changesets. Defines inline test modules mirroring the generated
  output with `MyApp.Accounts` as the context module.
  """
  use ExUnit.Case, async: true

  # ── Inline test modules mirroring generated schema output ──────────

  defmodule MyApp.Accounts.Organization do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "organizations" do
      field :name, :string
      field :slug, :string
      field :deleted_at, :utc_datetime
      field :enforce_mfa_for_members, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    def changeset(organization, attrs) do
      organization
      |> cast(attrs, [:name, :slug, :deleted_at])
      |> validate_required([:name, :slug])
      |> validate_length(:name, min: 1, max: 255)
      |> validate_length(:slug, min: 3, max: 63)
      |> validate_format(:slug, ~r/^[a-z][a-z0-9-]*[a-z0-9]$/,
        message: "must be lowercase alphanumeric with hyphens"
      )
      |> unique_constraint(:slug)
    end
  end

  defmodule MyApp.Accounts.OrganizationMembership do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "organization_memberships" do
      field :role, Ecto.Enum, values: [:owner, :admin, :member]

      timestamps(type: :utc_datetime)
    end

    def changeset(membership, attrs) do
      membership
      |> cast(attrs, [:role])
      |> validate_required([:role])
      |> unique_constraint([:user_id, :organization_id])
    end
  end

  defmodule MyApp.Accounts.OrganizationInvitation do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "organization_invitations" do
      field :email, :string
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
      field :hashed_token, :binary
      field :accepted_at, :utc_datetime
      field :revoked_at, :utc_datetime
      field :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    def changeset(invitation, attrs) do
      invitation
      |> cast(attrs, [:email, :role, :expires_at, :hashed_token, :accepted_at, :revoked_at])
      |> validate_required([:email, :role, :expires_at])
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────

  alias MyApp.Accounts.Organization
  alias MyApp.Accounts.OrganizationMembership
  alias MyApp.Accounts.OrganizationInvitation

  defp valid_org_attrs(overrides \\ %{}) do
    Map.merge(%{name: "Acme Corp", slug: "acme-corp"}, overrides)
  end

  defp valid_membership_attrs(overrides \\ %{}) do
    Map.merge(%{role: :member}, overrides)
  end

  defp valid_invitation_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        email: "user@example.com",
        role: :admin,
        expires_at: ~U[2026-12-31 23:59:59Z]
      },
      overrides
    )
  end

  # ── Organization changeset tests ──────────────────────────────────

  describe "Organization changeset" do
    test "valid attrs produce a valid changeset" do
      changeset = Organization.changeset(%Organization{}, valid_org_attrs())
      assert changeset.valid?
    end

    test "missing name returns error on :name" do
      changeset = Organization.changeset(%Organization{}, valid_org_attrs(%{name: nil}))
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "missing slug returns error on :slug" do
      changeset = Organization.changeset(%Organization{}, valid_org_attrs(%{slug: nil}))
      refute changeset.valid?
      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "name over 255 chars returns error" do
      long_name = String.duplicate("a", 256)
      changeset = Organization.changeset(%Organization{}, valid_org_attrs(%{name: long_name}))
      refute changeset.valid?
      assert %{name: [msg]} = errors_on(changeset)
      assert msg =~ "should be at most 255"
    end

    test "deleted_at field accepts nil and a datetime value" do
      # nil (default)
      changeset = Organization.changeset(%Organization{}, valid_org_attrs())
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :deleted_at) == nil

      # datetime value
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      changeset = Organization.changeset(%Organization{}, valid_org_attrs(%{deleted_at: now}))
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :deleted_at) == now
    end

    test "enforce_mfa_for_members defaults false and is not user-castable" do
      changeset =
        Organization.changeset(%Organization{}, Map.put(valid_org_attrs(), :enforce_mfa_for_members, true))

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :enforce_mfa_for_members) == nil
      assert Ecto.Changeset.get_field(changeset, :enforce_mfa_for_members) == false
    end
  end

  # ── OrganizationMembership changeset tests ────────────────────────

  describe "OrganizationMembership changeset" do
    test "valid attrs with role: :member produces valid changeset" do
      changeset =
        OrganizationMembership.changeset(%OrganizationMembership{}, valid_membership_attrs())

      assert changeset.valid?
    end

    test "invalid role value returns error on :role" do
      changeset =
        OrganizationMembership.changeset(
          %OrganizationMembership{},
          valid_membership_attrs(%{role: :superadmin})
        )

      refute changeset.valid?
      assert %{role: [_msg]} = errors_on(changeset)
    end

    test "missing role returns error" do
      changeset =
        OrganizationMembership.changeset(
          %OrganizationMembership{},
          valid_membership_attrs(%{role: nil})
        )

      refute changeset.valid?
      assert %{role: ["can't be blank"]} = errors_on(changeset)
    end

    test "Ecto.Enum values are exactly [:owner, :admin, :member]" do
      # Verify all three roles are accepted via changeset
      for role <- [:owner, :admin, :member] do
        changeset =
          OrganizationMembership.changeset(
            %OrganizationMembership{},
            valid_membership_attrs(%{role: role})
          )

        assert changeset.valid?, "expected role #{inspect(role)} to be valid"
      end

      # Verify invalid role is rejected
      changeset =
        OrganizationMembership.changeset(
          %OrganizationMembership{},
          valid_membership_attrs(%{role: :viewer})
        )

      refute changeset.valid?
    end
  end

  # ── OrganizationInvitation changeset tests ────────────────────────

  describe "OrganizationInvitation changeset" do
    test "valid attrs produces valid changeset" do
      changeset =
        OrganizationInvitation.changeset(%OrganizationInvitation{}, valid_invitation_attrs())

      assert changeset.valid?
    end

    test "missing email returns error" do
      changeset =
        OrganizationInvitation.changeset(
          %OrganizationInvitation{},
          valid_invitation_attrs(%{email: nil})
        )

      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "missing expires_at returns error" do
      changeset =
        OrganizationInvitation.changeset(
          %OrganizationInvitation{},
          valid_invitation_attrs(%{expires_at: nil})
        )

      refute changeset.valid?
      assert %{expires_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts optional hashed_token, accepted_at, revoked_at" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        OrganizationInvitation.changeset(
          %OrganizationInvitation{},
          valid_invitation_attrs(%{
            hashed_token: <<1, 2, 3>>,
            accepted_at: now,
            revoked_at: now
          })
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :hashed_token) == <<1, 2, 3>>
      assert Ecto.Changeset.get_change(changeset, :accepted_at) == now
      assert Ecto.Changeset.get_change(changeset, :revoked_at) == now
    end
  end

  # ── Test helper ───────────────────────────────────────────────────

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
