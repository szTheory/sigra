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
  The helper is opt-in and never runs automatically. As of Phase 92 / B2B-02
  (Plan 92-01), the helper requires an explicit `:roles` keyword — the
  library no longer ships a default admin-role list. Hosts that previously
  relied on the implicit role default must now pass it explicitly so the
  privilege contract stays visible at the call site.
  """

  @callback platform_admin?(scope :: term()) :: boolean()
  @callback admin_org_ids(scope :: term()) :: [term()]

  @doc """
  Extracts admin organization ids from a membership list.

  This helper is intentionally explicit. Host policy modules choose whether
  to call it and which membership roles count as org-admin access.

  ## Options

    * `:roles` — **required** as of Phase 92 / B2B-02. A list of role
      atoms whose memberships should be treated as conferring org-admin
      access. The library no longer ships an implicit role-list
      fallback; callers must spell out the roles they consider
      administrative so the privilege contract is visible at the call
      site.

  Raises `KeyError` if `:roles` is missing. Raises `ArgumentError` if
  `:roles` is not a list of atoms. The strict shape is intentional —
  silent acceptance of malformed roles would re-introduce the
  opinionated default this Phase 92 change deliberately removes.

  ## Example

      memberships = MyApp.Repo.all(MyApp.Memberships)
      Sigra.Admin.Policy.admin_org_ids_from_memberships(
        memberships,
        roles: [:tenant_lead, :site_admin]
      )
  """
  @spec admin_org_ids_from_memberships([map()], keyword()) :: [term()]
  def admin_org_ids_from_memberships(memberships, opts)
      when is_list(memberships) and is_list(opts) do
    roles = fetch_roles!(opts)

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

  defp fetch_roles!(opts) do
    case Keyword.fetch(opts, :roles) do
      {:ok, roles} when is_list(roles) ->
        unless Enum.all?(roles, &is_atom/1) do
          raise ArgumentError,
                "Sigra.Admin.Policy.admin_org_ids_from_memberships/2 :roles must be a " <>
                  "list of atoms, got: #{inspect(roles)}"
        end

        roles

      {:ok, other} ->
        raise ArgumentError,
              "Sigra.Admin.Policy.admin_org_ids_from_memberships/2 :roles must be a " <>
                "list of atoms, got: #{inspect(other)}"

      :error ->
        raise KeyError,
          key: :roles,
          term: opts,
          message:
            "Sigra.Admin.Policy.admin_org_ids_from_memberships/2 requires an explicit " <>
              ":roles option (Phase 92 / B2B-02 removed the implicit role default). " <>
              "Pass `roles: [...]` naming the host's admin-equivalent role atoms."
    end
  end
end
