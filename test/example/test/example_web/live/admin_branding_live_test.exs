defmodule ExampleWeb.AdminBrandingLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Sigra.Branding

  describe "global auth branding customizer" do
    test "renders config defaults with auth and email previews", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding")

      assert html =~ "Auth forms and emails"
      assert html =~ ~s(data-testid="admin-auth-branding-form")
      assert html =~ ~s(data-testid="admin-auth-preview")
      assert html =~ ~s(data-testid="admin-email-preview")
      assert html =~ ~s(data-testid="admin-email-preview-surface")
      assert html =~ ~s(data-theme="system")
      assert html =~ "--sigra-auth-light-bg:"
      assert html =~ "--sigra-auth-dark-bg:"
      assert html =~ "Vaultr"
    end

    test "theme picker drives login and email previews", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding")

      html =
        view
        |> form("#auth-branding-form", %{"branding" => brand_attrs("dark")})
        |> render_change()

      assert html =~ ~s(data-theme="dark")
      assert html =~ ~s(data-testid="admin-email-preview-surface")
      assert html =~ "--sigra-auth-dark-bg: #020617;"
      assert html =~ "--sigra-auth-dark-surface: #0f172a;"

      html =
        view
        |> form("#auth-branding-form", %{"branding" => brand_attrs("light")})
        |> render_change()

      assert html =~ ~s(data-theme="light")
      assert html =~ "--sigra-auth-light-bg: #f8fafc;"
    end

    test "saves and resets the global brand profile", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      config = Example.Accounts.sigra_config()

      :ok = Branding.delete_global(config)

      {:ok, view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding")

      attrs = brand_attrs("dark")

      html =
        view
        |> form("#auth-branding-form", %{"branding" => attrs})
        |> render_submit()

      assert html =~ "Auth branding profile saved."
      assert html =~ "Sigra Labs"
      assert html =~ ~s(data-theme="dark")

      assert {:ok, profile} = Branding.load_global(config)
      assert profile.product_name == "Sigra Labs"
      assert profile.theme == :dark
      assert profile.dark_background_color == "#020617"
      assert profile.dark_surface_color == "#0f172a"
      assert profile.email_from_address == "auth@example.com"

      html =
        view
        |> element("button[phx-click='reset_to_config']", "Use config defaults")
        |> render_click()

      assert html =~ "Auth branding reset to config defaults."
      assert html =~ "Vaultr"
      assert {:error, :not_found} = Branding.load_global(config)
    end
  end

  defp platform_admin_fixture do
    user_fixture(%{
      email: "platform-admin+branding-#{System.unique_integer([:positive])}@example.com",
      display_name: "Platform Admin"
    })
  end

  defp brand_attrs(theme) do
    %{
      "product_name" => "Sigra Labs",
      "logo_url" => "",
      "logo_alt" => "Sigra Labs logo",
      "theme" => theme,
      "accent_color" => "#0f766e",
      "accent_foreground" => "#ffffff",
      "background_color" => "#f8fafc",
      "surface_color" => "#ffffff",
      "text_color" => "#0f172a",
      "muted_color" => "#475569",
      "border_color" => "#cbd5e1",
      "dark_accent_color" => "#5eead4",
      "dark_accent_foreground" => "#062029",
      "dark_background_color" => "#020617",
      "dark_surface_color" => "#0f172a",
      "dark_text_color" => "#f8fafc",
      "dark_muted_color" => "#cbd5e1",
      "dark_border_color" => "#334155",
      "support_url" => "https://example.com/support",
      "privacy_url" => "https://example.com/privacy",
      "terms_url" => "https://example.com/terms",
      "email_from_name" => "Sigra Labs",
      "email_from_address" => "auth@example.com",
      "email_reply_to" => "help@example.com"
    }
  end
end
