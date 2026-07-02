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
      assert html =~ ~s(data-testid="admin-auth-branding-workbench")
      assert html =~ ~s(data-testid="admin-auth-branding-form")
      assert html =~ ~s(phx-hook="AuthBrandingPreview")
      assert html =~ "data-sg-auth-branding-preview-form"
      assert html =~ ~s(data-testid="admin-auth-preview")
      assert html =~ ~s(data-testid="admin-email-preview")
      assert html =~ ~s(data-testid="admin-email-preview-surface")
      assert html =~ ~s(data-sg-auth-branding-preview="login")
      assert html =~ ~s(data-sg-auth-branding-preview="email")
      assert html =~ ~s(data-sg-auth-branding-preview-theme="light")
      assert html =~ ~s(data-sg-auth-branding-preview-theme="dark")
      assert html =~ ~s(aria-label="Branding sections")
      assert html =~ ~s(aria-current="page")
      assert html =~ ~s(data-testid="admin-auth-branding-light-panel")
      assert html =~ ~s(data-theme="light")
      assert html =~ "--sigra-auth-light-bg:"
      assert html =~ "--sigra-auth-dark-bg:"
      assert html =~ "Tasklane"
      assert html =~ ~s(<fieldset class="sg-fieldset">)

      assert html =~
               ~s(<legend class="sg-fieldset__legend sg-section-heading">Light palette</legend>)

      assert html =~
               ~s(<legend class="sg-fieldset__legend sg-section-heading">Dark palette</legend>)

      assert html =~ ~s(class="sg-form-grid sg-color-grid")
      assert html =~ ~s(class="sg-field sg-color-field")
      assert html =~ ~s(class="sg-color-field__input")
      assert html =~ ~s(class="sg-color-field__value sg-muted sg-text-sm sg-tabular")
      assert length(Regex.scan(~r/phx-throttle="120"/, html)) == length(color_field_names())

      for name <- color_field_names() do
        assert html =~ ~s(name="branding[#{name}]")
        assert html =~ ~s(data-sg-auth-branding-color="#{name}")
        assert html =~ ~s(data-sg-auth-branding-color-value="#{name}")
      end
    end

    test "theme picker drives details preview before save", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding?panel=details")

      html =
        view
        |> form("#auth-branding-form", %{"branding" => brand_attrs("dark")})
        |> render_change()

      assert html =~ "Unsaved preview"
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

    test "details panel explains non-obvious branding fields", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding?panel=details")

      assert html =~ ~s(id="branding-product-name")
      refute html =~ ~s(aria-label="Help: Product name")

      assert length(Regex.scan(~r/data-sg-field-help-trigger="true"/, html)) == 9

      assert html =~ ~s(aria-label="Help: Logo URL")
      assert html =~ ~s(aria-controls="branding-logo-url-help")

      assert html =~
               "Shown on generated auth screens and email headers when set. Use an absolute URL that email clients can load."

      assert html =~ ~s(aria-label="Help: Logo alt text")
      assert html =~ "Used when a logo is shown. Keep it short, like &quot;Acme logo&quot;."

      assert html =~ ~s(aria-label="Help: Theme mode")

      assert html =~
               "System follows the user&#39;s device setting. Light or Dark forces generated auth screens into that theme."

      assert html =~ ~s(aria-label="Help: Support URL")

      assert html =~
               "Adds a Support link to generated auth screen footers. Leave blank to hide it."

      assert html =~ ~s(aria-label="Help: Privacy URL")

      assert html =~
               "Adds a Privacy link to generated auth screen footers. Leave blank to hide it."

      assert html =~ ~s(aria-label="Help: Terms URL")
      assert html =~ "Adds a Terms link to generated auth screen footers. Leave blank to hide it."

      assert html =~ ~s(aria-label="Help: Email from name")
      assert html =~ "Display name recipients see on generated auth emails."

      assert html =~ ~s(aria-label="Help: Email from address")

      assert html =~
               "Sender address for generated auth emails. Use an address your mailer is allowed to send from."

      assert html =~ ~s(aria-label="Help: Reply-to")
      assert html =~ "Replies go to this address when set. Leave blank to use the sender address."
    end

    test "light and dark panels force local previews and do not persist changes before save", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()
      config = Example.Accounts.sigra_config()

      :ok = Branding.delete_global(config)

      {:ok, light_view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding?panel=light")

      html =
        light_view
        |> form("#auth-branding-form", %{"branding" => brand_attrs("dark")})
        |> render_change()

      assert html =~ ~r/data-testid="admin-auth-preview"[\s\S]*data-theme="light"/
      assert html =~ "--sigra-auth-light-accent: #0f766e;"
      assert {:error, :not_found} = Branding.load_global(config)

      {:ok, dark_view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding?panel=dark")

      html =
        dark_view
        |> form("#auth-branding-form", %{"branding" => brand_attrs("light")})
        |> render_change()

      assert html =~ ~r/data-testid="admin-auth-preview"[\s\S]*data-theme="dark"/
      assert html =~ "--sigra-auth-dark-bg: #020617;"
      assert {:error, :not_found} = Branding.load_global(config)
    end

    test "discard changes restores the persisted draft without deleting the profile", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()
      config = Example.Accounts.sigra_config()

      :ok = Branding.delete_global(config)

      {:ok, view, _html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding?panel=details")

      html =
        view
        |> form("#auth-branding-form", %{"branding" => brand_attrs("dark")})
        |> render_submit()

      assert html =~ "Auth branding profile saved."

      assert {:ok, profile} = Branding.load_global(config)
      assert profile.product_name == "Sigra Labs"
      assert profile.theme == :dark

      draft_attrs =
        "light"
        |> brand_attrs()
        |> Map.put("product_name", "Draft Only")
        |> Map.put("email_from_address", "draft@example.com")

      html =
        view
        |> form("#auth-branding-form", %{"branding" => draft_attrs})
        |> render_change()

      assert html =~ "Unsaved preview"
      assert html =~ "Draft Only"
      assert html =~ "Discard changes"

      html =
        view
        |> element("button[phx-click='discard_changes']", "Discard changes")
        |> render_click()

      assert html =~ "Unsaved branding changes discarded."
      assert html =~ "Sigra Labs"
      refute html =~ "Draft Only"
      refute html =~ "Unsaved preview"

      assert {:ok, profile} = Branding.load_global(config)
      assert profile.product_name == "Sigra Labs"
      assert profile.email_from_address == "auth@example.com"
    end

    test "restoring config defaults requires confirmation before deleting saved profile", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()
      config = Example.Accounts.sigra_config()

      :ok = Branding.delete_global(config)

      {:ok, view, html} =
        conn
        |> log_in_user(platform_admin)
        |> live(~p"/admin/auth-branding?panel=details")

      refute html =~ "Restore config defaults"
      refute html =~ ">Reset<"

      html =
        view
        |> form("#auth-branding-form", %{"branding" => brand_attrs("dark")})
        |> render_submit()

      assert html =~ "Auth branding profile saved."
      assert html =~ "Sigra Labs"
      assert html =~ ~s(data-theme="dark")
      assert html =~ "Restore config defaults"
      assert {:ok, profile} = Branding.load_global(config)
      assert profile.dark_background_color == "#020617"
      assert profile.dark_surface_color == "#0f172a"

      html =
        view
        |> element("button[phx-click='open_restore_defaults']", "Restore config defaults")
        |> render_click()

      assert html =~ "Restore defaults?"
      assert html =~ "This removes the saved admin branding changes"
      assert html =~ ~s(class="sg-confirm-overlay")
      assert html =~ ~s(class="sg-confirm-dialog")
      assert html =~ ~s(role="dialog")
      assert html =~ ~s(aria-modal="true")
      refute html =~ "<dialog"
      refute html =~ ~s(class="modal")
      refute html =~ "modal-box"
      refute html =~ "modal-action"
      assert {:ok, _profile} = Branding.load_global(config)

      html =
        view
        |> element("button[phx-click='cancel_restore_defaults']", "Cancel")
        |> render_click()

      refute html =~ "Restore defaults?"
      refute html =~ "sg-confirm-overlay"
      assert {:ok, _profile} = Branding.load_global(config)

      view
      |> element("button[phx-click='open_restore_defaults']", "Restore config defaults")
      |> render_click()

      html =
        view
        |> element("button[phx-click='restore_config_defaults']", "Restore defaults")
        |> render_click()

      assert html =~ "Auth branding restored to config defaults."
      assert html =~ "Tasklane"
      assert html =~ "Source: Config defaults"
      refute html =~ "Restore defaults?"
      refute html =~ "Restore config defaults"
      assert {:error, :not_found} = Branding.load_global(config)
    end
  end

  defp platform_admin_fixture do
    user_fixture(%{
      email: "platform-admin+branding-#{System.unique_integer([:positive])}@example.com",
      display_name: "Platform Admin"
    })
  end

  defp color_field_names do
    ~w(
      accent_color
      accent_foreground
      background_color
      surface_color
      text_color
      muted_color
      border_color
      dark_accent_color
      dark_accent_foreground
      dark_background_color
      dark_surface_color
      dark_text_color
      dark_muted_color
      dark_border_color
    )
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
