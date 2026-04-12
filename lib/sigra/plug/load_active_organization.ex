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
      `[]`. When empty, `log_safe/2` is a no-op (by design).
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
    audit_opts = Keyword.get(opts, :audit_opts, [])

    # Step 1: clear the DB column (no-op-safe short-circuits if already nil).
    {:ok, cleared_session} = session_store.update_active_organization(session, nil, store_opts)

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
    Audit.log_safe(
      "organization.active_auto_reassigned",
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

  defp apply_selection({:ok, new_org, membership}, scope, cleared_session, session_store, store_opts) do
    {:ok, refreshed} =
      session_store.update_active_organization(cleared_session, new_org.id, store_opts)

    {refreshed, %{scope | active_organization: new_org, membership: membership}}
  end

  defp apply_selection({:none, :zero_orgs}, scope, cleared, _store, _opts) do
    {cleared, %{scope | active_organization: nil, membership: nil}}
  end

  defp apply_selection({:multiple, _orgs}, scope, cleared, _store, _opts) do
    # v1.1: leave nil; user sees the picker on the next RequireMembership hit.
    {cleared, %{scope | active_organization: nil, membership: nil}}
  end
end
