defmodule ExampleWeb.OrganizationServiceAccountsLive do
  use ExampleWeb, :live_view

  import Ecto.Query

  alias Example.Accounts.ServiceAccount
  alias Example.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Service accounts")
     |> assign(:service_accounts, [])
     |> assign(:empty_state_copy, "Issue and revoke org-scoped credentials for API integrations and scheduled jobs.")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    org = socket.assigns.current_scope && socket.assigns.current_scope.active_organization

    service_accounts =
      case org do
        %{id: org_id} ->
          from(sa in ServiceAccount, where: sa.organization_id == ^org_id, order_by: [asc: sa.name])
          |> Repo.all()

        _ ->
          []
      end

    {:noreply, assign(socket, :service_accounts, service_accounts) |> assign(:service_account_id, params["id"])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Service accounts (<%= length(@service_accounts) %>)
        <:subtitle><%= @empty_state_copy %></:subtitle>
      </.header>

      <%= if @service_accounts == [] do %>
        <div class="card bg-base-200 py-12 px-6 text-center">
          <h2 class="text-lg font-semibold">No service accounts yet</h2>
          <p class="mt-2 text-sm text-base-content/70">
            Service accounts let your CI, internal services, and scheduled jobs authenticate as the organization without using a member's password.
          </p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Status</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={service_account <- @service_accounts}>
                <td><%= service_account.name %></td>
                <td><%= if service_account.revoked_at, do: "Revoked", else: "Active" %></td>
                <td><%= service_account.inserted_at %></td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end
end
