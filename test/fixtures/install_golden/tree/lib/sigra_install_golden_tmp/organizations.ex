defmodule SigraInstallGoldenTmp.Organizations do
  @moduledoc """
  Host-app organizations context wrapper.

  Delegates sensitive operations to the Sigra library while exposing a
  stable, discoverable API for controllers and LiveViews. Edit freely —
  this file is your code.

  ## Active organization writes

  `set_active_organization/2` is the single authoritative write path
  for changing the active organization on a request. It delegates to
  `Sigra.Plug.PutActiveOrganization.call/3`, which:

    1. Verifies the current user is a member of the target organization
       (membership-before-write — T-14-06 authz choke point).
    2. Writes the organization id to the session row via the configured
       `Sigra.SessionStore`.
    3. Updates `conn.private[:sigra_session]` and
       `conn.assigns[:current_scope]` atomically with the row write.

  Returns `{:ok, conn}` on success or `{:error, :not_a_member}` when
  the user has no membership in the target organization (no write is
  performed on the reject path).
  """

  import Ecto.Query

  alias SigraInstallGoldenTmp.Accounts.OrganizationAuthPolicy
  alias SigraInstallGoldenTmp.Accounts.OrganizationAuthPolicyExemption
  alias SigraInstallGoldenTmp.Repo

  use Sigra.Organizations,
    repo: SigraInstallGoldenTmp.Repo,
    schemas: [
      organization: SigraInstallGoldenTmp.Accounts.Organization,
      membership: SigraInstallGoldenTmp.Accounts.OrganizationMembership,
      invitation: SigraInstallGoldenTmp.Accounts.OrganizationInvitation,
      user: SigraInstallGoldenTmp.Accounts.User,
      scope: SigraInstallGoldenTmp.Accounts.Scope
    ]

  @doc """
  Sets the active organization for the current request.

  See the moduledoc for the full contract.
  """
  def set_active_organization(conn, org) do
    Sigra.Plug.PutActiveOrganization.call(conn, org, [])
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Phase 16 thin-wrapper delegates (settings page + members list)
  #
  # `use Sigra.Organizations` above already injects thin delegators for
  # `list_organizations_for_user/1`, `remove_member/2`, and a 3-arg
  # `change_role/3`. The wrappers below route the Phase 16 LiveView callers
  # (settings page + members list) through Sigra.Organizations with the
  # configured @sigra_org_config. See .planning/phases/16-org-liveviews-switcher/
  # 16-CONTEXT.md D-10 / D-11 / D-16 for signatures.
  #
  # These call Sigra.Organizations functions added in Phase 16 Plan 01.
  # ──────────────────────────────────────────────────────────────────────────

  @doc "Rename an organization (D-10 — inline, no password required)."
  def rename_organization(scope, params),
    do:
      Sigra.Organizations.rename_organization(
        __sigra_org_config__(),
        scope,
        scope.active_organization,
        params
      )

  @doc "Update an organization's slug (D-11 — requires inline password + typed confirm)."
  def update_slug(scope, params),
    do:
      Sigra.Organizations.update_slug(
        __sigra_org_config__(),
        scope,
        scope.active_organization,
        params
      )

  @doc "Soft-delete an organization (D-11 — requires inline password + typed confirm)."
  def soft_delete_organization(scope, params),
    do:
      Sigra.Organizations.soft_delete_organization(
        __sigra_org_config__(),
        scope,
        scope.active_organization,
        params
      )

  # `list_members_with_activity/2` and `count_members/1` are injected by
  # `use Sigra.Organizations` above (Phase 16 Plan 01). Do not redeclare them
  # here — same-arity duplicates collide because both sites declare defaults.

  @doc "Change a member's role with last-owner guard (D-18)."
  def change_member_role(scope, membership, new_role),
    do:
      Sigra.Organizations.change_role(__sigra_org_config__(), scope, membership, new_role)

  @doc "Returns the current organization's enterprise connection, if present."
  def get_enterprise_connection(scope),
    do: Sigra.EnterpriseConnections.get_connection(enterprise_connection_config(), scope)

  @doc "Builds the enterprise connection changeset for the current organization."
  def change_enterprise_connection(scope, attrs \\ %{}),
    do: Sigra.EnterpriseConnections.change_connection(enterprise_connection_config(), scope, attrs)

  @doc "Saves enterprise SSO settings as a draft."
  def save_enterprise_connection(scope, attrs),
    do: Sigra.EnterpriseConnections.save_connection(enterprise_connection_config(), scope, attrs)

  @doc "Runs enterprise SSO validation without activating the connection."
  def validate_enterprise_connection(scope, attrs),
    do:
      Sigra.EnterpriseConnections.validate_connection(enterprise_connection_config(), scope, attrs)

  @doc "Activates the current organization's enterprise SSO connection when validation passes."
  def activate_enterprise_connection(scope, attrs),
    do:
      Sigra.EnterpriseConnections.activate_connection(enterprise_connection_config(), scope, attrs)

  @doc "Disables the current organization's enterprise SSO connection."
  def disable_enterprise_connection(scope),
    do: Sigra.EnterpriseConnections.disable_connection(enterprise_connection_config(), scope)

  @doc "Discovers one exact routable enterprise connection from a work-email entry."
  def discover_enterprise_connection(email),
    do: Sigra.EnterpriseRouting.discover_connection(enterprise_connection_config(), email)

  @doc "Loads the canonical routable enterprise connection for an organization."
  def get_routable_enterprise_connection(organization),
    do: Sigra.EnterpriseRouting.get_routable_connection(enterprise_connection_config(), organization)

  @doc "Returns the current organization's auth policy, defaulting to optional."
  def get_auth_policy(scope) do
    organization = scope.active_organization

    Repo.get_by(OrganizationAuthPolicy, organization_id: organization.id) ||
      %OrganizationAuthPolicy{
        organization_id: organization.id,
        organization: organization,
        enforcement_mode: :optional
      }
  end

  @doc "Builds the auth policy changeset for the current organization."
  def change_auth_policy(scope, attrs \\ %{}) do
    scope
    |> get_auth_policy()
    |> OrganizationAuthPolicy.changeset(
      Map.merge(%{"organization_id" => scope.active_organization.id}, stringify_keys(attrs))
    )
  end

  @doc "Persists auth policy changes for the current organization."
  def save_auth_policy(scope, attrs) do
    scope
    |> change_auth_policy(attrs)
    |> Repo.insert_or_update()
  end

  @doc "Lists explicit break-glass exemptions for the current organization."
  def list_auth_policy_exemptions(scope) do
    OrganizationAuthPolicyExemption
    |> where([row], row.organization_id == ^scope.active_organization.id)
    |> join(:inner, [row], membership in SigraInstallGoldenTmp.Accounts.OrganizationMembership,
      on:
        membership.organization_id == row.organization_id and
          membership.user_id == row.user_id
    )
    |> join(:inner, [_row, membership], user in SigraInstallGoldenTmp.Accounts.User,
      on: user.id == membership.user_id
    )
    |> order_by([_row, membership, user], asc: membership.role, asc: user.email)
    |> select([row, membership, user], %{id: row.id, user_id: user.id, email: user.email, role: membership.role})
    |> Repo.all()
  end

  @doc "Lists members who can be selected as break-glass exemptions."
  def list_break_glass_candidates(scope) do
    SigraInstallGoldenTmp.Accounts.OrganizationMembership
    |> where([membership], membership.organization_id == ^scope.active_organization.id)
    |> join(:inner, [membership], user in SigraInstallGoldenTmp.Accounts.User,
      on: user.id == membership.user_id
    )
    |> order_by([membership, user], asc: membership.role, asc: user.email)
    |> select([membership, user], %{user_id: user.id, email: user.email, role: membership.role})
    |> Repo.all()
  end

  @doc "Enables SSO-only with explicit break-glass exemptions."
  def enable_sso_only(scope, exempt_user_ids) when is_list(exempt_user_ids) do
    exempt_user_ids =
      exempt_user_ids
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.uniq()

    if exempt_user_ids == [] do
      {:error, :break_glass_required}
    else
      Repo.transaction(fn ->
        with {:ok, policy} <- save_auth_policy(scope, %{"enforcement_mode" => "sso_required"}),
             :ok <- replace_auth_policy_exemptions(scope, exempt_user_ids) do
          %{policy: policy, exemptions: list_auth_policy_exemptions(scope)}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> normalize_policy_transaction()
    end
  end

  @doc "Disables SSO-only while keeping explicit exemption records."
  def disable_sso_only(scope), do: save_auth_policy(scope, %{"enforcement_mode" => "optional"})

  @doc "Resolves the current user's local-auth policy for the selected organization."
  def local_auth_policy_for(user, opts \\ []) do
    selector_opts = [previous_active_organization_id: Keyword.get(opts, :previous_active_organization_id)]

    case Sigra.Organizations.select_active_organization(__sigra_org_config__(), user, selector_opts) do
      {:ok, organization} ->
        policy = Repo.get_by(OrganizationAuthPolicy, organization_id: organization.id)

        cond do
          is_nil(policy) or policy.enforcement_mode != :sso_required ->
            %{
              organization_id: organization.id,
              organization_slug: organization.slug,
              organization_name: organization.name,
              enforcement_mode: :optional,
              break_glass: false,
              password_login: :allow,
              password_reset: :allow
            }

          break_glass_exempt?(organization.id, user.id) ->
            %{
              organization_id: organization.id,
              organization_slug: organization.slug,
              organization_name: organization.name,
              enforcement_mode: :sso_required,
              break_glass: true,
              password_login: :allow,
              password_reset: :allow
            }

          true ->
            %{
              organization_id: organization.id,
              organization_slug: organization.slug,
              organization_name: organization.name,
              enforcement_mode: :sso_required,
              break_glass: false,
              password_login: :deny,
              password_reset: :deny
            }
        end

      _ ->
        %{password_login: :allow, password_reset: :allow, break_glass: false}
    end
  end

  defp enterprise_connection_config do
    __sigra_org_config__()
    |> Map.update!(:schemas, &Map.put(&1, :enterprise_connection, SigraInstallGoldenTmp.Accounts.EnterpriseConnection))
  end

  defp replace_auth_policy_exemptions(scope, exempt_user_ids) do
    organization_id = scope.active_organization.id

    candidates =
      list_break_glass_candidates(scope)
      |> Map.new(&{&1.user_id, &1})

    if Enum.all?(exempt_user_ids, &Map.has_key?(candidates, &1)) do
      from(row in OrganizationAuthPolicyExemption, where: row.organization_id == ^organization_id)
      |> Repo.delete_all()

      Enum.reduce_while(exempt_user_ids, :ok, fn user_id, :ok ->
        attrs = %{organization_id: organization_id, user_id: user_id}

        case %OrganizationAuthPolicyExemption{}
             |> OrganizationAuthPolicyExemption.changeset(attrs)
             |> Repo.insert() do
          {:ok, _row} -> {:cont, :ok}
          {:error, changeset} -> {:halt, {:error, changeset}}
        end
      end)
    else
      {:error, :invalid_break_glass_users}
    end
  end

  defp normalize_policy_transaction({:ok, result}), do: {:ok, result}
  defp normalize_policy_transaction({:error, reason}), do: {:error, reason}

  defp break_glass_exempt?(organization_id, user_id) do
    Repo.exists?(
      from row in OrganizationAuthPolicyExemption,
        where: row.organization_id == ^organization_id and row.user_id == ^user_id
    )
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
  end
end
