defmodule Sigra.Plug.LoadActiveOrganization do
  @moduledoc """
  Hydrates `scope.active_organization` and `scope.membership` from the caller's
  `%Sigra.Session{}` (read from `conn.private[:sigra_session]`, stashed by
  `Sigra.Plug.FetchSession`).

  This is a **Fetch** plug in the `phx.gen.auth` sense: it mutates
  `conn.assigns[:current_scope]` and `conn.private[:sigra_session]`, but NEVER
  halts the pipeline. Missing, invalid, or stale pointers resolve to a nil
  `active_organization` (or a reassigned one after hybrid recovery) and the
  request continues. Downstream `Sigra.Plug.RequireMembership` is responsible
  for halting when an active org is required.

  ## Stale-pointer recovery

  On `{:error, :not_a_member}` or `{:error, :org_not_found}` from
  `Sigra.Scope.Hydration.hydrate/3`, the plug:

    1. Clears the session row's `active_organization_id` via
       `SessionStore.update_active_organization/3`.
    2. Calls `Sigra.Organizations.select_active_organization/3` with
       `previous_active_organization_id: nil` (the stale pointer is NOT
       resumed — D-14).
    3. Writes the result (or leaves the session at nil) via the same store
       callback and assigns the final scope.
    4. Emits one audit event via `Sigra.Audit.log_safe/2`:
       `"organization.active_auto_reassigned"`, with `%{from: stale_id,
       to: new_id_or_nil}` in metadata.

  No Plug session cookie writes. No halts. Phase 14 D-03, D-04, D-14, D-17.

  ## Options

    * `:organizations` — required. The host's `use Sigra.Organizations` module,
      exposing `__sigra_org_config__/0` (the Phase 14 accessor added for the
      plug/on_mount consumers).

    * `:session_store` — required. The module implementing
      `Sigra.SessionStore`. Typically read from `Sigra.Config` at the call
      site but passed explicitly so the plug stays fully dependency-injected.

    * `:session_store_opts` — optional keyword list forwarded to the store
      callback (e.g. `[repo: MyApp.Repo, session_schema: MyApp.Accounts.UserSession]`).
      Defaults to `[]`.

    * `:audit_opts` — optional keyword list forwarded to `Sigra.Audit.log_safe/2`
      (e.g. `[audit_schema: MyApp.AuditEvent, repo: MyApp.Repo]`). Defaults to
      `[]`. When empty, the plug auto-derives `[repo: config.repo,
      audit_schema: config.audit_schema]` from the host's
      `__sigra_org_config__/0` so the documented
      `"organization.active_auto_reassigned"` audit event is written
      out-of-the-box whenever the host org config declares an
      `:audit_schema`. If the host org config has `audit_schema: nil` (the
      default), `log_safe/2` remains a no-op (by design).
  """

  @behaviour Plug

  alias Sigra.Audit
  alias Sigra.Organizations
  alias Sigra.Scope.Hydration

  @impl true
  def init(opts) do
    _ = Keyword.fetch!(opts, :organizations)
    _ = Keyword.fetch!(opts, :session_store)
    opts
  end

  @impl true
  def call(%Plug.Conn{} = conn, opts) do
    scope = conn.assigns[:current_scope]
    session = conn.private[:sigra_session]

    cond do
      is_nil(scope) -> conn
      is_nil(session) -> conn
      true -> hydrate_and_assign(conn, scope, session, opts)
    end
  end

  defp hydrate_and_assign(conn, scope, session, opts) do
    organizations = Keyword.fetch!(opts, :organizations)
    config = organizations.__sigra_org_config__()

    case Hydration.hydrate(scope, config, session) do
      {:ok, hydrated_scope} ->
        Plug.Conn.assign(conn, :current_scope, hydrated_scope)

      {:error, reason} when reason in [:not_a_member, :org_not_found] ->
        recover_from_stale_pointer(conn, scope, session, config, opts)
    end
  end

  defp recover_from_stale_pointer(conn, scope, session, config, opts) do
    stale_id = session.active_organization_id
    session_store = Keyword.fetch!(opts, :session_store)
    store_opts = Keyword.get(opts, :session_store_opts, [])
    audit_opts = resolve_audit_opts(opts, config)

    # Step 1: clear the DB column (no-op-safe short-circuits if already nil).
    # WR-05: tolerate {:error, :not_found} — the session row can be deleted
    # concurrently by delete_all_for_user/2 during a forced logout cascade.
    # A fail-closed MatchError here defeats the whole point of this plug.
    case session_store.update_active_organization(session, nil, store_opts) do
      {:ok, cleared_session} ->
        continue_recovery(conn, scope, session, cleared_session, config, opts,
          session_store: session_store,
          store_opts: store_opts,
          audit_opts: audit_opts,
          stale_id: stale_id
        )

      {:error, _reason} ->
        # Row is gone underneath us. Drop to a safe, empty-org scope and
        # leave the request unhalted — the next request will re-hydrate
        # cleanly (or the auth plug will redirect to login if the session
        # is fully gone). Do NOT crash the request.
        safe_scope = %{scope | active_organization: nil, membership: nil}
        Plug.Conn.assign(conn, :current_scope, safe_scope)
    end
  end

  defp continue_recovery(conn, scope, _session, cleared_session, config, _opts, state) do
    session_store = Keyword.fetch!(state, :session_store)
    store_opts = Keyword.fetch!(state, :store_opts)
    audit_opts = Keyword.fetch!(state, :audit_opts)
    stale_id = Keyword.fetch!(state, :stale_id)

    # Step 2: re-run the selector WITHOUT the stale pointer (D-14).
    # Use the _with_membership variant so the resume/single-org branches
    # return the membership struct from the same join that listed the
    # orgs — avoids a second get_membership/3 roundtrip (WR-03).
    selection =
      Organizations.select_active_organization_with_membership(config, scope.user,
        previous_active_organization_id: nil
      )

    {new_session, new_scope} =
      apply_selection(selection, scope, cleared_session, session_store, store_opts)

    # Step 3: emit one audit event (no-op when audit_schema is absent).
    # 15-02 Category 1: `new_scope` is the post-reassignment scope and carries
    # the resolved org — pass it directly so the audit row picks up the new
    # organization_id + effective_user_id.
    Audit.log_safe(
      "organization.active_auto_reassigned",
      new_scope,
      Keyword.merge(audit_opts,
        actor_id: scope.user.id,
        target_id: stale_id,
        target_type: "organization",
        metadata: %{
          from: stale_id,
          to: new_scope.active_organization && new_scope.active_organization.id
        }
      )
    )

    conn
    |> Plug.Conn.put_private(:sigra_session, new_session)
    |> Plug.Conn.assign(:current_scope, new_scope)
  end

  defp apply_selection(
         {:ok, new_org, membership},
         scope,
         cleared_session,
         session_store,
         store_opts
       ) do
    # WR-05: tolerate {:error, _} on the set-to-new-org write too. If the
    # row vanished between the clear and this write, fall through to a safe
    # empty scope rather than MatchError'ing mid-pipeline.
    case session_store.update_active_organization(cleared_session, new_org.id, store_opts) do
      {:ok, refreshed} ->
        {refreshed, %{scope | active_organization: new_org, membership: membership}}

      {:error, _reason} ->
        {cleared_session, %{scope | active_organization: nil, membership: nil}}
    end
  end

  defp apply_selection({:none, :zero_orgs}, scope, cleared, _store, _opts) do
    {cleared, %{scope | active_organization: nil, membership: nil}}
  end

  defp apply_selection({:multiple, _orgs}, scope, cleared, _store, _opts) do
    # v1.1: leave nil; user sees the picker on the next RequireMembership hit.
    {cleared, %{scope | active_organization: nil, membership: nil}}
  end

  # IN-01: If the caller did not thread `:audit_opts`, derive `[repo:,
  # audit_schema:]` from the host's org config so the documented
  # `"organization.active_auto_reassigned"` event is written for out-of-the-box
  # installs. If the host org config has `audit_schema: nil` (the default),
  # this stays a no-op via `Audit.log_safe/2` — no behavior change.
  defp resolve_audit_opts(opts, config) do
    case Keyword.get(opts, :audit_opts, []) do
      [] ->
        [repo: config.repo, audit_schema: Map.get(config, :audit_schema)]

      provided when is_list(provided) ->
        provided
    end
  end
end
