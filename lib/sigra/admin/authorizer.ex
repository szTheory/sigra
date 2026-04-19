defmodule Sigra.Admin.Authorizer do
  @moduledoc """
  Direct-path admin authorization helpers for exports, mutations, and queries.

  These helpers operate on a resolved `Sigra.Admin.Scope` so code outside the
  router and LiveView entry points can still enforce the same global-vs-org
  contract.
  """

  alias Sigra.Admin.Scope

  defmodule UnauthorizedError do
    defexception [:message, :reason]
  end

  @spec authorize_global!(Scope.t()) :: :ok
  def authorize_global!(%Scope{} = admin_scope) do
    if Scope.global?(admin_scope) do
      :ok
    else
      raise UnauthorizedError,
        reason: :forbidden,
        message: "global admin access is required for this operation"
    end
  end

  @spec authorize_organization!(Scope.t(), map() | binary()) :: :ok
  def authorize_organization!(%Scope{} = admin_scope, organization_or_id) do
    organization_id = organization_id(organization_or_id)

    cond do
      is_nil(organization_id) ->
        raise UnauthorizedError,
          reason: :not_found,
          message: "organization context is required for this operation"

      Scope.global?(admin_scope) ->
        :ok

      Scope.organization?(admin_scope) and admin_scope.organization_id == organization_id ->
        :ok

      true ->
        raise UnauthorizedError,
          reason: :not_found,
          message: "admin scope does not allow access to the requested organization"
    end
  end

  @spec scope_query(Ecto.Queryable.t(), Scope.t()) :: Ecto.Query.t()
  def scope_query(queryable, %Scope{} = admin_scope) do
    query = Ecto.Queryable.to_query(queryable)

    cond do
      Scope.global?(admin_scope) ->
        query

      Scope.organization?(admin_scope) and is_binary(admin_scope.organization_id) ->
        Sigra.Organizations.Query.for_org(query, admin_scope.organization_id)

      true ->
        raise UnauthorizedError,
          reason: :not_found,
          message: "organization-scoped admin queries require a resolved organization"
    end
  end

  @spec authorize_impersonation_target!(Scope.t(), map() | struct()) :: :ok
  def authorize_impersonation_target!(%Scope{} = admin_scope, target_user) do
    cond do
      Scope.global?(admin_scope) ->
        :ok

      Scope.organization?(admin_scope) and
          admin_scope.organization_id in target_organization_ids(target_user) ->
        :ok

      true ->
        raise UnauthorizedError,
          reason: :not_found,
          message: "admin scope cannot impersonate the requested user"
    end
  end

  defp organization_id(%{id: organization_id}), do: organization_id
  defp organization_id(organization_id) when is_binary(organization_id), do: organization_id
  defp organization_id(_), do: nil

  defp target_organization_ids(%{organization_ids: ids}) when is_list(ids), do: ids

  defp target_organization_ids(%{memberships: memberships}) when is_list(memberships) do
    Enum.map(memberships, &Map.get(&1, :organization_id))
  end

  defp target_organization_ids(_target_user), do: []
end
