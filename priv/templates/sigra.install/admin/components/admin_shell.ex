defmodule <%= web_module %>.Components.AdminShell do
  @moduledoc """
  Host-owned admin shell seam.
  """

  use <%= web_module %>, :html

  attr :admin_scope, :map, required: true
  attr :current_scope, :map, default: nil
  attr :page_title, :string, default: nil
  attr :admin_breadcrumbs, :list, default: nil
  slot :special_session
  slot :inner_block, required: true

  def admin_shell(assigns) do
    assigns =
      assign(
        assigns,
        :breadcrumb_items,
        breadcrumb_items(assigns.admin_scope, assigns.page_title, assigns.admin_breadcrumbs)
      )

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
            <.admin_link
              href={overview_link(@admin_scope)}
              live={same_admin_session?(@admin_scope, overview_link(@admin_scope))}
              class="sg-brand-mark"
              aria-label="Sigra admin overview"
            >
              <span class="sg-brand-mark__lockup" aria-hidden="true">
                <img
                  class="sg-brand-mark__image sg-brand-mark__image--light"
                  src={~p"/images/sigra-logo-primary.svg"}
                  alt=""
                  width="188"
                  height="54"
                  decoding="async"
                />
                <img
                  class="sg-brand-mark__image sg-brand-mark__image--dark"
                  src={~p"/images/sigra-logo-primary-dark.svg"}
                  alt=""
                  width="188"
                  height="54"
                  decoding="async"
                />
              </span>
              <span class="sg-brand-mark__section">Admin</span>
            </.admin_link>
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

            <.admin_link
              :if={show_global_link?(@admin_scope) and not global_active?(@admin_scope)}
              href={~p"/admin"}
              live={same_admin_session?(@admin_scope, ~p"/admin")}
              class="sg-btn sg-btn--ghost sg-btn--sm"
            >
              Exit to global
            </.admin_link>
          </div>
        </div>

        <.impersonation_banner :if={impersonating?(@current_scope)} current_scope={@current_scope} />
        <span
          class="sg-admin-loading-bar"
          data-sg-admin-loading-bar
          aria-hidden="true"
        />
      </header>

      <div class="sg-container sg-admin-content">
        <nav class="sg-admin-crumbs" aria-label="Breadcrumb">
          <ol class="sg-breadcrumb">
            <li :for={{item, index} <- Enum.with_index(@breadcrumb_items)}>
              <span class="sg-breadcrumb__segment">
                <.admin_link
                  :if={breadcrumb_link?(item, index, @breadcrumb_items)}
                  class="sg-breadcrumb__item"
                  href={item.href}
                  live={same_admin_session?(@admin_scope, item.href)}
                >
                  {item.label}
                </.admin_link>
                <span
                  :if={!breadcrumb_link?(item, index, @breadcrumb_items)}
                  class="sg-breadcrumb__item"
                  aria-current={if breadcrumb_current?(index, @breadcrumb_items), do: "page"}
                >
                  {item.label}
                </span>
                <span
                  :if={!breadcrumb_current?(index, @breadcrumb_items)}
                  class="sg-breadcrumb__sep"
                  aria-hidden="true"
                >/</span>
              </span>
            </li>
          </ol>
        </nav>

        <div class="sg-admin-body">
          <aside class="sg-admin-sidebar">
            <nav aria-label="Admin navigation" class="sg-stack">
              <div class="sg-nav-card">
                <p class="sg-nav-title">Overviews</p>
                <ul class="sg-stack sg-stack--2">
                  <li :if={show_global_link?(@admin_scope)}>
                    <.admin_link
                      class={nav_item_class(overview_active?(@page_title) and global_active?(@admin_scope))}
                      href={~p"/admin"}
                      live={same_admin_session?(@admin_scope, ~p"/admin")}
                    >
                      Global overview
                    </.admin_link>
                  </li>
                  <li :if={organization_link(@admin_scope)}>
                    <.admin_link
                      class={nav_item_class(overview_active?(@page_title) and organization_active?(@admin_scope))}
                      href={organization_link(@admin_scope)}
                      live={same_admin_session?(@admin_scope, organization_link(@admin_scope))}
                    >
                      Organization overview
                    </.admin_link>
                  </li>
                </ul>
              </div>

              <div class="sg-nav-card">
                <p class="sg-nav-title">Workspace</p>
                <ul class="sg-stack sg-stack--2">
                  <li>
                    <.admin_link
                      class={nav_item_class(users_active?(@page_title))}
                      href={users_link(@admin_scope)}
                      live={same_admin_session?(@admin_scope, users_link(@admin_scope))}
                    >
                      Users
                    </.admin_link>
                  </li>
                  <li>
                    <.admin_link
                      class={nav_item_class(audit_active?(@page_title))}
                      href={audit_link(@admin_scope)}
                      live={same_admin_session?(@admin_scope, audit_link(@admin_scope))}
                    >
                      Audit
                    </.admin_link>
                  </li>
                  <li>
                    <.admin_link
                      class={nav_item_class(branding_active?(@page_title))}
                      href={branding_link(@admin_scope)}
                      live={same_admin_session?(@admin_scope, branding_link(@admin_scope))}
                    >
                      Branding
                    </.admin_link>
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
        <.admin_link
          href={overview_link(@admin_scope)}
          live={same_admin_session?(@admin_scope, overview_link(@admin_scope))}
          class={["sg-bottom-nav__item", bottom_nav_class(overview_active?(@page_title))]}
        >
          <span>{scope_label(@admin_scope)}</span>
        </.admin_link>
        <.admin_link
          href={users_link(@admin_scope)}
          live={same_admin_session?(@admin_scope, users_link(@admin_scope))}
          class={["sg-bottom-nav__item", bottom_nav_class(users_active?(@page_title))]}
        >
          <span>Users</span>
        </.admin_link>
        <.admin_link
          href={audit_link(@admin_scope)}
          live={same_admin_session?(@admin_scope, audit_link(@admin_scope))}
          class={["sg-bottom-nav__item", bottom_nav_class(audit_active?(@page_title))]}
        >
          <span>Audit</span>
        </.admin_link>
        <.admin_link
          href={branding_link(@admin_scope)}
          live={same_admin_session?(@admin_scope, branding_link(@admin_scope))}
          class={["sg-bottom-nav__item", bottom_nav_class(branding_active?(@page_title))]}
        >
          <span>Brand</span>
        </.admin_link>
      </nav>
    </section>
    """
  end

  attr :href, :string, required: true
  attr :class, :any, default: nil
  attr :live, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  defp admin_link(assigns) do
    ~H"""
    <.link :if={@live} navigate={@href} class={@class} {@rest}>
      {render_slot(@inner_block)}
    </.link>
    <a :if={!@live} href={@href} class={@class} {@rest}>
      {render_slot(@inner_block)}
    </a>
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
        <.admin_link
          :for={target <- @targets}
          href={target.href}
          class="sg-scope-switch__item"
          live={same_admin_session?(@admin_scope, target.href)}
          aria-current={to_string(target.current?)}
        >
          {target.label}
        </.admin_link>
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

  defp breadcrumb_items(admin_scope, page_title, admin_breadcrumbs)
       when is_list(admin_breadcrumbs) do
    admin_breadcrumbs
    |> Enum.map(&normalize_breadcrumb/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> fallback_breadcrumb_items(admin_scope, page_title)
      items -> items
    end
  end

  defp breadcrumb_items(admin_scope, page_title, _admin_breadcrumbs) do
    fallback_breadcrumb_items(admin_scope, page_title)
  end

  defp fallback_breadcrumb_items(admin_scope, page_title) do
    if overview_active?(page_title) do
      [%{label: breadcrumb_label(page_title), href: nil}]
    else
      [
        %{label: "Overview", href: overview_link(admin_scope)},
        %{label: page_title || "Page", href: nil}
      ]
    end
  end

  defp normalize_breadcrumb(%{} = breadcrumb) do
    label = Map.get(breadcrumb, :label) || Map.get(breadcrumb, "label")
    href = Map.get(breadcrumb, :href) || Map.get(breadcrumb, "href")

    cond do
      not is_binary(label) or label == "" -> nil
      is_binary(href) and href != "" -> %{label: label, href: href}
      true -> %{label: label, href: nil}
    end
  end

  defp normalize_breadcrumb(_breadcrumb), do: nil

  defp breadcrumb_link?(%{href: href}, index, items) when is_binary(href) do
    not breadcrumb_current?(index, items)
  end

  defp breadcrumb_link?(_item, _index, _items), do: false

  defp breadcrumb_current?(index, items), do: index == length(items) - 1

  defp breadcrumb_label(title) when is_binary(title) do
    if overview_active?(title), do: "Overview", else: title
  end

  defp breadcrumb_label(_), do: "Overview"

  defp same_admin_session?(%{mode: :global}, href) when is_binary(href) do
    (href == "/admin" or String.starts_with?(href, "/admin/")) and
      not String.starts_with?(href, "/admin/organizations/")
  end

  defp same_admin_session?(%{mode: :organization, organization_slug: slug}, href)
       when is_binary(slug) and is_binary(href) do
    prefix = "/admin/organizations/#{slug}"
    href == prefix or String.starts_with?(href, prefix <> "/")
  end

  defp same_admin_session?(_admin_scope, _href), do: false

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
