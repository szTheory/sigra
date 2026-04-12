defmodule <%= app_module %>.Organizations do
  @moduledoc """
  Host-app organizations context wrapper.

  Delegates sensitive operations to the Sigra library while exposing a
  stable, discoverable API for controllers and LiveViews. Edit freely —
  this file is your code.

  ## Active organization writes

  `set_active_organization/2` is the single authoritative write path
  for changing the active organization on a request. It delegates to
  `Sigra.Plug.PutActiveOrganization.call/2`, which:

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
    organization: <%= app_module %>.Organization,
    membership: <%= app_module %>.OrganizationMembership,
    invitation: <%= app_module %>.OrganizationInvitation,
    user: <%= context_module %>.<%= schema_alias %>,
    scope: <%= context_module %>.Scope

  @doc """
  Sets the active organization for the current request.

  See the moduledoc for the full contract.
  """
  defdelegate set_active_organization(conn, org),
    to: Sigra.Plug.PutActiveOrganization,
    as: :call
end
