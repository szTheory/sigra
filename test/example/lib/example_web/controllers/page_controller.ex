defmodule ExampleWeb.PageController do
  use ExampleWeb, :controller

  alias Example.Demo.Branding
  alias Example.Demo.Personas

  def home(conn, _params) do
    conn = Plug.Conn.fetch_cookies(conn)
    personas = Personas.all()
    features = Personas.feature_map()
    default_selection = Branding.selection_from_cookies(conn.req_cookies)
    default_id = default_selection.id
    default_theme = default_selection.theme
    default_preset = default_selection.preset
    default_brand = default_selection.profile
    brand_presets = Branding.presets_for_ui()

    featured_credentials =
      personas
      |> Enum.map(fn persona ->
        local = persona.email |> String.split("@") |> hd()
        Map.merge(persona, %{local: local, feature: Map.fetch!(features, local)})
      end)
      |> Enum.filter(&(&1.local in Personas.featured_keys()))

    render(conn, :home,
      persona_count: length(personas),
      tenant_count: 2,
      audit_row_count: "15+",
      demo_domain: Personas.demo_domain(),
      local_origin: local_origin(conn),
      featured_credentials: featured_credentials,
      demo_brand_default_id: default_id,
      demo_brand_default_theme: default_theme,
      demo_brand_presets: brand_presets,
      demo_brand_presets_json: Jason.encode!(brand_presets),
      demo_brand_default_profile: default_brand,
      demo_brand_default_style: default_selection.style,
      demo_brand_default_description: Map.fetch!(default_preset, :description),
      demo_brand_default_subject: Map.fetch!(default_preset, :email_subject)
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
