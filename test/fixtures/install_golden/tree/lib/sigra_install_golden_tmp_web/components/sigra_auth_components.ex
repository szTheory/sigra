defmodule SigraInstallGoldenTmpWeb.SigraAuthComponents do
  @moduledoc """
  Host-owned Sigra auth UI primitives.

  These components provide the generated default auth experience. Customize
  this module, `priv/static/assets/sigra_auth.css`, or the generated auth
  templates directly when your application needs full control.
  """

  use SigraInstallGoldenTmpWeb, :html

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
      |> assign(:logo, logo_slots(branding))

    ~H"""
    <link phx-track-static rel="stylesheet" href={~p"/assets/sigra_auth.css"} />
    <main class={["sigra-auth", @class]} data-theme={@theme} style={@style} {@rest}>
      <section class="sigra-auth__viewport">
        <div class="sigra-auth__panel">
          <div class="sigra-auth__brand">
            <.logo_slot :if={@logo.mode == :single} url={@logo.url} alt={@branding.logo_alt} />
            <.logo_slot
              :if={@logo.mode == :dual}
              url={@logo.light}
              alt={@branding.logo_alt}
              slot_theme="light"
            />
            <.logo_slot
              :if={@logo.mode == :dual}
              url={@logo.dark}
              alt={@branding.logo_alt}
              slot_theme="dark"
            />
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
    SigraInstallGoldenTmp.Accounts.sigra_config()
    |> Sigra.Branding.resolve(
      defaults: [
        product_name: "SigraInstallGoldenTmp",
        email_from_name: "SigraInstallGoldenTmp",
        email_from_address: "noreply@example.com"
      ]
    )
  end

  defp theme_attr(%Sigra.Branding.Profile{theme: theme}), do: to_string(theme)
  defp theme_attr(%{theme: theme}) when theme in [:system, :light, :dark], do: to_string(theme)
  defp theme_attr(%{"theme" => theme}) when theme in ["system", "light", "dark"], do: theme
  defp theme_attr(_), do: "system"

  attr :url, :string, default: nil
  attr :alt, :string, required: true
  attr :slot_theme, :string, default: nil

  defp logo_slot(assigns) do
    ~H"""
    <img
      :if={@url}
      src={@url}
      alt={@alt}
      class="sigra-auth__logo"
      data-sigra-logo-slot={@slot_theme}
    />
    <div
      :if={!@url}
      class="sigra-auth__mark"
      aria-hidden="true"
      data-sigra-logo-slot={@slot_theme}
    >
      <span></span>
      <span></span>
      <span></span>
    </div>
    """
  end

  # Decides whether the brand row renders one logo or two CSS-toggled slots.
  #
  # A pinned theme resolves server-side and renders a single slot. Only "system"
  # needs both, because the theme is settled in the browser by prefers-color-scheme
  # and an <img src> cannot follow a CSS custom property the way a colour token can.
  #
  # <picture> with a dark <source> is the obvious approach and is deliberately NOT
  # used: it cannot express "placeholder mark in light, logo in dark", which is the
  # exact shape of a host whose only asset is a reversed mark. Those hosts are the
  # reason dark_logo_url exists, so the mechanism has to cover them. Two slots, each
  # independently an image or the placeholder, covers every combination.
  defp logo_slots(%Sigra.Branding.Profile{} = branding) do
    build_logo_slots(
      theme_attr(branding),
      Sigra.Branding.logo(branding, :light),
      Sigra.Branding.logo(branding, :dark)
    )
  end

  defp logo_slots(branding) do
    light = logo_value(branding, :logo_url)
    build_logo_slots(theme_attr(branding), light, logo_value(branding, :dark_logo_url) || light)
  end

  # Every branch returns the same keys. HEEx :if does short-circuit attribute
  # evaluation, so a partial map would work today -- but a total map means a future
  # refactor away from :if cannot turn this into a KeyError on the login page.
  defp build_logo_slots("system", light, dark) when light != dark do
    %{mode: :dual, url: light, light: light, dark: dark}
  end

  defp build_logo_slots("dark", light, dark) do
    %{mode: :single, url: dark, light: light, dark: dark}
  end

  defp build_logo_slots(_theme, light, dark) do
    %{mode: :single, url: light, light: light, dark: dark}
  end

  defp logo_value(%{} = branding, key) do
    Map.get(branding, key) || Map.get(branding, Atom.to_string(key))
  end

  defp logo_value(_branding, _key), do: nil
end
