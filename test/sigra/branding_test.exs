defmodule Sigra.BrandingTest do
  use ExUnit.Case, async: true

  alias Sigra.Branding
  alias Sigra.Branding.Profile
  alias Sigra.Config

  defmodule PrefixedUser do
    use Ecto.Schema

    @schema_prefix "auth"
    schema "users" do
    end
  end

  defmodule CaptureRepo do
    def one(_query, opts) do
      send(self(), {:repo_one_opts, opts})
      nil
    end
  end

  describe "Sigra.Branding.Profile" do
    test "normalizes string keys, blank optional values, and theme strings" do
      assert {:ok, profile} =
               Profile.new(%{
                 "product-name" => "  Acme Auth  ",
                 "logo_url" => "  ",
                 "theme" => "dark",
                 "accent_color" => "#0f766e",
                 "dark_background_color" => "#08111f"
               })

      assert profile.product_name == "Acme Auth"
      assert profile.logo_url == nil
      assert profile.theme == :dark
      assert profile.accent_color == "#0f766e"
      assert profile.dark_background_color == "#08111f"
    end

    test "rejects invalid color tokens, invalid dark tokens, and empty required strings" do
      assert {:error, "accent_color must be a 6-digit hex color like #c2410c"} =
               Profile.new(accent_color: "teal")

      assert {:error, "dark_surface_color must be a 6-digit hex color like #c2410c"} =
               Profile.new(dark_surface_color: "midnight")

      assert {:error, "product_name must be a non-empty string"} =
               Profile.new(product_name: " ")
    end

    test "persists with string keys and string enum values for JSON adapters" do
      profile = Profile.default(product_name: "Acme", theme: :system)

      assert %{"product_name" => "Acme", "theme" => "system"} = Profile.to_map(profile)
      refute Map.has_key?(Profile.to_map(profile), :theme)
    end
  end

  describe "config resolution" do
    test "merges generated defaults with config branding" do
      profile =
        Branding.from_config(
          [
            branding: [
              product_name: "Configured",
              accent_color: "#155e75",
              dark_background_color: "#061b22",
              theme: :light
            ]
          ],
          product_name: "Generated",
          email_from_name: "Generated Mail"
        )

      assert profile.product_name == "Configured"
      assert profile.email_from_name == "Generated Mail"
      assert profile.accent_color == "#155e75"
      assert profile.dark_background_color == "#061b22"
      assert profile.theme == :light
    end

    test "accepts external runtime maps with string keys" do
      profile =
        Branding.from_config(%{
          "branding" => %{
            "product_name" => "Runtime",
            "theme" => "dark",
            "email_from_address" => "auth@example.com"
          }
        })

      assert profile.product_name == "Runtime"
      assert profile.theme == :dark
      assert profile.email_from_address == "auth@example.com"
    end

    test "resolve falls back to config tokens when no repo is configured" do
      profile = Branding.resolve(branding: [product_name: "No Repo"])

      assert profile.product_name == "No Repo"
    end

    test "load_global queries the generated auth schema prefix when available" do
      assert {:error, :not_found} =
               Branding.load_global(repo: CaptureRepo, user_schema: PrefixedUser)

      assert_received {:repo_one_opts, [prefix: "auth"]}
    end

    test "Sigra.Config accepts branding options" do
      config =
        Config.new!(
          repo: MyApp.Repo,
          user_schema: MyApp.User,
          branding: [
            product_name: "Configured",
            dark_background_color: "#07171d",
            theme: :dark
          ]
        )

      assert config.branding[:product_name] == "Configured"
      assert config.branding[:dark_background_color] == "#07171d"
      assert config.branding[:theme] == :dark
    end
  end

  describe "theme-aware logo resolution" do
    test "light resolves logo_url and dark falls back to it when no dark logo is set" do
      profile = Profile.new!(logo_url: "/positive.svg")

      assert Branding.logo(profile, :light) == "/positive.svg"
      assert Branding.logo(profile, :dark) == "/positive.svg"
    end

    test "dark prefers dark_logo_url over logo_url" do
      profile = Profile.new!(logo_url: "/positive.svg", dark_logo_url: "/reversed.svg")

      assert Branding.logo(profile, :light) == "/positive.svg"
      assert Branding.logo(profile, :dark) == "/reversed.svg"
    end

    test "light does NOT fall back to dark_logo_url" do
      # The whole point of the token: a host whose only asset is a reversed,
      # near-white mark sets dark_logo_url and leaves logo_url unset on purpose.
      # Falling back the other way would paint that mark onto a light background,
      # which reads as a broken image. nil means "use the placeholder", which is
      # the honest result.
      profile = Profile.new!(dark_logo_url: "/reversed.svg")

      assert Branding.logo(profile, :light) == nil
      assert Branding.logo(profile, :dark) == "/reversed.svg"
    end

    test "email always uses the light slot and never reaches for the dark asset" do
      reversed_only = Profile.new!(dark_logo_url: "/reversed.svg")
      both = Profile.new!(logo_url: "/positive.svg", dark_logo_url: "/reversed.svg")

      assert Branding.email_logo(reversed_only) == nil
      assert Branding.email_logo(both) == "/positive.svg"
    end

    test "email ignores a pinned dark theme" do
      # Transactional email renders on an effectively light surface whatever the
      # profile theme says, so a pinned :dark theme must not pull in the dark asset.
      profile = Profile.new!(theme: :dark, logo_url: "/positive.svg", dark_logo_url: "/reversed.svg")

      assert Branding.email_logo(profile) == "/positive.svg"
    end
  end

  describe "dark accent derivation" do
    test "an explicit dark accent is authority and is never adjusted" do
      profile = Profile.new!(accent_color: "#1a2b5c", dark_accent_color: "#010203")

      assert {:explicit, "#010203"} = Branding.dark_accent_source(profile)
      assert Branding.color_tokens(profile, :dark).accent_color == "#010203"
    end

    test "a light accent that already meets contrast is inherited unchanged" do
      profile = Profile.new!(accent_color: "#ffd400")

      assert {:inherited, "#ffd400"} = Branding.dark_accent_source(profile)
      assert Branding.color_tokens(profile, :dark).accent_color == "#ffd400"
    end

    test "a light accent that fails against the dark surface is derived up to contrast" do
      profile = Profile.new!(accent_color: "#1a2b5c")

      assert {:derived, derived} = Branding.dark_accent_source(profile)
      assert derived != "#1a2b5c"

      tokens = Branding.color_tokens(profile, :dark)
      assert tokens.accent_color == derived
      assert Sigra.Branding.Contrast.contrast_ratio(derived, tokens.surface_color) >= 4.5
    end

    test "derivation measures against the host's own dark surface, not Sigra's default" do
      on_default = Profile.new!(accent_color: "#1a2b5c")
      on_light_surface = Profile.new!(accent_color: "#1a2b5c", dark_surface_color: "#cccccc")

      {:derived, default_accent} = Branding.dark_accent_source(on_default)
      {_source, custom_accent} = Branding.dark_accent_source(on_light_surface)

      refute default_accent == custom_accent
    end

    test "re-derives the foreground only when derivation broke a pairing that worked" do
      # White on navy is legible; white on the lightened navy is not, so we caused
      # the break and must fix it.
      profile = Profile.new!(accent_color: "#1a2b5c", accent_foreground: "#ffffff")
      tokens = Branding.color_tokens(profile, :dark)

      assert {:derived, _} = Branding.dark_accent_source(profile)
      assert tokens.accent_foreground == "#000000"
    end

    test "keeps a foreground the host was already running below target" do
      # White on this pink is already below target in light mode. That is the host's
      # aesthetic choice, not a defect for us to silently "fix" in dark mode only --
      # flipping their button text to black would be a far more visible change than
      # the sub-perceptual accent shift that triggered it.
      profile = Profile.new!(accent_color: "#ea4a71", accent_foreground: "#ffffff")

      assert Branding.color_tokens(profile, :dark).accent_foreground == "#ffffff"
    end

    test "an explicit dark foreground always wins" do
      profile =
        Profile.new!(
          accent_color: "#1a2b5c",
          accent_foreground: "#ffffff",
          dark_accent_foreground: "#abcdef"
        )

      assert Branding.color_tokens(profile, :dark).accent_foreground == "#abcdef"
    end

    test "light tokens are completely unaffected by dark derivation" do
      profile = Profile.new!(accent_color: "#1a2b5c", accent_foreground: "#ffffff")
      tokens = Branding.color_tokens(profile, :light)

      assert tokens.accent_color == "#1a2b5c"
      assert tokens.accent_foreground == "#ffffff"
    end

    test "css_variables carries the derived dark accent" do
      # This is the function a host consuming tokens directly reads, so the fix has
      # to land here and not only in color_tokens/2.
      profile = Profile.new!(accent_color: "#1a2b5c")
      {:derived, derived} = Branding.dark_accent_source(profile)

      css = Branding.css_variables(profile)

      assert css =~ "--sigra-auth-dark-accent: #{derived};"
      assert css =~ "--sigra-auth-light-accent: #1a2b5c;"
    end
  end

  describe "render helpers" do
    test "email_from returns a tuple when address exists and a display name otherwise" do
      assert Branding.email_from(Profile.default(email_from_name: "Acme")) == "Acme"

      assert Branding.email_from(
               Profile.default(email_from_name: "Acme", email_from_address: "auth@example.com")
             ) == {"Acme", "auth@example.com"}
    end

    test "css_variables emits the scoped auth design tokens" do
      css =
        Profile.default(
          accent_color: "#0f766e",
          border_color: "#94a3b8",
          dark_background_color: "#08111f"
        )
        |> Branding.css_variables()

      assert css =~ "--sigra-auth-light-accent: #0f766e;"
      assert css =~ "--sigra-auth-light-border: #94a3b8;"
      assert css =~ "--sigra-auth-dark-bg: #08111f;"
      refute css =~ "--sigra-auth-bg: #"

      # The dark accent is NOT the light accent echoed back. This teal is below
      # contrast against the dark surface, so it is derived up; asserting the light
      # value here is what encoded the asymmetry this behaviour replaced.
      refute css =~ "--sigra-auth-dark-accent: #0f766e;"
      assert css =~ ~r/--sigra-auth-dark-accent: #[0-9a-f]{6};/
    end

    test "color_tokens resolves dark fallbacks without mutating persisted profile values" do
      profile = Profile.default(accent_color: "#0f766e")

      assert Branding.color_tokens(profile, :light).background_color == "#f7f4ee"
      assert Branding.color_tokens(profile, :dark).background_color == "#171614"

      # Neutrals still fall back to Sigra's dark defaults; the accent is now fitted
      # to the resolved dark surface instead of inheriting the light value verbatim.
      assert {:derived, derived} = Branding.dark_accent_source(profile)
      assert Branding.color_tokens(profile, :dark).accent_color == derived

      # Derivation is a read-time resolution, never a write back onto the profile.
      assert profile.dark_background_color == nil
      assert profile.dark_accent_color == nil
      assert profile.accent_color == "#0f766e"
    end
  end
end
