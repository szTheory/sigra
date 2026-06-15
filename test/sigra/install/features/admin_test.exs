defmodule Sigra.Install.Features.AdminTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Admin

  describe "enabled?/1" do
    test "returns true by default" do
      assert Admin.enabled?([])
      assert Admin.enabled?([]) == true
    end

    test "supports explicit default-on and opt-out flags" do
      assert Admin.enabled?(admin: true)
      refute Admin.enabled?(admin: false)
    end
  end

  describe "files/1" do
    test "owns the generated admin policy and shell boundary files" do
      files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")

      assert {:eex, "admin/policy.ex", "lib/my_app/sigra_admin_policy.ex"} in files

      assert {:eex, "admin/components/admin_shell.ex", "lib/my_app_web/components/admin_shell.ex"} in files

      assert {:eex, "admin/sigra-logo-primary.svg", "priv/static/images/sigra-logo-primary.svg"} in files

      assert {:eex, "admin/sigra-logo-primary-dark.svg",
              "priv/static/images/sigra-logo-primary-dark.svg"} in files
    end

    test "emits impersonation_controller template to host controllers/admin/ directory" do
      files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")

      assert {:eex, "admin/impersonation_controller.ex",
              "lib/my_app_web/controllers/admin/impersonation_controller.ex"} in files
    end

    test "emits audit_export_controller template to host controllers/admin/ directory" do
      files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")

      assert {:eex, "admin/audit_export_controller.ex",
              "lib/my_app_web/controllers/admin/audit_export_controller.ex"} in files
    end

    test "emits sigra_admin.css installer template to host priv/static/assets/ (DIST-02)" do
      files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")

      assert {:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"} in files
    end
  end

  describe "migrations/1" do
    test "does not introduce any admin migrations in plan 27-01" do
      assert [] = Admin.migrations([])
    end
  end

  describe "injections/1" do
    test "owns the admin router, layout, and error-handler wiring" do
      injections =
        Admin.injections(otp_app: :my_app, web_module: "MyAppWeb", app_module: "MyApp")

      assert Enum.map(injections, & &1.target) == [
               "lib/my_app_web/router.ex",
               "lib/my_app_web/components/layouts.ex",
               "lib/my_app_web/components/layouts.ex",
               "lib/my_app_web/auth_error_handler.ex"
             ]

      [router, layouts_import, layouts_admin, error_handler] = injections

      assert router.marker == "# Sigra admin"
      assert router.anchor == :before_last_end
      assert router.content =~ "Sigra.Plug.RequireAdminAccess"
      assert router.content =~ "Sigra.LiveView.AdminScope"
      assert router.content =~ "MyApp.SigraAdminPolicy"
      assert router.content =~ "{MyAppWeb.Layouts, :admin}"
      assert router.content =~ ~s(live "/admin")
      assert router.content =~ ~s(scope "/admin/organizations/:org")

      assert layouts_import.marker == "import MyAppWeb.Components.AdminShell"
      assert layouts_import.anchor == :after_use_block
      assert layouts_import.content =~ "import MyAppWeb.Components.AdminShell"

      assert layouts_admin.marker == "def admin(assigns) do"
      assert layouts_admin.anchor == :before_last_end
      assert layouts_admin.content =~ "<.admin_shell"
      assert layouts_admin.content =~ "admin_breadcrumbs={@admin_breadcrumbs}"
      assert layouts_admin.content =~ "<.flash_group"
      assert layouts_admin.content =~ ~s|href={~p"/assets/sigra_admin.css"}|,
             "layouts_admin injection must include the sigra_admin.css <link> tag (DIST-03)"

      assert error_handler.marker == "def auth_error(conn, :insufficient_scope, _opts) do"
      assert error_handler.anchor == :before_last_end
      assert error_handler.content =~ ":insufficient_scope"
      assert error_handler.content =~ ":not_found"
    end
  end

  describe "impersonation_controller template (Phase 32)" do
    @binding [
      otp_app: :my_app,
      web_module: "MyAppWeb",
      app_module: "MyApp",
      context_module: "MyApp.Accounts",
      organizations?: true
    ]

    test "renders with no literal Example references (parameterization complete)" do
      content = render_impersonation_controller_template()

      refute content =~ "Example", "template still contains literal 'Example' reference"
      refute content =~ "ExampleWeb", "template still contains literal 'ExampleWeb' reference"
      assert content =~ "defmodule MyAppWeb.Admin.ImpersonationController"
    end

    test "renders with all Sigra runtime integration points wired" do
      content = render_impersonation_controller_template()

      assert content =~ "Sigra.Impersonation.start("
      assert content =~ "Sigra.Impersonation.stop("
      assert content =~ "UserAuth.begin_impersonation"
      assert content =~ "UserAuth.restore_impersonation"
      assert content =~ ":impersonator_user_token"
    end

    test "preserves enumeration-prevention mapping (:not_allowed -> :not_found)" do
      content = render_impersonation_controller_template()

      # T-IMPR-ESCALATION mitigation: the library returns {:error, :not_allowed}
      # but the controller surfaces :not_found (404) so attackers cannot
      # distinguish "user exists but you can't impersonate" from "user does
      # not exist." Do NOT change this to :forbidden.
      assert content =~ "{:error, :not_allowed} ->"
      assert content =~ "AuthErrorHandler.auth_error(:not_found, [])"
    end

    test "substitutes app_module and context_module per 5-rule EEx table" do
      content = render_impersonation_controller_template()

      # app_module substitution for Organizations reference
      assert content =~ "MyApp.Organizations.list_organizations_for_user"
      # context_module.Scope substitution for impersonation_config
      assert content =~ "MyApp.Accounts.Scope"
    end

    defp render_impersonation_controller_template do
      "priv/templates/sigra.install/admin/impersonation_controller.ex"
      |> File.read!()
      |> EEx.eval_string(@binding)
    end
  end

  describe "router_injection.ex template (Phase 32 route mounts)" do
    @router_binding [
      otp_app: :my_app,
      web_module: "MyAppWeb",
      app_module: "MyApp",
      context_module: "MyApp.Accounts"
    ]

    test "mounts UsersIndexLive in global admin live_session" do
      assert render_router_template() =~
               ~s|live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index|
    end

    test "mounts UserShowLive in global admin live_session" do
      assert render_router_template() =~
               ~s|live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show|
    end

    test "mounts UsersIndexLive in organization-scoped live_session" do
      assert render_router_template() =~
               ~s|live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index|
    end

    test "mounts UserShowLive in organization-scoped live_session" do
      assert render_router_template() =~
               ~s|live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show|
    end

    test "preserves existing mounts (no regression on audit or admin index lines)" do
      content = render_router_template()

      assert content =~ ~s|live "/admin", Elixir.Sigra.Admin.Live.IndexLive, :index|
      assert content =~ ~s|live "/admin/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index|

      assert content =~
               ~s|live "/admin/auth-branding", Elixir.Sigra.Admin.Live.BrandingLive, :index|

      assert content =~
               ~s|live "/admin/users/:id/audit", Elixir.Sigra.Admin.Live.AuditUserLive, :show|

      assert content =~ ~s|live "/", Elixir.Sigra.Admin.Live.OrganizationLive, :show|
      assert content =~ ~s|live "/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index|
      assert content =~ ~s|live "/users/:id/audit", Elixir.Sigra.Admin.Live.AuditUserLive, :show|
    end

    defp render_router_template do
      "priv/templates/sigra.install/admin/router_injection.ex"
      |> File.read!()
      |> EEx.eval_string(@router_binding)
    end
  end

  describe "template ownership guards" do
    test "admin templates exist on disk" do
      assert File.exists?("priv/templates/sigra.install/admin/policy.ex")
      assert File.exists?("priv/templates/sigra.install/admin/router_injection.ex")
      assert File.exists?("priv/templates/sigra.install/admin/components/admin_shell.ex")
      assert File.exists?("priv/templates/sigra.install/admin/admin_hooks.js")
      assert File.exists?("priv/templates/sigra.install/admin/impersonation_controller.ex")
      assert File.exists?("priv/templates/sigra.install/admin/audit_export_controller.ex")
    end

    test "admin shell template exposes the auth branding nav item" do
      source = File.read!("priv/templates/sigra.install/admin/components/admin_shell.ex")

      assert source =~ "sg-brand-mark__lockup"
      assert source =~ ~s|~p"/images/sigra-logo-primary.svg"|
      assert source =~ ~s|~p"/images/sigra-logo-primary-dark.svg"|
      assert source =~ ~s|width="188"|
      assert source =~ ~s|height="54"|
      refute source =~ "sg-brand-mark__word"
      refute source =~ "sg-brand-mark__core"
      assert source =~ "branding_link(@admin_scope)"
      assert source =~ ~s|~p"/admin/auth-branding"|
      assert source =~ "Branding"
      assert source =~ "branding_active?"
      assert source =~ "defp admin_link(assigns)"
      assert source =~ ~s|<.link :if={@live} navigate={@href}|
      assert source =~ "same_admin_session?"
      assert source =~ "attr :admin_breadcrumbs, :list"
      assert source =~ "breadcrumb_items(assigns.admin_scope"
      assert source =~ "breadcrumb_link?"
      assert source =~ ~s|Overview|
      assert source =~ "fallback_breadcrumb_items"
      assert source =~ "breadcrumb_label(page_title)"
      assert source =~ "data-sg-admin-js"
      assert source =~ "data-sg-admin-theme-preference"
      assert source =~ "sg-admin-loading-bar"
      assert source =~ "data-sg-admin-loading-bar"
      assert source =~ ~s|aria-hidden="true"|
      assert source =~ ~s(<nav class="sg-admin-crumbs" aria-label="Breadcrumb">)
      refute source =~ ":if={not overview_active?(@page_title)}"
      assert source_order?(source, "sg-nav-title\">Overviews<", "sg-nav-title\">Workspace<")

      bottom_nav = source_fragment(source, ~s(aria-label="Admin bottom nav"), 1600)
      assert source_order?(bottom_nav, "overview_link(@admin_scope)", "users_link(@admin_scope)")
    end

    test "admin logo templates are cropped path-only lockups" do
      for path <- [
            "priv/templates/sigra.install/admin/sigra-logo-primary.svg",
            "priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg"
          ] do
        source = File.read!(path)

        assert source =~ ~s(viewBox="20 220 2361 1000")
        assert source =~ "Space Grotesk v2.0"
        assert source =~ "<path"
        refute source =~ "<text"
        refute source =~ "font-family"
      end
    end

    test "admin hook template exports admin client utilities" do
      source = File.read!("priv/templates/sigra.install/admin/admin_hooks.js")

      assert source =~ "ThemeSwitch"
      assert source =~ "sigra.admin.theme"
      assert source =~ "data-sg-admin-theme"
      assert source =~ "sgAdminThemePreference"
      assert source =~ "aria-checked"
      assert source =~ "installPageLoadingIndicator"
      assert source =~ "installMetricHelp"
      assert source =~ "data-sg-metric-help-root"
      assert source =~ "installFieldHelp"
      assert source =~ "data-sg-field-help-root"
      assert source =~ "data-sg-field-help-trigger"
      assert source =~ "AuthBrandingPreview"
      assert source =~ "AUTH_BRANDING_COLOR_TOKENS"
      assert source =~ "data-sg-auth-branding-color"
      assert source =~ "data-sg-auth-branding-preview"
      assert source =~ "event.stopPropagation()"
      assert source =~ "phx:page-loading-start"
      assert source =~ "phx:page-loading-stop"
      assert source =~ "PAGE_LOADING_MAX_ACTIVE_MS"
      assert source =~ "pageLoadingKind(event) === \"error\""
      assert source =~ "data-sg-admin-page-loading"
      assert source =~ "aria-busy"
      refute source =~ "aria-pressed"
      refute source =~ "document.documentElement.setAttribute(\"data-theme\""
    end
  end

  describe "Mix.Tasks.Sigra.Install admin surface" do
    test "registers Admin as a default-on opt-out feature" do
      source = File.read!("lib/mix/tasks/sigra.install.ex")

      assert source =~ "Sigra.Install.Features.Admin"
      assert source =~ "admin: :boolean"
      assert source =~ "admin: true"
      assert source =~ "admin?: Keyword.get(opts, :admin, true)"
      assert source =~ "--no-admin"
    end

    test "requires phoenix_live_view because admin foundation ships LiveViews" do
      source = File.read!("mix.exs")

      assert source =~ ~s({:phoenix_live_view, "~> 1.1"})
      refute source =~ ~s({:phoenix_live_view, "~> 1.1", optional: true})
    end
  end

  describe "DIST-05 example≡template byte-parity (sigra_admin.css)" do
    test "example copy is byte-identical to the installer template" do
      template = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
      example = File.read!("test/example/priv/static/assets/sigra_admin.css")

      assert byte_size(template) == byte_size(example),
             "size mismatch — resync with: cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css"

      assert template == example,
             "content mismatch — example copy has diverged from the installer template; resync with: cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css"
    end
  end

  describe "D-11 System↔explicit-toggle dark-block parity" do
    test "admin dark @media block and app.css explicit-toggle dark block declare identical --sg-* values" do
      admin_css = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
      app_css = File.read!("test/example/priv/static/assets/css/app.css")

      admin_dark_props = extract_dark_media_props(admin_css)
      app_dark_props = extract_explicit_dark_props(app_css)

      assert admin_dark_props == app_dark_props,
             "Dark --sg-* token values diverged between System path (@media prefers-color-scheme: dark in sigra_admin.css) " <>
               "and explicit-toggle path (html[data-sg-admin-theme=dark] .sg-admin-shell in app.css) — " <>
               "update BOTH dark blocks together when changing any dark token"

      # Dark brand-strong must be #fdba74 (WCAG AA lightened value from v1.34; supersedes
      # the scoped .sg-filter-chip fix). If changed, update all four parity surfaces and
      # both snapshot allowlists (snapshot-allowlist + snapshot-allowlist-design).
      assert "--sg-color-brand-strong: #fdba74;" in admin_dark_props,
             "dark brand-strong must be #fdba74 (WCAG AA lightened value from v1.34); " <>
               "if changed, update all four parity surfaces and both snapshot allowlists"
    end

    test "auth ember-family values match admin equivalents in light and dark" do
      admin_css = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
      auth_css = File.read!("priv/templates/sigra.install/core/sigra_auth.css")

      # Light ember parity
      for {admin_token, auth_token} <- [
            {"--sg-color-risk", "--sigra-auth-risk"},
            {"--sg-color-warn", "--sigra-auth-warn"},
            {"--sg-color-ok", "--sigra-auth-ok"}
          ] do
        admin_val = extract_token_value(admin_css, admin_token)
        auth_val = extract_token_value(auth_css, auth_token)

        assert admin_val == auth_val,
               "Light ember parity mismatch for #{admin_token} (admin) vs #{auth_token} (auth): " <>
                 "#{inspect(admin_val)} != #{inspect(auth_val)} — " <>
                 "update sigra_auth.css to restore ember parity"
      end

      # Dark ember parity — extract dark-block lines from each file
      admin_dark_lines =
        admin_css |> extract_dark_media_props() |> Enum.join("\n")

      auth_dark_lines =
        auth_css
        |> String.split("\n")
        |> Enum.drop_while(&(not String.contains?(&1, "data-theme=\"dark\"")))
        |> Enum.take(30)
        |> Enum.join("\n")

      # Note: --sg-color-panel vs --sigra-auth-surface intentionally differ
      # (#1f1d1a vs #211f1c); not asserted here.
      for {admin_token, auth_token, dark_val} <- [
            {"--sg-color-risk", "--sigra-auth-risk", "#f8a39c"},
            {"--sg-color-warn", "--sigra-auth-warn", "#f5c451"},
            {"--sg-color-ok", "--sigra-auth-ok", "#5dd1a0"}
          ] do
        assert String.contains?(admin_dark_lines, "#{admin_token}: #{dark_val};"),
               "Admin dark #{admin_token} should be #{dark_val} — " <>
                 "if changed, update sigra_auth.css to restore ember parity"

        assert String.contains?(auth_dark_lines, "#{auth_token}: #{dark_val};"),
               "Auth dark #{auth_token} should be #{dark_val} — " <>
                 "update sigra_auth.css to restore ember parity with admin dark tokens"
      end
    end

    test "admin token reference documents every canonical :root --sg-* token" do
      admin_css = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
      token_reference = File.read!("guides/reference/admin-token-reference.md")

      documented_tokens =
        ~r/`(--sg-[\w-]+)`/
        |> Regex.scan(token_reference, capture: :all_but_first)
        |> List.flatten()
        |> MapSet.new()

      missing_tokens =
        admin_css
        |> extract_root_sg_token_names()
        |> Enum.reject(&MapSet.member?(documented_tokens, &1))

      assert missing_tokens == [],
             "guides/reference/admin-token-reference.md is missing documented rows for: " <>
               Enum.join(missing_tokens, ", ")
    end
  end

  defp extract_dark_media_props(css) do
    css
    |> extract_css_block("@media (prefers-color-scheme: dark)")
    |> extract_sg_declarations()
  end

  defp extract_explicit_dark_props(css) do
    css
    |> extract_css_block(~s(html[data-sg-admin-theme="dark"] .sg-admin-shell))
    |> extract_sg_declarations()
  end

  defp extract_css_block(css, selector) do
    with {selector_offset, _} <- :binary.match(css, selector),
         block_source <- binary_part(css, selector_offset, byte_size(css) - selector_offset),
         {brace_offset, 1} <- :binary.match(block_source, "{") do
      block_source
      |> binary_part(brace_offset, byte_size(block_source) - brace_offset)
      |> take_balanced_block()
    else
      :nomatch -> flunk("Could not find CSS block for #{selector}")
    end
  end

  defp take_balanced_block(source) do
    source
    |> String.graphemes()
    |> Enum.reduce_while({0, []}, fn
      "{", {depth, chars} ->
        {:cont, {depth + 1, ["{" | chars]}}

      "}", {1, chars} ->
        {:halt, Enum.reverse(["}" | chars])}

      "}", {depth, chars} ->
        {:cont, {depth - 1, ["}" | chars]}}

      char, {depth, chars} ->
        {:cont, {depth, [char | chars]}}
    end)
    |> case do
      chars when is_list(chars) -> Enum.join(chars)
      {_depth, _chars} -> flunk("Could not find balanced CSS block")
    end
  end

  defp extract_sg_declarations(block) do
    ~r/--sg-[\w-]+\s*:\s*[^;]+;/s
    |> Regex.scan(block)
    |> List.flatten()
    |> Enum.map(fn declaration ->
      declaration
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    end)
    |> Enum.sort()
  end

  defp extract_root_sg_token_names(css) do
    css
    |> extract_css_blocks(":root")
    |> Enum.flat_map(&extract_sg_declarations/1)
    |> Enum.map(fn declaration ->
      [token_name, _value] = String.split(declaration, ":", parts: 2)
      token_name
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp extract_css_blocks(css, selector) do
    do_extract_css_blocks(css, selector, [])
  end

  defp do_extract_css_blocks(css, selector, blocks) do
    case :binary.match(css, selector) do
      {selector_offset, _} ->
        block_source = binary_part(css, selector_offset, byte_size(css) - selector_offset)

        case :binary.match(block_source, "{") do
          {brace_offset, 1} ->
            block_with_prefix =
              binary_part(block_source, brace_offset, byte_size(block_source) - brace_offset)

            block = take_balanced_block(block_with_prefix)
            consumed_bytes = selector_offset + brace_offset + byte_size(block)
            rest = binary_part(css, consumed_bytes, byte_size(css) - consumed_bytes)
            do_extract_css_blocks(rest, selector, [block | blocks])

          :nomatch ->
            Enum.reverse(blocks)
        end

      :nomatch ->
        Enum.reverse(blocks)
    end
  end

  defp extract_token_value(css, token_name) do
    css
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      trimmed = String.trim(line)

      if String.starts_with?(trimmed, token_name <> ":") do
        trimmed
        |> String.replace_prefix(token_name <> ":", "")
        |> String.trim()
        |> String.trim_trailing(";")
      end
    end)
  end

  defp source_order?(source, first, second) do
    first_offset = source_offset(source, first)
    second_offset = source_offset(source, second)

    is_integer(first_offset) and is_integer(second_offset) and first_offset < second_offset
  end

  defp source_fragment(source, needle, len) do
    case :binary.match(source, needle) do
      {start, _} -> binary_part(source, start, min(len, byte_size(source) - start))
      :nomatch -> ""
    end
  end

  defp source_offset(source, needle) do
    case :binary.match(source, needle) do
      {offset, _} -> offset
      :nomatch -> nil
    end
  end
end
