defmodule ExampleWeb.ServiceAccountProbeController do
  use ExampleWeb, :controller

  def show(conn, _params) do
    scope = conn.assigns.current_scope || %{}

    json(conn, %{
      actor_type: Map.get(scope, :actor_type),
      service_account_id: Map.get(scope, :service_account_id),
      organization_id: get_in(scope, [:active_organization, :id]),
      user_id: get_in(scope, [:user, :id]),
      token_scopes: Map.get(scope, :token_scopes, [])
    })
  end
end
