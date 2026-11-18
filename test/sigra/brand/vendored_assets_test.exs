defmodule Sigra.Brand.VendoredAssetsTest do
  @moduledoc """
  BTOK-06 and the asset half of BTOK-05: the two web fonts, their OFL texts and
  the favicon pair are byte-identical copies of the files under `brand/`,
  vendored into the Sigra-owned example app by `cp` and never edited.

  `brand/` itself is pinned by `brand.sha256` (see `source_pin_test.exs`); this
  module pins the copies against it. The comparison is a sha256 over the bytes,
  so a renamed, re-encoded or hand-edited copy fails and the failure message
  names the exact `cp` that restores it.

  The root `test/example/priv/static/favicon.ico` (the demo's own icon) must stay
  byte-unchanged: Tasklane pages keep the demo identity, and only Sigra-owned
  pages link the book favicons.

  Red-ness is proven only by in-memory controls on `parity/2`. Never mutate a real
  file to show a guard can fail. Pure filesystem and stdlib `:crypto`; the repo
  root is resolved from `__DIR__`, never from the working directory.
  """

  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Admin
  alias Sigra.Branding.Contrast

  @root Path.expand("../../..", __DIR__)
  @fonts_dir "test/example/priv/static/assets/fonts"

  # {book source, example copy}. Copy with `cp`; never edit either side.
  @pairs [
    {"brand/assets/logo/sigra-lockup-light.svg", "docs/assets/brand/sigra-lockup-light.svg"},
    {"brand/assets/logo/sigra-lockup-dark.svg", "docs/assets/brand/sigra-lockup-dark.svg"},
    {"brand/assets/social/sigra-social-card-1280x640.png",
     "docs/assets/brand/social-card-1280x640.png"},
    {"guides/assets/admin-user-detail-demo-showcase-chromium.png",
     "docs/assets/screenshots/admin-user-detail-demo-showcase-chromium.png"},
    {"guides/assets/admin-user-list-demo-showcase-chromium.png",
     "docs/assets/screenshots/admin-user-list-demo-showcase-chromium.png"},
    {"guides/assets/audit-explorer-demo-showcase-chromium.png",
     "docs/assets/screenshots/audit-explorer-demo-showcase-chromium.png"},
    {"guides/assets/demo-credentials-demo-showcase-chromium.png",
     "docs/assets/screenshots/demo-credentials-demo-showcase-chromium.png"},
    {"brand/assets/icon/favicon.svg", "docs/assets/brand/favicon.svg"},
    {"brand/assets/fonts/web/fonts.css", "docs/assets/fonts/fonts.css"},
    {"brand/assets/fonts/web/sans.woff2", "docs/assets/fonts/sans.woff2"},
    {"brand/assets/fonts/web/mono.woff2", "docs/assets/fonts/mono.woff2"},
    {"brand/assets/fonts/web/sans.woff2", "#{@fonts_dir}/instrument-sans-var.woff2"},
    {"brand/assets/fonts/web/mono.woff2", "#{@fonts_dir}/red-hat-mono-var.woff2"},
    {"brand/assets/fonts/OFL-InstrumentSans.txt", "#{@fonts_dir}/OFL-InstrumentSans.txt"},
    {"brand/assets/fonts/OFL-RedHatMono.txt", "#{@fonts_dir}/OFL-RedHatMono.txt"},
    {"brand/assets/icon/favicon.svg", "test/example/priv/static/favicon.svg"},
    {"brand/assets/icon/favicon.ico", "test/example/priv/static/images/sigra-favicon.ico"}
  ]

  # The names this phase adds beside the demo's own Inter, Fraunces and Space
  # Grotesk files (`-var.woff2` and `OFL-` follow the existing naming).
  @sigra_owned_font_files ~w(
    instrument-sans-var.woff2
    red-hat-mono-var.woff2
    OFL-InstrumentSans.txt
    OFL-RedHatMono.txt
  )

  # The Sigra-owned example stylesheet (linked after app.css in the example root
  # layout) and the one rule it may hold besides the two font-face rules: the
  # opt-in font tokens, scoped to the admin shell. Values are the book's stacks.
  @brand_css "test/example/priv/static/assets/css/sigra_admin_brand.css"
  @brand_font_tokens %{
    "--sg-font-sans" => "'Instrument Sans', system-ui, -apple-system, 'Segoe UI', sans-serif",
    "--sg-font-mono" => "'Red Hat Mono', ui-monospace, 'SF Mono', Consolas, monospace"
  }

  # The installer ships text only (BTOK-06): the stylesheet template carries no
  # font-face rule and nothing under the templates directory is a font or icon.
  @templates_dir "priv/templates/sigra.install"
  @admin_css_template "#{@templates_dir}/admin/sigra_admin.css"
  @binary_exts ~w(.woff .woff2 .ttf .otf .ico)

  # sha256 of the demo's root favicon.ico (152 bytes, 64px PNG) at the start of
  # Phase 261, computed with `shasum -a 256`. The root icon is left alone.
  @root_favicon "test/example/priv/static/favicon.ico"
  @root_favicon_sha256 "01723aeae3ce3b5195a8f42e3eb6e9018a8c08b7acda4ed382b31341811f0a8a"

  describe "byte parity with brand/" do
    for {brand, example} <- @pairs do
      @brand brand
      @example example

      test "#{@example} is a byte-identical copy of #{@brand}" do
        contents = read_pair_files({@brand, @example})

        assert parity({@brand, @example}, contents) == :ok,
               "#{@example} differs from #{@brand} (sha256 mismatch). The vendored copy is " <>
                 "never edited; restore it from the repo root with:\n\n" <>
                 "  cp #{@brand} #{@example}\n"
      end
    end
  end

  describe "packaged ExDoc assets" do
    test "the README opens with the approved lockup, copy, and install action" do
      readme = @root |> Path.join("README.md") |> File.read!()

      assert Regex.match?(
               ~r/^<picture role="heading" aria-level="1">\s*<source media="\(prefers-color-scheme: dark\)" srcset=".*sigra-header-dark\.svg">\s*<img src=".*sigra-header-light\.svg" alt="Sigra" width="260">\s*<\/picture>\s*<p><b>Phoenix auth you own and can still update\.<\/b><\/p>\s*<p>Production-minded authentication for Phoenix 1\.8\+<\/p>\s*\*\*\[Install Sigra\]\(guides\/introduction\/installation\.md\)\*\*.*?\n\[!\[Hex version\]/s,
               readme
             )

      assert readme =~ "prefers-color-scheme: dark"
      assert readme =~ "alt=\"Sigra\" width=\"260\""
      refute readme =~ "\n# Sigra\n"

      assert readme =~
               "**[Install Sigra](guides/introduction/installation.md)** — add `{:sigra, \"~> 1.7.1\"}` to `mix.exs`"
    end

    test "the README social-card reference resolves to the packaged asset" do
      readme = @root |> Path.join("README.md") |> File.read!()
      social_card = Path.join(@root, "docs/assets/brand/social-card-1280x640.png")

      assert String.contains?(readme, "[Social card](docs/assets/brand/social-card-1280x640.png)")
      assert File.regular?(social_card)
    end

    test "showcase guide images point at packaged screenshot copies" do
      guide = @root |> Path.join("guides/introduction/demo-showcase.md") |> File.read!()

      for filename <- ~w(
            admin-user-detail-demo-showcase-chromium.png
            admin-user-list-demo-showcase-chromium.png
            audit-explorer-demo-showcase-chromium.png
            demo-credentials-demo-showcase-chromium.png
          ) do
        packaged_path = "assets/screenshots/#{filename}"
        packaged_file = Path.join(@root, "docs/#{packaged_path}")

        assert String.contains?(guide, packaged_path)
        assert File.regular?(packaged_file)
      end
    end

    test "favicon and stylesheet URLs resolve through the docs asset mapping" do
      mix_exs = @root |> Path.join("mix.exs") |> File.read!()

      assert String.contains?(mix_exs, ~s(favicon: "docs/assets/brand/favicon.svg"))
      assert String.contains?(mix_exs, ~s("docs/assets" => "assets"))
      assert String.contains?(mix_exs, ~s("guides/assets" => "assets"))
      assert String.contains?(mix_exs, ~s({"docs_config.js", ""}))
      assert String.contains?(mix_exs, ~s(href="assets/brand/sigra-exdoc.css"))
      assert String.contains?(mix_exs, ~s(href="assets/brand/sigra-exdoc-shell.css"))
      assert File.regular?(Path.join(@root, "docs/assets/brand/sigra-exdoc-shell.css"))
    end

    test "the copied stylesheet preserves the brand colors and imports packaged fonts" do
      source = @root |> Path.join("brand/assets/docs/sigra-exdoc.css") |> File.read!()
      css = read_docs_css()
      import = "@import url(\"../fonts/fonts.css\");\n\n"

      assert String.starts_with?(css, import <> source)
      assert String.contains?(css, "'Instrument Sans', system-ui, sans-serif")
      assert String.contains?(css, "'Red Hat Mono', ui-monospace, monospace")
      assert String.contains?(css, "@media (prefers-color-scheme: dark)")
      assert String.contains?(css, "body.dark {")
    end

    test "ExDoc chrome uses the Sigra type and palette in both theme states" do
      css = @root |> Path.join("docs/assets/brand/sigra-exdoc-shell.css") |> File.read!()

      assert css_declaration(css, ":root", "--sansFontFamily") ==
               ~s|"Instrument Sans", system-ui, sans-serif|

      assert css_declaration(css, ":root", "--monoFontFamily") ==
               ~s|"Red Hat Mono", ui-monospace, monospace|

      for {property, expected} <- [
            {"--background", "var(--sigra-doc-page-bg)"},
            {"--sidebarBackground", "var(--sigra-doc-page-bg)"},
            {"--sidebarHeader", "var(--sigra-doc-soft)"},
            {"--sidebarItem", "var(--sigra-doc-page-text)"},
            {"--sidebarActiveItem", "var(--sigra-doc-link)"},
            {"--searchSearch", "var(--sigra-doc-surface-bg)"},
            {"--modalBackground", "var(--sigra-doc-surface-bg)"},
            {"--autocompleteBackground", "var(--sigra-doc-surface-bg)"},
            {"--link-color", "var(--sigra-doc-link)"}
          ] do
        assert css_declaration(css, ":root, body.dark", property) == expected
      end

      assert css_declaration(css, ":root", "--sigra-doc-page-bg") == "#F7F3EE"
      assert css_declaration(css, "body.dark", "--sigra-doc-page-bg") == "#17120F"

      assert css_declaration(
               css,
               "#settings-modal-content .switch-button__checkbox",
               "background-color"
             ) == "var(--sigra-doc-surface-bg)"

      assert css_declaration(
               css,
               "#settings-modal-content .switch-button__checkbox",
               "border-color"
             ) == "var(--sigra-doc-control-edge)"

      assert css_declaration(
               css,
               "#settings-modal-content .switch-button__bg",
               "background-color"
             ) ==
               "var(--sigra-doc-soft)"

      assert css_declaration(css, "#settings-modal-content .switch-button__bg", "border") ==
               "1px solid var(--sigra-doc-control-edge)"

      assert css_declaration(
               css,
               "#settings-modal-content .switch-button__checkbox:checked + .switch-button__bg",
               "background-color"
             ) == "var(--sigra-doc-link)"

      assert css_declaration(
               css,
               "#settings-modal-content .switch-button__checkbox:focus + .switch-button__bg",
               "outline"
             ) == "2px solid var(--sigra-doc-focus)"

      assert css_declaration(
               css,
               "#settings-modal-content .switch-button__checkbox:focus:not(:focus-visible) + .switch-button__bg",
               "outline"
             ) == "none"

      assert css_declaration(
               css,
               ".top-search .search-bar .search-input::placeholder",
               "color"
             ) == "var(--sigra-doc-muted)"

      assert css_declaration(
               css,
               ".top-search .search-bar .search-input::placeholder",
               "opacity"
             ) == "1"

      assert String.contains?(css, ~S{.top-heading:has(> .copy-markdown[href="readme.md"]) > h1})

      assert css_declaration(
               css,
               ~S{.top-heading:has(> .copy-markdown[href="readme.md"]) > h1},
               "display"
             ) == "none"

      assert String.contains?(css, ".content-inner picture img")
      assert String.contains?(css, "max-width: min(260px, 100%)")
    end

    test "authored typography, colors, and focus meet the approved contract" do
      css = read_docs_css()

      assert css_declaration(css, "body", "font-family") ==
               "'Instrument Sans', system-ui, sans-serif"

      assert css_declaration(css, "body", "font-size") == "16px"
      assert css_declaration(css, "body", "font-weight") == "400"
      assert css_declaration(css, "body", "line-height") == "1.55"
      assert css_declaration(css, "h1,h2,h3,h4,h5,h6", "font-size") == "28px"
      assert css_declaration(css, "h1,h2,h3,h4,h5,h6", "font-weight") == "700"
      assert css_declaration(css, "h1,h2,h3,h4,h5,h6", "line-height") == "1.2"
      assert css_declaration(css, "body", "color") == "var(--sigra-page-text)"

      assert css_declaration(css, ".content .content-inner", "color") ==
               "var(--sigra-surface-text)"

      assert css_declaration(css, "body a", "color") == "var(--sigra-link)"
      assert css_declaration(css, ".content-inner a", "color") == "var(--sigra-link)"
      assert css_declaration(css, "body", "color", 1) == "var(--sigra-page-text)"

      assert css_declaration(css, ".content .content-inner", "color", 1) ==
               "var(--sigra-surface-text)"

      assert css_declaration(css, "body a", "color", 1) == "var(--sigra-link)"
      assert css_declaration(css, ".content-inner a", "color", 1) == "var(--sigra-link)"
      assert css_declaration(css, "body.dark", "color", 2) == "var(--sigra-page-text)"

      assert css_declaration(css, "body.dark .content .content-inner", "color") ==
               "var(--sigra-surface-text)"

      assert css_declaration(css, "body.dark a", "color") == "var(--sigra-link)"

      assert css_declaration(css, "body.dark .content-inner a", "color") ==
               "var(--sigra-link)"

      assert css_declaration(css, "pre code.makeup", "font-family", 1) ==
               "'Red Hat Mono', ui-monospace, monospace"

      assert css_declaration(css, "pre code.makeup", "font-size", 1) == "13px"
      assert css_declaration(css, "pre code.makeup", "font-weight", 1) == "400"
      assert css_declaration(css, "pre code.makeup", "line-height", 1) == "1.5"
      assert css_declaration(css, "pre code.makeup", "background") == "var(--sigra-doc-bg)"
      assert css_declaration(css, "pre code.makeup", "color") == "var(--sigra-doc-text)"
      assert String.contains?(css, ".makeup .c,.makeup .c1,.makeup .cm")
      assert String.contains?(css, ".makeup .k,.makeup .kd,.makeup .kn")
      assert String.contains?(css, ".makeup .s,.makeup .s1,.makeup .s2")
      assert String.contains?(css, ".makeup .ss,.makeup .na,.makeup .no")

      assert css_declaration(css, ":focus-visible", "outline") ==
               "2px solid var(--sigra-focus)"

      assert_contrast(css, :light, ":root", 2, ":root", 0)
      assert_contrast(css, :dark_system, ":root", 3, ":root", 1)
      assert_contrast(css, :dark_explicit, "body.dark", 1, "body.dark", 0)

      assert css_declaration(css, "body.dark :focus-visible", "outline-color") ==
               "var(--sigra-focus)"

      # The contract's missing-rule control is in memory; no repository file is modified.
      planted = String.replace(css, "body a {", "body a_missing {")
      assert :light_body_link in css_violations(planted)
    end
  end

  describe "parity/2 positive controls" do
    test "identical bytes are reported as parity" do
      pair = {"book/a.bin", "example/a.bin"}
      contents = %{"book/a.bin" => <<1, 2, 3, 4>>, "example/a.bin" => <<1, 2, 3, 4>>}

      assert parity(pair, contents) == :ok
    end

    test "one flipped byte in an otherwise identical real font is reported as a mismatch" do
      {brand, example} = pair = hd(@pairs)
      contents = read_pair_files(pair)

      planted = Map.update!(contents, example, &flip_last_byte/1)

      assert byte_size(planted[example]) == byte_size(contents[brand])
      assert parity(pair, planted) == {:mismatch, example}
    end

    test "one missing byte is reported as a mismatch" do
      {_brand, example} = pair = List.last(@pairs)
      contents = read_pair_files(pair)

      planted = Map.update!(contents, example, &binary_part(&1, 0, byte_size(&1) - 1))

      assert parity(pair, planted) == {:mismatch, example}
    end
  end

  describe "vendored font files" do
    test "the Sigra-owned font names sit beside the demo's fonts and no stray variant exists" do
      listing = @root |> Path.join(@fonts_dir) |> File.ls!() |> Enum.sort()

      owned =
        Enum.filter(
          listing,
          &String.contains?(String.downcase(&1), ["instrument", "red-hat", "redhat"])
        )

      assert Enum.sort(@sigra_owned_font_files) == owned
    end
  end

  describe "root favicon.ico" do
    test "stays byte-unchanged so Tasklane pages keep the demo identity" do
      bytes = @root |> Path.join(@root_favicon) |> File.read!()

      assert sha256_hex(bytes) == @root_favicon_sha256,
             "#{@root_favicon} changed. Phase 261 leaves the demo's root favicon alone; " <>
               "restore it with: git checkout -- #{@root_favicon}"
    end
  end

  describe "example brand stylesheet" do
    test "holds exactly two local font-face rules and one font-token rule on the admin shell" do
      css = read_brand_css()

      assert String.contains?(css, "@font-face")
      assert brand_css_violations(css) == []
    end

    test "a header comment that names the at-rule is not counted as a font-face rule" do
      css = "/* the @font-face rules below are self-hosted */\n" <> read_brand_css()

      assert brand_css_violations(css) == []
    end

    test "a third font-face rule is reported" do
      extra =
        "@font-face { font-family: X; src: url('/assets/fonts/x.woff2'); font-display: swap; }"

      assert :font_face_count in brand_css_violations(read_brand_css() <> extra)
    end

    test "a CDN source is reported" do
      css =
        String.replace(
          read_brand_css(),
          "/assets/fonts/instrument-sans-var.woff2",
          "https://fonts.example.net/sans.woff2"
        )

      assert :font_url in brand_css_violations(css)
      assert :remote_or_inline in brand_css_violations(css)
    end

    test "a base64 data URI source is reported" do
      css =
        String.replace(
          read_brand_css(),
          "/assets/fonts/red-hat-mono-var.woff2",
          "data:font/woff2;base64,AAAA"
        )

      assert :font_url in brand_css_violations(css)
      assert :remote_or_inline in brand_css_violations(css)
    end

    test "a face without font-display: swap is reported" do
      css =
        String.replace(read_brand_css(), "font-display: swap", "font-display: auto",
          global: false
        )

      assert :font_display in brand_css_violations(css)
    end

    test "an extra rule or a changed token value is reported" do
      real = read_brand_css()
      narrowed = String.replace(real, "'Instrument Sans', system-ui", "'Instrument Sans'")

      assert :rule_set in brand_css_violations(real <> ".sg-btn { color: red; }")
      assert :rule_set in brand_css_violations(narrowed)
    end
  end

  describe "installer ships text only" do
    test "every Admin.files/1 entry is the :eex kind" do
      files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")

      # Non-vacuous: the list really is the admin feature's, stylesheet entry included.
      assert {:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"} in files
      assert file_kind_violations(files) == []
    end

    test "a planted non-eex file entry is reported by the file-kind guard" do
      planted = [
        {:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"},
        {:binary, "admin/fonts/sans.woff2", "priv/static/assets/fonts/sans.woff2"}
      ]

      assert file_kind_violations(planted) ==
               [{:binary, "admin/fonts/sans.woff2", "priv/static/assets/fonts/sans.woff2"}]
    end

    test "no font or icon binary lives under the installer templates" do
      paths = template_paths()

      # Non-vacuous: the walk really sees the installer templates.
      assert "admin/sigra_admin.css" in paths
      assert binary_asset_paths(paths) == []
    end

    test "a planted font or icon path is reported by the binary-asset guard, whatever its case" do
      planted = ["admin/sigra_admin.css", "admin/fonts/sans.woff2", "core/Favicon.ICO", "a/b.ttf"]

      assert binary_asset_paths(planted) ==
               ["admin/fonts/sans.woff2", "core/Favicon.ICO", "a/b.ttf"]
    end

    test "sigra_admin.css ships no font-face rule" do
      css = @root |> Path.join(@admin_css_template) |> File.read!()

      # Non-vacuous: this is the real stylesheet, not an empty or missing read.
      assert String.contains?(css, ".sg-admin-shell")
      assert font_face_violations(css) == []
    end

    test "a planted font-face rule is reported by the stylesheet guard" do
      css = ".sg-btn { color: red; }\n@font-face { font-family: X; src: url('/x.woff2'); }\n"

      assert font_face_violations(css) == [:font_face]
    end

    test "the stylesheet guard recognizes case-insensitive font-face at-rules" do
      for at_rule <- ["@font-face", "@FONT-FACE", "@Font-Face"] do
        css = ".sg-btn { color: red; }\n#{at_rule} { font-family: X; src: url('/x.woff2'); }\n"

        assert font_face_violations(css) == [:font_face]
      end
    end

    test "prose that names the at-rule inside a comment is not a font-face rule" do
      css =
        "/* hosts add their own @font-face rules; none ships here */\n.sg-btn { color: red; }\n"

      assert font_face_violations(css) == []
    end
  end

  # -- pure helpers ----------------------------------------------------------

  # Violations of the Sigra-owned example stylesheet contract (BTOK-06), as a list
  # of atoms; `[]` is clean. Block comments are stripped first, so prose that
  # names the at-rule is not a rule. Pure, so planted strings run the same code.
  defp brand_css_violations(css) do
    stripped = strip_comments(css)
    faces = ~r/@font-face\s*\{([^}]*)\}/ |> Regex.scan(stripped) |> Enum.map(&List.last/1)
    rest = Regex.replace(~r/@font-face\s*\{[^}]*\}/, stripped, "")

    checks = [
      {:font_face_count, length(faces) != 2},
      {:font_display, Enum.any?(faces, &(not Regex.match?(~r/font-display:\s*swap\s*;/, &1)))},
      {:font_url, not Enum.all?(faces, &local_font_urls?/1)},
      {:remote_or_inline, Regex.match?(~r{https?:|data:|@import|//}, stripped)},
      {:rule_set, rules(rest) != [{".sg-admin-shell", @brand_font_tokens}]}
    ]

    for {kind, true} <- checks, do: kind
  end

  # Installer guards. Pure, so the planted controls call the same functions the real
  # assertions call.

  # Entries of a feature's `files/1` list that are not the text-only `{:eex, src, target}`
  # kind (the installer has no binary kind).
  defp file_kind_violations(files), do: Enum.reject(files, &match?({:eex, _src, _target}, &1))

  # Paths with a font or icon binary extension, compared case-insensitively.
  defp binary_asset_paths(paths) do
    Enum.filter(paths, &(&1 |> Path.extname() |> String.downcase() |> Kernel.in(@binary_exts)))
  end

  # `[:font_face]` when a comment-stripped stylesheet declares the at-rule.
  defp font_face_violations(css) do
    if Regex.match?(~r/@font-face(?![\w-])/i, strip_comments(css)), do: [:font_face], else: []
  end

  # Regular files under the installer templates, relative to that directory.
  defp template_paths do
    templates = Path.join(@root, @templates_dir)

    templates
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, templates))
  end

  defp strip_comments(css), do: Regex.replace(~r{/\*.*?\*/}s, css, "")

  # Every `url(...)` in one face body points under /assets/fonts/, and there is one.
  defp local_font_urls?(face) do
    urls = ~r/url\(\s*['"]?([^'")\s]+)/ |> Regex.scan(face) |> Enum.map(&List.last/1)

    urls != [] and Enum.all?(urls, &String.starts_with?(&1, "/assets/fonts/"))
  end

  # `[{selector, %{property => value}}]` for the plain rules left in the stylesheet.
  defp rules(css) do
    for [_whole, selector, body] <- Regex.scan(~r/([^{}]+)\{([^}]*)\}/, css) do
      declarations =
        body
        |> String.split(";")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Map.new(fn declaration ->
          [property, value] = String.split(declaration, ":", parts: 2)
          {String.trim(property), String.trim(value)}
        end)

      {String.trim(selector), declarations}
    end
  end

  defp read_brand_css, do: @root |> Path.join(@brand_css) |> File.read!()

  defp read_docs_css, do: @root |> Path.join("docs/assets/brand/sigra-exdoc.css") |> File.read!()

  defp css_declaration(css, selector, property, occurrence \\ 0) do
    pattern = ~r/(?:^|[{}\n])\s*#{Regex.escape(selector)}\s*\{([^{}]*)\}/s

    Regex.scan(pattern, strip_comments(css))
    |> Enum.map(&List.last/1)
    |> Enum.at(occurrence)
    |> case do
      nil ->
        nil

      body ->
        body
        |> String.split(";")
        |> Enum.find_value(fn declaration ->
          case String.split(String.trim(declaration), ":", parts: 2) do
            [^property, value] -> String.trim(value)
            _ -> nil
          end
        end)
    end
  end

  defp css_violations(css) do
    checks = [
      {:light_body_link, css_declaration(css, "body a", "color") == nil},
      {:light_focus, css_declaration(css, ":focus-visible", "outline") == nil},
      {:dark_system, css_declaration(css, ":root", "--sigra-page-bg", 3) == nil},
      {:dark_explicit, css_declaration(css, "body.dark", "--sigra-page-bg", 1) == nil}
    ]

    for {kind, true} <- checks, do: kind
  end

  defp assert_contrast(css, mode, selector, occurrence, code_selector, code_occurrence) do
    values = %{
      page: css_declaration(css, selector, "--sigra-page-bg", occurrence),
      page_text: css_declaration(css, selector, "--sigra-page-text", occurrence),
      surface: css_declaration(css, selector, "--sigra-surface-bg", occurrence),
      surface_text: css_declaration(css, selector, "--sigra-surface-text", occurrence),
      link: css_declaration(css, selector, "--sigra-link", occurrence),
      focus: css_declaration(css, selector, "--sigra-focus", occurrence)
    }

    for {foreground, background, label} <- [
          {values.page_text, values.page, :page_text_on_page},
          {values.page_text, values.surface, :page_text_on_surface},
          {values.surface_text, values.page, :surface_text_on_page},
          {values.surface_text, values.surface, :surface_text_on_surface},
          {values.link, values.page, :link_on_page},
          {values.link, values.surface, :link_on_surface},
          {values.focus, values.page, :focus_on_page}
        ] do
      minimum = if label == :focus_on_page, do: 3.0, else: 4.5

      assert Contrast.contrast_ratio(foreground, background) >= minimum,
             "#{mode} #{label} contrast is below #{minimum}:1"
    end

    code_background = css_declaration(css, code_selector, "--sigra-doc-bg", code_occurrence)

    code_tokens = [
      "--sigra-doc-text",
      "--sigra-doc-comment",
      "--sigra-doc-keyword",
      "--sigra-doc-string",
      "--sigra-doc-atom"
    ]

    for token <- code_tokens do
      color = css_declaration(css, code_selector, token, code_occurrence)

      assert Contrast.contrast_ratio(color, code_background) >= 4.5,
             "#{mode} #{token} contrast is below 4.5:1"
    end
  end

  # `:ok` when the example copy has the same sha256 as the book source, otherwise
  # `{:mismatch, example_path}`. `contents` is `%{repo_relative_path => bytes}`.
  defp parity({brand, example}, contents) do
    if sha256_hex(Map.fetch!(contents, brand)) == sha256_hex(Map.fetch!(contents, example)),
      do: :ok,
      else: {:mismatch, example}
  end

  defp read_pair_files({brand, example}) do
    Map.new([brand, example], fn rel -> {rel, @root |> Path.join(rel) |> File.read!()} end)
  end

  defp flip_last_byte(bytes) do
    size = byte_size(bytes) - 1
    <<head::binary-size(size), last>> = bytes
    <<head::binary, Bitwise.bxor(last, 1)>>
  end

  defp sha256_hex(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)
end
