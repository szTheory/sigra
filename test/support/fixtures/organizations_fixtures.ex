defmodule Sigra.OrganizationsFixtures do
  @moduledoc """
  Phase 17 organization test fixtures.

  These helpers are parameterized on the caller's `config` (the same
  `%{repo: _, schemas: _, ...}` map passed to
  `Sigra.Organizations` context functions) so they are reusable from
  both the Sigra library test suite and downstream host-app suites.

  Paired with `Sigra.InvitationsFixtures` to give every Phase 17 test
  file a consistent setup API.
  """

  @doc """
  Builds an organization with one confirmed owner and one confirmed
  admin.

  Returns `%{org: org, owner: owner, admin: admin}`. Used by Phase 17
  invitation tests that need two authorized actors (for example, one
  test agent who invites and another who revokes).

  ## Required config keys

    * `:repo`
    * `:schemas.organization`
    * `:schemas.user`
  """
  @spec org_with_owner_and_admin(map(), keyword()) :: %{
          org: struct(),
          owner: struct(),
          admin: struct()
        }
  def org_with_owner_and_admin(config, opts \\ []) do
    owner = user_fixture(config, Keyword.get(opts, :owner_attrs, %{}))
    admin = user_fixture(config, Keyword.get(opts, :admin_attrs, %{}))
    org = organization_fixture(config, Keyword.get(opts, :org_attrs, %{}))

    scope = %{user: owner}

    {:ok, _} = Sigra.Organizations.add_member(config, scope, org, owner, :owner)
    {:ok, _} = Sigra.Organizations.add_member(config, scope, org, admin, :admin)

    %{org: org, owner: owner, admin: admin}
  end

  @doc """
  Inserts a bare user using the caller's `:schemas.user` schema and
  `:repo`. Stamps `confirmed_at` so the user is ready for any flow
  that requires a confirmed account.
  """
  @spec user_fixture(map(), map()) :: struct()
  def user_fixture(config, attrs \\ %{}) do
    user_schema = config.schemas.user
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    unique = System.unique_integer([:positive])

    defaults = %{
      email: "user-#{unique}@example.com",
      confirmed_at: now
    }

    user_schema
    |> struct!(Map.merge(defaults, attrs))
    |> config.repo.insert!()
  end

  @doc """
  Inserts a bare organization using the caller's `:schemas.organization`
  schema and `:repo`. Callers wanting the full creation pipeline should
  use `Sigra.Organizations.create_organization/3` instead.
  """
  @spec organization_fixture(map(), map()) :: struct()
  def organization_fixture(config, attrs \\ %{}) do
    org_schema = config.schemas.organization
    unique = System.unique_integer([:positive])

    defaults = %{
      name: "Acme #{unique}",
      slug: "acme-#{unique}"
    }

    org_schema
    |> struct!(Map.merge(defaults, attrs))
    |> config.repo.insert!()
  end
end
