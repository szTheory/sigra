defmodule ExampleWeb.Demo.CredentialsLive do
  @moduledoc """
  Read-only LiveView that lists all six demo persona credentials at `/demo/credentials`.

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
      <section class="space-y-6">
        <header class="sg-page-header">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <p class="sg-page-kicker">Evaluator hub</p>
            <span class="sg-status-pill badge badge-warning badge-sm" data-tone="warn" data-testid="demo-dev-only-badge">
              DEV ONLY
            </span>
          </div>
          <h1 class="sg-page-title text-3xl font-semibold">Demo personas</h1>
          <p class="sg-page-copy text-sm text-base-content/70">
            Use these public-by-design credentials to exercise Sigra’s main happy paths and rough-edge operator workflows in a realistic Vaultr tenant.
          </p>
        </header>

        <div class="grid gap-4 lg:grid-cols-3">
          <a href="/users/log_in" class="sg-card sg-card-hover block rounded-lg border border-base-300 bg-base-100 p-5">
            <h2 class="text-lg font-semibold">Sign in</h2>
            <p class="mt-2 text-sm text-base-content/70">Use a persona below to experience the end-user auth journey.</p>
          </a>
          <a href="/admin" class="sg-card sg-card-hover block rounded-lg border border-base-300 bg-base-100 p-5">
            <h2 class="text-lg font-semibold">Operate admin</h2>
            <p class="mt-2 text-sm text-base-content/70">Inspect users, sessions, MFA, organizations, and support actions.</p>
          </a>
          <a href="/dev/mailbox" class="sg-card sg-card-hover block rounded-lg border border-base-300 bg-base-100 p-5">
            <h2 class="text-lg font-semibold">Inspect emails</h2>
            <p class="mt-2 text-sm text-base-content/70">Review generated auth emails through the local mailbox preview.</p>
          </a>
        </div>

        <div class="sg-table-panel overflow-x-auto" data-testid="demo-credentials-table">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Persona</th>
                <th>Email</th>
                <th>Password</th>
                <th>Auth Feature Demonstrated</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={c <- @credentials} data-testid={"demo-persona-row-#{c.local}"}>
                <td class="font-semibold">{c.display_name}</td>
                <td>{c.email}</td>
                <td><code class="sg-code font-mono text-sm">{c.password}</code></td>
                <td>{c.feature}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-xs text-base-content/60">
          Passwords are public-by-design demo credentials. Never use in production.
        </p>
      </section>
    </Layouts.app>
    """
  end
end
