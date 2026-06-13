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
      assert css =~ "--sigra-auth-dark-accent: #0f766e;"
      assert css =~ "--sigra-auth-dark-bg: #08111f;"
      refute css =~ "--sigra-auth-bg: #"
    end

    test "color_tokens resolves dark fallbacks without mutating persisted profile values" do
      profile = Profile.default(accent_color: "#0f766e")

      assert Branding.color_tokens(profile, :light).background_color == "#f7f4ee"
      assert Branding.color_tokens(profile, :dark).accent_color == "#0f766e"
      assert Branding.color_tokens(profile, :dark).background_color == "#171614"
      assert profile.dark_background_color == nil
    end
  end
end
