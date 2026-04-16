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
    organization_name = admin_scope.organization && admin_scope.organization.name

    {:ok,
     socket
     |> assign(:admin_scope, admin_scope)
     |> assign(:page_title, organization_name || "Organization admin")
     |> assign(:heading, organization_name || "Organization admin")
     |> assign(
       :body,
       "This organization-scoped admin surface is ready for later user operations without losing the active scope."
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-4">
      <div class="space-y-2">
        <h1 class="text-2xl font-semibold">{@heading}</h1>
        <p class="text-sm text-base-content/70">{@body}</p>
      </div>

      <div class="rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm">
        <p class="text-sm font-semibold">Active scope</p>
        <p class="mt-2 text-sm text-base-content/70">
          {organization_scope_summary(@admin_scope)}
        </p>
      </div>
    </section>
    """
  end

  defp organization_scope_summary(%{organization: %{name: name}}), do: name
  defp organization_scope_summary(%{organization_slug: slug}) when is_binary(slug), do: slug
  defp organization_scope_summary(_), do: "Unknown organization"
end
