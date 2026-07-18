defmodule ExampleWeb.Demo.CredentialsLive do
  @moduledoc """
  Read-only LiveView that lists all demo persona credentials at `/demo/credentials`.

  Available only in development — the route is gated by `Application.compile_env(:example,
  :dev_routes)` and compiles out in test and prod builds.

  Allows evaluators to quickly copy persona credentials without digging through Seeds source.
  """
  use ExampleWeb, :live_view

  alias Example.Demo.Personas
  alias ExampleWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    credentials =
      Personas.all()
      |> Enum.map(fn p ->
        local = p.email |> String.split("@") |> hd()
        Map.merge(p, %{local: local, feature: Personas.feature_map()[local]})
      end)

    {:ok, assign(socket, page_title: "Demo Credentials", credentials: credentials)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <section class="vt-page-intro">
        <header class="vt-panel__header">
          <div>
            <p class="vt-kicker">Evaluator hub</p>
            <h1 class="vt-panel__title">Tasklane demo personas</h1>
            <p class="vt-copy">
              Tasklane is the fictional host app; Sigra supplies its auth, organizations,
              audit, and admin UI. Use these public-by-design
              <code class="vt-code">{"@" <> Personas.demo_domain()}</code>
              credentials on the shared Tasklane login page to exercise both customer journeys
              and Sigra operator workflows.
            </p>
          </div>
          <span class="vt-status-pill" data-testid="demo-dev-only-badge">DEV ONLY</span>
        </header>

        <div class="vt-card-grid vt-card-grid--three">
          <a href="/users/log_in" class="vt-panel">
            <p class="vt-kicker">Tasklane</p>
            <h2 class="vt-panel__title">Sign in</h2>
            <p class="vt-copy">Use a persona below on Tasklane's shared login page.</p>
          </a>
          <a href="/admin" class="vt-panel">
            <p class="vt-kicker">Sigra</p>
            <h2 class="vt-panel__title">Operate admin</h2>
            <p class="vt-copy">
              Sign in as admin@demo.tasklane.test for global /admin. Use
              morgan@demo.tasklane.test for /admin/organizations/acme-corp.
            </p>
          </a>
          <a href="/dev/mailbox" class="vt-panel">
            <p class="vt-kicker">Local DX</p>
            <h2 class="vt-panel__title">Inspect emails</h2>
            <p class="vt-copy">Review generated auth emails through the local mailbox preview.</p>
          </a>
        </div>
      </section>

      <div class="vt-table-panel" data-testid="demo-credentials-table">
        <table class="vt-table">
          <thead>
            <tr>
              <th>Persona</th>
              <th>Email</th>
              <th>Password</th>
              <th>Auth feature demonstrated</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={c <- @credentials} data-testid={"demo-persona-row-#{c.local}"}>
              <td><strong>{c.display_name}</strong></td>
              <td><code class="vt-code vt-code--copy">{c.email}</code></td>
              <td><code class="vt-code vt-code--copy">{c.password}</code></td>
              <td>{c.feature}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="vt-copy">
        Passwords are public-by-design demo credentials. Never use in production.
      </p>
    </Layouts.app>
    """
  end
end
