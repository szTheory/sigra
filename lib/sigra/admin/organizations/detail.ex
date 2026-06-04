defmodule Sigra.Admin.Organizations.Detail do
  @moduledoc """
  Org-scoped data layer for the admin organization overview surface.

  Provides the member roster and the set of pending invitations for a single
  organization. Both surfaces are inherently per-org: there is no global-scope
  behavior. Every query authorizes the admin scope against the requested
  organization and filters by `organization_id`, so an org-admin can never see
  another organization's members or invitations (fails closed).

  Host schemas are resolved by namespace inference (`optional_schema/2`),
  mirroring `Sigra.Admin.Users.Detail`. When a membership or invitation schema
  is absent (legacy installs), the corresponding function returns `[]` rather
  than raising.
  """

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope

  @type member_row :: %{
          user: struct(),
          role: atom() | String.t() | nil,
          confirmed?: boolean(),
          locked?: boolean(),
          deletion_scheduled?: boolean(),
          display_name: String.t() | nil
        }

  @type invitation_row :: %{
          email: String.t() | nil,
          role: atom() | String.t() | nil,
          expires_at: DateTime.t() | nil,
          expired?: boolean()
        }

  @doc """
  Returns the member roster for the admin scope's organization.

  Each row is a map with the full user struct, the membership role, derived
  `confirmed?`/`locked?` status flags, and a display label. Returns `[]` when no
  membership schema can be resolved. Rows are ordered owners -> admins ->
  members, then by downcased display name (falling back to email).

  Fails closed: authorizes the org scope and filters by `organization_id`.
  """
  @spec member_roster(map(), Scope.t()) :: [member_row()]
  def member_roster(config, %Scope{} = admin_scope) do
    helpers = helpers(config)

    case helpers.membership_schema do
      nil ->
        []

      membership_schema ->
        org_id = admin_scope.organization_id
        Authorizer.authorize_organization!(admin_scope, org_id)

        membership_schema
        |> from(as: :membership)
        |> where([membership: m], m.organization_id == ^org_id)
        |> join(:inner, [membership: m], u in ^helpers.user_schema, as: :user, on: u.id == m.user_id)
        |> select([membership: m, user: u], %{user: u, role: m.role})
        |> config.repo.all()
        |> Enum.map(&shape_member_row/1)
        |> Enum.sort_by(&member_sort_key/1)
    end
  end

  @doc """
  Returns only the pending invitations for the admin scope's organization.

  Pending means `accepted_at IS NULL AND revoked_at IS NULL`. Each row carries
  an `expired?` flag computed in Elixir against the current time (`expires_at <
  now`) to avoid DB-time skew. Returns `[]` when no invitation schema can be
  resolved.

  Fails closed: authorizes the org scope and filters by `organization_id`.
  """
  @spec pending_invitations(map(), Scope.t()) :: [invitation_row()]
  def pending_invitations(config, %Scope{} = admin_scope) do
    invitation_schema = optional_schema(accounts_module(config), :OrganizationInvitation)

    case invitation_schema do
      nil ->
        []

      invitation_schema ->
        org_id = admin_scope.organization_id
        Authorizer.authorize_organization!(admin_scope, org_id)
        now = DateTime.utc_now()

        invitation_schema
        |> from(as: :invitation)
        |> where([invitation: i], i.organization_id == ^org_id)
        |> where([invitation: i], is_nil(i.accepted_at) and is_nil(i.revoked_at))
        |> order_by([invitation: i], asc: i.expires_at, asc: i.email)
        |> config.repo.all()
        |> Enum.map(&shape_invitation_row(&1, now))
    end
  end

  defp shape_member_row(%{user: user, role: role}) do
    display_name = Map.get(user, :display_name) || Map.get(user, :email)

    %{
      user: user,
      role: role,
      confirmed?: not is_nil(Map.get(user, :confirmed_at)),
      locked?: not is_nil(Map.get(user, :locked_at)),
      deletion_scheduled?: not is_nil(Map.get(user, :deleted_at)),
      display_name: display_name
    }
  end

  defp shape_invitation_row(invitation, now) do
    expires_at = Map.get(invitation, :expires_at)

    expired? =
      not is_nil(expires_at) and DateTime.compare(expires_at, now) == :lt

    %{
      email: Map.get(invitation, :email),
      role: Map.get(invitation, :role),
      expires_at: expires_at,
      expired?: expired?
    }
  end

  defp member_sort_key(row) do
    label = (row.display_name || "") |> to_string() |> String.downcase()
    {role_rank(row.role), label}
  end

  defp role_rank(role) do
    case to_string(role) do
      "owner" -> 0
      "admin" -> 1
      "member" -> 2
      _ -> 3
    end
  end

  defp helpers(config) do
    accounts_module = accounts_module(config)

    %{
      user_schema: Map.fetch!(config, :user_schema),
      membership_schema:
        Map.get(config, :membership_schema) ||
          optional_schema(accounts_module, :OrganizationMembership)
    }
  end

  defp accounts_module(%{accounts_module: module}) when is_atom(module), do: module
  defp accounts_module(%{accounts: module}) when is_atom(module), do: module

  defp accounts_module(%{user_schema: module}) when is_atom(module) do
    module |> Module.split() |> Enum.drop(-1) |> Module.safe_concat()
  rescue
    ArgumentError -> nil
  end

  defp accounts_module(_config), do: nil

  defp optional_schema(nil, _name), do: nil

  defp optional_schema(module, name) do
    schema = Module.concat(module, name)
    if Code.ensure_loaded?(schema), do: schema, else: nil
  end
end
