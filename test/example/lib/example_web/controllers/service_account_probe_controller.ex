defmodule ExampleWeb.ServiceAccountProbeController do
  use ExampleWeb, :controller

  def show(conn, _params) do
    scope = conn.assigns.current_scope || %{}

    org = Map.get(scope, :active_organization)
    user = Map.get(scope, :user)

    json(conn, %{
      actor_type: Map.get(scope, :actor_type),
      service_account_id: Map.get(scope, :service_account_id),
      organization_id: org && Map.get(org, :id),
      user_id: user && Map.get(user, :id),
      token_scopes: Map.get(scope, :token_scopes, [])
    })
  end
end
