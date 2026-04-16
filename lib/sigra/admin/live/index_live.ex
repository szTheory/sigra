defmodule Sigra.Admin.Live.IndexLive do
  @moduledoc """
  Foundation global admin entry LiveView.

  Phase 27 keeps this surface intentionally thin: it consumes the resolved
  admin scope, assigns a page title, and renders placeholder content through
  the host-owned admin shell layout.
  """

  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    admin_scope = socket.assigns.admin_scope

    {:ok,
     socket
     |> assign(:admin_scope, admin_scope)
     |> assign(:page_title, "Admin")
     |> assign(:heading, "Global admin")
     |> assign(
       :body,
       "Open a global admin destination or intentionally enter an organization scope."
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
          {admin_scope_summary(@admin_scope)}
        </p>
      </div>
    </section>
    """
  end

  defp admin_scope_summary(%{mode: :global}), do: "Global"
  defp admin_scope_summary(_), do: "Unknown"
end
