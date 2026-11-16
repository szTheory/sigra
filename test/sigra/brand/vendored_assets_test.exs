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

  @root Path.expand("../../..", __DIR__)
  @fonts_dir "test/example/priv/static/assets/fonts"

  # {book source, example copy}. Copy with `cp`; never edit either side.
  @pairs [
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
    if String.contains?(strip_comments(css), "@font-face"), do: [:font_face], else: []
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
