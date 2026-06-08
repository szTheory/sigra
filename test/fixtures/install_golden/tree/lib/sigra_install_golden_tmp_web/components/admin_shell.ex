defmodule SigraInstallGoldenTmpWeb.Components.AdminShell do
  @moduledoc """
  Host-owned admin shell seam.
  """

  use SigraInstallGoldenTmpWeb, :html

  attr :admin_scope, :map, required: true
  attr :current_scope, :map, default: nil
  attr :page_title, :string, default: nil
  slot :special_session
  slot :inner_block, required: true

  def admin_shell(assigns) do
    ~H"""
    <script>
      (function () {
        try {
          var value = window.localStorage && window.localStorage.getItem("sigra.admin.theme");
          var preference = value === "light" || value === "dark" ? value : "system";
          document.documentElement.setAttribute("data-sg-admin-js", "true");
          document.documentElement.setAttribute("data-sg-admin-theme-preference", preference);
          if (preference === "system") {
            document.documentElement.removeAttribute("data-sg-admin-theme");
          } else {
            document.documentElement.setAttribute("data-sg-admin-theme", preference);
          }
        } catch (err) {
          document.documentElement.setAttribute("data-sg-admin-js", "true");
          document.documentElement.setAttribute("data-sg-admin-theme-preference", "system");
          document.documentElement.removeAttribute("data-sg-admin-theme");
        }
      })();
    </script>
    <section class="sg-admin-shell" data-scope={scope_mode(@admin_scope)}>
      <header class="sg-admin-topbar">
        <div class="sg-admin-topbar-inner sg-container sg-cluster sg-cluster--between sg-cluster--3">
          <div class="sg-cluster sg-cluster--3">
            <a href={overview_link(@admin_scope)} class="sg-brand-mark" aria-label="Sigra admin overview">
              <svg
                class="sg-brand-mark__logo"
                viewBox="0 0 64 64"
                aria-hidden="true"
                focusable="false"
              >
                <path class="sg-brand-mark__rail-accent" d="M17 14v14M32 23v18M47 36v14" />
                <path class="sg-brand-mark__rail-ember" d="M17 36v14M47 14v14" />
                <path class="sg-brand-mark__core" d="M17 32h30" />
              </svg>
              <span class="sg-brand-mark__word">Sigra</span>
              <span class="sg-brand-mark__section">Admin</span>
            </a>
            <.scope_switcher admin_scope={@admin_scope} />
          </div>

          <div class="sg-cluster sg-cluster--2">
            <div
              id="admin-theme-switch"
              class="sg-theme-switch"
              phx-hook="ThemeSwitch"
              role="radiogroup"
              aria-label="Theme"
            >
              <button
                type="button"
                class="sg-theme-switch__button"
                role="radio"
                data-theme-value="light"
                aria-checked="false"
                tabindex="-1"
              >
                Light
              </button>
              <button
                type="button"
                class="sg-theme-switch__button"
                role="radio"
                data-theme-value="dark"
                aria-checked="false"
                tabindex="-1"
              >
                Dark
              </button>
              <button
                type="button"
                class="sg-theme-switch__button"
                role="radio"
                data-theme-value="system"
                aria-checked="true"
                tabindex="0"
              >
                System
              </button>
            </div>

            <button
              id="admin-cmdk"
              type="button"
              phx-hook="CmdK"
              class="sg-cmdk__trigger"
              aria-label="Open command palette"
              data-users-href={users_link(@admin_scope)}
              data-audit-href={audit_link(@admin_scope)}
              data-overview-href={overview_link(@admin_scope)}
              data-overview-label={scope_label(@admin_scope)}
            >
              <span>Jump to…</span>
              <span class="sg-cmdk__trigger-kbd" aria-hidden="true">⌘K</span>
            </button>

            <a
              :if={show_global_link?(@admin_scope) and not global_active?(@admin_scope)}
              href={~p"/admin"}
              class="sg-btn sg-btn--ghost sg-btn--sm"
            >
              Exit to global
            </a>
          </div>
        </div>

        <.impersonation_banner :if={impersonating?(@current_scope)} current_scope={@current_scope} />
      </header>

      <div class="sg-container sg-admin-content">
        <nav class="sg-admin-crumbs" aria-label="Breadcrumb">
          <ol class="sg-breadcrumb">
            <%= if overview_active?(@page_title) do %>
              <li>
                <span class="sg-breadcrumb__item" aria-current="page">{@page_title}</span>
              </li>
            <% else %>
              <li>
                <a class="sg-breadcrumb__item" href={overview_link(@admin_scope)}>
                  {scope_label(@admin_scope)}
                </a>
              </li>
              <li class="sg-breadcrumb__sep" aria-hidden="true">/</li>
              <li>
                <span class="sg-breadcrumb__item" aria-current="page">{@page_title}</span>
              </li>
            <% end %>
          </ol>
        </nav>

        <div class="sg-admin-body">
          <aside class="sg-admin-sidebar">
            <nav aria-label="Admin navigation" class="sg-stack">
              <div class="sg-nav-card">
                <p class="sg-nav-title">Overviews</p>
                <ul class="sg-stack sg-stack--2">
                  <li :if={show_global_link?(@admin_scope)}>
                    <a
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

              <div class="sg-nav-card">
                <p class="sg-nav-title">Workspace</p>
                <ul class="sg-stack sg-stack--2">
                  <li>
                    <a class={nav_item_class(users_active?(@page_title))} href={users_link(@admin_scope)}>
                      Users
                    </a>
                  </li>
                  <li>
                    <a class={nav_item_class(audit_active?(@page_title))} href={audit_link(@admin_scope)}>
                      Audit
                    </a>
                  </li>
                  <li>
                    <a class={nav_item_class(branding_active?(@page_title))} href={branding_link(@admin_scope)}>
                      Branding
                    </a>
                  </li>
                </ul>
              </div>
            </nav>
          </aside>

          <main class="sg-admin-main sg-stack sg-stack--5">
            {render_slot(@inner_block)}
          </main>
        </div>
      </div>

      <nav aria-label="Admin bottom nav" class="sg-bottom-nav sg-show-mobile">
        <a
          href={overview_link(@admin_scope)}
          class={["sg-bottom-nav__item", bottom_nav_class(overview_active?(@page_title))]}
        >
          <span>{scope_label(@admin_scope)}</span>
        </a>
        <a
          href={users_link(@admin_scope)}
          class={["sg-bottom-nav__item", bottom_nav_class(users_active?(@page_title))]}
        >
          <span>Users</span>
        </a>
        <a
          href={audit_link(@admin_scope)}
          class={["sg-bottom-nav__item", bottom_nav_class(audit_active?(@page_title))]}
        >
          <span>Audit</span>
        </a>
        <a
          href={branding_link(@admin_scope)}
          class={["sg-bottom-nav__item", bottom_nav_class(branding_active?(@page_title))]}
        >
          <span>Brand</span>
        </a>
      </nav>
    </section>
    """
  end

  attr :admin_scope, :map, required: true

  defp scope_switcher(assigns) do
    assigns = assign(assigns, :targets, scope_targets(assigns.admin_scope))

    ~H"""
    <details :if={length(@targets) > 1} class="sg-scope-switch">
      <summary class={scope_chip_class(@admin_scope)}>
        <span
          :if={@admin_scope.mode == :organization}
          class="sg-scope-pill__tenant"
          aria-hidden="true"
        >⌂</span>
        {scope_chip_label(@admin_scope)}
      </summary>
      <div class="sg-scope-switch__menu">
        <a
          :for={target <- @targets}
          href={target.href}
          class="sg-scope-switch__item"
          aria-current={to_string(target.current?)}
        >
          {target.label}
        </a>
      </div>
    </details>
    <span :if={length(@targets) <= 1} class={scope_chip_class(@admin_scope)}>
      <span
        :if={@admin_scope.mode == :organization}
        class="sg-scope-pill__tenant"
        aria-hidden="true"
      >⌂</span>
      {scope_chip_label(@admin_scope)}
    </span>
    """
  end

  attr :current_scope, :map, required: true

  def impersonation_banner(assigns) do
    ~H"""
    <section class="sg-impersonation">
      <div class="sg-impersonation__inner sg-container sg-cluster sg-cluster--between sg-cluster--3">
        <div class="sg-stack sg-stack--2">
          <p class="sg-impersonation__primary">Impersonating {user_label(@current_scope.user)}</p>
          <p>Signed in as {user_label(@current_scope.impersonating_from)}</p>
        </div>

        <form method="post" action={~p"/impersonation"}>
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <button type="submit" class="sg-btn sg-btn--danger sg-btn--sm">End impersonation</button>
        </form>
      </div>
    </section>
    """
  end

  defp scope_targets(admin_scope) do
    global =
      if show_global_link?(admin_scope) do
        [%{label: "Global overview", href: "/admin", current?: global_active?(admin_scope)}]
      else
        []
      end

    organization =
      case organization_link(admin_scope) do
        nil ->
          []

        href ->
          [
            %{
              label: "#{scope_label(admin_scope)} overview",
              href: href,
              current?: organization_active?(admin_scope)
            }
          ]
      end

    global ++ organization
  end

  defp scope_label(%{mode: :global}), do: "Global"
  defp scope_label(%{mode: :organization, organization: %{name: name}}), do: name
  defp scope_label(%{mode: :organization, organization_slug: slug}) when is_binary(slug), do: slug
  defp scope_label(_), do: "Unknown scope"

  defp scope_chip_class(_admin_scope), do: "sg-scope-pill"

  defp scope_mode(%{mode: :organization}), do: "organization"
  defp scope_mode(_), do: "global"

  defp scope_chip_label(%{mode: :organization} = s), do: "Org · " <> scope_label(s)
  defp scope_chip_label(s), do: scope_label(s)

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

  defp branding_link(_admin_scope), do: ~p"/admin/auth-branding"

  defp users_active?(title) when is_binary(title) do
    title = String.downcase(title)
    String.contains?(title, "user") and not String.contains?(title, "audit")
  end

  defp users_active?(_), do: false

  defp audit_active?(title) when is_binary(title),
    do: String.contains?(String.downcase(title), "audit")

  defp audit_active?(_), do: false

  defp branding_active?(title) when is_binary(title),
    do: String.contains?(String.downcase(title), "brand")

  defp branding_active?(_), do: false

  defp overview_active?(title) when is_binary(title),
    do: String.contains?(String.downcase(title), "overview")

  defp overview_active?(_), do: false

  defp global_active?(%{mode: :global}), do: true
  defp global_active?(_), do: false

  defp organization_active?(%{mode: :organization}), do: true
  defp organization_active?(_), do: false

  defp nav_item_class(true), do: "sg-nav-link active"
  defp nav_item_class(false), do: "sg-nav-link"

  defp bottom_nav_class(true), do: "active"
  defp bottom_nav_class(false), do: ""
end
