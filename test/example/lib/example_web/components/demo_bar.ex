defmodule ExampleWeb.Components.DemoBar do
  @moduledoc """
  Single shared demo band component used across all three demo surfaces:
  the login page (`SessionHTML`), the sudo page (`SudoHTML`), and the
  authenticated app layout (`Layouts.demo_persona_switch/1`).

  Replaces the three previously-divergent inline `vt-demo-switch` bars with one
  `demo_bar/1` function and a single `data-testid="demo-bar"` hook.

  This is intentionally a SEPARATE component from
  `AdminShell.impersonation_banner/1` — different CSS namespace
  (`vt-demo-switch`, never `sg-impersonation*`), different copy (never says
  "impersonate").

  This function carries NO compile-env gate of its own. Dev-gating lives at the
  call sites: the login/sudo `:if={@demo_personas != []}` guards, the authed
  `:if={@dev_routes? && @current_scope}` guard, and the controller
  `Application.compile_env(:example, :dev_routes)` gates that return a nil
  persona + `[]` options under a non-dev build — so `mix test`
  (`dev_routes=false`) renders no bar at all.
  """
  use ExampleWeb, :html

  @doc """
  Renders the unified demo persona band.

  ## Attributes

  - `persona` — enriched persona map (`%{key, display_name, email, password,
    feature}`) or `nil`. When present, the band shows the persona identity and
    (optionally) a Fill-password button.
  - `personas` — list of `%{key, display_name}` options for the switch dropdown.
    Empty list renders an empty dropdown (call sites guard rendering the whole
    band on `@demo_personas != []`).
  - `fill` — when true and a persona is present, renders the Fill-password
    button carrying `data-demo-password` (dev-only surface).
  - `centered` — when true, adds the `vt-demo-switch--login` modifier that
    centers the band (login + sudo surfaces).
  """
  attr :persona, :map, default: nil
  attr :personas, :list, default: []
  attr :fill, :boolean, default: false
  attr :centered, :boolean, default: false

  def demo_bar(assigns) do
    ~H"""
    <div class={["vt-demo-switch", @centered && "vt-demo-switch--login"]} data-testid="demo-bar">
      <span class="vt-status-pill" title="Disposable demo accounts — never use in production">DEMO</span>
      <span :if={@persona} class="vt-demo-switch__identity">
        <strong class="vt-demo-switch__name">{@persona.display_name}</strong>
        <span :if={@persona.feature} class="vt-demo-switch__desc">{@persona.feature}</span>
        <code class="vt-code vt-code--copy">{@persona.email}</code>
      </span>
      <span :if={is_nil(@persona)} class="vt-demo-switch__label">Demo personas — never use in production</span>
      <button
        :if={@fill && @persona}
        type="button"
        class="vt-btn vt-btn--ghost"
        data-demo-fill-password
        data-demo-password={@persona.password}
      >
        Fill password
      </button>
      <select class="vt-demo-switch__select" data-demo-persona-switch aria-label="Switch demo persona">
        <option value="" disabled selected={is_nil(@persona)}>Switch persona…</option>
        <option :for={p <- @personas} value={p.key} selected={@persona && @persona.key == p.key}>
          {[p.display_name, p.tagline && " — #{p.tagline}"]}
        </option>
      </select>
    </div>
    """
  end
end
