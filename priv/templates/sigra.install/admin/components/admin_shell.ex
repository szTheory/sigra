defmodule <%= web_module %>.Components.AdminShell do
  @moduledoc """
  Host-owned admin shell seam.
  """

  use <%= web_module %>, :html

  attr :admin_scope, :map, required: true
  attr :current_scope, :map, default: nil
  attr :page_title, :string, default: nil
  slot :special_session
  slot :inner_block, required: true

  def admin_shell(assigns) do
    ~H"""
    <section class="sg-admin-shell min-h-screen bg-base-100 text-base-content">
      <header class="sg-admin-topbar sticky top-0 border-b border-base-300 bg-base-200/95 backdrop-blur">
        <div class="sg-admin-topbar-inner mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 sm:px-6 lg:px-8">
          <div class="flex min-w-0 items-center gap-3">
            <a href={overview_link(@admin_scope)} class="sg-brand-mark text-sm font-semibold">
              <span>Admin</span>
            </a>
            <span class={scope_chip_class(@admin_scope)}>{scope_label(@admin_scope)}</span>
          </div>

          <div class="flex items-center gap-2">
            <.scope_switch_link href={users_link(@admin_scope)} active={users_active?(@page_title)}>
              Support users
            </.scope_switch_link>
            <.scope_switch_link
              :if={show_global_link?(@admin_scope)}
              href={~p"/admin"}
              active={overview_active?(@page_title) and global_active?(@admin_scope)}
            >
              Global overview
            </.scope_switch_link>
            <.scope_switch_link
              :if={organization_link(@admin_scope)}
              href={organization_link(@admin_scope)}
              active={overview_active?(@page_title) and organization_active?(@admin_scope)}
            >
              Organization overview
            </.scope_switch_link>
            <.scope_switch_link href={audit_link(@admin_scope)} active={audit_active?(@page_title)}>
              Audit evidence
            </.scope_switch_link>
          </div>
        </div>

        <.impersonation_banner :if={impersonating?(@current_scope)} current_scope={@current_scope} />
      </header>

      <div class="mx-auto flex max-w-7xl gap-6 px-4 py-6 pb-24 sm:px-6 lg:px-8">
        <aside class="hidden w-64 shrink-0 lg:block">
          <nav aria-label="Admin navigation" class="space-y-4">
            <div class="sg-nav-card rounded-lg bg-base-200 p-3">
              <p class="sg-nav-title mb-2 text-xs font-semibold uppercase text-base-content/60">Operations</p>
              <ul class="menu gap-1 p-0">
                <li>
                  <a
                    class={nav_item_class(users_active?(@page_title))}
                    href={users_link(@admin_scope)}
                  >
                    Support users
                  </a>
                </li>
                <li>
                  <a class={nav_item_class(audit_active?(@page_title))} href={audit_link(@admin_scope)}>
                    Audit evidence
                  </a>
                </li>
              </ul>
            </div>

            <div class="sg-nav-card rounded-lg bg-base-200 p-3">
              <p class="sg-nav-title mb-2 text-xs font-semibold uppercase text-base-content/60">Scope</p>
              <ul class="menu gap-1 p-0">
                <li>
                  <a
                    :if={show_global_link?(@admin_scope)}
                    class={nav_item_class(overview_active?(@page_title) and global_active?(@admin_scope))}
                    href={~p"/admin"}
                  >
                    Global overview
                  </a>
                </li>
                <li :if={organization_link(@admin_scope)}>
                  <a
                    class={nav_item_class(overview_active?(@page_title) and organization_active?(@admin_scope))}
                    href={organization_link(@admin_scope)}
                  >
                    Organization overview
                  </a>
                </li>
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
        class="sg-bottom-nav btm-nav border-t border-base-300 bg-base-200 lg:hidden"
      >
        <a
          href={users_link(@admin_scope)}
          class={bottom_nav_class(users_active?(@page_title))}
        >
          <span class="btm-nav-label">Users</span>
        </a>
        <a
          :if={show_global_link?(@admin_scope)}
          href={~p"/admin"}
          class={bottom_nav_class(overview_active?(@page_title) and global_active?(@admin_scope))}
        >
          <span class="btm-nav-label">Home</span>
        </a>
        <a
          :if={organization_link(@admin_scope)}
          href={organization_link(@admin_scope)}
          class={bottom_nav_class(overview_active?(@page_title) and organization_active?(@admin_scope))}
        >
          <span class="btm-nav-label">Org</span>
        </a>
        <a href={audit_link(@admin_scope)} class={bottom_nav_class(audit_active?(@page_title))}>
          <span class="btm-nav-label">Audit</span>
        </a>
      </nav>
    </section>
    """
  end

  attr :current_scope, :map, required: true

  def impersonation_banner(assigns) do
    ~H"""
    <section class="sg-impersonation border-t border-base-300 bg-warning/15 text-warning-content">
      <div class="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-3 sm:px-6 lg:px-8">
        <div class="space-y-1 text-sm">
          <p class="font-semibold">Impersonating {user_label(@current_scope.user)}</p>
          <p>Signed in as {user_label(@current_scope.impersonating_from)}</p>
        </div>

        <form method="post" action={~p"/impersonation"}>
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <button type="submit" class="sg-press btn btn-sm btn-warning">End impersonation</button>
        </form>
      </div>
    </section>
    """
  end

  attr :href, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp scope_switch_link(assigns) do
    ~H"""
    <a href={@href} class={["sg-top-action btn btn-sm", if(@active, do: "btn-primary", else: "btn-ghost")]}>
      {render_slot(@inner_block)}
    </a>
    """
  end

  defp scope_label(%{mode: :global}), do: "Global"
  defp scope_label(%{mode: :organization, organization: %{name: name}}), do: name
  defp scope_label(%{mode: :organization, organization_slug: slug}) when is_binary(slug), do: slug
  defp scope_label(_), do: "Unknown scope"

  defp scope_chip_class(%{mode: :global}), do: "sg-scope-pill badge badge-primary"
  defp scope_chip_class(%{mode: :organization}), do: "sg-scope-pill badge badge-secondary"
  defp scope_chip_class(_), do: "sg-scope-pill badge badge-ghost"

  defp impersonating?(%{impersonating_from: %_{}}), do: true
  defp impersonating?(_), do: false

  defp user_label(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp user_label(%{email: email}) when is_binary(email), do: email
  defp user_label(%{id: id}) when is_binary(id), do: id
  defp user_label(_user), do: "Unknown user"

  defp show_global_link?(%{mode: :global}), do: true
  defp show_global_link?(%{platform_admin?: true}), do: true
  defp show_global_link?(_), do: false

  defp overview_link(%{mode: :organization, organization_slug: slug}) when is_binary(slug) do
    ~p"/admin/organizations/#{slug}"
  end

  defp overview_link(_), do: ~p"/admin"

  defp organization_link(%{mode: :organization, organization_slug: slug}) when is_binary(slug) do
    ~p"/admin/organizations/#{slug}"
  end

  defp organization_link(_), do: nil

  defp users_link(%{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: ~p"/admin/organizations/#{slug}/users"

  defp users_link(_admin_scope), do: ~p"/admin/users"

  defp audit_link(%{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/audit"

  defp audit_link(_admin_scope), do: "/admin/audit"

  defp users_active?(title) when is_binary(title) do
    title = String.downcase(title)
    String.contains?(title, "user") and not String.contains?(title, "audit")
  end

  defp users_active?(_), do: false

  defp audit_active?(title) when is_binary(title), do: String.contains?(String.downcase(title), "audit")
  defp audit_active?(_), do: false

  defp overview_active?(title) when is_binary(title), do: String.contains?(String.downcase(title), "overview")
  defp overview_active?(_), do: false

  defp global_active?(%{mode: :global}), do: true
  defp global_active?(_), do: false

  defp organization_active?(%{mode: :organization}), do: true
  defp organization_active?(_), do: false

  defp nav_item_class(true), do: "sg-nav-link active rounded-md"
  defp nav_item_class(false), do: "sg-nav-link rounded-md"

  defp bottom_nav_class(true), do: "active"
  defp bottom_nav_class(false), do: ""
end
