defmodule Sigra.Admin.Live.OrganizationLive do
  @moduledoc """
  Foundation organization-scoped admin entry LiveView.

  This page stays intentionally minimal in Phase 27. It proves that the
  resolved admin scope reaches the LiveView and that the host-owned shell can
  keep organization context visible before user-operations pages exist.
  """

  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    admin_scope = socket.assigns.admin_scope
    slug = admin_scope.organization_slug || admin_scope.organization && admin_scope.organization.slug

    {:ok, redirect(socket, to: "/admin/organizations/#{slug}/users")}
  end
end
