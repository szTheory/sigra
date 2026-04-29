defmodule Sigra.Scope.Hydration do
  @moduledoc """
  Pure scope-hydration contract shared between `Sigra.Plug.LoadActiveOrganization`
  (Plug pipeline) and the generated `UserAuth.on_mount` callback (LiveView).

  Given a `(scope, config, session)`, returns a fully populated `%Scope{}` or
  a fail-closed error tuple. This module is the SINGLE place scope hydration
  lives. Any future scope augmentation — impersonation (v1.2), feature flags,
  passkey context — extends this function.

  ## Fail-closed contract

  On stale pointer (`:not_a_member`) or deleted org (`:org_not_found`),
  callers MUST clear `session.active_organization_id` and re-run
  `Sigra.Organizations.select_active_organization/3`. See
  `Sigra.Plug.LoadActiveOrganization` (Plan 14-02) for the orchestration.

  The hydrator NEVER raises. It calls the non-raising
  `Sigra.Organizations.fetch_organization/2` (not `get_organization!/2`)
  specifically to keep `Ecto.NoResultsError` out of the request pipeline
  (PITFALLS O-6).

  ## Purity

  This module performs only the reads necessary to resolve the active
  organization and the calling user's membership in it. It writes nothing:
  no session mutation, no audit event, no cache update. Calling `hydrate/3`
  twice with the same inputs yields structurally-equal scopes.

  Source of truth: Phase 14 CONTEXT.md D-01 / D-14 / D-23.

  ## Phase 92 / B2B-02 (Plan 92-03) — `:role` propagation

  On successful org-active hydration this module copies `membership.role`
  onto `scope.role`. This is the **only** Phase 92 library seam that
  populates `:role` from a membership read; `Sigra.Plug.PutActiveOrganization`
  is the only OTHER seam that writes `:role`, and only in lockstep with
  membership transitions.

  `Sigra.Plug.FetchSession` and `Sigra.Plug.FetchBearer` MUST NOT touch
  `:role` — they enrich identity, not authorization context. The
  Phase 14 D-23 plug ↔ on_mount parity also implies role parity: both
  paths flow through this hydrator.

  Error tuples (`:not_a_member`, `:org_not_found`) and the nil-pointer /
  nil-user branches do NOT propagate a role atom. Callers that take the
  recovery branch (`Sigra.Plug.LoadActiveOrganization`) clear `:role`
  explicitly when they synthesize a no-org scope.

  `:actor_type` is reserved Phase 93 prep — this module does not branch
  on it under Phase 92.
  """

  alias Sigra.Organizations

  @type hydrate_error :: :not_a_member | :org_not_found

  @doc """
  Hydrates the given scope with `:active_organization` and `:membership`
  based on `session.active_organization_id`.

  Returns `{:ok, scope}` unchanged when the session has no active organization
  pointer. Returns `{:ok, scope}` with the org and membership populated on the
  happy path. Returns `{:error, :not_a_member}` when the session points at an
  org the user was removed from. Returns `{:error, :org_not_found}` when the
  session points at a hard-deleted or soft-deleted org.

  The `config` argument is the Sigra.Organizations config map (the same shape
  produced by the private `__validate_config__!` helper in Sigra.Organizations),
  NOT the top-level
  `Sigra.Config.t()`. Callers in the plug/on_mount paths resolve this from
  the generated wrapper module.
  """
  @spec hydrate(scope :: struct(), config :: map(), session :: Sigra.Session.t()) ::
          {:ok, struct()} | {:error, hydrate_error()}
  def hydrate(scope, config, %Sigra.Session{} = session) do
    scope = hydrate_impersonation(scope, config, session)
    do_hydrate(scope, config, session)
  end

  defp do_hydrate(scope, _config, %Sigra.Session{active_organization_id: nil}) do
    {:ok, scope}
  end

  defp do_hydrate(%{user: nil} = scope, _config, %Sigra.Session{}) do
    # Defensive: if a caller invokes hydrate/3 without a populated user
    # (e.g. a scope wired in before the auth plug) return the scope
    # unchanged rather than raising on `user.id` inside get_membership/3.
    # The hydrator's contract is "NEVER raises" (PITFALLS O-6) and this
    # is the one remaining path that would.
    {:ok, scope}
  end

  defp do_hydrate(scope, config, %Sigra.Session{active_organization_id: org_id}) do
    user = scope.user

    case Organizations.fetch_organization(config, org_id) do
      {:ok, org} ->
        case Organizations.get_membership(config, user, org) do
          nil ->
            {:error, :not_a_member}

          membership ->
            # Phase 92 / B2B-02 (Plan 92-03 Task 2): the shared seam derives
            # `scope.role` from `membership.role` only on successful
            # org-active enrichment. `Map.get/3` tolerates a membership
            # struct without a `:role` key (defense-in-depth — host
            # OrganizationMembership schemas may add the field at any
            # point) and a nil role value (Plan 92-02 made the column
            # nullable + plain :string with no opinionated default).
            {:ok,
             %{
               scope
               | active_organization: org,
                 membership: membership,
                 role: Map.get(membership, :role)
             }}
        end

      {:error, :not_found} ->
        {:error, :org_not_found}
    end
  end

  defp hydrate_impersonation(scope, _config, %Sigra.Session{impersonator_user_id: nil}), do: scope

  defp hydrate_impersonation(
         %{impersonating_from: impersonating_from} = scope,
         _config,
         %Sigra.Session{}
       )
       when not is_nil(impersonating_from),
       do: scope

  defp hydrate_impersonation(scope, config, %Sigra.Session{impersonator_user_id: user_id}) do
    repo = Map.get(config, :repo)
    user_schema = get_in(config, [:schemas, :user])

    admin_user =
      case {repo, user_schema, user_id} do
        {repo, schema, id} when is_atom(repo) and is_atom(schema) and not is_nil(id) ->
          repo.get(schema, id)

        _ ->
          nil
      end

    %{scope | impersonating_from: admin_user}
  end
end
