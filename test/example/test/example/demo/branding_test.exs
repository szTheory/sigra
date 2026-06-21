defmodule Example.Demo.BrandingTest do
  use ExUnit.Case, async: true

  alias Example.Demo.Branding
  alias Sigra.Branding.Profile

  @moduletag :example_app

  test "demo brand presets have unique ids and validated light/dark profiles" do
    presets = Branding.presets()
    ids = Enum.map(presets, & &1.id)

    assert Branding.default_id() in ids
    assert Branding.default_id() == "vaultr"
    assert Enum.uniq(ids) == ids

    for preset <- presets do
      assert preset.default_theme in Branding.theme_modes()
      assert %Profile{} = preset.profile
      assert %{light: %Profile{}, dark: %Profile{}} = preset.profiles
      assert preset.label != ""
      assert preset.description != ""
      assert Branding.profile_for_theme(preset, :light).theme == :light
      assert Branding.profile_for_theme(preset, :dark).theme == :dark
    end

    assert Branding.default_profile().product_name == "Vaultr"
    assert Branding.default_profile().theme == :light
    assert Branding.default_profile().logo_url == "/images/vaultr-mark.svg"
    assert Branding.default_profile().logo_alt == "Vaultr logo"
    assert Branding.profile_for_id("vaultr", "light").theme == :light
  end

  test "UI presets expose JSON-safe dual profile maps" do
    preset = Branding.presets_for_ui() |> List.first()

    assert preset.profile["product_name"] == "Vaultr"
    assert preset.profile["logo_url"] == "/images/vaultr-mark.svg"
    assert preset.profile["theme"] == "light"
    assert preset.default_theme == "light"
    assert preset.profiles.light["theme"] == "light"
    assert preset.profiles.dark["theme"] == "dark"
    assert preset.css_variables =~ "--sigra-auth-light-accent"
    assert preset.css_variables =~ "--sigra-auth-dark-accent"
    assert preset.demo_surface_variables =~ "--vt-light-color-primary: #045f73"
    assert preset.demo_surface_variables =~ "--vt-dark-color-primary: #5eead4"
    assert Jason.encode!(Branding.presets_for_ui()) =~ "Night Ops"
    assert Jason.encode!(Branding.presets_for_ui()) =~ "default_theme"
  end

  test "demo surface style includes generated auth and Night Ops first-paint variant tokens" do
    style = Branding.demo_surface_style(Branding.preset_for_id("night-ops"))

    assert style =~ "--sigra-auth-dark-accent: #a78bfa"
    assert style =~ "--sigra-auth-light-accent: #6d28d9"
    assert style =~ "--vt-dark-color-primary: #a78bfa"
    assert style =~ "--vt-dark-color-panel: #15122a"
    assert style =~ "--vt-dark-color-on-primary: #140f29"
    assert style =~ "--vt-light-color-primary: #6d28d9"
  end

  test "cookie-selected preset ids and themes are validated against known demo presets" do
    assert Branding.cookie_name() == "sigra_demo_brand"
    assert Branding.theme_cookie_name() == "sigra_demo_theme"
    assert Branding.preset_id_from_cookie(%{"sigra_demo_brand" => "night-ops"}) == "night-ops"
    assert Branding.preset_id_from_cookie(%{"sigra_demo_brand" => "unknown"}) == "vaultr"
    assert Branding.profile_for_id("night-ops").product_name == "Night Ops"
    assert Branding.theme_from_cookie(%{}, "night-ops") == :dark
    assert Branding.theme_from_cookie(%{}, "vaultr") == :light
    assert Branding.theme_from_cookie(%{"sigra_demo_theme" => "system"}, "night-ops") == :system
    assert Branding.theme_from_cookie(%{"sigra_demo_theme" => "dark"}, "vaultr") == :dark
    assert Branding.theme_from_cookie(%{"sigra_demo_theme" => "unknown"}, "vaultr") == :light

    selection =
      Branding.selection_from_cookies(%{
        "sigra_demo_brand" => "meridian",
        "sigra_demo_theme" => "dark"
      })

    assert selection.id == "meridian"
    assert selection.theme == :dark
    assert selection.profile.product_name == "Meridian Health"
    assert selection.profile.theme == :dark
    assert selection.style =~ "--vt-dark-color-primary: #72e0aa"
  end
end
