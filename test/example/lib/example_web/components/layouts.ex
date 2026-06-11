defmodule ExampleWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ExampleWeb, :html

  import ExampleWeb.Components.AdminShell
  # Phase 16 D-27: organization switcher function component.
  import ExampleWeb.Components.OrgSwitcher

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :user_organizations, :list,
    default: [],
    doc: "list of {organization, role} tuples for the current user (Phase 16 D-26)"

  attr :wide, :boolean, default: false
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="vt-app-header">
      <div class="vt-app-header__inner vt-app-container">
        <a href="/" class="vt-brand">
          <img src={~p"/images/vaultr-mark.svg"} width="36" height="36" alt="" class="vt-brand__mark" />
          <span>
            <span class="vt-brand__name" data-testid="app-name">Vaultr</span>
            <span class="vt-brand__tag">Fictional cohort app</span>
          </span>
        </a>
        <div class="vt-app-actions">
          <.org_switcher
            :if={@current_scope && @current_scope.active_organization}
            current_scope={@current_scope}
            user_organizations={@user_organizations}
            return_to="/"
          />
          <a :if={is_nil(@current_scope)} href={~p"/users/log_in"} class="vt-btn vt-btn--primary">
            Sign In <span aria-hidden="true">&rarr;</span>
          </a>
        </div>
      </div>
    </header>

    <.impersonation_banner
      :if={@current_scope && @current_scope.impersonating_from}
      current_scope={@current_scope}
    />

    <main class="vt-app-main">
      <div class={["vt-app-container", @wide && "vt-app-container--wide"]}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :current_scope, :map, default: nil
  attr :admin_scope, :map, default: nil
  attr :page_title, :string, default: nil
  attr :admin_breadcrumbs, :list, default: nil
  attr :inner_content, :any, default: nil

  def admin(assigns) do
    ~H"""
    <.admin_shell
      admin_scope={@admin_scope}
      current_scope={@current_scope}
      page_title={@page_title}
      admin_breadcrumbs={@admin_breadcrumbs}
    >
      {@inner_content}
    </.admin_shell>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
