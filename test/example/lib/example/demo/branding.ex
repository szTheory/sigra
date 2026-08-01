defmodule Example.Demo.Branding do
  @moduledoc """
  Demo-only brand presets for evaluator-facing white-label previews.

  These presets intentionally do not write Sigra's admin-managed global brand
  profile. They are presentation fixtures used by the Tasklane example app.
  """

  alias Sigra.Branding.Profile

  @cookie_name "sigra_demo_brand"
  @theme_cookie_name "sigra_demo_theme"
  @default_id "tasklane"
  @theme_modes [:system, :light, :dark]

  @sigra_style_tokens [
    {"--sigra-auth-accent", :accent_color},
    {"--sigra-auth-on-accent", :accent_foreground},
    {"--sigra-auth-bg", :background_color},
    {"--sigra-auth-surface", :surface_color},
    {"--sigra-auth-text", :text_color},
    {"--sigra-auth-muted", :muted_color},
    {"--sigra-auth-border", :border_color}
  ]

  @tasklane_style_tokens [
    {"--vt-color-primary", :accent_color},
    {"--vt-color-primary-strong", :accent_color},
    {"--vt-color-accent", :accent_color},
    {"--vt-color-on-primary", :accent_foreground},
    {"--vt-color-page", :background_color},
    {"--vt-color-panel", :surface_color},
    {"--vt-color-panel-alt", :background_color},
    {"--vt-color-ink", :text_color},
    {"--vt-color-muted", :muted_color},
    {"--vt-color-line", :border_color},
    {"--vt-color-line-strong", :border_color}
  ]

  @tasklane_light Profile.new!(
                    product_name: "Tasklane",
                    logo_url: "/images/tasklane-mark.svg",
                    logo_alt: "Tasklane logo",
                    accent_color: "#045f73",
                    accent_foreground: "#ffffff",
                    background_color: "#edf7f6",
                    surface_color: "#fbfefd",
                    text_color: "#10242c",
                    muted_color: "#526971",
                    border_color: "#bfd8d6",
                    email_from_name: "Tasklane",
                    email_from_address: "noreply@demo.tasklane.test",
                    theme: :light
                  )
  @tasklane_dark Profile.new!(
                   product_name: "Tasklane",
                   logo_url: "/images/tasklane-mark.svg",
                   logo_alt: "Tasklane logo",
                   accent_color: "#5eead4",
                   accent_foreground: "#062029",
                   background_color: "#061b22",
                   surface_color: "#0b2930",
                   text_color: "#e9fffb",
                   muted_color: "#a7c5c5",
                   border_color: "#1f4b52",
                   email_from_name: "Tasklane",
                   email_from_address: "noreply@demo.tasklane.test",
                   theme: :dark
                 )

  @rail_accent_light Profile.new!(
                       product_name: "Rail Accent",
                       logo_url: "/images/rail-accent-mark.svg",
                       logo_alt: "Rail Accent logo",
                       accent_color: "#c2410c",
                       accent_foreground: "#ffffff",
                       background_color: "#f7f4ee",
                       surface_color: "#ffffff",
                       text_color: "#171717",
                       muted_color: "#6b6258",
                       border_color: "#ded8cf",
                       email_from_name: "Rail Accent",
                       email_from_address: "hello@rail-accent.test",
                       theme: :light
                     )
  @rail_accent_dark Profile.new!(
                      product_name: "Rail Accent",
                      logo_url: "/images/rail-accent-mark-dark.svg",
                      logo_alt: "Rail Accent logo",
                      accent_color: "#fdba74",
                      accent_foreground: "#151515",
                      background_color: "#171614",
                      surface_color: "#211f1c",
                      text_color: "#f4f1eb",
                      muted_color: "#bdb5aa",
                      border_color: "#4a4035",
                      email_from_name: "Rail Accent",
                      email_from_address: "hello@rail-accent.test",
                      theme: :dark
                    )

  @meridian_light Profile.new!(
                    product_name: "Meridian Health",
                    logo_alt: "Meridian Health logo",
                    accent_color: "#176b43",
                    accent_foreground: "#ffffff",
                    background_color: "#eef7f3",
                    surface_color: "#ffffff",
                    text_color: "#14231d",
                    muted_color: "#587067",
                    border_color: "#c9ddd3",
                    email_from_name: "Meridian Health",
                    email_from_address: "care@meridian.test",
                    theme: :light
                  )
  @meridian_dark Profile.new!(
                   product_name: "Meridian Health",
                   logo_alt: "Meridian Health logo",
                   accent_color: "#72e0aa",
                   accent_foreground: "#062116",
                   background_color: "#071b14",
                   surface_color: "#0d281e",
                   text_color: "#eafbf2",
                   muted_color: "#a7c8b8",
                   border_color: "#214c3a",
                   email_from_name: "Meridian Health",
                   email_from_address: "care@meridian.test",
                   theme: :dark
                 )

  # Indigo/violet "security ops" palette — deliberately distinct from Tasklane teal,
  # Meridian green, and Rail Accent orange so the white-label preview spans 4 hues.
  @night_ops_light Profile.new!(
                     product_name: "Night Ops",
                     logo_alt: "Night Ops logo",
                     accent_color: "#6d28d9",
                     accent_foreground: "#ffffff",
                     background_color: "#f5f3ff",
                     surface_color: "#ffffff",
                     text_color: "#1e1b2e",
                     muted_color: "#6b6488",
                     border_color: "#ddd6f5",
                     email_from_name: "Night Ops",
                     email_from_address: "security@night-ops.test",
                     theme: :light
                   )
  @night_ops_dark Profile.new!(
                    product_name: "Night Ops",
                    logo_alt: "Night Ops logo",
                    accent_color: "#a78bfa",
                    accent_foreground: "#140f29",
                    background_color: "#0c0a1a",
                    surface_color: "#15122a",
                    text_color: "#ece9fb",
                    muted_color: "#a7a0c8",
                    border_color: "#2e2750",
                    email_from_name: "Night Ops",
                    email_from_address: "security@night-ops.test",
                    theme: :dark
                  )

  @presets [
    %{
      id: "tasklane",
      label: "Tasklane",
      description: "Teal default for Tasklane — the fictional project tracker.",
      email_subject: "Confirm your Tasklane account",
      default_theme: :light,
      profile: @tasklane_light,
      profiles: %{light: @tasklane_light, dark: @tasklane_dark}
    },
    %{
      id: "rail-accent",
      label: "Rail Accent",
      description: "Sigra's restrained default palette for neutral host apps.",
      email_subject: "Confirm your Rail Accent account",
      default_theme: :light,
      profile: @rail_accent_light,
      profiles: %{light: @rail_accent_light, dark: @rail_accent_dark}
    },
    %{
      id: "meridian",
      label: "Meridian Health",
      description: "Calm clinical green with high-contrast operational copy.",
      email_subject: "Confirm your Meridian Health account",
      default_theme: :system,
      profile: %Profile{@meridian_light | theme: :system},
      profiles: %{light: @meridian_light, dark: @meridian_dark}
    },
    %{
      id: "night-ops",
      label: "Night Ops",
      description: "Dark-mode-first incident operations surface.",
      email_subject: "Confirm your Night Ops account",
      default_theme: :dark,
      profile: @night_ops_dark,
      profiles: %{light: @night_ops_light, dark: @night_ops_dark}
    }
  ]

  def default_id, do: @default_id
  def cookie_name, do: @cookie_name
  def theme_cookie_name, do: @theme_cookie_name
  def theme_modes, do: @theme_modes

  def default_profile do
    default_preset()
    |> profile_for_theme(default_theme_for_id(@default_id))
  end

  def presets, do: @presets

  def default_preset do
    preset_for_id(@default_id)
  end

  def preset_for_id(id) when is_binary(id) do
    Enum.find(@presets, &(&1.id == id)) || Enum.find(@presets, &(&1.id == @default_id))
  end

  def preset_for_id(_), do: default_preset()

  def default_theme_for_id(id) do
    id
    |> preset_for_id()
    |> Map.fetch!(:default_theme)
  end

  def preset_id_from_cookie(cookies) when is_map(cookies) do
    cookies
    |> Map.get(@cookie_name)
    |> preset_for_id()
    |> Map.fetch!(:id)
  end

  def preset_id_from_cookie(_), do: @default_id

  def theme_from_cookie(cookies, id \\ nil)

  def theme_from_cookie(cookies, id) when is_map(cookies) do
    normalize_theme(Map.get(cookies, @theme_cookie_name)) ||
      default_theme_for_id(id || preset_id_from_cookie(cookies))
  end

  def theme_from_cookie(_cookies, id), do: default_theme_for_id(id)

  def selection_from_cookies(cookies) when is_map(cookies) do
    id = preset_id_from_cookie(cookies)
    theme = theme_from_cookie(cookies, id)
    preset = preset_for_id(id)

    %{
      id: id,
      theme: theme,
      preset: preset,
      profile: profile_for_theme(preset, theme),
      style: demo_surface_style(preset)
    }
  end

  def selection_from_cookies(_), do: selection_from_cookies(%{})

  def profile_for_id(id, theme \\ nil) do
    preset = preset_for_id(id)
    profile_for_theme(preset, normalize_theme(theme) || Map.fetch!(preset, :default_theme))
  end

  def profile_for_theme(%{profiles: profiles} = preset, theme) do
    theme = normalize_theme(theme) || Map.fetch!(preset, :default_theme)
    variant = if theme == :dark, do: :dark, else: :light

    profiles
    |> Map.fetch!(variant)
    |> Map.put(:theme, theme)
  end

  def demo_surface_style(%Profile{} = profile) do
    [Sigra.Branding.css_variables(profile), tasklane_css_variables(profile)]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  def demo_surface_style(%{profiles: _profiles} = preset) do
    [sigra_variant_css_variables(preset), tasklane_variant_css_variables(preset)]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  def presets_for_ui do
    Enum.map(@presets, fn preset ->
      default_profile = profile_for_theme(preset, preset.default_theme)

      %{
        id: preset.id,
        label: preset.label,
        description: preset.description,
        email_subject: preset.email_subject,
        default_theme: Atom.to_string(preset.default_theme),
        profile: Profile.to_map(default_profile),
        profiles: %{
          light: Profile.to_map(profile_for_theme(preset, :light)),
          dark: Profile.to_map(profile_for_theme(preset, :dark))
        },
        css_variables: sigra_variant_css_variables(preset),
        demo_surface_variables: demo_surface_style(preset)
      }
    end)
  end

  defp normalize_theme(value) when value in @theme_modes, do: value

  defp normalize_theme(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "system" -> :system
      "light" -> :light
      "dark" -> :dark
      _ -> nil
    end
  end

  defp normalize_theme(_), do: nil

  defp sigra_variant_css_variables(%{profiles: profiles}) do
    variant_css_variables(@sigra_style_tokens, profiles)
  end

  defp tasklane_variant_css_variables(%{profiles: profiles}) do
    [
      variant_css_variables(@tasklane_style_tokens, profiles),
      "--vt-light-color-accent-soft: color-mix(in oklab, var(--vt-light-color-accent) 18%, var(--vt-light-color-panel));",
      "--vt-dark-color-accent-soft: color-mix(in oklab, var(--vt-dark-color-accent) 26%, transparent);"
    ]
    |> Enum.join(" ")
  end

  defp variant_css_variables(tokens, profiles) do
    Enum.map_join([:light, :dark], " ", fn variant ->
      profile = Map.fetch!(profiles, variant)

      Enum.map_join(tokens, " ", fn {property, key} ->
        "#{variant_property(property, variant)}: #{Map.fetch!(profile, key)};"
      end)
    end)
  end

  defp variant_property("--sigra-auth-" <> suffix, variant),
    do: "--sigra-auth-#{variant}-#{suffix}"

  defp variant_property("--vt-color-" <> suffix, variant),
    do: "--vt-#{variant}-color-#{suffix}"

  defp tasklane_css_variables(%Profile{} = profile) do
    Enum.map_join(@tasklane_style_tokens, " ", fn {property, key} ->
      "#{property}: #{Map.fetch!(profile, key)};"
    end)
  end
end
