defmodule Sigra.Plug.LoadOrganizationFromSlug do
  @moduledoc """
  URL-driven active organization loader (Phase 16 D-03, D-04, D-13).

  Reads `conn.params[scope_param]` (default `"org"`), resolves the
  organization by slug, verifies membership, follows 7-day slug aliases,
  and refreshes the session pointer when the URL org differs from the
  session pointer — delegating the write to
  `Sigra.Plug.PutActiveOrganization.call/3` (Phase 14 D-16 single-writer).

  Returns 404 via the configured `error_handler` for unknown slugs AND
  for known slugs the current user is not a member of (enumeration
  prevention, D-04). Both paths go through the same `:not_found`
  disposition so callers cannot distinguish them by response shape or
  timing.

  ## Options

    * `:error_handler` — required. Module implementing
      `Sigra.Plug.ErrorHandler`. Used for the `:not_found` halt path.
    * `:organizations` — required. The host's `use Sigra.Organizations`
      module exposing `__sigra_org_config__/0`.
    * `:session_store` — required. Module implementing
      `Sigra.SessionStore`. Forwarded to
      `Sigra.Plug.PutActiveOrganization.call/3` when the URL org
      differs from the session pointer.
    * `:scope_module` — required. Host scope module for `put_active_organization/3`.
    * `:scope_param` — optional. URL param name holding the slug.
      Default: `"org"`.
    * `:session_store_opts` — optional. Forwarded to the session store.
  """

  @behaviour Plug

  alias Sigra.Organizations

  @impl true
  def init(opts) do
    _ = Keyword.fetch!(opts, :error_handler)
    _ = Keyword.fetch!(opts, :organizations)
    _ = Keyword.fetch!(opts, :session_store)
    _ = Keyword.fetch!(opts, :scope_module)
    Keyword.put_new(opts, :scope_param, "org")
  end

  @impl true
  def call(%Plug.Conn{} = conn, opts) do
    scope_param = Keyword.fetch!(opts, :scope_param)
    error_handler = Keyword.fetch!(opts, :error_handler)
    organizations = Keyword.fetch!(opts, :organizations)
    config = organizations.__sigra_org_config__()

    scope = conn.assigns[:current_scope]
    slug = conn.params[scope_param] || conn.params[to_string(scope_param)]

    cond do
      is_nil(scope) or is_nil(scope.user) ->
        halt_not_found(conn, error_handler, opts)

      is_nil(slug) ->
        halt_not_found(conn, error_handler, opts)

      true ->
        case resolve(config, scope, slug) do
          {:ok, org, membership} ->
            conn
            |> assign_scope(org, membership, opts)
            |> maybe_refresh_session_pointer(scope, org, opts)

          {:redirect, new_slug} ->
            conn
            |> redirect_to_canonical(slug, new_slug)
            |> Plug.Conn.halt()

          :not_found ->
            halt_not_found(conn, error_handler, opts)
        end
    end
  end

  defp resolve(config, scope, slug) do
    with org when not is_nil(org) <- Organizations.get_organization_by_slug(config, slug),
         membership when not is_nil(membership) <- Organizations.get_membership(config, scope.user, org) do
      {:ok, org, membership}
    else
      _ -> resolve_alias(config, slug)
    end
  end

  defp resolve_alias(config, slug) do
    case Organizations.get_active_slug_alias(config, slug) do
      nil ->
        :not_found

      alias_row ->
        case Organizations.fetch_organization(config, alias_row.organization_id) do
          {:ok, current_org} -> {:redirect, current_org.slug}
          {:error, :not_found} -> :not_found
        end
    end
  end

  defp assign_scope(conn, org, membership, opts) do
    scope_module = Keyword.fetch!(opts, :scope_module)
    scope = conn.assigns.current_scope
    new_scope = scope_module.put_active_organization(scope, org, membership)
    Plug.Conn.assign(conn, :current_scope, new_scope)
  end

  defp maybe_refresh_session_pointer(conn, old_scope, url_org, opts) do
    current_id = old_scope.active_organization && old_scope.active_organization.id

    if current_id != url_org.id do
      case Sigra.Plug.PutActiveOrganization.call(conn, url_org, opts) do
        {:ok, refreshed_conn} -> refreshed_conn
        {:error, _reason} -> conn
      end
    else
      conn
    end
  end

  defp redirect_to_canonical(conn, old_slug, new_slug) do
    # Single-hop redirect: replace the old slug segment in the path and
    # the `org` query param (if present) with the current canonical
    # slug. This is single-hop by construction because the redirect
    # target is resolved through fetch_organization to the live org,
    # not via alias chain (Phase 16 D-13 / T-16-01-08).
    new_path = String.replace(conn.request_path, old_slug, new_slug)

    query =
      case conn.query_string do
        "" ->
          ""

        qs ->
          rewritten = String.replace(qs, "org=" <> old_slug, "org=" <> new_slug)
          "?" <> rewritten
      end

    conn
    |> Plug.Conn.put_resp_header("location", new_path <> query)
    |> Plug.Conn.resp(301, "")
  end

  defp halt_not_found(conn, error_handler, opts) do
    conn
    |> error_handler.auth_error(:not_found, opts)
    |> Plug.Conn.halt()
  end
end
