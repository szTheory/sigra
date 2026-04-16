defmodule <%= web_module %>.Components.AdminShell do
  @moduledoc """
  Host-owned admin shell seam.
  """

  use <%= web_module %>, :html

  attr :scope_label, :string, default: "Global"
  attr :active_scope_note, :string, default: "active scope"
  slot :inner_block, required: true

  def admin_shell(assigns) do
    ~H"""
    <section class="min-h-screen bg-base-100 text-base-content">
      <header class="sticky top-0 z-20 border-b border-base-300 bg-base-200">
        <div class="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3">
          <div class="flex items-center gap-2">
            <span class="text-sm font-semibold uppercase tracking-normal">Admin</span>
            <span class="badge badge-primary">{@scope_label}</span>
            <span class="badge badge-ghost">{@active_scope_note}</span>
          </div>
          <div class="flex items-center gap-2">
            <span class="badge badge-outline">Global</span>
            <button type="button" class="btn btn-ghost btn-sm">Open admin</button>
          </div>
        </div>
      </header>

      <div class="mx-auto flex max-w-7xl flex-col gap-6 px-4 py-6 lg:flex-row">
        <aside class="hidden w-64 shrink-0 lg:block">
          <nav aria-label="Admin navigation" class="menu rounded-box bg-base-200 p-2">
            <li><a class="active">Overview</a></li>
            <li><a>Organizations</a></li>
            <li><a>Audit</a></li>
          </nav>
        </aside>

        <main class="min-w-0 flex-1">
          <%= render_slot(@inner_block) %>
        </main>

        <nav
          aria-label="Admin bottom navigation"
          class="btm-nav border-t border-base-300 bg-base-200 lg:hidden"
        >
          <a class="active">Overview</a>
          <a>Users</a>
          <a>Audit</a>
        </nav>
      </div>
    </section>
    """
  end
end
