defmodule Sigra.Brand.ContrastPairsTest do
  @moduledoc """
  BTOK-02: contrast proven over the IMPLEMENTED admin stylesheet, not over the book.

  `brand/brand.json` records 15 contrast pairs, each for light and dark (30 in all).
  Each one is bound below to the stylesheet token (or, for the two shape pairs, the
  shipped artwork) that is meant to deliver it. The test resolves that token through
  `Sigra.Test.Brand.CssContrast` (a cascade, not a flat merge) and asserts three
  things per pair: the colours the stylesheet really resolves to equal the book's
  recorded hexes, the ratio computed by `Sigra.Branding.Contrast.contrast_ratio/2`
  is within 0.01 of the recorded one, and it meets the book's minimum.

  A theme can be shown in two ways, and a missing declaration in the explicit
  blocks only shows in one of them, so every pair is evaluated in both:

    * light: the OS is light and no theme is chosen, or the OS is dark and the admin
      is set to Light;
    * dark: the OS is dark and no theme is chosen, or the OS is light and the admin
      is set to Dark.

  The instrument has to be seen to fire, so a planted bad colour (white on Kiln
  Bright, 2.48:1) and a planted missing explicit-block declaration are asserted to
  fail, and the thinnest margins are printed and asserted to lead with the known
  thinnest pair (`selected-status`, light), so an empty or no-op run cannot pass.
  """

  use ExUnit.Case, async: true

  alias Sigra.Test.Brand.CssContrast

  @root Path.expand("../../..", __DIR__)
  @brand_json Path.join(@root, "brand/brand.json")
  @admin_dir Path.join(@root, "priv/templates/sigra.install/admin")
  @logos %{
    light: Path.join(@admin_dir, "sigra-logo-primary.svg"),
    dark: Path.join(@admin_dir, "sigra-logo-primary-dark.svg")
  }
  @themes [:light, :dark]

  @external_resource @brand_json

  # Each book pair id bound to what delivers it in the stylesheet: the text (or shape)
  # source and the ground token. `{:ring, token}` is the OUTER layer of a box-shadow
  # token; `{:logo_square, theme}` is the square fill read from the shipped logo.
  # The bindings come from the UI-SPEC Contrast Contract table.
  @pair_bindings %{
    "body" => {{:token, "--sg-color-ink"}, "--sg-color-subtle"},
    "descriptor" => {{:token, "--sg-color-muted"}, "--sg-color-subtle"},
    "caption" => {{:token, "--sg-color-muted"}, "--sg-color-panel"},
    "application-copy" => {{:token, "--sg-color-ink"}, "--sg-color-panel"},
    "link" => {{:token, "--sg-color-brand-strong"}, "--sg-color-panel"},
    "focus" => {{:ring, "--sg-focus-ring"}, "--sg-color-subtle"},
    "artwork" => {:logo_square, "--sg-color-subtle"},
    "button" => {{:token, "--sg-color-on-brand"}, "--sg-color-brand"},
    "selected-row" => {{:token, "--sg-color-muted"}, "--sg-color-selected"},
    "selected-status" => {{:token, "--sg-status-unconfirmed"}, "--sg-color-selected"},
    "status-active" => {{:token, "--sg-status-active"}, "--sg-color-panel"},
    "status-unconfirmed" => {{:token, "--sg-status-unconfirmed"}, "--sg-color-panel"},
    "status-locked" => {{:token, "--sg-status-locked"}, "--sg-color-panel"},
    "status-suspended" => {{:token, "--sg-status-suspended"}, "--sg-color-panel"},
    "status-deleting" => {{:token, "--sg-status-deleting"}, "--sg-color-panel"}
  }
  @pair_ids @pair_bindings |> Map.keys() |> Enum.sort()

  @app_css Path.join(@root, "test/example/priv/static/assets/css/app.css")
  @panel "--sg-color-panel"
  @page "--sg-color-subtle"
  @tones ~w(risk warn ok info)

  # Derived and state pairs. Each side is `{selector, property, expected}`: the colour
  # is READ from the real rule (so a later edit to the rule is what the proof follows)
  # and the declared expression must equal `expected` (so a rule that no longer uses
  # the bound token fails by name instead of passing on a colour nobody checked).
  # `over` lists the opaque grounds a translucent ground can sit on; without it the
  # ground must be opaque. `file` is `:template` (the shipped stylesheet, default) or
  # `:app` (the example-owned admin chrome in app.css).
  @state_specs [
    %{
      id: "primary",
      text: {".sg-btn--primary", "color", "var(--sg-color-on-brand)"},
      ground: {".sg-btn--primary", "background", "var(--sg-color-brand)"}
    },
    %{
      id: "primary hover",
      text: {".sg-btn--primary:hover", "color", "var(--sg-color-on-brand)"},
      ground: {".sg-btn--primary:hover", "background", "var(--sg-color-brand-fill-hover)"}
    },
    %{
      id: "primary active",
      text: {".sg-btn--primary:active", "color", "var(--sg-color-on-brand)"},
      ground: {".sg-btn--primary:active", "background", "var(--sg-color-brand-fill-active)"}
    },
    %{
      id: "ghost hover",
      over: [@panel, @page],
      text: {".sg-btn--ghost:hover", "color", "var(--sg-color-brand-strong)"},
      ground: {".sg-btn--ghost:hover", "background", "var(--sg-color-brand-soft)"}
    },
    %{
      id: "nav hover",
      file: :app,
      over: [@panel, @page],
      text: {".sg-nav-link:hover", "color", "var(--sg-color-brand-strong)"},
      ground: {".sg-nav-link:hover", "background", "var(--sg-color-brand-soft)"}
    },
    %{
      id: "danger armed",
      text: {".sg-btn--danger.is-armed", "color", "var(--sg-color-on-brand)"},
      ground: {".sg-btn--danger.is-armed", "background", "var(--sg-color-risk)"}
    },
    %{
      id: "danger hover",
      over: [@panel],
      text: {".sg-btn--danger", "color", "var(--sg-color-risk)"},
      ground: {".sg-btn--danger:hover", "background", "var(--sg-color-risk-soft)"}
    },
    %{
      id: "theme-switch active, light text",
      themes: [:light],
      text:
        {~s(html[data-sg-admin-theme-preference="light"] .sg-theme-switch__button[data-theme-value="light"]),
         "color", "var(--sg-color-ink)"},
      ground:
        {~s(html[data-sg-admin-theme-preference="light"] .sg-theme-switch__button[data-theme-value="light"]),
         "background", "var(--sg-logo-rail-accent)"}
    },
    %{
      id: "theme-switch active, dark text",
      themes: [:dark],
      text:
        {~s(html[data-sg-admin-theme="dark"][data-sg-admin-theme-preference="light"] .sg-theme-switch__button[data-theme-value="light"]),
         "color", "var(--sg-color-on-brand-solid)"},
      ground:
        {~s(html[data-sg-admin-theme-preference="light"] .sg-theme-switch__button[data-theme-value="light"]),
         "background", "var(--sg-logo-rail-accent)"}
    },
    %{
      id: "nav active",
      file: :app,
      text: {".sg-nav-link.active", "color", "var(--sg-color-on-brand)"},
      ground: {".sg-nav-link.active", "background", "var(--sg-color-brand)"}
    },
    %{
      id: "table header",
      text: {".sg-table-panel th", "color", "var(--sg-color-muted)"},
      ground: {".sg-table-panel th", "background", "var(--sg-color-sunken)"}
    },
    %{
      id: "code chip, resting",
      over: [@panel],
      text: {".sg-code", "color", "var(--sg-color-muted)"},
      ground:
        {".sg-code", "background", "color-mix(in oklab, var(--sg-color-ink) 5%, transparent)"}
    },
    %{
      id: "code chip, hover",
      over: [@panel],
      text: {".sg-admin-shell code.sg-code:hover", "color", "var(--sg-color-ink)"},
      ground:
        {".sg-admin-shell code.sg-code:hover", "background",
         "color-mix(in oklab, var(--sg-color-ink) 9%, transparent)"}
    },
    %{
      id: "checked filter chip",
      over: [@panel],
      text: {".sg-filter-chip:has(input:checked)", "color", "var(--sg-color-brand-strong)"},
      ground: {".sg-filter-chip:has(input:checked)", "background", "var(--sg-color-brand-soft)"}
    }
  ]

  # The notice action link in each state on every ground a notice can have: the
  # default panel-alt ground and the four tone grounds, each a mix toward the panel.
  @notice_states [
    {"rest", ".sg-notice__action", "var(--sg-color-brand-strong)"},
    {"hover", ".sg-notice__action:hover",
     "color-mix(in oklab, var(--sg-color-brand-strong) 78%, var(--sg-color-ink))"},
    {"active", ".sg-notice__action:active",
     "color-mix(in oklab, var(--sg-color-brand-strong) 66%, var(--sg-color-ink))"}
  ]
  @notice_grounds [
    {"default", ".sg-notice", "var(--sg-color-panel-alt)"}
    | for(
        tone <- @tones,
        do:
          {tone, ~s(.sg-notice[data-tone="#{tone}"]),
           "color-mix(in oklab, var(--sg-color-#{tone}-soft) 62%, var(--sg-color-panel))"}
      )
  ]
  @notice_specs (for {state, text_selector, text_value} <- @notice_states,
                     {ground, ground_selector, ground_value} <- @notice_grounds do
                   %{
                     id: "notice action #{state} on #{ground} notice",
                     over: [@panel, @page],
                     text: {text_selector, "color", text_value},
                     ground: {ground_selector, "background", ground_value}
                   }
                 end)

  # Tone and muted text on the two new grounds. The rows below 4.5 are exactly this
  # list, so a new low pair cannot hide: warn is never bare text on these grounds.
  @low_ground_texts ~w(--sg-color-risk --sg-color-warn --sg-color-ok --sg-color-info --sg-color-muted)
  @low_grounds ~w(--sg-color-sunken --sg-color-selected)
  @exempt_reason "never bare text on this ground; use a pill with its own soft ground or a --sg-status-* token"
  @exempt_rows [
    %{
      text: "--sg-color-warn",
      ground: "--sg-color-sunken",
      theme: :light,
      reason: @exempt_reason
    },
    %{
      text: "--sg-color-warn",
      ground: "--sg-color-selected",
      theme: :light,
      reason: @exempt_reason
    }
  ]

  # Colour expressions the evaluator knowingly cannot resolve, as `{selector, expression}`
  # with a reason. Empty: every `color-mix()` and `rgba()` in the shipped stylesheet
  # and in the example's admin chrome evaluates. An unresolved expression is a hole in
  # the proof, so a new one must be fixed in the helper or justified here, and the
  # check is exact in both directions, so a stale entry fails as hard as a new hole.
  @unresolved_allowlist []

  # The template holds 40 `color-mix()` call sites at the start of the phase and the
  # focus-ring rewrite removed one, so at least 39 outermost expressions are scanned
  # (the `rgba()` calls come on top). A broken extractor cannot pass on zero.
  @min_template_expressions 39

  setup_all do
    css = CssContrast.read_css()
    blocks = CssContrast.blocks(css)
    book = load_book()

    %{
      css: css,
      app_css: File.read!(@app_css),
      blocks: blocks,
      book: book,
      evaluations: evaluate_book(blocks, book)
    }
  end

  describe "the book and the bindings" do
    test "brand.json records 15 pair ids, each with light and dark text, ground and contrast",
         %{book: book} do
      assert map_size(book) == 15
      assert book |> Map.keys() |> Enum.sort() == @pair_ids

      for {id, pair} <- book, theme <- ["light", "dark"] do
        side = Map.fetch!(pair, theme)

        assert is_binary(side["text"]) and is_binary(side["ground"]),
               "#{id} #{theme}: text and ground must be hex strings"

        assert is_number(side["contrast"]), "#{id} #{theme}: contrast must be a number"
        assert is_number(pair["minimum"]), "#{id}: minimum must be a number"
      end
    end

    test "every pair is evaluated in both scopes of both themes (60 evaluations)", %{
      evaluations: evaluations
    } do
      assert length(evaluations) == 60

      for id <- @pair_ids, theme <- @themes do
        assert length(rows_for(evaluations, id, theme)) == 2,
               "#{id} #{theme} must be evaluated in exactly two scopes"
      end
    end

    test "the scopes of a theme are the two ways it can be shown" do
      assert CssContrast.scopes(:light) == [[os: :light, shell: nil], [os: :dark, shell: :light]]
      assert CssContrast.scopes(:dark) == [[os: :dark, shell: nil], [os: :light, shell: :dark]]
    end
  end

  describe "the 30 book pairs: hex parity with the book" do
    for id <- @pair_ids, theme <- @themes do
      test "#{id} #{theme}: text and ground resolve to the book's hexes in both scopes", %{
        evaluations: evaluations,
        book: book
      } do
        rows = rows_for(evaluations, unquote(id), unquote(theme))
        side = book_side(book, unquote(id), unquote(theme))

        assert length(rows) == 2
        Enum.each(rows, &assert_hex_parity!(&1, side))
      end
    end
  end

  describe "the 30 book pairs: ratio parity with the book and the minimum" do
    for id <- @pair_ids, theme <- @themes do
      test "#{id} #{theme}: ratio is within 0.01 of the recorded one and meets the minimum", %{
        evaluations: evaluations,
        book: book
      } do
        rows = rows_for(evaluations, unquote(id), unquote(theme))
        side = book_side(book, unquote(id), unquote(theme))

        assert length(rows) == 2
        Enum.each(rows, &assert_ratio!(&1, side))
      end
    end
  end

  describe "focus: the outer layer of --sg-focus-ring" do
    for {theme, expected} <- [light: "#9A3412", dark: "#F08A55"] do
      test "#{theme}: the outer ring layer is #{expected} and is at least 3:1 on the page", %{
        blocks: blocks
      } do
        for scope <- CssContrast.scopes(unquote(theme)) do
          computed = CssContrast.computed(blocks, scope)
          layers = CssContrast.shadow_colors(computed["--sg-focus-ring"])
          where = "focus #{unquote(theme)} (#{CssContrast.scope_label(scope)})"

          assert length(layers) == 2,
                 "#{where}: the ring must be two layers (a page-ground gap, then the ring)"

          ground = opaque_hex("--sg-color-subtle", computed)
          assert opaque_hex(hd(layers), computed) == ground, "#{where}: the gap layer is the page"

          outer = layers |> List.last() |> opaque_hex(computed)
          assert outer == unquote(expected), "#{where}: outer layer is #{inspect(outer)}"
          assert CssContrast.ratio(outer, ground) >= 3.0, "#{where}: ring below 3:1 on the page"
        end
      end
    end
  end

  describe "artwork: the logo square" do
    for {theme, expected_fills} <- [
          light: ["#1F1A17", "#C2410C"],
          dark: ["#F3EEE8", "#F08A55"]
        ] do
      test "#{theme}: the shipped logo fills are #{inspect(expected_fills)} and the square is at least 3:1 on the page",
           %{blocks: blocks, book: book} do
        fills = unquote(theme) |> logo_svg() |> CssContrast.svg_fills()
        assert fills == unquote(expected_fills)

        [_letters, square] = fills
        recorded = book_side(book, "artwork", unquote(theme))["contrast"]

        for scope <- CssContrast.scopes(unquote(theme)) do
          computed = CssContrast.computed(blocks, scope)
          ground = opaque_hex("--sg-color-subtle", computed)
          ratio = CssContrast.ratio(square, ground)
          where = "artwork #{unquote(theme)} (#{CssContrast.scope_label(scope)})"

          assert ratio >= 3.0, "#{where}: #{ratio}"
          assert_in_delta ratio, recorded, 0.01, "#{where}: book records #{recorded}"
        end
      end
    end
  end

  describe "planted controls: the instrument can go red" do
    test "a planted white label on Kiln Bright fails the pair check and the failure names the pair",
         %{blocks: blocks, book: book} do
      assert %{pass?: false, id: "button"} =
               CssContrast.check_pair("button", :dark, "#FFFFFF", "#F08A55")

      planted = %{"button" => {{:literal, "#FFFFFF"}, "--sg-color-brand"}}
      [row | _] = evaluate_book(blocks, book, planted) |> Enum.filter(&(&1.theme == :dark))
      side = book_side(book, "button", :dark)

      assert row.pass? == false
      assert_in_delta row.ratio, 2.48, 0.01

      error = assert_raise ExUnit.AssertionError, fn -> assert_ratio!(row, side) end
      assert error.message =~ "button dark"

      error = assert_raise ExUnit.AssertionError, fn -> assert_hex_parity!(row, side) end
      assert error.message =~ "button dark"
    end

    test "dropping the explicit-Light restatement of the Kiln pair is caught under a dark OS",
         %{blocks: blocks, book: book} do
      restated = ["--sg-color-brand", "--sg-color-on-brand"]

      for token <- restated do
        assert Enum.any?(blocks.explicit_light, &(elem(&1, 0) == token)),
               "#{token} must be declared in the explicit Light block for this control to mean anything"
      end

      broken =
        Map.update!(blocks, :explicit_light, fn declarations ->
          Enum.reject(declarations, &(elem(&1, 0) in restated))
        end)

      rows =
        broken
        |> evaluate_book(book)
        |> rows_for("button", :light)

      side = book_side(book, "button", :light)
      dark_os = Enum.find(rows, &(&1.scope == [os: :dark, shell: :light]))

      assert dark_os.text == "#17120F"

      assert_raise ExUnit.AssertionError, ~r/button light/, fn ->
        assert_hex_parity!(dark_os, side)
      end
    end
  end

  describe "the thinnest-margin printout" do
    test "lists evaluations by margin, ascending, and leads with selected-status light", %{
      evaluations: evaluations
    } do
      report = CssContrast.report(evaluations)
      lines = String.split(report, "\n")

      IO.puts("\nThinnest contrast margins, book pairs (id theme scope ratio minimum margin):")
      IO.puts(report)

      assert length(lines) == 60
      assert Enum.any?(Enum.take(lines, 3), &(&1 =~ "selected-status"))
      assert hd(lines) =~ ~r/^selected-status\s+light\s/
      assert report =~ "selected-status"

      margins = for line <- lines, do: line |> margin_of() |> String.to_float()
      assert margins == Enum.sort(margins)
    end
  end

  describe "derived and state pairs, read from the real rules" do
    for spec <- @state_specs ++ @notice_specs do
      test "#{spec.id}: the rules declare the bound tokens and every scope is at least 4.5",
           ctx do
        spec = unquote(Macro.escape(spec))

        rows = evaluate_spec(spec, sheets(ctx), ctx.blocks)
        themes = Map.get(spec, :themes, @themes)

        assert length(rows) == length(themes) * 2 * length(Map.get(spec, :over, [nil])),
               "#{spec.id}: expected two scopes per theme per ground, got #{length(rows)} rows"

        Enum.each(rows, &assert_floor!/1)
      end
    end

    test "a rule that no longer declares the bound token fails by selector and property", ctx do
      drifted = %{
        id: "planted",
        text: {".sg-btn--primary:hover", "color", "var(--sg-color-ink)"},
        ground: {".sg-btn--primary:hover", "background", "var(--sg-color-brand-fill-hover)"}
      }

      error =
        assert_raise ExUnit.AssertionError, fn ->
          evaluate_spec(drifted, sheets(ctx), ctx.blocks)
        end

      assert error.message =~ ".sg-btn--primary:hover"
      assert error.message =~ "color"

      missing = %{drifted | text: {".sg-no-such-rule", "color", nil}}

      assert_raise ExUnit.AssertionError, ~r/\.sg-no-such-rule/, fn ->
        evaluate_spec(missing, sheets(ctx), ctx.blocks)
      end
    end

    test "every active theme-switch segment rule declares the colours the pair is bound to", %{
      css: css
    } do
      for value <- ~w(light dark system) do
        light =
          ~s(html[data-sg-admin-theme-preference="#{value}"] .sg-theme-switch__button[data-theme-value="#{value}"])

        assert declared!(css, {light, "color", "var(--sg-color-ink)"}) == "var(--sg-color-ink)"

        assert declared!(css, {light, "background", "var(--sg-logo-rail-accent)"}) ==
                 "var(--sg-logo-rail-accent)"

        for dark <- [
              ~s(html[data-sg-admin-theme="dark"][data-sg-admin-theme-preference="#{value}"] .sg-theme-switch__button[data-theme-value="#{value}"]),
              ~s(html[data-sg-admin-theme-preference="#{value}"] .sg-admin-shell[data-theme="dark"] .sg-theme-switch__button[data-theme-value="#{value}"]),
              ~s|html:not([data-sg-admin-theme])[data-sg-admin-theme-preference="#{value}"] .sg-admin-shell:not([data-theme]) .sg-theme-switch__button[data-theme-value="#{value}"]|
            ] do
          declared!(css, {dark, "color", "var(--sg-color-on-brand-solid)"})
        end
      end
    end
  end

  describe "the four kept tones and muted on their grounds" do
    for tone <- @tones do
      test "#{tone}: at least 4.5 on the page, on the panel and on its own soft ground over the panel",
           %{blocks: blocks} do
        rows = tone_rows(blocks, unquote(tone))

        assert length(rows) == 12
        Enum.each(rows, &assert_floor!/1)
      end
    end

    test "muted on the panel-alt ground is at least 4.5", %{blocks: blocks} do
      rows =
        token_rows(
          blocks,
          "muted on panel-alt",
          {:token, "--sg-color-muted"},
          "--sg-color-panel-alt"
        )

      assert length(rows) == 4
      Enum.each(rows, &assert_floor!/1)
    end
  end

  describe "tones and muted on the sunken and selected grounds" do
    test "every combination is computed and printed; the rows below 4.5 are exactly the exempt list",
         %{blocks: blocks} do
      rows = low_ground_rows(blocks)

      assert length(rows) == 40

      assert exempt_mismatch(rows, @exempt_rows) == %{unevaluated: [], unlisted: [], stale: []}

      labelled = label_exempt(rows, @exempt_rows)

      IO.puts("\nTone and muted text on the sunken and selected grounds (exempt rows labelled):")
      IO.puts(CssContrast.report(labelled, exempt: :include))

      exempt_report = CssContrast.report(labelled, exempt: :only)
      assert exempt_report =~ "never bare text"
      assert length(String.split(exempt_report, "\n")) == length(@exempt_rows) * 2
    end

    test "light warn is really below 4.5 on both grounds, so the exempt entries are not stale",
         %{blocks: blocks} do
      rows = low_ground_rows(blocks)

      for ground <- ["--sg-color-sunken", "--sg-color-selected"] do
        row =
          Enum.find(
            rows,
            &(&1.text_token == "--sg-color-warn" and &1.ground_token == ground and
                &1.theme == :light)
          )

        assert row.ratio < 4.5, "warn on #{ground} (light) is #{row.ratio}, no longer below 4.5"
      end
    end

    test "a planted new low row makes the exactness check fail", %{blocks: blocks} do
      rows = low_ground_rows(blocks)

      planted = %{
        id: "planted",
        theme: :dark,
        scope: [os: :dark, shell: nil],
        text_token: "--sg-color-ok",
        ground_token: "--sg-color-sunken",
        ratio: 3.0,
        minimum: 4.5
      }

      assert %{unlisted: [{"--sg-color-ok", "--sg-color-sunken", :dark}], stale: []} =
               exempt_mismatch(rows ++ [planted], @exempt_rows)
    end

    test "a stale exempt entry makes the exactness check fail", %{blocks: blocks} do
      rows = low_ground_rows(blocks)

      stale =
        @exempt_rows ++
          [%{text: "--sg-color-ink", ground: "--sg-color-sunken", theme: :light, reason: "x"}]

      assert %{unlisted: [], stale: [{"--sg-color-ink", "--sg-color-sunken", :light}]} =
               exempt_mismatch(rows, stale)
    end

    test "an unevaluated row fails the exactness check instead of hiding", %{blocks: blocks} do
      rows = low_ground_rows(blocks)
      broken = %{hd(rows) | ratio: nil}

      assert %{unevaluated: [_one]} = exempt_mismatch([broken | tl(rows)], @exempt_rows)
    end
  end

  describe "disabled" do
    test "disabled primary at the rule's opacity is computed and printed, labelled exempt", %{
      css: css,
      blocks: blocks
    } do
      rows = disabled_rows(css, blocks)

      assert length(rows) == 4
      assert Enum.all?(rows, &is_float(&1.ratio))
      assert Enum.all?(rows, &(&1.exempt == "inactive component"))

      report = CssContrast.report(rows, exempt: :only)
      IO.puts("\nDisabled primary button (opacity composited over the page, not asserted):")
      IO.puts(report)

      assert report =~ "exempt: inactive component"
      assert CssContrast.report(rows) == ""
    end

    test "the opacity is read from the .sg-btn[disabled] rule", %{css: css} do
      assert css |> CssContrast.rule_decls(".sg-btn[disabled]") |> Map.fetch!("opacity") == "0.5"
    end

    test "opacity compositing: a black label at opacity 0.5 over white is #808080" do
      assert CssContrast.to_hex({0, 0, 0, 0.5}, "#FFFFFF") == "#808080"
    end
  end

  describe "non-text pairs at 3:1 (token level)" do
    test "control edge on the panel and on the sunken header", %{blocks: blocks} do
      edge = {:token, "--sg-color-control-edge"}

      rows =
        token_rows(blocks, "control edge on panel", edge, @panel, minimum: 3.0) ++
          token_rows(blocks, "control edge on sunken", edge, "--sg-color-sunken", minimum: 3.0)

      assert length(rows) == 8
      Enum.each(rows, &assert_floor!/1)
    end

    test "selected edge on the selected ground (no consumer yet, so token level only)", %{
      blocks: blocks
    } do
      rows =
        token_rows(
          blocks,
          "selected edge on selected",
          {:token, "--sg-color-selected-edge"},
          "--sg-color-selected",
          minimum: 3.0
        )

      assert length(rows) == 4
      Enum.each(rows, &assert_floor!/1)
    end

    test "focus ring on the page and on the panel", %{blocks: blocks} do
      ring = {:ring, "--sg-focus-ring"}

      rows =
        token_rows(blocks, "focus ring on page", ring, @page, minimum: 3.0) ++
          token_rows(blocks, "focus ring on panel", ring, @panel, minimum: 3.0)

      assert length(rows) == 8
      Enum.each(rows, &assert_floor!/1)
    end
  end

  describe "opaque grounds" do
    test "sunken, selected and control-edge are opaque in every scope of both themes", %{
      blocks: blocks
    } do
      for token <- ~w(--sg-color-sunken --sg-color-selected --sg-color-control-edge),
          theme <- @themes,
          scope <- CssContrast.scopes(theme) do
        computed = CssContrast.computed(blocks, scope)

        assert {:ok, {_r, _g, _b, alpha}} = CssContrast.resolve_color(token, computed)

        assert alpha == 1,
               "#{token} is translucent (alpha #{alpha}) in #{theme} (#{CssContrast.scope_label(scope)})"
      end
    end

    test "a planted rgba value with alpha 0.9 is reported as translucent" do
      planted = %{"--sg-color-sunken" => "rgba(18, 14, 12, 0.9)"}

      assert {:unresolved, reason} = opaque_hex("--sg-color-sunken", planted)
      assert reason =~ "translucent"
    end
  end

  describe "the combined thinnest-margin printout" do
    test "book pairs and derived pairs together, thinnest first", ctx do
      derived =
        Enum.flat_map(@state_specs ++ @notice_specs, &evaluate_spec(&1, sheets(ctx), ctx.blocks)) ++
          Enum.flat_map(@tones, &tone_rows(ctx.blocks, &1))

      lines = (ctx.evaluations ++ derived) |> CssContrast.report() |> String.split("\n")

      IO.puts("\nThinnest margins over every asserted pair (book pairs, state pairs, tones):")
      lines |> Enum.take(12) |> Enum.each(&IO.puts/1)

      assert length(lines) == length(ctx.evaluations) + length(derived)
      assert Enum.any?(lines, &(&1 =~ "selected-status"))
      assert Enum.any?(lines, &(&1 =~ "primary hover"))
      assert Enum.any?(lines, &(&1 =~ "notice action hover on warn notice"))

      assert Enum.all?(derived, &(&1.ratio >= &1.minimum))
    end
  end

  describe "fail-closed scan of every colour expression" do
    test "the template stylesheet: every color-mix() and rgba() resolves in all four scopes",
         %{css: css, blocks: blocks} do
      scanned = CssContrast.color_expressions(css)

      assert length(scanned) >= @min_template_expressions,
             "scanned #{length(scanned)} expressions, expected at least #{@min_template_expressions}"

      assert Enum.any?(scanned, fn {_selector, expression} -> expression =~ "color-mix(" end)
      assert Enum.any?(scanned, fn {_selector, expression} -> expression =~ "rgba(" end)

      report = unresolved_in_all_scopes(scanned, blocks)
      print_unresolved("template stylesheet", scanned, report)

      assert :ok =
               CssContrast.check_unresolved(report, Enum.map(@unresolved_allowlist, &elem(&1, 0)))

      assert unresolved_mismatch(report, @unresolved_allowlist) == %{unlisted: [], stale: []}
    end

    test "the example's admin chrome (rules naming .sg- in app.css) resolves in all four scopes",
         %{app_css: app_css, blocks: blocks} do
      scanned = CssContrast.color_expressions(app_css, selector_contains: ".sg-")

      assert scanned != [], "no .sg- expression was scanned in app.css; the extraction is broken"

      for {selector, _expression} <- scanned do
        assert selector =~ ".sg-", "#{selector} was scanned but names no .sg- class"
      end

      report = unresolved_in_all_scopes(scanned, blocks)
      print_unresolved("app.css .sg- rules", scanned, report)

      assert :ok =
               CssContrast.check_unresolved(report, Enum.map(@unresolved_allowlist, &elem(&1, 0)))

      assert unresolved_mismatch(report, @unresolved_allowlist) == %{unlisted: [], stale: []}
    end

    test "demo-owned vt-* rules are out of scope: they are not scanned", %{app_css: app_css} do
      everything = CssContrast.color_expressions(app_css)
      admin = CssContrast.color_expressions(app_css, selector_contains: ".sg-")

      assert length(everything) > length(admin),
             "the .sg- filter removed nothing, so the demo's vt-* rules are being scanned"

      refute Enum.any?(admin, fn {selector, _expression} -> not (selector =~ ".sg-") end)
    end

    test "a planted unresolvable expression is listed by selector and fails the exactness check",
         %{blocks: blocks} do
      planted = [
        {".sg-planted", "color-mix(in oklch, #C2410C 50%, #FFFFFF)"},
        {".sg-undefined", "color-mix(in oklab, var(--sg-not-a-token) 50%, #FFFFFF)"},
        {".sg-fine", "rgba(21, 21, 21, 0.1)"}
      ]

      report = unresolved_in_all_scopes(planted, blocks)

      assert report |> Enum.map(& &1.selector) |> Enum.uniq() |> Enum.sort() ==
               [".sg-planted", ".sg-undefined"]

      assert {:error, :allowlist_mismatch} = CssContrast.check_unresolved(report, [])

      assert %{unlisted: [{".sg-planted", _}, {".sg-undefined", _}], stale: []} =
               unresolved_mismatch(report, [])
    end

    test "a stale allowlist entry fails as hard as a new hole", %{blocks: blocks} do
      report = unresolved_in_all_scopes([{".sg-fine", "rgba(21, 21, 21, 0.1)"}], blocks)

      assert report == []
      assert {:error, :allowlist_mismatch} = CssContrast.check_unresolved(report, [".sg-gone"])

      assert %{unlisted: [], stale: [{".sg-gone", "rgba(1, 2, 3, 0.5)"}]} =
               unresolved_mismatch(report, [{".sg-gone", "rgba(1, 2, 3, 0.5)", "stale"}])
    end
  end

  describe "color_expressions/2" do
    @scan_css """
    .sg-a { box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1), 0 0 0 1px color-mix(
        in oklab,
        rgba(1, 2, 3, 0.5) 50%,
        transparent
      ); }
    @layer sg-components { .sg-b, .vt-b { background: color-mix(in oklab, #fff 10%, #000); } }
    .vt-c { color: rgba(9, 9, 9, 0.9); }
    /* .sg-d { color: rgba(7, 7, 7, 0.7); } */
    .sg-e { color: rgb(1 2 3); border-color: hsl(10 20% 30%); }
    .sg-f { color: color-mix(in oklab, #fff 10%, #000; }
    """

    test "returns each outermost colour call with its selector, nested calls once, comments excluded" do
      assert CssContrast.color_expressions(@scan_css) |> Enum.map(&elem(&1, 0)) |> Enum.uniq() ==
               [".sg-a", ".sg-b, .vt-b", ".vt-c", ".sg-e", ".sg-f"]

      assert [{".sg-a", first}, {".sg-a", second} | _] = CssContrast.color_expressions(@scan_css)
      assert first == "rgba(0, 0, 0, 0.1)"
      assert second == "color-mix( in oklab, rgba(1, 2, 3, 0.5) 50%, transparent )"
    end

    test "selector_contains keeps only the rules whose selector list names the fragment" do
      assert @scan_css
             |> CssContrast.color_expressions(selector_contains: ".sg-")
             |> Enum.map(&elem(&1, 0))
             |> Enum.uniq() == [".sg-a", ".sg-b, .vt-b", ".sg-e", ".sg-f"]
    end

    test "other colour functions are returned too, so an unsupported one fails closed" do
      expressions =
        for {".sg-e", expression} <- CssContrast.color_expressions(@scan_css), do: expression

      assert expressions == ["rgb(1 2 3)", "hsl(10 20% 30%)"]

      assert [%{selector: ".sg-e", reason: reason}] =
               [{".sg-e", "hsl(10 20% 30%)"}] |> CssContrast.unresolved_report()

      assert reason =~ "hsl"
    end

    test "an unbalanced call is returned to the end of its rule, so it is reported, not dropped" do
      assert [{".sg-f", expression}] =
               @scan_css
               |> CssContrast.color_expressions()
               |> Enum.filter(&(elem(&1, 0) == ".sg-f"))

      assert expression =~ "color-mix("

      assert [%{selector: ".sg-f"}] = CssContrast.unresolved_report([{".sg-f", expression}])
    end
  end

  describe "rule_decls/2" do
    @planted_css """
    @layer sg-components {
      .x, .y:hover { color: red; background: color-mix(
        in oklab,
        #fff 50%,
        #000
      ); }
    }
    @media (hover: hover) { .y:hover { color: blue; } }
    .x { border: 1px solid; --sg-t: 1px }
    /* .z { color: green; } */
    .q { content: ";"; color: tan }
    """

    test "merges every rule whose selector list contains the exact selector, later wins" do
      assert CssContrast.rule_decls(@planted_css, ".x") == %{
               "color" => "red",
               "background" => "color-mix(in oklab, #fff 50%, #000)",
               "border" => "1px solid",
               "--sg-t" => "1px"
             }

      assert CssContrast.rule_decls(@planted_css, ".y:hover") == %{
               "color" => "blue",
               "background" => "color-mix(in oklab, #fff 50%, #000)"
             }
    end

    test "ignores comments, a selector that is not exact and a missing selector" do
      assert CssContrast.rule_decls(@planted_css, ".z") == %{}
      assert CssContrast.rule_decls(@planted_css, ".absent") == %{}
      assert CssContrast.rule_decls(@planted_css, ".y") == %{}
    end

    test "a semicolon inside a string does not end the declaration" do
      assert CssContrast.rule_decls(@planted_css, ".q") == %{
               "content" => ~s(";"),
               "color" => "tan"
             }
    end

    test "reads a multi-line selector as one whitespace-collapsed selector" do
      css = ".a\n    .b[data-x=\"1\"],\n  .c { color: red; }"

      assert CssContrast.rule_decls(css, ~s(.a .b[data-x="1"])) == %{"color" => "red"}
      assert CssContrast.rule_decls(css, ".c") == %{"color" => "red"}
    end
  end

  describe "helper additions" do
    test "shadow_colors/1 returns the colour of each layer in order" do
      assert CssContrast.shadow_colors("0 0 0 2px #F7F3EE, 0 0 0 calc(2px + 2px) #9a3412") ==
               ["#F7F3EE", "#9a3412"]

      assert CssContrast.shadow_colors(
               "inset 0 0 0 1px rgba(21, 21, 21, 0.1), 0 1px 2px rgb(0 0 0 / 5%)"
             ) == ["rgba(21, 21, 21, 0.1)", "rgb(0 0 0 / 5%)"]

      assert CssContrast.shadow_colors("0 0 0 3px color-mix(in oklab, #C2410C 35%, transparent)") ==
               ["color-mix(in oklab, #C2410C 35%, transparent)"]
    end

    test "shadow_colors/1 splits on top-level commas only and skips a layer with no colour" do
      assert CssContrast.shadow_colors("0 0 0 1px rgba(1, 2, 3, 0.5), 0 0 4px 0") ==
               ["rgba(1, 2, 3, 0.5)"]

      assert CssContrast.shadow_colors("") == []
      assert CssContrast.shadow_colors("none") == []
    end

    test "svg_fills/1 returns the distinct fill colours in order of appearance, upper-cased" do
      svg =
        ~s(<svg><path fill="#1f1a17" d="M0 0"/><path fill="#C2410C" d="M1 1"/>) <>
          ~s(<path fill='#1F1A17' d="M2 2"/></svg>)

      assert CssContrast.svg_fills(svg) == ["#1F1A17", "#C2410C"]
      assert CssContrast.svg_fills("<svg></svg>") == []
      assert CssContrast.svg_fills(~s(<path fill="none"/>)) == []
    end

    test "report/1 sorts by margin ascending, excludes exempt rows and can show only them" do
      wide = %{
        id: "wide",
        theme: :light,
        scope: [os: :light, shell: nil],
        ratio: 12.0,
        minimum: 4.5
      }

      thin = %{id: "thin", theme: :dark, scope: [os: :dark, shell: nil], ratio: 4.6, minimum: 4.5}

      exempt =
        %{id: "low", theme: :light, scope: [os: :light, shell: nil], ratio: 2.2, minimum: 4.5}
        |> Map.put(:exempt, "inactive component")

      lines = [wide, exempt, thin] |> CssContrast.report() |> String.split("\n")

      assert length(lines) == 2
      assert hd(lines) =~ ~r/^thin\s+dark\s/
      refute Enum.any?(lines, &(&1 =~ "low"))

      assert [only] =
               [wide, exempt, thin] |> CssContrast.report(exempt: :only) |> String.split("\n")

      assert only =~ "low"
      assert only =~ "exempt: inactive component"

      assert [wide, exempt, thin]
             |> CssContrast.report(exempt: :include)
             |> String.split("\n")
             |> length() == 3
    end

    test "report/1 refuses a row that was never evaluated" do
      row = %{id: "x", theme: :light, scope: [os: :light, shell: nil], ratio: nil, minimum: 4.5}

      assert_raise ArgumentError, ~r/never evaluated|unevaluated/, fn ->
        CssContrast.report([row])
      end
    end

    test "scope_label/1 names the OS and the chosen theme" do
      assert CssContrast.scope_label(os: :dark, shell: :light) == "os=dark shell=light"
      assert CssContrast.scope_label(os: :light, shell: nil) == "os=light shell=none"
    end
  end

  # -- evaluation ----------------------------------------------------------------

  defp load_book do
    @brand_json
    |> File.read!()
    |> JSON.decode!()
    |> get_in(["color", "contrastPairs"])
    |> Map.new(&{&1["id"], &1})
  end

  defp book_side(book, id, theme), do: book |> Map.fetch!(id) |> Map.fetch!(Atom.to_string(theme))

  defp evaluate_book(blocks, book, bindings \\ @pair_bindings) do
    for theme <- @themes, scope <- CssContrast.scopes(theme), {id, binding} <- bindings do
      evaluate_pair(blocks, book, id, binding, theme, scope)
    end
  end

  defp evaluate_pair(blocks, book, id, {text_source, ground_token}, theme, scope) do
    computed = CssContrast.computed(blocks, scope)
    minimum = book |> Map.fetch!(id) |> Map.fetch!("minimum")
    text = resolve_text(text_source, computed, theme)

    build_row(id, theme, scope, text, opaque_hex(ground_token, computed), minimum)
  end

  # One evaluated row. `ratio` stays nil when either side did not resolve, so a
  # report or an assertion can say so instead of passing on nothing.
  defp build_row(id, theme, scope, text, ground, minimum, extra \\ %{}) do
    row = %{
      id: id,
      theme: theme,
      scope: scope,
      text: text,
      ground: ground,
      minimum: minimum,
      ratio: nil,
      pass?: false
    }

    row =
      if is_binary(text) and is_binary(ground) do
        %{ratio: ratio, pass?: pass?} = CssContrast.check_pair(id, theme, text, ground, minimum)
        %{row | ratio: ratio, pass?: pass?}
      else
        row
      end

    Map.merge(row, extra)
  end

  defp resolve_text({:token, token}, computed, _theme), do: opaque_hex(token, computed)
  defp resolve_text({:literal, hex}, _computed, _theme), do: hex

  defp resolve_text({:ring, token}, computed, _theme) do
    case computed |> Map.fetch!(token) |> CssContrast.shadow_colors() do
      [] -> {:unresolved, "#{token} has no colour layer"}
      layers -> layers |> List.last() |> opaque_hex(computed)
    end
  end

  defp resolve_text(:logo_square, _computed, theme) do
    case theme |> logo_svg() |> CssContrast.svg_fills() do
      [_letters, square] -> square
      other -> {:unresolved, "the #{theme} logo has fills #{inspect(other)}, expected two"}
    end
  end

  defp logo_svg(theme), do: @logos |> Map.fetch!(theme) |> File.read!()

  # An opaque colour as upper-case hex. A translucent colour is refused rather than
  # silently composited, because a book pair is a colour on a colour.
  defp opaque_hex(expression, computed) do
    case CssContrast.resolve_color(expression, computed) do
      {:ok, {_r, _g, _b, alpha} = rgba} when alpha == 1 -> CssContrast.to_hex(rgba, "#FFFFFF")
      {:ok, {_r, _g, _b, alpha}} -> {:unresolved, "#{expression} is translucent (alpha #{alpha})"}
      {:unresolved, _reason} = unresolved -> unresolved
    end
  end

  # A colour or token composited over an opaque `base` hex (alpha 0 is the base).
  defp composite_hex(expression, computed, base) do
    case CssContrast.resolve_color(expression, computed) do
      {:ok, rgba} -> CssContrast.to_hex(rgba, base)
      {:unresolved, _reason} = unresolved -> unresolved
    end
  end

  # A ground: opaque by itself, or composited over the opaque ground it sits on.
  defp resolve_ground(expression, computed, nil), do: opaque_hex(expression, computed)

  defp resolve_ground(expression, computed, over) do
    case opaque_hex(over, computed) do
      base when is_binary(base) -> composite_hex(expression, computed, base)
      unresolved -> unresolved
    end
  end

  defp rows_for(rows, id, theme), do: Enum.filter(rows, &(&1.id == id and &1.theme == theme))

  defp assert_hex_parity!(row, side) do
    where = where(row)

    assert row.text == String.upcase(side["text"]),
           "#{where}: text resolves to #{inspect(row.text)}, the book records #{side["text"]}"

    assert row.ground == String.upcase(side["ground"]),
           "#{where}: ground resolves to #{inspect(row.ground)}, the book records #{side["ground"]}"
  end

  defp assert_ratio!(row, side) do
    where = where(row)

    assert is_float(row.ratio),
           "#{where}: never evaluated (text #{inspect(row.text)} on #{inspect(row.ground)})"

    assert row.ratio >= row.minimum,
           "#{where}: #{row.ratio} is below the book minimum #{row.minimum}"

    assert_in_delta row.ratio,
                    side["contrast"],
                    0.01,
                    "#{where}: computed #{row.ratio}, the book records #{side["contrast"]}"
  end

  defp where(row), do: "#{row.id} #{row.theme} (#{CssContrast.scope_label(row.scope)})"

  # -- rule-driven pairs ----------------------------------------------------------

  defp sheets(%{css: css, app_css: app_css}), do: %{template: css, app: app_css}

  # The declared value of a property in the first-to-last merge of the rules for a
  # selector, asserted to exist and (when `expected` is given) to equal it.
  defp declared!(sheet, {selector, property, expected}) do
    value = sheet |> CssContrast.rule_decls(selector) |> Map.get(property)

    assert value != nil, "no rule for #{selector} declares #{property}"

    if expected do
      assert value == expected,
             "#{selector} declares #{property}: #{value}, but the pair is bound to #{expected}"
    end

    value
  end

  defp evaluate_spec(spec, sheets, blocks) do
    sheet = Map.fetch!(sheets, Map.get(spec, :file, :template))
    text_expression = declared!(sheet, spec.text)
    ground_expression = declared!(sheet, spec.ground)

    for theme <- Map.get(spec, :themes, @themes),
        scope <- CssContrast.scopes(theme),
        over <- Map.get(spec, :over, [nil]) do
      computed = CssContrast.computed(blocks, scope)
      ground = resolve_ground(ground_expression, computed, over)

      text =
        if is_binary(ground),
          do: composite_hex(text_expression, computed, ground),
          else: ground

      build_row(
        row_id(spec.id, over),
        theme,
        scope,
        text,
        ground,
        Map.get(spec, :minimum, 4.5)
      )
    end
  end

  defp row_id(id, nil), do: id
  defp row_id(id, over), do: "#{id} over #{String.replace_prefix(over, "--sg-color-", "")}"

  defp assert_floor!(row) do
    where = where(row)

    assert is_float(row.ratio),
           "#{where}: never evaluated (text #{inspect(row.text)} on #{inspect(row.ground)})"

    assert row.ratio >= row.minimum,
           "#{where}: #{Float.round(row.ratio, 2)} is below #{row.minimum} (#{row.text} on #{row.ground})"
  end

  # -- colour expression scan ------------------------------------------------------

  # Every expression resolved in all four scope combinations (two ways to show each
  # theme), against the admin token map.
  defp unresolved_in_all_scopes(expressions, blocks) do
    scopes = Enum.flat_map(@themes, &CssContrast.scopes/1)

    entries =
      for scope <- scopes,
          computed = CssContrast.computed(blocks, scope),
          {selector, expression} <- expressions do
        {selector, expression, computed}
      end

    CssContrast.unresolved_report(entries)
  end

  # Exact in both directions on `{selector, expression}` pairs: a new unresolved
  # expression is `unlisted`, an allowlist entry that now resolves is `stale`.
  defp unresolved_mismatch(report, allowlist) do
    found = report |> Enum.map(&{&1.selector, &1.value}) |> Enum.uniq() |> Enum.sort()
    listed = allowlist |> Enum.map(&{elem(&1, 0), elem(&1, 1)}) |> Enum.uniq() |> Enum.sort()

    %{unlisted: found -- listed, stale: listed -- found}
  end

  defp print_unresolved(label, scanned, report) do
    selectors = report |> Enum.map(& &1.selector) |> Enum.uniq() |> Enum.sort()

    IO.puts(
      "\nColour expressions scanned in the #{label}: #{length(scanned)}, " <>
        "unresolved selectors: #{length(selectors)}"
    )

    for selector <- selectors, do: IO.puts("  unresolved: #{selector}")
  end

  # -- token-level pairs ---------------------------------------------------------

  # `text_source` is `{:token, token}` or `{:ring, token}`; `ground` is a token
  # (composited over `:over` when given). Rows carry the token names so the
  # exempt-list check can key on them.
  defp token_rows(blocks, id, text_source, ground, opts \\ []) do
    over = Keyword.get(opts, :over)
    minimum = Keyword.get(opts, :minimum, 4.5)

    for theme <- @themes, scope <- CssContrast.scopes(theme) do
      computed = CssContrast.computed(blocks, scope)
      text = resolve_text(text_source, computed, theme)
      ground_hex = resolve_ground(ground, computed, over)

      build_row(id, theme, scope, text, ground_hex, minimum, %{
        text_token: elem(text_source, 1),
        ground_token: ground
      })
    end
  end

  defp tone_rows(blocks, tone) do
    text = {:token, "--sg-color-#{tone}"}

    token_rows(blocks, "#{tone} on page", text, @page) ++
      token_rows(blocks, "#{tone} on panel", text, @panel) ++
      token_rows(blocks, "#{tone} on its soft ground", text, "--sg-color-#{tone}-soft",
        over: @panel
      )
  end

  defp low_ground_rows(blocks) do
    for text <- @low_ground_texts, ground <- @low_grounds, reduce: [] do
      rows ->
        id =
          "#{String.replace_prefix(text, "--sg-color-", "")} on #{String.replace_prefix(ground, "--sg-color-", "")}"

        rows ++ token_rows(blocks, id, {:token, text}, ground)
    end
  end

  defp key(row), do: {row.text_token, row.ground_token, row.theme}

  # Rows below their minimum must be exactly the committed exempt list (in both
  # directions), and a row that never evaluated is reported rather than skipped.
  defp exempt_mismatch(rows, exempt_rows) do
    unevaluated = Enum.reject(rows, &is_float(&1.ratio))
    evaluated = Enum.filter(rows, &is_float(&1.ratio))
    low = for row <- evaluated, row.ratio < row.minimum, uniq: true, do: key(row)
    listed = Enum.map(exempt_rows, &{&1.text, &1.ground, &1.theme})

    %{
      unevaluated: unevaluated,
      unlisted: Enum.sort(low -- listed),
      stale: Enum.sort(listed -- low)
    }
  end

  defp label_exempt(rows, exempt_rows) do
    reasons = Map.new(exempt_rows, &{{&1.text, &1.ground, &1.theme}, &1.reason})

    Enum.map(rows, fn row ->
      case Map.fetch(reasons, key(row)) do
        {:ok, reason} -> Map.put(row, :exempt, reason)
        :error -> row
      end
    end)
  end

  # `opacity` on a disabled control blends the label and the fill with whatever is
  # behind it, so both are composited over the page at that opacity.
  defp disabled_rows(css, blocks) do
    opacity =
      css
      |> CssContrast.rule_decls(".sg-btn[disabled]")
      |> Map.fetch!("opacity")
      |> parse_number()

    primary = CssContrast.rule_decls(css, ".sg-btn--primary")

    for theme <- @themes, scope <- CssContrast.scopes(theme) do
      computed = CssContrast.computed(blocks, scope)
      page = opaque_hex(@page, computed)

      label = faded(primary["color"], computed, opacity, page)
      fill = faded(primary["background"], computed, opacity, page)

      build_row("disabled primary", theme, scope, label, fill, 4.5, %{
        exempt: "inactive component"
      })
    end
  end

  defp faded(expression, computed, opacity, page) do
    case CssContrast.resolve_color(expression, computed) do
      {:ok, {r, g, b, _alpha}} -> CssContrast.to_hex({r, g, b, opacity}, page)
      {:unresolved, _reason} = unresolved -> unresolved
    end
  end

  defp parse_number(text) do
    {number, ""} = Float.parse(text)
    number
  end

  defp margin_of(line) do
    [_whole, margin] = Regex.run(~r/margin=([+-]?\d+\.\d+)/, line)
    String.trim_leading(margin, "+")
  end
end
