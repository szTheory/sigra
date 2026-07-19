defmodule <%= web_module %>.SigraAuthComponents do
  @moduledoc """
  Host-owned Sigra auth UI primitives.

  These components provide the generated default auth experience. Customize
  this module, `priv/static/assets/sigra_auth.css`, or the generated auth
  templates directly when your application needs full control.
  """

  use <%= web_module %>, :html

  attr :branding, :map, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def sigra_auth_page(assigns) do
    branding = assigns[:branding] || default_branding()

    assigns =
      assigns
      |> assign(:branding, branding)
      |> assign(:theme, theme_attr(branding))
      |> assign(:style, Sigra.Branding.css_variables(branding))

    ~H"""
    <link phx-track-static rel="stylesheet" href={~p"/assets/sigra_auth.css"} />
    <main class={["sigra-auth", @class]} data-theme={@theme} style={@style} {@rest}>
      <section class="sigra-auth__viewport">
        <div class="sigra-auth__panel">
          <div class="sigra-auth__brand">
            <img
              :if={@branding.logo_url}
              src={@branding.logo_url}
              alt={@branding.logo_alt}
              class="sigra-auth__logo"
            />
            <div :if={!@branding.logo_url} class="sigra-auth__mark" aria-hidden="true">
              <span></span>
              <span></span>
              <span></span>
            </div>
            <p class="sigra-auth__product">{@branding.product_name}</p>
          </div>

          {render_slot(@inner_block)}

          <footer
            :if={@branding.support_url || @branding.privacy_url || @branding.terms_url}
            class="sigra-auth__footer"
          >
            <a :if={@branding.support_url} href={@branding.support_url}>Support</a>
            <a :if={@branding.privacy_url} href={@branding.privacy_url}>Privacy</a>
            <a :if={@branding.terms_url} href={@branding.terms_url}>Terms</a>
          </footer>
        </div>
      </section>
    </main>
    """
  end

  attr :type, :string, default: "submit", values: ~w(button submit reset)
  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders an auth action without inheriting host CoreComponents button styles."
  def sigra_auth_button(assigns) do
    ~H"""
    <button type={@type} class={@class} disabled={@disabled} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc "Returns the generated default brand profile, including admin-saved overrides when available."
  def default_branding do
    <%= context_module %>.sigra_config()
    |> Sigra.Branding.resolve(
      defaults: [
        product_name: "<%= app_name %>",
        email_from_name: "<%= app_name %>",
        email_from_address: "<%= from_email %>"
      ]
    )
  end

  defp theme_attr(%Sigra.Branding.Profile{theme: theme}), do: to_string(theme)
  defp theme_attr(%{theme: theme}) when theme in [:system, :light, :dark], do: to_string(theme)
  defp theme_attr(%{"theme" => theme}) when theme in ["system", "light", "dark"], do: theme
  defp theme_attr(_), do: "system"
end
