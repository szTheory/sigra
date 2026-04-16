defmodule ExampleWeb.Components.AdminShell do
  @moduledoc """
  Host-owned admin shell seam.
  """

  use ExampleWeb, :html

  attr :admin_scope, :map, required: true
  attr :current_scope, :map, default: nil
  slot :special_session
  slot :inner_block, required: true

  def admin_shell(assigns) do
    ~H"""
    <section class="min-h-screen bg-base-100 text-base-content">
      <header class="sticky top-0 z-30 border-b border-base-300 bg-base-200/95 backdrop-blur">
        <div class="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-3 sm:px-6 lg:px-8">
          <div class="flex items-center gap-2">
            <span class="text-sm font-semibold">Admin</span>
            <span class={scope_chip_class(@admin_scope)}>{scope_label(@admin_scope)}</span>
            <%= if render_special_session?(@special_session, @current_scope) do %>
              <span class="badge badge-outline">{special_session_label(@current_scope)}</span>
            <% end %>
          </div>

          <div class="flex items-center gap-2">
            <.scope_switch_link
              :if={show_global_link?(@admin_scope)}
              href={~p"/admin"}
              active={global_active?(@admin_scope)}
            >
              Global
            </.scope_switch_link>
            <.scope_switch_link
              :if={organization_link(@admin_scope)}
              href={organization_link(@admin_scope)}
              active={organization_active?(@admin_scope)}
            >
              Organization
            </.scope_switch_link>
          </div>
        </div>
      </header>

      <div class="mx-auto flex max-w-7xl gap-6 px-4 py-6 pb-24 sm:px-6 lg:px-8">
        <aside class="hidden w-64 shrink-0 lg:block">
          <nav aria-label="Admin navigation" class="space-y-4">
            <div class="rounded-lg bg-base-200 p-3">
              <p class="mb-2 text-xs font-semibold uppercase text-base-content/60">Overview</p>
              <ul class="menu gap-1 p-0">
                <li>
                  <a class={nav_item_class(global_active?(@admin_scope))} href={~p"/admin"}>Global</a>
                </li>
                <li :if={organization_link(@admin_scope)}>
                  <a
                    class={nav_item_class(organization_active?(@admin_scope))}
                    href={organization_link(@admin_scope)}
                  >
                    Organization
                  </a>
                </li>
              </ul>
            </div>

            <div class="rounded-lg bg-base-200 p-3">
              <p class="mb-2 text-xs font-semibold uppercase text-base-content/60">Operations</p>
              <ul class="menu gap-1 p-0">
                <li>
                  <a
                    class={nav_item_class(users_active?(@admin_scope))}
                    href={users_link(@admin_scope)}
                  >
                    Users
                  </a>
                </li>
                <li><span class="text-base-content/60">Audit</span></li>
              </ul>
            </div>
          </nav>
        </aside>

        <main class="min-w-0 flex-1 space-y-4">
          {render_slot(@inner_block)}
        </main>
      </div>

      <nav
        aria-label="Admin bottom nav"
        class="btm-nav border-t border-base-300 bg-base-200 lg:hidden"
      >
        <a href={~p"/admin"} class={bottom_nav_class(global_active?(@admin_scope))}>
          <span class="btm-nav-label">Global</span>
        </a>
        <a
          href={users_link(@admin_scope)}
          class={bottom_nav_class(users_active?(@admin_scope))}
        >
          <span class="btm-nav-label">Users</span>
        </a>
        <a
          :if={organization_link(@admin_scope)}
          href={organization_link(@admin_scope)}
          class={bottom_nav_class(organization_active?(@admin_scope))}
        >
          <span class="btm-nav-label">Organization</span>
        </a>
        <a class="pointer-events-none text-base-content/50">
          <span class="btm-nav-label">Audit</span>
        </a>
      </nav>
    </section>
    """
  end

  attr :href, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp scope_switch_link(assigns) do
    ~H"""
    <a href={@href} class={["btn btn-sm", if(@active, do: "btn-primary", else: "btn-ghost")]}>
      {render_slot(@inner_block)}
    </a>
    """
  end

  defp scope_label(%{mode: :global}), do: "Global"
  defp scope_label(%{mode: :organization, organization: %{name: name}}), do: name
  defp scope_label(%{mode: :organization, organization_slug: slug}) when is_binary(slug), do: slug
  defp scope_label(_), do: "Unknown scope"

  defp scope_chip_class(%{mode: :global}), do: "badge badge-primary"
  defp scope_chip_class(%{mode: :organization}), do: "badge badge-secondary"
  defp scope_chip_class(_), do: "badge badge-ghost"

  defp render_special_session?([], current_scope),
    do: not is_nil(special_session_label(current_scope))

  defp render_special_session?(_slot, _current_scope), do: true

  defp special_session_label(%{impersonating_from: %_{}}), do: "Special session"
  defp special_session_label(_), do: nil

  defp show_global_link?(%{mode: :global}), do: true
  defp show_global_link?(%{platform_admin?: true}), do: true
  defp show_global_link?(_), do: false

  defp organization_link(%{mode: :organization, organization_slug: slug}) when is_binary(slug) do
    ~p"/admin/organizations/#{slug}"
  end

  defp organization_link(_), do: nil

  defp global_active?(%{mode: :global}), do: true
  defp global_active?(_), do: false

  defp organization_active?(%{mode: :organization}), do: true
  defp organization_active?(_), do: false

  defp users_link(%{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: ~p"/admin/organizations/#{slug}/users"

  defp users_link(_admin_scope), do: ~p"/admin/users"

  defp users_active?(_admin_scope), do: true

  defp nav_item_class(true), do: "active rounded-md"
  defp nav_item_class(false), do: "rounded-md"

  defp bottom_nav_class(true), do: "active"
  defp bottom_nav_class(false), do: ""
end
