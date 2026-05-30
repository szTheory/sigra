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
    <Layouts.app flash={@flash}>
      <.header>
        Demo Credentials
        <:actions>
          <span class="badge badge-warning badge-sm" data-testid="demo-dev-only-badge">
            DEV ONLY
          </span>
        </:actions>
      </.header>
      <p class="text-sm text-base-content/60">
        This page is only available in development mode.
      </p>
      <table class="table table-zebra" data-testid="demo-credentials-table">
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
            <td>{c.display_name}</td>
            <td>{c.email}</td>
            <td><code class="font-mono text-sm">{c.password}</code></td>
            <td>{c.feature}</td>
          </tr>
        </tbody>
      </table>
      <p class="text-xs text-base-content/60">
        Passwords are public-by-design demo credentials. Never use in production.
      </p>
    </Layouts.app>
    """
  end
end
