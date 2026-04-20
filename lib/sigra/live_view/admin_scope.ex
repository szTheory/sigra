defmodule Sigra.LiveView.AdminScope do
  @moduledoc """
  LiveView `on_mount` parity for admin scope enforcement.

  Live navigation inside a `live_session` bypasses the Plug pipeline, so this
  module must resolve the same admin scope contract on every mount.
  """

  alias Sigra.Admin.Scope
  alias Sigra.Organizations

  @doc """
  `on_mount/4` callback for admin route protection.
  """
  def on_mount(opts, params, _session, socket) when is_list(opts) do
    login_path = Keyword.get(opts, :login_path, "/users/log_in")
    assign_key = Keyword.get(opts, :assign, :admin_scope)
    scope = socket.assigns[:current_scope]

    case resolve_requested_scope(scope, params, opts) do
      {:ok, admin_scope} ->
        {:cont, put_in(socket.assigns[assign_key], admin_scope)}

      {:error, :unauthenticated} ->
        {:halt, put_in(socket.assigns[:sigra_redirect_to], login_path)}

      {:error, :forbidden} ->
        {:halt, put_in(socket.assigns[:sigra_admin_forbidden], true)}

      {:error, :not_found} ->
        {:halt, put_in(socket.assigns[:sigra_not_found], true)}
    end
  end

  defp resolve_requested_scope(scope, params, opts) do
    case Keyword.fetch!(opts, :mode) do
      :global ->
        Scope.resolve(scope, nil, Keyword.fetch!(opts, :policy))

      :organization ->
        organizations = Keyword.fetch!(opts, :organizations)
        config = organizations.__sigra_org_config__()
        org_param = Keyword.get(opts, :org_param, "org")
        slug = params[org_param] || params[to_string(org_param)]

        requested_org =
          if is_binary(slug), do: Organizations.get_organization_by_slug(config, slug), else: nil

        Scope.resolve(scope, requested_org || slug, Keyword.fetch!(opts, :policy))
    end
  end
end
