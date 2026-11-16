defmodule Sigra.Brand.CssContrastTest do
  @moduledoc """
  BTOK-02: the contrast instrument, proven on the CURRENT stylesheet before any
  token value changes.

  The tracer is one real path through every layer: parse the implemented admin
  stylesheet, resolve a token through the cascade (a `var()` resolves in the scope
  that declares it, a token a theme block does not restate resolves from `:root`),
  composite to hex, run `Sigra.Branding.Contrast.contrast_ratio/2`, assert. The
  body pair (`--sg-color-ink` on `--sg-color-subtle`) is the slice.

  A green run of a check proves nothing until the check has been seen to fire, so
  the positive control plants a bad colour (white label on `#F08A55`, 2.48:1) in
  memory and asserts the pair check goes red. Every real-file test asserts the
  parse is non-empty first, so a broken extraction cannot pass vacuously.
  """

  use ExUnit.Case, async: true

  alias Sigra.Branding.Contrast
  alias Sigra.Test.Brand.CssContrast

  @places [:root, :root_dark, :explicit_light, :explicit_dark]

  # Selectors of expressions the instrument knowingly cannot evaluate. Empty today:
  # an unresolved colour is a hole in the proof, so it must be fixed in the helper,
  # not listed here. The check is an exact match, so a stale entry fails too.
  @unresolved_allowlist []

  # In-memory stylesheet shaped like the shipped one: a :root block, a dark OS
  # block, and the two explicit shell blocks (inside a cascade layer). `--sg-a` is
  # an alias of a theme-variant token declared only in :root, the exact footgun
  # the four-place rule exists to prevent.
  @cascade_css """
  :root {
    --sg-x: #111111;
    --sg-a: var(--sg-x);
    --sg-chain: var(--sg-a);
    --sg-only-root: #abcdef;
    --sg-fallback: var(--sg-missing, #999999);
    --sg-dangling: var(--sg-missing);
    color-scheme: light;
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --sg-x: #222222;
      color-scheme: dark;
    }
  }

  @layer sg-base {
    .sg-admin-shell[data-theme="light"],
    html[data-sg-admin-theme="light"] .sg-admin-shell {
      --sg-x: #333333;
    }

    .sg-admin-shell[data-theme="dark"],
    html[data-sg-admin-theme="dark"] .sg-admin-shell {
      --sg-x: #444444;
    }
  }
  """

  setup_all do
    css = CssContrast.read_css()
    %{css: css, blocks: CssContrast.blocks(css)}
  end

  describe "tracer: the body pair, end to end on the real stylesheet" do
    test "the four token places of the shipped stylesheet are parsed and non-empty", %{
      blocks: blocks
    } do
      for place <- @places do
        refute Map.fetch!(blocks, place) == [],
               "the #{place} block parsed to no --sg-* declarations; the extraction is broken"
      end
    end

    test "body pair (ink on subtle) is at least 4.5 in light", %{blocks: blocks} do
      computed = CssContrast.computed(blocks, os: :light, shell: nil)

      result = body_pair(computed, :light)

      assert result.id == "body"
      assert result.ratio >= 4.5, "body pair light is #{result.ratio}"
      assert result.pass?
    end

    test "body pair (ink on subtle) is at least 4.5 in dark", %{blocks: blocks} do
      computed = CssContrast.computed(blocks, os: :dark, shell: nil)

      result = body_pair(computed, :dark)

      assert result.ratio >= 4.5, "body pair dark is #{result.ratio}"
      assert result.pass?
    end

    test "the ratio is the one Sigra.Branding.Contrast.contrast_ratio/2 computes", %{
      blocks: blocks
    } do
      computed = CssContrast.computed(blocks, os: :light, shell: nil)

      result = body_pair(computed, :light)

      assert result.ratio == Contrast.contrast_ratio(result.text, result.ground)
      assert result.ratio == CssContrast.ratio(result.text, result.ground)
    end

    test "light and dark resolve to different pairs, so the scopes are not collapsed", %{
      blocks: blocks
    } do
      light = body_pair(CssContrast.computed(blocks, os: :light, shell: nil), :light)
      dark = body_pair(CssContrast.computed(blocks, os: :dark, shell: nil), :dark)

      refute light.text == dark.text
      refute light.ground == dark.ground
    end
  end

  describe "positive control: the pair check can go red" do
    test "a planted bad colour (white label on #F08A55, 2.48:1) fails the pair check" do
      result = CssContrast.check_pair("button-planted", :dark, "#FFFFFF", "#F08A55")

      assert result.id == "button-planted"
      assert result.pass? == false
      assert_in_delta result.ratio, 2.48, 0.01
    end

    test "a good pair passes and a custom minimum is honoured" do
      assert %{pass?: true, minimum: 4.5} =
               CssContrast.check_pair("ok", :light, "#000000", "#FFFFFF")

      assert %{pass?: true, minimum: 3} =
               CssContrast.check_pair("ring", :light, "#767676", "#FFFFFF", 3)

      assert %{pass?: false} = CssContrast.check_pair("ring", :light, "#767676", "#FFFFFF", 7)
    end
  end

  describe "computed/2 selects the scope the browser would" do
    test "os light and no shell: ink is the :root value", %{blocks: blocks} do
      computed = CssContrast.computed(blocks, os: :light, shell: nil)

      assert computed["--sg-color-ink"] == declared(blocks.root, "--sg-color-ink")
    end

    test "os dark and no shell: ink is the dark @media value", %{blocks: blocks} do
      computed = CssContrast.computed(blocks, os: :dark, shell: nil)

      assert computed["--sg-color-ink"] == declared(blocks.root_dark, "--sg-color-ink")
      refute computed["--sg-color-ink"] == declared(blocks.root, "--sg-color-ink")
    end

    test "os light and explicit dark shell: ink is the explicit-dark value", %{blocks: blocks} do
      computed = CssContrast.computed(blocks, os: :light, shell: :dark)

      assert computed["--sg-color-ink"] == declared(blocks.explicit_dark, "--sg-color-ink")
      refute computed["--sg-color-ink"] == declared(blocks.root, "--sg-color-ink")
    end

    test "os dark and explicit light shell: ink is the explicit-light value", %{blocks: blocks} do
      computed = CssContrast.computed(blocks, os: :dark, shell: :light)

      assert computed["--sg-color-ink"] == declared(blocks.explicit_light, "--sg-color-ink")
      refute computed["--sg-color-ink"] == declared(blocks.root_dark, "--sg-color-ink")
    end
  end

  describe "computed/2 mirrors the cascade, not a flat merge" do
    setup do
      %{planted: CssContrast.blocks(@cascade_css)}
    end

    test "an alias declared in :root stays at the :root value inside an explicit-dark shell", %{
      planted: planted
    } do
      computed = CssContrast.computed(planted, os: :light, shell: :dark)

      assert computed["--sg-x"] == "#444444"
      # The cascade footgun: the alias was substituted where it is declared (html),
      # so the shell inherits the light result even though --sg-x changed there.
      assert computed["--sg-a"] == "#111111"
      assert computed["--sg-chain"] == "#111111"
    end

    test "an alias resolves against the dark value at the root under a dark OS", %{
      planted: planted
    } do
      computed = CssContrast.computed(planted, os: :dark, shell: nil)

      assert computed["--sg-x"] == "#222222"
      assert computed["--sg-a"] == "#222222"
      assert computed["--sg-chain"] == "#222222"
    end

    test "an explicit light shell over a dark OS inherits the dark alias", %{planted: planted} do
      computed = CssContrast.computed(planted, os: :dark, shell: :light)

      assert computed["--sg-x"] == "#333333"
      assert computed["--sg-a"] == "#222222"
    end

    test "a token a theme block does not restate resolves from :root", %{planted: planted} do
      assert CssContrast.computed(planted, os: :light, shell: :dark)["--sg-only-root"] ==
               "#abcdef"

      assert CssContrast.computed(planted, os: :dark, shell: :light)["--sg-only-root"] ==
               "#abcdef"
    end

    test "a var() fallback is used for a missing token and an unfallbacked var stays visible", %{
      planted: planted
    } do
      computed = CssContrast.computed(planted, os: :light, shell: nil)

      assert computed["--sg-fallback"] == "#999999"
      assert computed["--sg-dangling"] == "var(--sg-missing)"
    end

    test "a self-referencing token does not loop" do
      blocks =
        CssContrast.blocks(
          ":root { --sg-loop: var(--sg-loop); --sg-b: var(--sg-c); --sg-c: var(--sg-b); }"
        )

      computed = CssContrast.computed(blocks, os: :light, shell: nil)

      assert computed["--sg-loop"] == "var(--sg-loop)"
      assert computed["--sg-b"] =~ "var("
    end

    test "invalid scope options are refused" do
      blocks = CssContrast.blocks(@cascade_css)

      assert_raise ArgumentError, fn -> CssContrast.computed(blocks, os: :auto, shell: nil) end

      assert_raise ArgumentError, fn ->
        CssContrast.computed(blocks, os: :light, shell: :system)
      end
    end
  end

  describe "resolve_color/2 colour shapes" do
    test "hex in three, six and eight digits" do
      assert {:ok, {170, 187, 204, 1.0}} = CssContrast.resolve_color("#abc")
      assert {:ok, {194, 65, 12, 1.0}} = CssContrast.resolve_color("#C2410C")
      assert {:ok, {194, 65, 12, alpha}} = CssContrast.resolve_color("#c2410c80")
      assert_in_delta alpha, 128 / 255, 0.0001
    end

    test "rgb and rgba in comma and slash forms" do
      assert {:ok, {21, 21, 21, 0.1}} = CssContrast.resolve_color("rgba(21, 21, 21, 0.1)")
      assert {:ok, {21, 21, 21, 0.16}} = CssContrast.resolve_color("rgb(21 21 21 / 0.16)")
      assert {:ok, {255, 255, 255, 1.0}} = CssContrast.resolve_color("rgb(255, 255, 255)")
      assert {:ok, {255, 255, 255, 0.5}} = CssContrast.resolve_color("rgb(255 255 255 / 50%)")
    end

    test "transparent is transparent black" do
      assert {:ok, {0, 0, 0, alpha}} = CssContrast.resolve_color("transparent")
      assert alpha == 0.0
    end

    test "a token name is looked up in the computed map; an unknown token is unresolved" do
      computed = %{"--sg-a" => "#112233", "--sg-b" => "var(--sg-a)"}

      assert {:ok, {17, 34, 51, 1.0}} = CssContrast.resolve_color("--sg-a", computed)
      assert {:ok, {17, 34, 51, 1.0}} = CssContrast.resolve_color("var(--sg-a)", computed)
      assert {:unresolved, reason} = CssContrast.resolve_color("--sg-nope", computed)
      assert reason =~ "--sg-nope"
    end

    test "resolve_hex/3 composites over a ground and returns upper-case hex" do
      assert {:ok, "#C2410C"} = CssContrast.resolve_hex("#c2410c")
      assert {:unresolved, _reason} = CssContrast.resolve_hex("oklch(0.7 0.1 40)")
    end
  end

  describe "extractors (consolidated for plan 261-03 to import)" do
    @planted_blocks """
    .alpha { --sg-b: 2px; --sg-a:   1px; }
    .mid { color: red; }
    .alpha { --sg-c: 3px; }
    @media (x) { .nested { --sg-n: 1; } }
    """

    test "extract_css_block/2 returns the first balanced block for a selector" do
      assert CssContrast.extract_css_block(@planted_blocks, ".alpha") ==
               "{ --sg-b: 2px; --sg-a:   1px; }"
    end

    test "extract_css_block/2 balances nested braces" do
      assert CssContrast.extract_css_block(@planted_blocks, "@media (x)") ==
               "{ .nested { --sg-n: 1; } }"
    end

    test "extract_css_block/2 raises ArgumentError for a missing selector" do
      assert_raise ArgumentError, ~r/\.absent/, fn ->
        CssContrast.extract_css_block(@planted_blocks, ".absent")
      end
    end

    test "extract_css_blocks/2 returns every block for a repeated selector" do
      assert CssContrast.extract_css_blocks(@planted_blocks, ".alpha") == [
               "{ --sg-b: 2px; --sg-a:   1px; }",
               "{ --sg-c: 3px; }"
             ]

      assert CssContrast.extract_css_blocks(@planted_blocks, ".absent") == []
    end

    test "take_balanced_block/1 raises ArgumentError on an unbalanced block" do
      assert_raise ArgumentError, fn -> CssContrast.take_balanced_block("{ .a { --sg-x: 1; }") end
    end

    test "extract_sg_declarations/1 returns sorted, whitespace-collapsed declarations" do
      block = CssContrast.extract_css_block(@planted_blocks, ".alpha")

      assert CssContrast.extract_sg_declarations(block) == ["--sg-a: 1px;", "--sg-b: 2px;"]
    end

    test "the :root block of the real stylesheet yields declarations", %{css: css} do
      declarations =
        css
        |> CssContrast.extract_css_block(":root")
        |> CssContrast.extract_sg_declarations()

      refute declarations == []
      assert Enum.any?(declarations, &(&1 =~ "--sg-color-ink:"))
    end

    test "css_path/0 is absolute and exists, whatever the working directory" do
      assert Path.type(CssContrast.css_path()) == :absolute
      assert File.regular?(CssContrast.css_path())
      assert String.ends_with?(CssContrast.css_path(), "admin/sigra_admin.css")
    end
  end

  describe "compositing rgba over a ground" do
    test "rgba(21, 21, 21, 0.1) over white is the channel-wise blend, about #E8E8E8" do
      assert {:ok, rgba} = CssContrast.resolve_color("rgba(21, 21, 21, 0.1)")

      assert CssContrast.composite(rgba, "#FFFFFF") == {232, 232, 232}
      assert CssContrast.to_hex(rgba, "#FFFFFF") == "#E8E8E8"
    end

    test "alpha 0 returns the ground and alpha 1 returns the colour" do
      assert CssContrast.to_hex({10, 20, 30, 0.0}, "#ABCDEF") == "#ABCDEF"
      assert CssContrast.to_hex({10, 20, 30, 1.0}, "#ABCDEF") == "#0A141E"
    end

    test "opacity compositing: a disabled primary label over its fill (0.5) is about 2.23 light and 2.76 dark" do
      # `.sg-btn[disabled]` is `opacity: 0.5` on the whole element, so the label and
      # the fill both blend with the page. WCAG 1.4.3 exempts inactive components;
      # the point here is that the instrument evaluates the state instead of
      # skipping it.
      light = disabled_ratio("#FFFFFF", "#C2410C", "#F7F3EE")
      dark = disabled_ratio("#17120F", "#F08A55", "#17120F")

      assert_in_delta light, 2.23, 0.02
      assert_in_delta dark, 2.76, 0.02
    end
  end

  describe "OKLab (published reference vectors)" do
    test "white is (1, 0, 0) and black is (0, 0, 0)" do
      assert_oklab(CssContrast.oklab("#FFFFFF"), {1.0, 0.0, 0.0})
      assert_oklab(CssContrast.oklab("#000000"), {0.0, 0.0, 0.0})
    end

    test "sRGB red, green and blue match the reference to 0.001" do
      assert_oklab(CssContrast.oklab("#FF0000"), {0.6280, 0.2249, 0.1258})
      assert_oklab(CssContrast.oklab("#00FF00"), {0.8664, -0.2339, 0.1795})
      assert_oklab(CssContrast.oklab("#0000FF"), {0.4520, -0.0325, -0.3115})
    end

    test "oklab/1 accepts an rgb tuple as well as a hex" do
      assert_oklab(CssContrast.oklab({255, 0, 0}), {0.6280, 0.2249, 0.1258})
    end

    test "from_oklab(oklab(hex)) round-trips within 1 per channel" do
      for hex <- ["#C2410C", "#F08A55", "#17120F", "#F7F3EE", "#857569", "#1D6B3C", "#EADFD2"] do
        {r, g, b} = Contrast.to_rgb(hex)
        {r2, g2, b2} = hex |> CssContrast.oklab() |> CssContrast.from_oklab()

        assert abs(r - r2) <= 1 and abs(g - g2) <= 1 and abs(b - b2) <= 1,
               "#{hex} round-tripped to #{inspect({r2, g2, b2})}"
      end
    end
  end

  describe "color-mix()" do
    test "in srgb, black 50% with white is #808080" do
      assert {:ok, rgba} = CssContrast.resolve_color("color-mix(in srgb, #000000 50%, #FFFFFF)")

      assert CssContrast.to_hex(rgba, "#FFFFFF") == "#808080"
    end

    test "in oklab, a colour at 22% against transparent keeps the colour and carries alpha 0.22" do
      assert {:ok, {r, g, b, alpha}} =
               CssContrast.resolve_color("color-mix(in oklab, #C2410C 22%, transparent)")

      assert {round(r), round(g), round(b)} == {194, 65, 12}
      assert_in_delta alpha, 0.22, 0.0001
    end

    test "in oklab, an opaque mix differs from the srgb mix by no more than 2 per channel" do
      assert {:ok, {_, _, _, oklab_alpha} = oklab} =
               CssContrast.resolve_color("color-mix(in oklab, #FBFAF7 55%, #FFFFFF)")

      assert {:ok, srgb} = CssContrast.resolve_color("color-mix(in srgb, #FBFAF7 55%, #FFFFFF)")

      assert_in_delta oklab_alpha, 1.0, 0.0001
      {r1, g1, b1} = CssContrast.composite(oklab, "#FFFFFF")
      {r2, g2, b2} = CssContrast.composite(srgb, "#FFFFFF")

      assert abs(r1 - r2) <= 2 and abs(g1 - g2) <= 2 and abs(b1 - b2) <= 2
      assert oklab != srgb
    end

    test "a single percentage leaves the remainder to the other colour" do
      assert {:ok, rgba} = CssContrast.resolve_color("color-mix(in srgb, #000000 25%, #FFFFFF)")

      assert CssContrast.to_hex(rgba, "#FFFFFF") == "#BFBFBF"
    end

    test "omitted percentages split 50/50 and a leading percentage is accepted" do
      assert {:ok, even} = CssContrast.resolve_color("color-mix(in srgb, #000000, #FFFFFF)")

      assert {:ok, leading} =
               CssContrast.resolve_color("color-mix(in srgb, 25% #000000, #FFFFFF)")

      assert CssContrast.to_hex(even, "#FFFFFF") == "#808080"
      assert CssContrast.to_hex(leading, "#FFFFFF") == "#BFBFBF"
    end

    test "percentages that sum to under 100 scale the result alpha" do
      assert {:ok, {r, _g, _b, alpha}} =
               CssContrast.resolve_color("color-mix(in srgb, #000000 20%, #FFFFFF 20%)")

      assert_in_delta r, 127.5, 0.0001
      assert_in_delta alpha, 0.4, 0.0001
    end

    test "interpolation is premultiplied by alpha" do
      assert {:ok, {r, g, b, alpha}} =
               CssContrast.resolve_color("color-mix(in srgb, rgba(255, 0, 0, 0.5) 50%, #0000FF)")

      assert_in_delta alpha, 0.75, 0.0001
      assert_in_delta r, 85.0, 0.0001
      assert_in_delta g, 0.0, 0.0001
      assert_in_delta b, 170.0, 0.0001
    end

    test "mix/4 takes rgba tuples and a percentage pair" do
      assert {:ok, {127.5, 127.5, 127.5, 1.0}} ==
               CssContrast.mix(:srgb, {0, 0, 0, 1.0}, {255, 255, 255, 1.0}, {50, nil})

      assert {:unresolved, _reason} =
               CssContrast.mix(:srgb, {0, 0, 0, 1.0}, {255, 255, 255, 1.0}, {150, nil})

      assert {:unresolved, _reason} =
               CssContrast.mix(:srgb, {0, 0, 0, 1.0}, {255, 255, 255, 1.0}, {0, 0})
    end

    test "an unsupported colour space is unresolved, naming the space" do
      assert {:unresolved, reason} = CssContrast.resolve_color("color-mix(in lab, #fff, #000)")
      assert reason =~ "lab"
    end
  end

  describe "nested and multi-line expressions" do
    test "var() inside color-mix resolves after substitution" do
      computed = %{"--sg-t" => "#C2410C"}

      assert {:ok, {r, g, b, alpha}} =
               CssContrast.resolve_color(
                 "color-mix(in oklab, var(--sg-t) 22%, transparent)",
                 computed
               )

      assert {round(r), round(g), round(b)} == {194, 65, 12}
      assert_in_delta alpha, 0.22, 0.0001
    end

    test "a multi-line color-mix resolves identically to its single-line form" do
      computed = %{"--sg-a" => "#FBFAF7", "--sg-b" => "#FFFFFF"}

      multi_line = """
      color-mix(
        in oklab,
        var(--sg-a) 55%,
        var(--sg-b)
      )
      """

      single_line = "color-mix(in oklab, var(--sg-a) 55%, var(--sg-b))"

      assert CssContrast.resolve_color(multi_line, computed) ==
               CssContrast.resolve_color(single_line, computed)

      assert {:ok, _rgba} = CssContrast.resolve_color(multi_line, computed)
    end

    test "a color-mix operand can itself be a color-mix" do
      assert {:ok, rgba} =
               CssContrast.resolve_color(
                 "color-mix(in srgb, color-mix(in srgb, #000000, #FFFFFF) 50%, #FFFFFF)"
               )

      assert CssContrast.to_hex(rgba, "#FFFFFF") == "#BFBFBF"
    end

    test "a token whose value holds commas does not split the color-mix arguments" do
      computed = %{"--sg-line" => "rgba(21, 21, 21, 0.1)"}

      assert {:ok, {_r, _g, _b, alpha}} =
               CssContrast.resolve_color(
                 "color-mix(in srgb, var(--sg-line) 50%, #FFFFFF)",
                 computed
               )

      assert_in_delta alpha, 0.55, 0.0001
    end

    test "a var() fallback is honoured inside color-mix" do
      assert {:ok, rgba} =
               CssContrast.resolve_color(
                 "color-mix(in srgb, var(--sg-missing, #000000) 50%, #FFFFFF)"
               )

      assert CssContrast.to_hex(rgba, "#FFFFFF") == "#808080"
    end
  end

  describe "fail closed: unresolved expressions" do
    test "currentColor, oklch(), light-dark() and an undefined var() are unresolved with a reason" do
      assert {:unresolved, current} = CssContrast.resolve_color("currentColor")
      assert current =~ ~r/currentcolor/i

      assert {:unresolved, oklch} = CssContrast.resolve_color("oklch(0.7 0.1 40)")
      assert oklch =~ "oklch"

      assert {:unresolved, light_dark} = CssContrast.resolve_color("light-dark(#fff, #000)")
      assert light_dark =~ "light-dark"

      assert {:unresolved, undefined} = CssContrast.resolve_color("var(--sg-nowhere)")
      assert undefined =~ "--sg-nowhere"
    end

    test "unresolved_report/1 lists the unresolved entries with their selector" do
      entries = [
        {".sg-ok", "#C2410C"},
        {".sg-planted", "oklch(0.7 0.1 40)"},
        {".sg-dangling", "var(--sg-nowhere)", %{}},
        {".sg-alias", "var(--sg-t)", %{"--sg-t" => "#112233"}}
      ]

      report = CssContrast.unresolved_report(entries)

      assert Enum.map(report, & &1.selector) == [".sg-planted", ".sg-dangling"]
      assert Enum.all?(report, &(is_binary(&1.reason) and is_binary(&1.value)))
    end

    test "a planted unresolvable expression is rejected against an empty allowlist" do
      report = CssContrast.unresolved_report([{".sg-planted", "oklch(0.7 0.1 40)"}])

      assert report != []

      assert CssContrast.check_unresolved(report, @unresolved_allowlist) ==
               {:error, :allowlist_mismatch}
    end

    test "an allowlist of the wrong size fails closed, in either direction" do
      report = CssContrast.unresolved_report([{".sg-planted", "oklch(0.7 0.1 40)"}])

      assert CssContrast.check_unresolved(report, []) == {:error, :allowlist_mismatch}

      assert CssContrast.check_unresolved(report, [".sg-planted", ".sg-extra"]) ==
               {:error, :allowlist_mismatch}

      assert CssContrast.check_unresolved([], [".sg-stale"]) == {:error, :allowlist_mismatch}
    end

    test "an allowlist that equals the unresolved selectors passes" do
      report =
        CssContrast.unresolved_report([
          {".sg-b", "oklch(0.7 0.1 40)"},
          {".sg-a", "currentColor"},
          {".sg-ok", "#fff"}
        ])

      assert CssContrast.check_unresolved(report, [".sg-a", ".sg-b"]) == :ok
      assert CssContrast.check_unresolved([], @unresolved_allowlist) == :ok
    end

    test "every colour token of the shipped stylesheet resolves in all six scope combinations", %{
      blocks: blocks
    } do
      entries =
        for os <- [:light, :dark],
            shell <- [nil, :light, :dark],
            computed = CssContrast.computed(blocks, os: os, shell: shell),
            {token, value} <- computed,
            colour_token?(token),
            do: {"#{os}/#{shell || "system"}/#{token}", value, computed}

      assert length(entries) > 6 * 20,
             "the colour-token scan is vacuous: #{length(entries)} entries"

      report = CssContrast.unresolved_report(entries)

      assert CssContrast.check_unresolved(report, @unresolved_allowlist) == :ok,
             "unresolved colour tokens: #{inspect(report)}"
    end
  end

  describe "color_mix_expressions/1" do
    @planted_mixes """
    :root { --sg-a: color-mix(in oklab, var(--sg-x) 22%, transparent); }
    @media (hover: hover) {
      .sg-b:hover {
        background: color-mix(
          in oklab,
          var(--sg-y) 55%,
          var(--sg-z)
        );
      }
    }
    /* color-mix(in oklab, red 1%, blue) is a comment and must not be found */
    .sg-c { background: color-mix(in srgb, color-mix(in srgb, #000, #fff) 50%, #fff); }
    """

    test "finds every expression with its selector, balanced, collapsed and without comments" do
      assert CssContrast.color_mix_expressions(@planted_mixes) == [
               {":root", "color-mix(in oklab, var(--sg-x) 22%, transparent)"},
               {".sg-b:hover", "color-mix( in oklab, var(--sg-y) 55%, var(--sg-z) )"},
               {".sg-c", "color-mix(in srgb, color-mix(in srgb, #000, #fff) 50%, #fff)"}
             ]
    end

    test "every color-mix() in the shipped stylesheet resolves in all six scope combinations", %{
      css: css,
      blocks: blocks
    } do
      expressions = CssContrast.color_mix_expressions(css)

      assert length(expressions) >= 30,
             "the color-mix scan is vacuous: #{length(expressions)} expressions"

      entries =
        for os <- [:light, :dark],
            shell <- [nil, :light, :dark],
            computed = CssContrast.computed(blocks, os: os, shell: shell),
            {selector, expression} <- expressions,
            do: {selector, expression, computed}

      report = CssContrast.unresolved_report(entries)

      assert CssContrast.check_unresolved(report, @unresolved_allowlist) == :ok,
             "unresolved color-mix expressions: #{inspect(Enum.uniq_by(report, & &1.selector))}"
    end
  end

  defp colour_token?(token) do
    String.starts_with?(token, ["--sg-color-", "--sg-logo-", "--sg-status-"])
  end

  defp disabled_ratio(label, fill, ground) do
    {:ok, label_rgba} = CssContrast.resolve_color(label)
    {:ok, fill_rgba} = CssContrast.resolve_color(fill)
    {r1, g1, b1, _alpha} = label_rgba
    {r2, g2, b2, _alpha} = fill_rgba

    CssContrast.ratio(
      CssContrast.to_hex({r1, g1, b1, 0.5}, ground),
      CssContrast.to_hex({r2, g2, b2, 0.5}, ground)
    )
  end

  defp assert_oklab({l, a, b}, {expected_l, expected_a, expected_b}) do
    assert_in_delta l, expected_l, 0.001
    assert_in_delta a, expected_a, 0.001
    assert_in_delta b, expected_b, 0.001
  end

  defp body_pair(computed, theme) do
    {:ok, text} = CssContrast.resolve_hex("--sg-color-ink", computed)
    {:ok, ground} = CssContrast.resolve_hex("--sg-color-subtle", computed)

    CssContrast.check_pair("body", theme, text, ground)
  end

  defp declared(block, token) do
    {^token, value} = List.keyfind(block, token, 0)
    value
  end
end
