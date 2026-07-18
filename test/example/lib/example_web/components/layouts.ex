defmodule ExampleWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ExampleWeb, :html

  import ExampleWeb.Components.AdminShell
  # Phase 16 D-27: organization switcher function component.
  import ExampleWeb.Components.OrgSwitcher

  alias Example.Demo.Personas

  # Compile-time gate for the dev-only "Demo personas" switch bar. Captured as
  # a module attribute (legal: Application.compile_env/2-3 can only be called
  # in the module body, never inside a function — including inside a ~H
  # template, which compiles as part of the enclosing function). Assigned
  # explicitly into `assigns` below so the template's `@dev_routes?` reads
  # `assigns.dev_routes?`, not a module attribute (HEEx `@name` always reads
  # assigns).
  @dev_routes? Application.compile_env(:example, :dev_routes, false)

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
    assigns = assign(assigns, :dev_routes?, @dev_routes?)

    ~H"""
    <header class="vt-app-header">
      <div class="vt-app-header__inner vt-app-container">
        <a href="/" class="vt-brand">
          <img src={~p"/images/tasklane-mark.svg"} width="36" height="36" alt="" class="vt-brand__mark" />
          <span>
            <span class="vt-brand__name" data-testid="app-name">Tasklane</span>
            <span class="vt-brand__tag">Work tracking for teams</span>
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
          <a :if={@current_scope} href={~p"/app"} class="vt-btn vt-btn--ghost">Dashboard</a>
          <.link
            :if={@current_scope}
            href={~p"/users/log_out"}
            method="delete"
            class="vt-btn vt-btn--ghost"
            data-testid="header-log-out"
          >
            Log out
          </.link>
        </div>
      </div>
    </header>

    <.impersonation_banner
      :if={@current_scope && @current_scope.impersonating_from}
      current_scope={@current_scope}
    />

    <.demo_persona_switch
      :if={@dev_routes? && @current_scope}
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

  @doc """
  Renders the dev-only "Demo personas" fast-switch bar for the authenticated
  app layout.

  This is intentionally a SEPARATE component from `AdminShell.impersonation_banner/1`
  — different module, different CSS namespace (`vt-demo-switch`, never
  `sg-impersonation*`), different copy (never says "impersonate"). Compiled
  out under `dev_routes=false` via the `:if` guard at the `app/1` call site
  (this function itself carries no gate — callers must guard it).
  """
  attr :current_scope, :map, required: true

  def demo_persona_switch(assigns) do
    display_names =
      Personas.all()
      |> Map.new(fn p -> {p.email |> String.split("@") |> hd(), p.display_name} end)

    assigns =
      assign(
        assigns,
        :featured,
        Enum.map(Personas.featured_keys(), &{&1, Map.fetch!(display_names, &1)})
      )

    ~H"""
    <div class="vt-demo-switch" data-testid="demo-persona-switch">
      <span class="vt-status-pill">DEMO</span>
      <span class="vt-demo-switch__label">Demo personas — switch account:</span>
      <a
        :for={{key, display_name} <- @featured}
        href={~p"/demo/use/#{key}"}
        class="vt-btn vt-btn--ghost"
      >
        {display_name}
      </a>
    </div>
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
