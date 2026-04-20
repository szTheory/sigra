defmodule Sigra.Admin.Scope do
  @moduledoc """
  Request-local resolved admin scope derived from the host's current scope.

  `/admin` and `/admin/organizations/:org` are distinct authorization paths.
  This module resolves that route-owned intent into an explicit struct that
  downstream plugs, LiveViews, queries, and mutations can share.
  """

  @enforce_keys [:mode, :scope, :platform_admin?, :admin_org_ids]
  defstruct [
    :mode,
    :scope,
    :organization,
    :organization_id,
    :organization_slug,
    :platform_admin?,
    :admin_org_ids
  ]

  @type mode :: :global | :organization

  @type t :: %__MODULE__{
          mode: mode(),
          scope: term(),
          organization: map() | nil,
          organization_id: term() | nil,
          organization_slug: String.t() | nil,
          platform_admin?: boolean(),
          admin_org_ids: [term()]
        }

  @type error_reason :: :unauthenticated | :forbidden | :not_found

  @spec resolve(term(), nil | binary() | map(), module()) :: {:ok, t()} | {:error, error_reason()}
  def resolve(scope, requested_org, policy_module)
      when is_atom(policy_module) do
    cond do
      is_nil(scope) or is_nil(Map.get(scope, :user)) ->
        {:error, :unauthenticated}

      is_nil(requested_org) ->
        resolve_global(scope, policy_module)

      is_binary(requested_org) ->
        {:error, :not_found}

      is_map(requested_org) ->
        resolve_organization(scope, requested_org, policy_module)

      true ->
        {:error, :not_found}
    end
  end

  @spec global?(t()) :: boolean()
  def global?(%__MODULE__{mode: :global}), do: true
  def global?(%__MODULE__{}), do: false

  @spec organization?(t()) :: boolean()
  def organization?(%__MODULE__{mode: :organization}), do: true
  def organization?(%__MODULE__{}), do: false

  defp resolve_global(scope, policy_module) do
    if platform_admin?(policy_module, scope) do
      {:ok,
       %__MODULE__{
         mode: :global,
         scope: scope,
         organization: nil,
         organization_id: nil,
         organization_slug: nil,
         platform_admin?: true,
         admin_org_ids: admin_org_ids(policy_module, scope)
       }}
    else
      {:error, :forbidden}
    end
  end

  defp resolve_organization(scope, organization, policy_module) do
    allowed_ids = admin_org_ids(policy_module, scope)
    organization_id = Map.get(organization, :id)

    cond do
      is_nil(organization_id) ->
        {:error, :not_found}

      platform_admin?(policy_module, scope) ->
        {:ok, build_organization_scope(scope, organization, true, allowed_ids)}

      organization_id in allowed_ids ->
        {:ok, build_organization_scope(scope, organization, false, allowed_ids)}

      true ->
        {:error, :not_found}
    end
  end

  defp build_organization_scope(scope, organization, platform_admin?, allowed_ids) do
    %__MODULE__{
      mode: :organization,
      scope: scope,
      organization: organization,
      organization_id: Map.get(organization, :id),
      organization_slug: Map.get(organization, :slug),
      platform_admin?: platform_admin?,
      admin_org_ids: allowed_ids
    }
  end

  defp platform_admin?(policy_module, scope) do
    policy_module.platform_admin?(scope) == true
  end

  defp admin_org_ids(policy_module, scope) do
    case policy_module.admin_org_ids(scope) do
      ids when is_list(ids) -> Enum.uniq(ids)
      _ -> []
    end
  end
end
