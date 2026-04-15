defmodule Sigra.Plug.PutActiveOrganization do
  @moduledoc """
  The **single** authoritative write site for "set the active organization".

  Every Phase 14+ call site that needs to set, clear, or change the active
  organization funnels through this function: login (Plan 03), the switcher
  controller (Phase 16), invitation accept (Phase 17), stale-pointer recovery
  inside `Sigra.Plug.LoadActiveOrganization`, and the backfill upgrade
  (Phase 18). No ad-hoc Plug-session writes. No direct ecto updates on
  `user_sessions`. No shortcuts.

  This function is **not** a Plug `call/2` — it is a function-call contract
  invoked from controllers, other plugs, and the login entry point. It takes
  a `Plug.Conn`, an `Organization` struct (or `nil` to clear), and an opts
  keyword list, and returns `{:ok, updated_conn}` or `{:error, reason}`.

  ## Writes performed

    1. `user_sessions.active_organization_id` column (via the configured
       `Sigra.SessionStore` implementation's `update_active_organization/3`
       callback).
    2. `conn.private[:sigra_session]` (refreshed with the updated struct).
    3. `conn.assigns[:current_scope]` (via the host scope module's
       `put_active_organization/3` — D-15).

  ## Writes explicitly NOT performed

    * Plug session cookie writes — no mirror of the DB column into the
      cookie session (D-03/D-17).
    * Session token rotation / session renewal — a scope transition is
      NOT a trust transition (D-18).

  ## Authorization (T-14-06)

  Before any write, `call/3` verifies the user's membership in the target
  organization via `Sigra.Organizations.get_membership/3`. If `nil`, the
  function returns `{:error, :not_a_member}` **without** calling the
  SessionStore's `update_active_organization/3` callback. The SessionStore
  callback itself does not enforce authz (see Phase 14 T-14-04).

  ## Options

    * `:organizations` — required. The host's `use Sigra.Organizations`
      module exposing `__sigra_org_config__/0`.
    * `:session_store` — required. Module implementing `Sigra.SessionStore`.
    * `:scope_module` — required. The host scope module whose
      `put_active_organization/3` builds the updated scope struct (D-15).
    * `:session_store_opts` — optional keyword list forwarded to the
      session store callback (e.g. `[repo: MyApp.Repo]`). Defaults to `[]`.
  """

  alias Sigra.Organizations

  @type call_error :: :not_a_member | :no_session | :no_scope | term()

  @doc """
  Set, change, or clear the active organization on the caller's session.
  Returns `{:ok, updated_conn}` on success or `{:error, reason}` on failure.

  Returns `{:error, :no_session}` if no `%Sigra.Session{}` has been stashed
  at `conn.private[:sigra_session]` (the FetchSession plug has not run, or
  the user is not logged in). Returns `{:error, :no_scope}` if
  `conn.assigns[:current_scope]` is missing or has a nil `:user`. Both
  errors are fail-closed: the request does not crash and no write is
  performed.
  """
  @doc since: "0.8.0"
  @spec call(Plug.Conn.t(), struct() | nil, keyword()) ::
          {:ok, Plug.Conn.t()} | {:error, call_error()}
  def call(%Plug.Conn{} = conn, nil, opts) do
    with {:ok, session} <- fetch_session(conn),
         {:ok, scope} <- fetch_scope(conn) do
      session_store = Keyword.fetch!(opts, :session_store)
      scope_module = Keyword.fetch!(opts, :scope_module)
      store_opts = Keyword.get(opts, :session_store_opts, [])

      with {:ok, refreshed} <- session_store.update_active_organization(session, nil, store_opts) do
        new_scope = scope_module.put_active_organization(scope, nil, nil)

        {:ok,
         conn
         |> Plug.Conn.put_private(:sigra_session, refreshed)
         |> Plug.Conn.assign(:current_scope, new_scope)}
      end
    end
  end

  def call(%Plug.Conn{} = conn, org, opts) when is_struct(org) do
    with {:ok, session} <- fetch_session(conn),
         {:ok, scope} <- fetch_scope(conn) do
      organizations = Keyword.fetch!(opts, :organizations)
      session_store = Keyword.fetch!(opts, :session_store)
      scope_module = Keyword.fetch!(opts, :scope_module)
      store_opts = Keyword.get(opts, :session_store_opts, [])
      config = organizations.__sigra_org_config__()

      case Organizations.get_membership(config, scope.user, org) do
        nil ->
          {:error, :not_a_member}

        membership ->
          with {:ok, refreshed} <-
                 session_store.update_active_organization(session, org.id, store_opts) do
            new_scope = scope_module.put_active_organization(scope, org, membership)

            {:ok,
             conn
             |> Plug.Conn.put_private(:sigra_session, refreshed)
             |> Plug.Conn.assign(:current_scope, new_scope)}
          end
      end
    end
  end

  defp fetch_session(conn) do
    case conn.private[:sigra_session] do
      %Sigra.Session{} = session -> {:ok, session}
      _ -> {:error, :no_session}
    end
  end

  defp fetch_scope(conn) do
    case conn.assigns[:current_scope] do
      %{user: %_{}} = scope -> {:ok, scope}
      _ -> {:error, :no_scope}
    end
  end
end
