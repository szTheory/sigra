defmodule <%= app_module %>.Organizations do
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

  use Sigra.Organizations,
    repo: <%= repo_module %>,
    schemas: [
      organization: <%= context_module %>.Organization,
      membership: <%= context_module %>.OrganizationMembership,
      invitation: <%= context_module %>.OrganizationInvitation,
      user: <%= context_module %>.<%= schema_alias %>,
      scope: <%= context_module %>.Scope
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
end
