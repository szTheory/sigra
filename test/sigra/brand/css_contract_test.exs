defmodule Sigra.Brand.CssContractTest do
  @moduledoc """
  BTOK-06, BTOK-08: the shipped admin stylesheet applies the book's typographic
  rules through tokens and existing selectors, with no new class.

  The assertions read declaration text, not substrings, from comment-stripped CSS:
  `rule_bodies/2` returns the declaration body of every rule whose selector list
  contains a selector exactly (the stylesheet nests rules inside `@layer` and
  `@media`, and a selector list such as `.sg-admin-shell :is(button, input)` holds
  commas inside parentheses, so the split is on top-level commas only). Each
  assertion first requires a non-empty result, so a selector that is renamed or
  dropped fails loudly instead of passing on nothing.

  Every check is a pure function over in-memory text, so each one is shown to fail
  on a planted stylesheet that lacks its rule (the `css_gap.ex` pattern).

  Token values are not tested here: `token_migration_test.exs` pins them against
  the reviewed table, and `token_parity_test.exs` pins the four-place rules. This
  file pins which selectors read the tokens.
  """

  use ExUnit.Case, async: true

  alias Sigra.Test.Brand.CssContrast

  @root Path.expand("../../..", __DIR__)
  @example_app_css "test/example/priv/static/assets/css/app.css"
  @markup_roots ["lib/sigra/admin", "priv/templates/sigra.install/admin"]
  @markup_extensions [".ex", ".heex", ".eex"]

  @grouping_at_rules ["@media", "@layer", "@supports", "@container"]

  @font_tokens %{
    "--sg-font-sans" => "inherit",
    "--sg-font-mono" => "ui-monospace, 'SF Mono', Consolas, monospace"
  }

  # The edge of an interactive control: a 1px inset ring in the book's Control Edge.
  @control_edge_shadow "inset 0 0 0 1px var(--sg-color-control-edge)"
  @stale_edge_tokens ["--sg-elev-inset", "--sg-color-line-strong"]
  @interactive_controls [
    ".sg-btn--secondary",
    ".sg-btn--danger",
    ".sg-filter-chip",
    ".sg-theme-switch"
  ]

  # Left and right arrows as characters, named entities and numeric references.
  @arrow ~r/\x{2190}|\x{2192}|&larr;|&rarr;|&#0*(?:8592|8594);|&#x0*(?:2190|2192);/iu

  setup_all do
    css = CssContrast.read_css()
    %{css: css, blocks: CssContrast.blocks(css)}
  end

  describe "the rule reader" do
    test "finds a rule nested in @layer and @media, and reads a selector list with commas inside parentheses" do
      css = """
      @layer sg-components {
        @media (min-width: 640px) {
          .a, .b:is(.x, .y) { color: red; margin: 0 }
        }
        .c { color: blue }
      }
      """

      assert rule_bodies(css, ".a") |> Enum.map(&declarations/1) == [
               [{"color", "red"}, {"margin", "0"}]
             ]

      assert rule_bodies(css, ".b:is(.x, .y)") != []
      assert rule_bodies(css, ".x") == []
      assert rule_bodies(css, ".c") |> Enum.map(&declarations/1) == [[{"color", "blue"}]]
    end

    test "returns no body for a selector that is absent, so every assertion below can fail" do
      css = ".sg-btn { color: red; }"

      assert rule_bodies(css, ".sg-absent") == []
      refute declares?(css, ".sg-absent", "font-family", "inherit")
      refute declares?(css, ".sg-btn", "font-family", "inherit")
    end

    test "ignores a selector or declaration that appears only inside a comment" do
      css = "/* .sg-code { font-family: var(--sg-font-mono); } */\n.sg-btn { color: red; }"

      assert rule_bodies(css, ".sg-code") == []
      refute declares?(css, ".sg-code", "font-family", "var(--sg-font-mono)")
    end

    test "reads the real stylesheet (a parse that yields nothing must not pass)", %{css: css} do
      assert rule_bodies(css, ":root") != []
      assert rule_bodies(css, ".sg-btn") != []
    end
  end

  describe "font tokens (BTOK-06)" do
    test "the light :root declares each token once with the shipped default; no theme block restates it",
         %{blocks: blocks} do
      for {token, value} <- @font_tokens do
        assert Enum.count(blocks.root, &(elem(&1, 0) == token)) == 1,
               "#{token} must be declared exactly once in the light :root"

        assert List.keyfind(blocks.root, token, 0) == {token, value}
      end

      for place <- [:root_dark, :explicit_light, :explicit_dark] do
        declared = Map.fetch!(blocks, place)
        refute declared == [], "the #{place} block parsed to nothing; the parse is broken"

        for token <- Map.keys(@font_tokens) do
          assert List.keyfind(declared, token, 0) == nil,
                 "#{token} is theme-invariant and must not appear in the #{place} block"
        end
      end
    end

    test "the stylesheet ships no @font-face rule; a comment that names it is not a rule", %{
      css: css
    } do
      refute font_face?(css)

      refute font_face?("/* a host opts in with its own @font-face */ .a { color: red }")
      assert font_face?("@font-face { font-family: X; src: url('/x.woff2'); }")
      assert font_face?("/* note */ @font-face { font-family: X; }")
    end

    test ".sg-admin-shell takes its family from the sans token, falling back to inheritance", %{
      css: css
    } do
      assert declares?(css, ".sg-admin-shell", "font-family", "var(--sg-font-sans, inherit)")

      planted = ".sg-admin-shell { font-family: var(--sg-font-sans); }"
      refute declares?(planted, ".sg-admin-shell", "font-family", "var(--sg-font-sans, inherit)")
    end

    test "controls inherit the shell family instead of falling back to the user agent face", %{
      css: css
    } do
      selector = ".sg-admin-shell :is(button, input, select, textarea)"

      assert declares?(css, selector, "font-family", "inherit")
      refute declares?(".sg-btn { font-family: inherit; }", selector, "font-family", "inherit")
    end

    test "one rule gives .sg-code and code in the shell the mono token, no ligatures and a slashed zero",
         %{css: css} do
      selectors = [".sg-code", ".sg-admin-shell code"]

      assert rule_bodies_all(css, selectors) != []
      assert declares?(css, selectors, "font-family", "var(--sg-font-mono)")
      assert declares?(css, selectors, "font-variant-ligatures", "none")
      assert declares?(css, selectors, "font-feature-settings", ~s("zero"))

      planted = ".sg-code { font-family: var(--sg-font-mono); }"
      refute declares?(planted, selectors, "font-family", "var(--sg-font-mono)")
      refute declares?(planted, ".sg-code", "font-feature-settings", ~s("zero"))
    end

    test "table cells use tabular numerals in both table families", %{css: css} do
      for selectors <- [
            [".sg-table td", ".sg-table th"],
            [".sg-table-panel td", ".sg-table-panel th"]
          ] do
        assert rule_bodies_all(css, selectors) != []
        assert declares?(css, selectors, "font-variant-numeric", "tabular-nums")
      end

      planted = ".sg-table td, .sg-table th { padding: 0; }"

      refute declares?(
               planted,
               [".sg-table td", ".sg-table th"],
               "font-variant-numeric",
               "tabular-nums"
             )
    end
  end

  describe "control edges (BTOK-08)" do
    test "interactive controls draw their edge in the Control Edge token, not the divider or the strong line",
         %{css: css} do
      for selector <- @interactive_controls do
        assert control_edge_problems(css, selector) == []
      end
    end

    test "a control that keeps the divider edge or the strong line is reported" do
      divider = ".sg-btn--secondary { box-shadow: var(--sg-elev-inset); }"
      strong = ".sg-filter-chip { box-shadow: inset 0 0 0 1px var(--sg-color-line-strong); }"

      mixed =
        ".sg-btn--danger { box-shadow: #{@control_edge_shadow}; border-color: var(--sg-color-line-strong); }"

      assert control_edge_problems(divider, ".sg-btn--secondary") != []
      assert control_edge_problems(strong, ".sg-filter-chip") != []
      assert control_edge_problems(mixed, ".sg-btn--danger") != []
      assert control_edge_problems("", ".sg-theme-switch") == ["no rule lists .sg-theme-switch"]
    end

    test "surfaces that are not controls keep the divider edge", %{css: css} do
      for selectors <- [
            [".sg-status-pill", ".sg-badge"],
            [".sg-list-row"],
            [".sg-notice"]
          ] do
        assert rule_bodies_all(css, selectors) != []
        assert declares?(css, selectors, "box-shadow", "var(--sg-elev-inset)")
      end

      assert declares?(css, ".sg-empty-state", "border", "1px dashed var(--sg-color-line-strong)")
    end

    test "the example input and select edge is the Control Edge token" do
      app_css = File.read!(Path.join(@root, @example_app_css))
      selectors = [".sg-input", ".sg-select"]

      assert rule_bodies_all(app_css, selectors) != []
      assert declares?(app_css, selectors, "border", "1px solid var(--sg-color-control-edge)")

      for body <- rule_bodies(app_css, ".sg-input") do
        refute body =~ "--sg-color-line-strong"
      end
    end
  end

  describe "selected and current states (Phase 262)" do
    test "selected command rows use the selected surface and 2px edge tokens", %{css: css} do
      selector = ".sg-cmdk__item[aria-selected=\"true\"]"

      assert rule_bodies(css, selector) != []
      assert declares?(css, selector, "background", "var(--sg-color-selected)")

      assert declares?(
               css,
               selector,
               "border-inline-start",
               "2px solid var(--sg-color-selected-edge)"
             )

      assert declares?(css, selector, "color", "var(--sg-color-ink)")

      planted = "#{selector} { background: var(--sg-color-selected); }"

      refute declares?(
               planted,
               selector,
               "border-inline-start",
               "2px solid var(--sg-color-selected-edge)"
             )
    end

    test "the current tab keeps its text cue and gets one tokenized square", %{css: css} do
      selector = ".sg-tabs__tab[aria-current=\"page\"]::before"

      assert rule_bodies(css, selector) != []
      assert declares?(css, selector, "width", "0.5rem")
      assert declares?(css, selector, "height", "0.5rem")
      assert declares?(css, selector, "background", "var(--sg-color-current-tab)")

      assert declares?(
               css,
               ".sg-tabs__tab[aria-current=\"page\"]",
               "color",
               "var(--sg-color-brand-strong)"
             )

      planted = ".sg-tabs__tab[aria-current=\"page\"]::before { width: 0.5rem; }"
      refute declares?(planted, selector, "background", "var(--sg-color-current-tab)")
    end
  end

  describe "table header ground (BTOK-08)" do
    test "the sticky header cell reads the sunken token, not the panel", %{css: css} do
      for selector <- [".sg-table-panel th", ".sg-table__head th"] do
        assert rule_bodies(css, selector) != []
        assert declares?(css, selector, "background", "var(--sg-color-sunken)")
        refute declares?(css, selector, "background", "var(--sg-color-panel)")
      end

      planted = ".sg-table-panel th { background: var(--sg-color-panel); }"
      refute declares?(planted, ".sg-table-panel th", "background", "var(--sg-color-sunken)")
    end

    test "the sunken ground is an opaque hex in every scope, so rows scrolling under the sticky header never show through",
         %{blocks: blocks} do
      for os <- [:light, :dark], shell <- [nil, :light, :dark] do
        computed = CssContrast.computed(blocks, os: os, shell: shell)
        value = Map.fetch!(computed, "--sg-color-sunken")

        assert opaque_hex?(value),
               "sunken is #{inspect(value)} for os #{os}, shell #{inspect(shell)}"
      end

      assert opaque_hex?("#EFE9E1")
      refute opaque_hex?("rgba(239, 233, 225, 0.5)")
      refute opaque_hex?("#EFE9E180")
      refute opaque_hex?("var(--sg-color-panel)")
    end
  end

  describe "arrow glyph guard (BTOK-06)" do
    test "no arrow sits inside a code element or an .sg-code element in the admin markup" do
      files =
        for root <- @markup_roots,
            extension <- @markup_extensions,
            path <- Path.wildcard(Path.join([@root, root, "**", "*" <> extension])),
            do: path

      refute files == [], "no markup file was found under #{inspect(@markup_roots)}"

      assert Enum.any?(files, &(File.read!(&1) =~ "sg-code")),
             "the scan never reached an .sg-code element"

      offenders =
        for path <- files,
            hit <- arrow_in_code(File.read!(path)),
            do: {Path.relative_to(path, @root), hit}

      assert offenders == []
    end

    test "a named entity, a numeric reference or a literal arrow inside <code> is reported" do
      assert arrow_in_code("<code>&larr; back</code>") == ["<code>&larr; back</code>"]
      assert arrow_in_code("<code>next &rarr;</code>") == ["<code>next &rarr;</code>"]
      assert arrow_in_code("<code>go &#8594; on</code>") == ["<code>go &#8594; on</code>"]
      assert arrow_in_code("<code>go &#x2190; on</code>") == ["<code>go &#x2190; on</code>"]
      assert arrow_in_code("<code>a → b</code>") == ["<code>a → b</code>"]
      assert arrow_in_code("<code>a ← b</code>") == ["<code>a ← b</code>"]
    end

    test "an element with the .sg-code class is covered whatever its tag" do
      assert arrow_in_code(~s(<span class="sg-code">x → y</span>)) ==
               [~s(<span class="sg-code">x → y</span>)]

      assert arrow_in_code(~s(<td class="a sg-code b">x &rarr; y</td>)) ==
               [~s(<td class="a sg-code b">x &rarr; y</td>)]

      assert arrow_in_code(~s(<span class={["sg-code", @x]}>x &larr; y</span>)) != []
    end

    test "an arrow outside code, or a look-alike class, is not reported" do
      assert arrow_in_code(~s(<span aria-hidden="true">&larr;</span> <code>back</code>)) == []
      assert arrow_in_code(~s(<p>go → now</p>)) == []
      assert arrow_in_code(~s(<span class="sg-code-chip">x &rarr; y</span>)) == []
      assert arrow_in_code(~s(<code>a</code> &rarr; <code>b</code>)) == []
      assert arrow_in_code(~s(<code />&rarr;)) == []
    end
  end

  # -- pure helpers --------------------------------------------------------------

  # Problems with the resting edge of one control rule; `[]` means it is correct.
  defp control_edge_problems(css, selector) do
    bodies = rule_bodies(css, selector)

    if bodies == [] do
      ["no rule lists #{selector}"]
    else
      missing =
        if declares?(css, selector, "box-shadow", @control_edge_shadow),
          do: [],
          else: ["#{selector} does not declare box-shadow: #{@control_edge_shadow}"]

      stale =
        for body <- bodies, token <- @stale_edge_tokens, body =~ token do
          "#{selector} still references #{token}"
        end

      missing ++ stale
    end
  end

  # An opaque colour is a six-digit hex: no alpha channel, no var(), no function.
  defp opaque_hex?(value), do: Regex.match?(~r/\A#[0-9A-Fa-f]{6}\z/, value)

  # Source text of every element that holds an arrow glyph and must not: any
  # `<code ...>` and any element whose literal class lists `sg-code`. The element
  # runs from its opening tag to the first closing tag of the same name (an
  # unterminated element runs to the end of the text, so it fails closed).
  defp arrow_in_code(markup) do
    ~r/<([a-zA-Z][\w.:-]*)([^>]*)>/
    |> Regex.scan(markup, return: :index)
    |> Enum.flat_map(fn [{start, length}, {name_start, name_length}, {attrs_start, attrs_length}] ->
      name = binary_part(markup, name_start, name_length)
      attrs = binary_part(markup, attrs_start, attrs_length)

      if code_element?(name, attrs) and not String.ends_with?(attrs, "/") do
        element_with_arrow(markup, name, start, start + length)
      else
        []
      end
    end)
  end

  defp code_element?("code", _attrs), do: true

  defp code_element?(_name, attrs),
    do: Regex.match?(~r/class=(?:"[^"]*|\{[^}]*)(?<![\w-])sg-code(?![\w-])/, attrs)

  defp element_with_arrow(markup, name, start, content_start) do
    rest = binary_part(markup, content_start, byte_size(markup) - content_start)

    {content, element_end} =
      case Regex.run(~r{</#{Regex.escape(name)}\s*>}, rest, return: :index) do
        [{close, close_length}] ->
          {binary_part(rest, 0, close), content_start + close + close_length}

        nil ->
          {rest, byte_size(markup)}
      end

    if Regex.match?(@arrow, content),
      do: [binary_part(markup, start, element_end - start)],
      else: []
  end

  defp strip_comments(css), do: Regex.replace(~r{/\*.*?\*/}s, css, " ")

  defp collapse(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()

  # True when the comment-stripped text contains an @font-face at-rule.
  defp font_face?(css), do: css |> strip_comments() |> String.contains?("@font-face")

  # Declaration bodies of every rule whose selector list contains `selector` exactly.
  defp rule_bodies(css, selector) do
    for %{selectors: selectors, body: body} <- rules(css), selector in selectors, do: body
  end

  # Declaration bodies of every rule whose selector list contains every selector.
  defp rule_bodies_all(css, selectors) do
    for %{selectors: listed, body: body} <- rules(css),
        Enum.all?(List.wrap(selectors), &(&1 in listed)),
        do: body
  end

  describe "theme switch contrast" do
    test "theme buttons do not tween text or fill colors while the palette changes", %{css: css} do
      selector = ".sg-theme-switch__button"

      assert declares?(css, selector, "transition", "var(--sg-transition-press)")
      refute declares?(css, selector, "transition", "var(--sg-transition-tone)")
    end
  end

  # True when some rule listing every selector declares `property: value`.
  defp declares?(css, selectors, property, value) do
    css
    |> rule_bodies_all(selectors)
    |> Enum.any?(&({property, value} in declarations(&1)))
  end

  # `[{property, value}]` from a declaration body, whitespace-collapsed.
  defp declarations(body) do
    body
    |> String.split(";")
    |> Enum.flat_map(fn declaration ->
      case String.split(declaration, ":", parts: 2) do
        [property, value] -> [{collapse(property), collapse(value)}]
        _ -> []
      end
    end)
  end

  # A flat list of `%{selectors, body}`. Grouping at-rules (`@media`, `@layer`, ...)
  # are entered; any other block is a rule; `;` ends a statement at-rule.
  defp rules(css), do: css |> strip_comments() |> parse_rules([]) |> Enum.reverse()

  defp parse_rules(source, acc) do
    source = String.trim_leading(source)

    case :binary.match(source, ["{", ";"]) do
      :nomatch ->
        acc

      {position, 1} ->
        <<prelude::binary-size(position), delimiter::binary-size(1), rest::binary>> = source
        parse_after(delimiter, collapse(prelude), rest, acc)
    end
  end

  defp parse_after(";", _prelude, rest, acc), do: parse_rules(rest, acc)

  defp parse_after("{", prelude, rest, acc) do
    close = closing_brace(rest, 0, 1)
    body = binary_part(rest, 0, close)
    remainder = binary_part(rest, close + 1, byte_size(rest) - close - 1)

    acc =
      if String.starts_with?(prelude, @grouping_at_rules) do
        parse_rules(body, acc)
      else
        [%{selectors: split_selectors(prelude), body: body} | acc]
      end

    parse_rules(remainder, acc)
  end

  defp closing_brace(source, position, _depth) when position >= byte_size(source) do
    raise ArgumentError, "Could not find a balanced CSS block"
  end

  defp closing_brace(source, position, depth) do
    case :binary.at(source, position) do
      ?{ -> closing_brace(source, position + 1, depth + 1)
      ?} when depth == 1 -> position
      ?} -> closing_brace(source, position + 1, depth - 1)
      _other -> closing_brace(source, position + 1, depth)
    end
  end

  # Selectors split on top-level commas: a comma inside `(...)` or `[...]` stays.
  defp split_selectors(prelude) do
    prelude
    |> split_top_level(0, "", [])
    |> Enum.map(&collapse/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_top_level("", _depth, current, acc), do: Enum.reverse([current | acc])

  defp split_top_level(<<?,, rest::binary>>, 0, current, acc),
    do: split_top_level(rest, 0, "", [current | acc])

  defp split_top_level(<<char, rest::binary>>, depth, current, acc) do
    depth =
      cond do
        char in [?(, ?[] -> depth + 1
        char in [?), ?]] -> max(depth - 1, 0)
        true -> depth
      end

    split_top_level(rest, depth, current <> <<char>>, acc)
  end
end
