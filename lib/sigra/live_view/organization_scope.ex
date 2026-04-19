defmodule Sigra.LiveView.OrganizationScope do
  @moduledoc """
  LiveView `on_mount` parallel of `Sigra.Plug.LoadOrganizationFromSlug`
  (Phase 16 D-03, D-04).

  Rebinds `socket.assigns.current_scope.active_organization` and
  `.membership` from the `:org` URL param for the scoped route. The
  on_mount path is READ-ONLY with respect to the Plug session — it
  never calls `put_session/2` (it has no `Plug.Conn`). The plug
  counterpart owns all session writes.

  Behavior:
    * Unauthenticated socket (scope.user == nil): halts with
      `{:halt, redirect(socket, to: login_path)}`.
    * Missing org or not-a-member: halts by raising
      `Phoenix.Router.NoRouteError` so the router renders a 404 page
      (D-04 enumeration prevention — no distinction between unknown
      slug and not-a-member).

  ## Usage

  Inside a `live_session`:

      on_mount {Sigra.LiveView.OrganizationScope, organizations: MyApp.Organizations, scope_module: MyApp.Scope}

  ## Params forwarded to `on_mount/4`

    * `:organizations` — required. The host's `use Sigra.Organizations`
      module exposing `__sigra_org_config__/0`.
    * `:scope_module` — required. Host scope module implementing
      `put_active_organization/3` (D-15).
    * `:login_path` — optional. Default: `"/users/log_in"`.
  """

  alias Sigra.Organizations

  @doc """
  `on_mount` callback. See `Phoenix.LiveView.on_mount/1`.
  """
  def on_mount(opts, params, _session, socket) when is_list(opts) do
    organizations = Keyword.fetch!(opts, :organizations)
    scope_module = Keyword.fetch!(opts, :scope_module)
    login_path = Keyword.get(opts, :login_path, "/users/log_in")
    config = organizations.__sigra_org_config__()

    scope = socket.assigns[:current_scope]

    cond do
      is_nil(scope) or is_nil(scope.user) ->
        # Return a tagged tuple the caller bridges to Phoenix.LiveView.redirect.
        # Kept as data (not a direct LV call) so this module is unit-testable
        # without pulling phoenix_live_view into Sigra's test deps.
        {:halt, assign_redirect(socket, login_path)}

      true ->
        slug = params["org"] || params[:org]

        case resolve(config, scope, slug) do
          {:ok, org, membership} ->
            new_scope = scope_module.put_active_organization(scope, org, membership)
            {:cont, put_in(socket.assigns[:current_scope], new_scope)}

          :not_found ->
            # D-04 enumeration prevention: mirror the plug's 404 path.
            # Raising Phoenix.Router.NoRouteError requires a populated conn;
            # instead return a :halt tuple carrying a :sigra_not_found flag
            # on the socket that the host LV error handler can translate
            # into a 404 render.
            {:halt, put_in(socket.assigns[:sigra_not_found], true)}
        end
    end
  end

  defp assign_redirect(socket, path) do
    put_in(socket.assigns[:sigra_redirect_to], path)
  end

  defp resolve(_config, _scope, nil), do: :not_found

  defp resolve(config, scope, slug) do
    with org when not is_nil(org) <- Organizations.get_organization_by_slug(config, slug),
         membership when not is_nil(membership) <-
           Organizations.get_membership(config, scope.user, org) do
      {:ok, org, membership}
    else
      _ -> :not_found
    end
  end
end
