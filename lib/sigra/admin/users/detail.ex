defmodule Sigra.Admin.Users.Detail do
  @moduledoc """
  Scope-safe loader for the admin user detail surface.
  """

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Hooks

  @audit_preview_limit 5

  @spec load!(map(), Scope.t(), binary()) :: map()
  def load!(config, %Scope{} = admin_scope, user_id) when is_binary(user_id) do
    hooks = Hooks.resolve(config)
    helpers = helpers(config)
    user = load_user!(config, admin_scope, user_id, helpers)
    display_name = safe_apply(hooks, :display_name, [user]) || Map.get(user, :display_name) || user.email
    organizations = list_organizations(config, admin_scope, user, helpers)
    {identities, identities_available?} = identities_with_flag(config, user, helpers)
    sessions = Sigra.Auth.list_sessions(config, user.id)
    passkeys = list_passkeys(config, user, helpers)
    mfa_status = load_mfa_status(config, user, helpers)
    recent_audit = recent_audit_preview(config, admin_scope, user.id)

    %{
      user: user,
      display_name: display_name,
      identities_available?: identities_available?,
      copy_overrides: safe_apply(hooks, :copy_overrides, []) || %{},
      extra_detail_sections: safe_apply(hooks, :extra_detail_sections, [user]) || [],
      scope_label: scope_label(admin_scope),
      identity: %{
        email: user.email,
        display_name: display_name,
        confirmed?: not is_nil(Map.get(user, :confirmed_at)),
        locked?: not is_nil(Map.get(user, :locked_at)),
        deleted?: not is_nil(Map.get(user, :deleted_at)),
        inserted_at: Map.get(user, :inserted_at)
      },
      sessions: sessions,
      security: %{
        mfa_status: mfa_status,
        passkeys: passkeys,
        passkey_count: length(passkeys)
      },
      identities: identities,
      organizations: organizations,
      recent_audit: recent_audit,
      danger_zone: %{
        revoke_all_sessions?: sessions != [],
        impersonation_target_label: display_name || user.email
      }
    }
  end

  @spec recent_audit_preview(map(), Scope.t(), binary()) :: [struct()]
  def recent_audit_preview(config, %Scope{} = admin_scope, user_id) when is_binary(user_id) do
    case audit_schema(config) do
      nil ->
        []

      audit_schema ->
        filters =
          [target_id: user_id]
          |> maybe_put_audit_scope(admin_scope)

        audit_schema
        |> Sigra.Audit.Query.build(filters)
        |> order_by([event], desc: event.inserted_at, desc: event.id)
        |> limit(^@audit_preview_limit)
        |> config.repo.all()
    end
  end

  @spec list_identities(map(), struct(), keyword()) :: [struct()]
  def list_identities(config, user, opts \\ []) do
    identity_schema = Keyword.get(opts, :identity_schema) || helpers(config).identity_schema

    if identity_schema do
      from(identity in identity_schema,
        where: identity.user_id == ^user.id,
        order_by: [asc: identity.provider, asc: identity.inserted_at]
      )
      |> config.repo.all()
    else
      []
    end
  end

  @spec load_user!(map(), Scope.t(), binary()) :: struct()
  def load_user!(config, %Scope{} = admin_scope, user_id) when is_binary(user_id) do
    load_user!(config, admin_scope, user_id, helpers(config))
  end

  defp load_user!(config, %Scope{} = admin_scope, user_id, helpers) do
    user_schema = helpers.user_schema

    query =
      case admin_scope do
        %Scope{mode: :global} ->
          Authorizer.scope_query(user_schema, admin_scope)

        %Scope{mode: :organization, organization_id: org_id} ->
          Authorizer.authorize_organization!(admin_scope, org_id)

          from(user in user_schema,
            where: user.id in subquery(membership_user_ids_query(helpers.membership_schema, org_id))
          )
      end

    case config.repo.one(from(user in query, where: user.id == ^user_id)) do
      nil -> raise Authorizer.UnauthorizedError, reason: :not_found, message: "user not found"
      user -> user
    end
  end

  defp list_organizations(_config, _admin_scope, _user, %{membership_schema: nil}), do: []
  defp list_organizations(_config, _admin_scope, _user, %{organization_schema: nil}), do: []

  defp list_organizations(config, %Scope{} = admin_scope, user, helpers) do
    query =
      from(membership in helpers.membership_schema,
        where: membership.user_id == ^user.id,
        join: organization in ^helpers.organization_schema,
        on: organization.id == membership.organization_id,
        order_by: [asc: organization.name],
        select: %{
          organization_id: organization.id,
          organization_name: organization.name,
          organization_slug: organization.slug,
          role: membership.role
        }
      )

    query =
      case admin_scope do
        %Scope{mode: :global} ->
          query

        %Scope{mode: :organization, organization_id: org_id} ->
          Authorizer.authorize_organization!(admin_scope, org_id)
          where(query, [membership, _organization], membership.organization_id == ^org_id)
      end

    config.repo.all(query)
  end

  defp identities_with_flag(config, user, helpers) do
    case helpers.identity_schema do
      nil -> {[], false}
      schema -> {list_identities(config, user, identity_schema: schema), true}
    end
  end

  defp list_passkeys(_config, _user, %{passkey_schema: nil}), do: []

  defp list_passkeys(config, user, helpers) do
    Sigra.Passkeys.list_for_user(config, user, user_passkey_schema: helpers.passkey_schema)
  rescue
    ArgumentError -> []
  end

  defp load_mfa_status(_config, _user, %{mfa_schema: nil}), do: nil

  defp load_mfa_status(config, user, helpers) do
    Sigra.MFA.status(config, user, mfa_credential_schema: helpers.mfa_schema)
  rescue
    ArgumentError -> nil
  end

  defp maybe_put_audit_scope(filters, %Scope{mode: :organization, organization_id: org_id})
       when is_binary(org_id) do
    Keyword.put(filters, :organization_scope, {:including_global, org_id})
  end

  defp maybe_put_audit_scope(filters, _admin_scope), do: filters

  defp scope_label(%Scope{mode: :organization, organization: %{name: name}}) when is_binary(name),
    do: name

  defp scope_label(%Scope{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: slug

  defp scope_label(_admin_scope), do: "Global scope"

  defp helpers(config) do
    accounts_module = accounts_module(config)

    %{
      user_schema: Map.fetch!(config, :user_schema),
      membership_schema:
        Map.get(config, :membership_schema) || optional_schema(accounts_module, :OrganizationMembership),
      organization_schema:
        Map.get(config, :organization_schema) || optional_schema(accounts_module, :Organization),
      identity_schema: identity_schema(config, accounts_module),
      mfa_schema: mfa_schema(config, accounts_module),
      passkey_schema: passkey_schema(config, accounts_module)
    }
  end

  defp membership_user_ids_query(membership_schema, org_id) do
    from(membership in membership_schema,
      where: membership.organization_id == ^org_id,
      select: membership.user_id
    )
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

  defp identity_schema(%{oauth: oauth}, accounts_module) when is_list(oauth) do
    Keyword.get(oauth, :user_identity_schema) || optional_schema(accounts_module, :UserIdentity)
  end

  defp identity_schema(_config, accounts_module),
    do: optional_schema(accounts_module, :UserIdentity)

  defp passkey_schema(%{passkeys: passkeys}, accounts_module) when is_list(passkeys) do
    Keyword.get(passkeys, :user_passkey_schema) || optional_schema(accounts_module, :UserPasskey)
  end

  defp passkey_schema(_config, accounts_module),
    do: optional_schema(accounts_module, :UserPasskey)

  defp mfa_schema(%{mfa: mfa}, accounts_module) when is_list(mfa) do
    Keyword.get(mfa, :mfa_credential_schema) || optional_schema(accounts_module, :UserMFACredential)
  end

  defp mfa_schema(_config, accounts_module),
    do: optional_schema(accounts_module, :UserMFACredential)

  defp audit_schema(%{audit: audit}) when is_list(audit), do: Keyword.get(audit, :audit_schema)
  defp audit_schema(_config), do: nil

  defp safe_apply(module, function, args) when is_atom(module) do
    if function_exported?(module, function, length(args)) do
      apply(module, function, args)
    end
  end
end
