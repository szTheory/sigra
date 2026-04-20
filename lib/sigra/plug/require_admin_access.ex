defmodule Sigra.Plug.RequireAdminAccess do
  @moduledoc """
  Resolves and enforces admin access at the Plug boundary.

  `/admin` and `/admin/organizations/:org` are distinct authorization paths.
  This plug converts the route intent into a `Sigra.Admin.Scope` and assigns it
  to the connection for downstream controller or mutation code.
  """

  @behaviour Plug

  alias Sigra.Admin.Scope
  alias Sigra.Organizations

  @impl Plug
  def init(opts) do
    _ = Keyword.fetch!(opts, :error_handler)
    _ = Keyword.fetch!(opts, :policy)

    mode = Keyword.get(opts, :mode, :global)

    unless mode in [:global, :organization] do
      raise ArgumentError,
            "Sigra.Plug.RequireAdminAccess :mode must be :global or :organization, got: #{inspect(mode)}"
    end

    if mode == :organization do
      _ = Keyword.fetch!(opts, :organizations)
    end

    opts
    |> Keyword.put(:mode, mode)
    |> Keyword.put_new(:org_param, "org")
    |> Keyword.put_new(:assign, :admin_scope)
  end

  @impl Plug
  def call(%Plug.Conn{} = conn, opts) do
    scope = conn.assigns[:current_scope]
    error_handler = Keyword.fetch!(opts, :error_handler)

    case resolve_requested_scope(scope, conn.params, opts) do
      {:ok, admin_scope} ->
        Plug.Conn.assign(conn, Keyword.fetch!(opts, :assign), admin_scope)

      {:error, :unauthenticated} ->
        conn
        |> error_handler.auth_error(:unauthenticated, opts)
        |> Plug.Conn.halt()

      {:error, :forbidden} ->
        conn
        |> error_handler.auth_error(:insufficient_scope, opts)
        |> Plug.Conn.halt()

      {:error, :not_found} ->
        conn
        |> error_handler.auth_error(:not_found, opts)
        |> Plug.Conn.halt()
    end
  end

  defp resolve_requested_scope(scope, params, opts) do
    case Keyword.fetch!(opts, :mode) do
      :global ->
        Scope.resolve(scope, nil, Keyword.fetch!(opts, :policy))

      :organization ->
        org_param = Keyword.fetch!(opts, :org_param)
        slug = params[org_param] || params[to_string(org_param)]
        organizations = Keyword.fetch!(opts, :organizations)
        config = organizations.__sigra_org_config__()

        requested_org =
          if is_binary(slug), do: Organizations.get_organization_by_slug(config, slug), else: nil

        Scope.resolve(scope, requested_org || slug, Keyword.fetch!(opts, :policy))
    end
  end
end
