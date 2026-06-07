defmodule ExampleWeb.PageController do
  use ExampleWeb, :controller

  alias Example.Demo.Personas

  def home(conn, _params) do
    personas = Personas.all()
    features = Personas.feature_map()

    featured_credentials =
      personas
      |> Enum.map(fn persona ->
        local = persona.email |> String.split("@") |> hd()
        Map.merge(persona, %{local: local, feature: Map.fetch!(features, local)})
      end)
      |> Enum.filter(&(&1.local in ~w(admin alice morgan pat)))

    render(conn, :home,
      persona_count: length(personas),
      tenant_count: 2,
      audit_row_count: "15+",
      demo_domain: Personas.demo_domain(),
      local_origin: local_origin(conn),
      featured_credentials: featured_credentials
    )
  end

  defp local_origin(conn) do
    port =
      case {conn.scheme, conn.port} do
        {:http, 80} -> ""
        {:https, 443} -> ""
        {_, port} -> ":#{port}"
      end

    "#{conn.scheme}://#{conn.host}#{port}"
  end
end
