defmodule Sigra.Admin.Policy do
  @moduledoc """
  Behaviour for host-owned admin access decisions.

  Host apps must answer two questions explicitly:

  * does this scope have platform-wide admin access?
  * which organization ids may this scope administer?

  Sigra does not infer either answer from signup order, email domain,
  or any other hidden default.

  Hosts that derive org-admin access from organization memberships can call
  `admin_org_ids_from_memberships/2` explicitly from their policy module.
  The helper is opt-in and never runs automatically.
  """

  @callback platform_admin?(scope :: term()) :: boolean()
  @callback admin_org_ids(scope :: term()) :: [term()]

  @default_admin_roles [:owner, :admin]

  @doc """
  Extracts admin organization ids from a membership list.

  This helper is intentionally explicit. Host policy modules choose whether
  to call it and which membership roles count as org-admin access.
  """
  @spec admin_org_ids_from_memberships([map()], keyword()) :: [term()]
  def admin_org_ids_from_memberships(memberships, opts \\ [])
      when is_list(memberships) and is_list(opts) do
    roles = Keyword.get(opts, :roles, @default_admin_roles)

    memberships
    |> Enum.reduce([], fn membership, ids ->
      case membership do
        %{organization_id: organization_id, role: role} ->
          if not is_nil(organization_id) and role in roles do
            [organization_id | ids]
          else
            ids
          end

        _ ->
          ids
      end
    end)
    |> Enum.uniq()
    |> Enum.reverse()
  end
end
