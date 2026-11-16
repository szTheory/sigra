defmodule Sigra.Test.Brand.CssContrast do
  @moduledoc """
  Test-only contrast instrument over the IMPLEMENTED admin stylesheet (BTOK-02).

  The brand book records 30 contrast pairs; this module is how a test evaluates
  them against what actually ships in
  `priv/templates/sigra.install/admin/sigra_admin.css`, not against the book.

  ## What it does

    * `blocks/1` parses the stylesheet into the four places a token lives: the light
      `:root` block, the `:root` block inside `@media (prefers-color-scheme: dark)`,
      and the explicit Light and Dark shell blocks. Each is an ordered list of
      `{"--sg-name", "raw value"}` with comments stripped and whitespace collapsed.
    * `computed/2` mirrors the cascade as two levels, not a flat merge. Level one is
      the root element (the `:root` declarations, then the dark `@media`
      declarations under a dark OS). Level two is the `.sg-admin-shell` element when
      an explicit theme is chosen: it inherits the level-one computed values and then
      applies its own block. A `var()` is substituted where it is declared, so an
      alias of a theme-variant token that is declared only in `:root` stays at the
      `:root` result inside an explicit-Dark shell. That is the footgun the
      four-place rule exists to prevent, and this is what lets a test catch it.
    * `resolve_color/2` turns a computed value into `{:ok, {r, g, b, a}}`, handling
      hex, `rgb()`/`rgba()`, `transparent`, and `color-mix()` in `srgb` and `oklab`.
      Anything else is `{:unresolved, reason}` so a caller fails closed rather than
      passing on an expression it could not evaluate.
    * `to_hex/2` composites an alpha colour over an opaque ground, and `check_pair/5`
      runs `Sigra.Branding.Contrast.contrast_ratio/2` (hex only, no alpha) on the
      result. `check_pair/5` is pure, so a test plants a bad colour in memory and
      watches it fail.

  The module also consolidates the block extractors that `admin_test.exs` keeps as
  private functions (`extract_css_block/2`, `extract_css_blocks/2`,
  `extract_sg_declarations/1`, `take_balanced_block/1`), so one parser remains. They
  raise `ArgumentError` where the private copies call `flunk`.

  Nothing here reads the environment, and the repo root comes from `__DIR__`, never
  the working directory.
  """

  alias Sigra.Branding.Contrast

  @typedoc "A parsed colour: channels in `0..255`, alpha in `0.0..1.0`."
  @type rgba :: {number(), number(), number(), float()}

  @typedoc "The four places a token is declared, each an ordered `{token, raw_value}` list."
  @type blocks :: %{
          root: [{String.t(), String.t()}],
          root_dark: [{String.t(), String.t()}],
          explicit_light: [{String.t(), String.t()}],
          explicit_dark: [{String.t(), String.t()}]
        }

  @root Path.expand("../../..", __DIR__)
  @admin_css "priv/templates/sigra.install/admin/sigra_admin.css"
  @dark_media "@media (prefers-color-scheme: dark)"
  @light_shell ~s(html[data-sg-admin-theme="light"] .sg-admin-shell)
  @dark_shell ~s(html[data-sg-admin-theme="dark"] .sg-admin-shell)
  @grouping_at_rules ["@media", "@layer", "@supports", "@container"]

  # -- files --------------------------------------------------------------------

  @doc "Absolute path of the shipped admin stylesheet, derived from this file's location."
  @spec css_path() :: Path.t()
  def css_path, do: Path.join(@root, @admin_css)

  @doc "The shipped admin stylesheet text."
  @spec read_css() :: String.t()
  def read_css, do: File.read!(css_path())

  # -- block extraction (consolidated from admin_test.exs) -----------------------

  @doc """
  The first balanced `{ ... }` block that follows `selector` in `css`, braces
  included. Raises `ArgumentError` when the selector or its block is missing.
  """
  @spec extract_css_block(String.t(), String.t()) :: String.t()
  def extract_css_block(css, selector) do
    case next_block(css, selector) do
      {:ok, block, _rest} -> block
      :nomatch -> raise ArgumentError, "Could not find CSS block for #{selector}"
    end
  end

  @doc """
  Every balanced block that follows an occurrence of `selector`, in source order.
  Returns `[]` when the selector does not occur.
  """
  @spec extract_css_blocks(String.t(), String.t()) :: [String.t()]
  def extract_css_blocks(css, selector), do: collect_blocks(css, selector, [])

  defp collect_blocks(css, selector, acc) do
    case next_block(css, selector) do
      {:ok, block, rest} -> collect_blocks(rest, selector, [block | acc])
      :nomatch -> Enum.reverse(acc)
    end
  end

  # The first block after `selector`, and the text after that block.
  defp next_block(css, selector) do
    with {selector_offset, _length} <- :binary.match(css, selector),
         {brace_offset, 1} <-
           :binary.match(css, "{", scope: {selector_offset, byte_size(css) - selector_offset}) do
      block =
        css
        |> binary_part(brace_offset, byte_size(css) - brace_offset)
        |> take_balanced_block()

      consumed = brace_offset + byte_size(block)
      {:ok, block, binary_part(css, consumed, byte_size(css) - consumed)}
    else
      :nomatch -> :nomatch
    end
  end

  @doc """
  The balanced `{ ... }` block at the start of `source`, braces included. Raises
  `ArgumentError` when the braces never balance.
  """
  @spec take_balanced_block(String.t()) :: String.t()
  def take_balanced_block(source) do
    close = closing_brace(source, 0, 0)
    binary_part(source, 0, close + 1)
  end

  # Offset of the `}` that brings `depth` back to zero.
  defp closing_brace(source, position, _depth) when position >= byte_size(source) do
    raise ArgumentError, "Could not find balanced CSS block"
  end

  defp closing_brace(source, position, depth) do
    case :binary.at(source, position) do
      ?{ -> closing_brace(source, position + 1, depth + 1)
      ?} when depth == 1 -> position
      ?} -> closing_brace(source, position + 1, depth - 1)
      _other -> closing_brace(source, position + 1, depth)
    end
  end

  @doc """
  The `--sg-name: value;` declarations of a block, whitespace-collapsed and sorted.
  """
  @spec extract_sg_declarations(String.t()) :: [String.t()]
  def extract_sg_declarations(block) do
    ~r/--sg-[\w-]+\s*:\s*[^;]+;/s
    |> Regex.scan(block)
    |> List.flatten()
    |> Enum.map(&collapse/1)
    |> Enum.sort()
  end

  # -- the four token places ----------------------------------------------------

  @doc """
  Parses `css` into the four token places (see the `t:blocks/0` type).

  Selectors are matched exactly (a selector list is split on commas), so a nested
  rule such as `html[data-sg-admin-theme="dark"] .sg-admin-shell .sg-x` is not
  mistaken for the shell block. A missing place is `[]`, never an error, so a
  caller must assert non-emptiness before trusting a result.
  """
  @spec blocks(String.t()) :: blocks()
  def blocks(css) do
    rules = rules(css)

    %{
      root: declarations_for(rules, ":root", &(not media?(&1))),
      root_dark: declarations_for(rules, ":root", &dark_media?/1),
      explicit_light: declarations_for(rules, @light_shell, &(not media?(&1))),
      explicit_dark: declarations_for(rules, @dark_shell, &(not media?(&1)))
    }
  end

  defp rules(css), do: css |> strip_comments() |> parse_rules([], []) |> Enum.reverse()

  defp declarations_for(rules, selector, context_filter) do
    rules
    |> Enum.filter(&(selector in &1.selectors and context_filter.(&1.context)))
    |> Enum.flat_map(&declarations(&1.body))
  end

  defp media?(context), do: Enum.any?(context, &String.starts_with?(&1, "@media"))
  defp dark_media?(context), do: @dark_media in context

  defp declarations(body) do
    ~r/(--sg-[\w-]+)\s*:\s*([^;]+?)\s*(?:;|\z)/s
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(fn [name, value] -> {name, collapse(value)} end)
  end

  defp strip_comments(css), do: Regex.replace(~r{/\*.*?\*/}s, css, " ")

  # A flat, reversed list of `%{selectors, body, context}`: grouping at-rules
  # (`@media`, `@layer`, ...) are entered and recorded in `context`, anything else
  # with a block is a rule.
  defp parse_rules(source, context, acc) do
    source = String.trim_leading(source)

    case :binary.match(source, ["{", ";"]) do
      :nomatch ->
        acc

      {position, 1} ->
        <<prelude::binary-size(position), delimiter::binary-size(1), rest::binary>> = source
        parse_after(delimiter, collapse(prelude), rest, context, acc)
    end
  end

  # `;` ends a statement at-rule such as `@layer a, b;`.
  defp parse_after(";", _prelude, rest, context, acc), do: parse_rules(rest, context, acc)

  defp parse_after("{", prelude, rest, context, acc) do
    close = closing_brace(rest, 0, 1)
    body = binary_part(rest, 0, close)
    remainder = binary_part(rest, close + 1, byte_size(rest) - close - 1)

    acc =
      if String.starts_with?(prelude, @grouping_at_rules) do
        parse_rules(body, context ++ [prelude], acc)
      else
        [%{selectors: split_selectors(prelude), body: body, context: context} | acc]
      end

    parse_rules(remainder, context, acc)
  end

  defp split_selectors(prelude) do
    prelude
    |> String.split(",")
    |> Enum.map(&collapse/1)
    |> Enum.reject(&(&1 == ""))
  end

  # -- cascade ------------------------------------------------------------------

  @doc """
  The computed value of every token for a scope.

  Options:

    * `:os` - `:light` (default) or `:dark`, the OS colour scheme.
    * `:shell` - `nil` (default, no admin shell: root element only), `:light` or
      `:dark`, the explicit admin theme on the shell element.

  Returns `%{"--sg-name" => computed_value}`. A `var()` with no declaration and no
  fallback stays in the value as written, so `resolve_color/2` reports it instead
  of the cascade silently inventing a colour.
  """
  @spec computed(blocks(), keyword()) :: %{String.t() => String.t()}
  def computed(blocks, opts \\ []) do
    os = Keyword.get(opts, :os, :light)
    shell = Keyword.get(opts, :shell)

    if os not in [:light, :dark] do
      raise ArgumentError, "expected :os to be :light or :dark, got: #{inspect(os)}"
    end

    if shell not in [nil, :light, :dark] do
      raise ArgumentError, "expected :shell to be nil, :light or :dark, got: #{inspect(shell)}"
    end

    root_level = compute_scope(root_declarations(blocks, os), %{})

    case shell do
      nil -> root_level
      theme -> Map.merge(root_level, compute_scope(shell_declarations(blocks, theme), root_level))
    end
  end

  defp root_declarations(blocks, :light), do: blocks.root
  defp root_declarations(blocks, :dark), do: blocks.root ++ blocks.root_dark

  defp shell_declarations(blocks, :light), do: blocks.explicit_light
  defp shell_declarations(blocks, :dark), do: blocks.explicit_dark

  # Later declarations win, as in the cascade.
  defp compute_scope(declarations, inherited) do
    raw = Map.new(declarations)
    Map.new(raw, fn {name, _value} -> {name, resolve_token(name, raw, inherited, [])} end)
  end

  defp resolve_token(name, raw, inherited, visiting) do
    visiting = [name | visiting]

    raw
    |> Map.fetch!(name)
    |> substitute(&lookup(&1, raw, inherited, visiting))
  end

  # A scope's own declarations win over what the element inherits. A reference back
  # into the chain being resolved is a cycle and is left unresolved.
  defp lookup(reference, raw, inherited, visiting) do
    cond do
      reference in visiting -> :error
      Map.has_key?(raw, reference) -> {:ok, resolve_token(reference, raw, inherited, visiting)}
      true -> Map.fetch(inherited, reference)
    end
  end

  # Replaces every `var(--name[, fallback])` in `value`. `lookup` returns
  # `{:ok, text}` or `:error`; with `:error` the fallback is used, or the `var()` is
  # left exactly as written.
  defp substitute(value, lookup), do: substitute_from(value, 0, lookup)

  defp substitute_from(value, from, lookup) do
    case :binary.match(value, "var(", scope: {from, byte_size(value) - from}) do
      :nomatch -> value
      {position, 4} -> substitute_at(value, position, lookup)
    end
  end

  defp substitute_at(value, position, lookup) do
    arguments_start = position + 4
    preceded_by_name? = position > 0 and name_byte?(:binary.at(value, position - 1))
    close = if preceded_by_name?, do: nil, else: closing_paren(value, arguments_start, 1)

    if is_nil(close) do
      substitute_from(value, arguments_start, lookup)
    else
      [name | fallback_parts] =
        value |> binary_part(arguments_start, close - arguments_start) |> split_top_level()

      replacement = var_replacement(name, fallback_parts, lookup)
      head = binary_part(value, 0, position)
      tail = binary_part(value, close + 1, byte_size(value) - close - 1)

      substitute_from(head <> replacement <> tail, position + byte_size(replacement), lookup)
    end
  end

  defp var_replacement(name, fallback_parts, lookup) do
    case {lookup.(name), fallback_parts} do
      {{:ok, text}, _fallback} -> text
      {:error, []} -> "var(#{name})"
      {:error, parts} -> parts |> Enum.join(",") |> String.trim() |> substitute(lookup)
    end
  end

  defp name_byte?(byte) when byte in ?a..?z or byte in ?A..?Z or byte in ?0..?9, do: true
  defp name_byte?(byte), do: byte in [?-, ?_]

  # Offset of the `)` that closes the call whose arguments start at `position`.
  defp closing_paren(value, position, _depth) when position >= byte_size(value), do: nil

  defp closing_paren(value, position, depth) do
    case :binary.at(value, position) do
      ?( -> closing_paren(value, position + 1, depth + 1)
      ?) when depth == 1 -> position
      ?) -> closing_paren(value, position + 1, depth - 1)
      _other -> closing_paren(value, position + 1, depth)
    end
  end

  # Splits on commas that are not inside parentheses; each part is trimmed.
  defp split_top_level(string) do
    {parts, current, _depth} =
      string
      |> :binary.bin_to_list()
      |> Enum.reduce({[], [], 0}, &split_byte/2)

    Enum.reverse([finish_part(current) | parts])
  end

  defp split_byte(?(, {parts, current, depth}), do: {parts, [?( | current], depth + 1}
  defp split_byte(?), {parts, current, depth}), do: {parts, [?) | current], depth - 1}
  defp split_byte(?,, {parts, current, 0}), do: {[finish_part(current) | parts], [], 0}
  defp split_byte(byte, {parts, current, depth}), do: {parts, [byte | current], depth}

  defp finish_part(reversed_bytes) do
    reversed_bytes |> Enum.reverse() |> :binary.list_to_bin() |> String.trim()
  end

  @doc """
  The two scope option sets under which a theme is shown, each a keyword list for
  `computed/2`.

  `:light` is the OS light with no chosen theme, and the OS dark with the admin set
  to Light; `:dark` is the OS dark with no chosen theme, and the OS light with the
  admin set to Dark. A declaration missing from an explicit block only breaks the
  second of each pair, so a proof has to evaluate both.
  """
  @spec scopes(:light | :dark) :: [keyword()]
  def scopes(:light), do: [[os: :light, shell: nil], [os: :dark, shell: :light]]
  def scopes(:dark), do: [[os: :dark, shell: nil], [os: :light, shell: :dark]]

  @doc "A short label for a `computed/2` scope, e.g. `\"os=dark shell=light\"`."
  @spec scope_label(keyword() | nil) :: String.t()
  def scope_label(nil), do: "-"

  def scope_label(scope) do
    "os=#{Keyword.fetch!(scope, :os)} shell=#{Keyword.get(scope, :shell) || "none"}"
  end

  # -- colours ------------------------------------------------------------------

  @doc """
  Resolves a colour to `{:ok, {r, g, b, a}}`, or `{:unresolved, reason}`.

  `value` is a CSS colour expression or a `--sg-*` token name found in `computed`.
  Any `var()` in it is substituted from `computed` first.
  """
  @spec resolve_color(String.t(), %{String.t() => String.t()}) ::
          {:ok, rgba()} | {:unresolved, String.t()}
  def resolve_color(value, computed \\ %{}) do
    value = collapse(value)

    if String.starts_with?(value, "--") do
      resolve_token_name(value, computed)
    else
      value |> substitute(&Map.fetch(computed, &1)) |> parse_resolved()
    end
  end

  defp resolve_token_name(name, computed) do
    case Map.fetch(computed, name) do
      {:ok, value} -> resolve_color(value, computed)
      :error -> {:unresolved, "unknown token #{name}"}
    end
  end

  defp parse_resolved(value) do
    case Regex.run(~r/var\(\s*(--[\w-]+)/, value) do
      [_whole, name] -> {:unresolved, "undefined var(#{name}) with no fallback"}
      nil -> value |> String.downcase() |> parse_color()
    end
  end

  defp parse_color("transparent"), do: {:ok, {0, 0, 0, 0.0}}

  defp parse_color("currentcolor"),
    do: {:unresolved, "currentColor depends on the element, not on the token map"}

  defp parse_color("#" <> digits), do: parse_hex(digits)
  defp parse_color("rgb(" <> rest), do: parse_rgb(rest)
  defp parse_color("rgba(" <> rest), do: parse_rgb(rest)
  defp parse_color("color-mix(" <> rest), do: parse_color_mix(rest)
  defp parse_color(other), do: {:unresolved, unsupported_reason(other)}

  defp unsupported_reason(value) do
    case Regex.run(~r/^([a-z][a-z0-9-]*)\(/, value) do
      [_whole, function] -> "unsupported function #{function}()"
      nil -> "unsupported colour value #{inspect(value)}"
    end
  end

  defp parse_hex(digits) do
    if String.match?(digits, ~r/\A(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})\z/) do
      <<r::binary-size(2), g::binary-size(2), b::binary-size(2), a::binary>> =
        digits |> expand_short_hex() |> Kernel.<>("ff") |> binary_part(0, 8)

      alpha = if byte_size(digits) in [4, 8], do: hex_byte(a) / 255, else: 1.0
      {:ok, {hex_byte(r), hex_byte(g), hex_byte(b), alpha}}
    else
      {:unresolved, "malformed hex colour #{inspect("#" <> digits)}"}
    end
  end

  defp expand_short_hex(digits) when byte_size(digits) in [3, 4] do
    digits |> String.graphemes() |> Enum.map_join(&(&1 <> &1))
  end

  defp expand_short_hex(digits), do: digits

  defp hex_byte(pair), do: pair |> Integer.parse(16) |> elem(0)

  defp parse_rgb(rest) do
    with {inner, ")"} <- String.split_at(rest, -1),
         tokens = inner |> String.replace(["/", ","], " ") |> String.split(),
         true <- length(tokens) in [3, 4],
         {:ok, [r, g, b | alpha]} <- parse_all(tokens, &parse_channel/2) do
      {:ok, {r, g, b, List.first(alpha, 1.0)}}
    else
      _other -> {:unresolved, "malformed rgb() colour #{inspect("rgb(" <> rest)}"}
    end
  end

  # Channels 0..255 (or percentages of 255); the optional fourth token is alpha.
  defp parse_all(tokens, parser) do
    tokens
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {token, index}, {:ok, acc} ->
      case parser.(token, index) do
        {:ok, value} -> {:cont, {:ok, acc ++ [value]}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp parse_channel(token, 3), do: parse_fraction(token)

  defp parse_channel(token, _index) do
    case parse_percentage_or_number(token, 255) do
      {:ok, value} -> {:ok, value |> clamp(0, 255) |> tidy()}
      :error -> :error
    end
  end

  defp parse_fraction(token) do
    case parse_percentage_or_number(token, 1) do
      {:ok, value} -> {:ok, clamp(value, 0, 1) * 1.0}
      :error -> :error
    end
  end

  # `scale` is what 100% means: 255 for a channel, 1 for an alpha.
  defp parse_percentage_or_number(token, scale) do
    case String.split_at(token, -1) do
      {number, "%"} -> with {:ok, value} <- parse_number(number), do: {:ok, value * scale / 100}
      _other -> parse_number(token)
    end
  end

  defp parse_number(string) do
    string = if String.starts_with?(string, "."), do: "0" <> string, else: string

    case Float.parse(string) do
      {number, ""} -> {:ok, number}
      _other -> :error
    end
  end

  # `21.0` reads better as `21`.
  defp tidy(number) when is_float(number) and number == trunc(number), do: trunc(number)
  defp tidy(number), do: number

  defp clamp(number, low, _high) when number < low, do: low
  defp clamp(number, _low, high) when number > high, do: high
  defp clamp(number, _low, _high), do: number

  @doc """
  The colour of each layer of a `box-shadow` value, as written, in layer order.

  The value is split on top-level commas (a comma inside `rgba()` or `color-mix()`
  is not a layer break) and the first colour in each layer is returned: a hex, a
  colour function (`rgb()`, `rgba()`, `color-mix()`, `oklab()` and the other CSS
  colour functions, so one this module cannot evaluate is still returned and fails
  closed in `resolve_color/2`), `transparent` or `currentColor`. A layer with no
  colour is skipped. The outer ring of a two-layer focus ring is the last entry.
  """
  @spec shadow_colors(String.t()) :: [String.t()]
  def shadow_colors(shadow) do
    shadow |> collapse() |> split_top_level() |> Enum.flat_map(&layer_color/1)
  end

  defp layer_color(layer) do
    pattern =
      ~r/#[0-9a-fA-F]+(?![0-9a-zA-Z])|\b(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|color-mix|color|light-dark)\(|\b(?:transparent|currentcolor)\b/i

    case Regex.run(pattern, layer, return: :index) do
      nil -> []
      [{start, length}] -> [layer_color_at(layer, start, length)]
    end
  end

  # A function colour runs to its closing parenthesis; an unbalanced one is returned
  # to its end so the resolver reports it.
  defp layer_color_at(layer, start, length) do
    matched = binary_part(layer, start, length)

    if String.ends_with?(matched, "(") do
      case closing_paren(layer, start + length, 1) do
        nil -> binary_part(layer, start, byte_size(layer) - start)
        close -> binary_part(layer, start, close + 1 - start)
      end
    else
      matched
    end
  end

  @doc """
  The distinct `fill="#hex"` colours of an SVG, upper-cased, in order of first
  appearance. A shipped logo has the letters first and the square second.
  """
  @spec svg_fills(String.t()) :: [String.t()]
  def svg_fills(svg) do
    ~r/\bfill=["'](#[0-9a-fA-F]{3,8})["']/
    |> Regex.scan(svg, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.upcase/1)
    |> Enum.uniq()
  end

  # -- compositing and ratio ----------------------------------------------------

  @doc """
  Composites an `{r, g, b, a}` colour over an opaque ground hex and returns the
  resulting integer `{r, g, b}`. Channel arithmetic is in sRGB, as a browser blends,
  rounded half up. Alpha 0 returns the ground and alpha 1 returns the colour.
  """
  @spec composite(rgba(), String.t()) :: {0..255, 0..255, 0..255}
  def composite({r, g, b, alpha}, ground) do
    {gr, gg, gb} = Contrast.to_rgb(ground)

    {blend(r, gr, alpha), blend(g, gg, alpha), blend(b, gb, alpha)}
  end

  defp blend(channel, ground_channel, alpha) do
    mixed = channel * alpha + ground_channel * (1 - alpha)
    mixed |> clamp(0, 255) |> round_half_up()
  end

  defp round_half_up(number), do: trunc(number + 0.5)

  @doc """
  Composites an `{r, g, b, a}` colour over an opaque ground hex and returns
  upper-case `"#RRGGBB"`, the form `Sigra.Branding.Contrast.contrast_ratio/2` takes.
  """
  @spec to_hex(rgba(), String.t()) :: String.t()
  def to_hex(rgba, ground) do
    {r, g, b} = composite(rgba, ground)
    "#" <> hex_pair(r) <> hex_pair(g) <> hex_pair(b)
  end

  defp hex_pair(value), do: value |> Integer.to_string(16) |> String.pad_leading(2, "0")

  @doc """
  Resolves a colour or token (see `resolve_color/2`) and composites it over an
  opaque `ground` hex. `{:ok, "#RRGGBB"}` or `{:unresolved, reason}`.
  """
  @spec resolve_hex(String.t(), %{String.t() => String.t()}, String.t()) ::
          {:ok, String.t()} | {:unresolved, String.t()}
  def resolve_hex(value, computed \\ %{}, ground \\ "#FFFFFF") do
    with {:ok, rgba} <- resolve_color(value, computed), do: {:ok, to_hex(rgba, ground)}
  end

  @doc "WCAG 2.x contrast ratio of two opaque hex colours, from `Sigra.Branding.Contrast`."
  @spec ratio(String.t(), String.t()) :: float()
  def ratio(text, ground), do: Contrast.contrast_ratio(text, ground)

  @doc """
  Evaluates one contrast pair. Pure: a test can plant a colour in memory.

  Returns `%{id, theme, text, ground, ratio, minimum, pass?}`.
  """
  @spec check_pair(String.t(), atom(), String.t(), String.t(), number()) :: map()
  def check_pair(id, theme, text, ground, minimum \\ 4.5) do
    ratio = ratio(text, ground)

    %{
      id: id,
      theme: theme,
      text: text,
      ground: ground,
      ratio: ratio,
      minimum: minimum,
      pass?: ratio >= minimum
    }
  end

  # -- color-mix() --------------------------------------------------------------

  defp parse_color_mix(rest) do
    with {inner, ")"} <- String.split_at(rest, -1),
         [space_argument, first, second] <- split_top_level(inner),
         {:ok, space} <- parse_mix_space(space_argument),
         {:ok, {first_color, first_percent}} <- parse_mix_operand(first),
         {:ok, {second_color, second_percent}} <- parse_mix_operand(second) do
      mix(space, first_color, second_color, {first_percent, second_percent})
    else
      {:unresolved, _reason} = unresolved -> unresolved
      _other -> {:unresolved, "malformed color-mix() #{inspect("color-mix(" <> rest)}"}
    end
  end

  defp parse_mix_space("in srgb"), do: {:ok, :srgb}
  defp parse_mix_space("in oklab"), do: {:ok, :oklab}

  defp parse_mix_space(other),
    do: {:unresolved, "unsupported colour space #{inspect(other)} in color-mix()"}

  defp parse_mix_operand(operand) do
    {color_text, percentage} = split_percentage(operand)

    with {:ok, color} <- parse_color(color_text), do: {:ok, {color, percentage}}
  end

  # The percentage may lead or trail the colour; `rgb(10% 20% 30%)` ends in `)`, so
  # a percentage inside a colour function is never mistaken for it.
  defp split_percentage(operand) do
    leading = Regex.run(~r/\A(\d*\.?\d+)%\s+(\S.*)\z/s, operand)
    trailing = Regex.run(~r/\A(.*\S)\s+(\d*\.?\d+)%\z/s, operand)

    case {leading, trailing} do
      {[_whole, percent, color], _trailing} -> {color, percentage_number(percent)}
      {_leading, [_whole, color, percent]} -> {color, percentage_number(percent)}
      _neither -> {operand, nil}
    end
  end

  defp percentage_number(text) do
    {:ok, number} = parse_number(text)
    number
  end

  @doc """
  CSS Color 5 `color-mix(in <space>, c1 p1%, c2 p2%)` over `{r, g, b, a}` colours.

  `percentages` is `{p1, p2}` where either may be `nil`: both `nil` is 50/50, one
  `nil` is the remainder to 100, and two given percentages that sum to under 100
  scale the result alpha by the sum (over 100 they are normalised). Interpolation
  is premultiplied by alpha, which is how a browser mixes against `transparent`:
  the other colour is kept and carries its percentage as alpha.

  `space` is `:srgb` or `:oklab`. Returns `{:ok, rgba}` or `{:unresolved, reason}`
  for a percentage outside `0..100` or a zero sum. Channels are not rounded here;
  `to_hex/2` rounds once at the end.
  """
  @spec mix(:srgb | :oklab, rgba(), rgba(), {number() | nil, number() | nil}) ::
          {:ok, rgba()} | {:unresolved, String.t()}
  def mix(space, first, second, {first_percent, second_percent}) when space in [:srgb, :oklab] do
    with {:ok, {first_weight, second_weight, scale}} <-
           mix_weights(first_percent, second_percent) do
      {first_components, first_alpha} = to_mix_space(space, first)
      {second_components, second_alpha} = to_mix_space(space, second)

      shares = {first_alpha * first_weight, second_alpha * second_weight}
      mixed = premultiplied_mix(space, first_components, second_components, shares)

      {:ok, with_alpha(mixed, scale)}
    end
  end

  # Components weighted by `alpha * percentage` and divided by the mixed alpha. A
  # fully transparent result has no colour, so it is transparent black.
  defp premultiplied_mix(space, first, second, {first_share, second_share}) do
    alpha = first_share + second_share

    if alpha == 0 do
      {0, 0, 0, 0.0}
    else
      {r, g, b} =
        [first, second]
        |> Enum.map(&Tuple.to_list/1)
        |> Enum.zip_with(fn [a, b] -> (a * first_share + b * second_share) / alpha end)
        |> List.to_tuple()
        |> from_mix_space(space)

      {r, g, b, alpha}
    end
  end

  defp with_alpha({r, g, b, alpha}, scale), do: {r, g, b, alpha * scale}

  defp mix_weights(first, second) do
    {first, second} = fill_percentages(first, second)
    sum = first + second

    cond do
      first < 0 or second < 0 or first > 100 or second > 100 ->
        {:unresolved, "color-mix() percentage outside 0..100"}

      sum == 0 ->
        {:unresolved, "color-mix() percentages sum to zero"}

      true ->
        {:ok, {first / sum, second / sum, min(sum / 100, 1.0)}}
    end
  end

  defp fill_percentages(nil, nil), do: {50, 50}
  defp fill_percentages(first, nil), do: {first, 100 - first}
  defp fill_percentages(nil, second), do: {100 - second, second}
  defp fill_percentages(first, second), do: {first, second}

  defp to_mix_space(:srgb, {r, g, b, alpha}), do: {{r, g, b}, alpha}
  defp to_mix_space(:oklab, {r, g, b, alpha}), do: {oklab({r, g, b}), alpha}

  defp from_mix_space({r, g, b}, :srgb),
    do: {clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255)}

  defp from_mix_space(lab, :oklab) do
    {r, g, b} = oklab_to_srgb(lab)
    {clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255)}
  end

  # -- OKLab (Ottosson, https://bottosson.github.io/posts/oklab/) ---------------

  @doc """
  The OKLab `{l, a, b}` of an opaque sRGB colour, given as a hex string or an
  `{r, g, b}` tuple of `0..255` numbers.
  """
  @spec oklab(String.t() | {number(), number(), number()}) :: {float(), float(), float()}
  def oklab("#" <> _digits = hex), do: hex |> Contrast.to_rgb() |> oklab()

  def oklab({r, g, b}) do
    {r, g, b} = {linear_channel(r), linear_channel(g), linear_channel(b)}

    l = cube_root(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = cube_root(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = cube_root(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

    {
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    }
  end

  @doc """
  The sRGB `{r, g, b}` of an OKLab `{l, a, b}`, clamped to the gamut and rounded to
  integers in `0..255`.
  """
  @spec from_oklab({number(), number(), number()}) :: {0..255, 0..255, 0..255}
  def from_oklab(lab) do
    {r, g, b} = oklab_to_srgb(lab)
    {to_byte(r), to_byte(g), to_byte(b)}
  end

  defp to_byte(channel), do: channel |> clamp(0, 255) |> round_half_up()

  # Unrounded, unclamped sRGB channels (`0..255` scale) for an OKLab colour.
  defp oklab_to_srgb({l, a, b}) do
    l_ = l + 0.3963377774 * a + 0.2158037573 * b
    m_ = l - 0.1055613458 * a - 0.0638541728 * b
    s_ = l - 0.0894841775 * a - 1.2914855480 * b
    {l3, m3, s3} = {l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_}

    {
      encode_channel(4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3),
      encode_channel(-1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3),
      encode_channel(-0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
    }
  end

  defp linear_channel(channel) do
    value = channel / 255

    if value <= 0.04045, do: value / 12.92, else: :math.pow((value + 0.055) / 1.055, 2.4)
  end

  defp encode_channel(linear) do
    linear = max(linear, 0.0)

    encoded =
      if linear <= 0.0031308, do: 12.92 * linear, else: 1.055 * :math.pow(linear, 1 / 2.4) - 0.055

    encoded * 255
  end

  defp cube_root(value) when value < 0, do: -:math.pow(-value, 1 / 3)
  defp cube_root(value), do: :math.pow(value, 1 / 3)

  @doc """
  Every outermost `color-mix(...)` expression in `css` with the selector of the rule
  that holds it, whitespace-collapsed, comments excluded, in source order.

  A nested `color-mix()` is part of its outer expression, so it is evaluated with it.
  This is what lets a test resolve every colour expression the stylesheet really
  uses, against each scope, instead of only the ones a pair happens to name.
  """
  @spec color_mix_expressions(String.t()) :: [{String.t(), String.t()}]
  def color_mix_expressions(css) do
    css
    |> rules()
    |> Enum.flat_map(fn rule ->
      selector = Enum.join(rule.selectors, ", ")
      rule.body |> collapse() |> scan_color_mix() |> Enum.map(&{selector, &1})
    end)
  end

  defp scan_color_mix(text) do
    with {position, length} <- :binary.match(text, "color-mix("),
         close when is_integer(close) <- closing_paren(text, position + length, 1) do
      rest_start = close + 1

      [
        binary_part(text, position, rest_start - position)
        | scan_color_mix(binary_part(text, rest_start, byte_size(text) - rest_start))
      ]
    else
      _none -> []
    end
  end

  # -- rule declarations --------------------------------------------------------

  @doc """
  The declarations of the rules for one selector, as `%{property => value}`.

  Every rule whose selector list contains `selector` exactly (after whitespace
  collapse, so a selector wrapped over several lines matches) contributes, found
  inside `@layer` and `@media` nesting too, and a later declaration replaces an
  earlier one of the same property. That is deliberately a merge and not "the first
  rule": a class such as `.sg-code` is named by a font rule and again by its colour
  rule, and the proof wants both. Comments are stripped; values are whitespace
  collapsed with no space just inside a parenthesis, so a multi-line `color-mix()`
  reads as one line. An absent selector returns `%{}`, so a caller has to assert the
  property it needs is there.
  """
  @spec rule_decls(String.t(), String.t()) :: %{String.t() => String.t()}
  def rule_decls(css, selector) do
    selector = collapse(selector)

    css
    |> rules()
    |> Enum.filter(&(selector in &1.selectors))
    |> Enum.reduce(%{}, &Map.merge(&2, property_map(&1.body)))
  end

  defp property_map(body) do
    body
    |> split_declarations(0, nil, [], [])
    |> Enum.flat_map(&parse_declaration/1)
    |> Map.new()
  end

  defp parse_declaration(declaration) do
    with [name, value] <- String.split(declaration, ":", parts: 2),
         name = String.trim(name),
         value = normalize_value(value),
         true <- name != "" and value != "" do
      [{name, value}]
    else
      _other -> []
    end
  end

  defp normalize_value(value) do
    value = collapse(value)
    value = Regex.replace(~r/\(\s+/, value, "(")
    Regex.replace(~r/\s+\)/, value, ")")
  end

  # Splits on `;` outside parentheses and quotes (a `;` inside `content: ";"` or a
  # data URL is part of the value).
  defp split_declarations(<<>>, _depth, _in_quote, current, parts) do
    Enum.reverse([finish_part(current) | parts])
  end

  defp split_declarations(<<byte, rest::binary>>, depth, in_quote, current, parts) do
    cond do
      in_quote == byte ->
        split_declarations(rest, depth, nil, [byte | current], parts)

      in_quote != nil ->
        split_declarations(rest, depth, in_quote, [byte | current], parts)

      byte in [?", ?'] ->
        split_declarations(rest, depth, byte, [byte | current], parts)

      byte == ?( ->
        split_declarations(rest, depth + 1, nil, [byte | current], parts)

      byte == ?) ->
        split_declarations(rest, depth - 1, nil, [byte | current], parts)

      byte == ?; and depth == 0 ->
        split_declarations(rest, 0, nil, [], [finish_part(current) | parts])

      true ->
        split_declarations(rest, depth, nil, [byte | current], parts)
    end
  end

  @doc """
  Every outermost colour call in `css` with the selector of the rule that holds it,
  whitespace-collapsed, comments excluded, in source order.

  The calls are `color-mix()` and `rgba()`, plus every other CSS colour function
  (`rgb()`, `hsl()`, `oklab()`, `oklch()`, `light-dark()` and the rest) so that one
  `resolve_color/2` cannot evaluate is still returned and fails closed instead of
  being skipped. A nested call is part of its outer expression, so `color-mix(in
  oklab, rgba(...) 50%, transparent)` is one entry. A call whose parentheses never
  balance is returned to the end of its rule, so it is reported as unresolved and
  never dropped.

  The selector is the rule's selector list joined with `", "`. Options:

    * `:selector_contains` - keep only rules with at least one selector that
      contains this text (for example `".sg-"`, the admin chrome in a stylesheet
      that also holds demo-owned rules).
  """
  @spec color_expressions(String.t(), keyword()) :: [{String.t(), String.t()}]
  def color_expressions(css, opts \\ []) do
    fragment = Keyword.get(opts, :selector_contains)

    css
    |> rules()
    |> Enum.filter(&selector_matches?(&1, fragment))
    |> Enum.flat_map(fn rule ->
      selector = Enum.join(rule.selectors, ", ")
      rule.body |> collapse() |> scan_color_calls() |> Enum.map(&{selector, &1})
    end)
  end

  defp selector_matches?(_rule, nil), do: true

  defp selector_matches?(rule, fragment),
    do: Enum.any?(rule.selectors, &String.contains?(&1, fragment))

  defp scan_color_calls(text) do
    pattern = ~r/\b(?:color-mix|rgba|rgb|hsla|hsl|hwb|oklab|oklch|lab|lch|light-dark|color)\(/

    case Regex.run(pattern, text, return: :index) do
      nil -> []
      [{start, length}] -> scan_call(text, start, length)
    end
  end

  defp scan_call(text, start, length) do
    case closing_paren(text, start + length, 1) do
      nil ->
        [binary_part(text, start, byte_size(text) - start)]

      close ->
        rest_start = close + 1

        [
          binary_part(text, start, rest_start - start)
          | scan_color_calls(binary_part(text, rest_start, byte_size(text) - rest_start))
        ]
    end
  end

  # -- unresolved report --------------------------------------------------------

  @doc """
  Evaluates `[{selector, value}]` or `[{selector, value, computed}]` and returns the
  entries that could not be resolved, as `%{selector, value, reason}` maps in the
  order given. `computed` (default `%{}`) supplies any `var()` left in `value`.
  """
  @spec unresolved_report([{String.t(), String.t()} | {String.t(), String.t(), map()}]) :: [
          %{selector: String.t(), value: String.t(), reason: String.t()}
        ]
  def unresolved_report(entries) do
    Enum.flat_map(entries, fn entry ->
      {selector, value, computed} = normalize_entry(entry)

      case resolve_color(value, computed) do
        {:ok, _rgba} -> []
        {:unresolved, reason} -> [%{selector: selector, value: value, reason: reason}]
      end
    end)
  end

  defp normalize_entry({selector, value}), do: {selector, value, %{}}
  defp normalize_entry({_selector, _value, _computed} = entry), do: entry

  @doc """
  `:ok` only when the unresolved selectors equal `allowlist` exactly (order and
  repeats ignored, since one selector can be unresolved in several scopes). A new
  unresolved colour fails, and so does a stale allowlist entry, so the allowlist
  can neither hide a hole nor outlive one.
  """
  @spec check_unresolved([%{selector: String.t()}], [String.t()]) ::
          :ok | {:error, :allowlist_mismatch}
  def check_unresolved(report, allowlist) do
    if report |> Enum.map(& &1.selector) |> Enum.uniq() |> Enum.sort() ==
         allowlist |> Enum.uniq() |> Enum.sort() do
      :ok
    else
      {:error, :allowlist_mismatch}
    end
  end

  # -- report -------------------------------------------------------------------

  @doc """
  A printable list of evaluated pairs, thinnest margin (ratio minus minimum) first.

  Each row is a map with `:id`, `:theme`, `:scope`, `:ratio` and `:minimum`; an
  optional `:exempt` reason marks a row that is computed and printed but not
  asserted. One line per row: `id theme scope ratio= min= margin=`.

  Options: `:exempt` is `:exclude` (default, exempt rows left out), `:only` (just
  the exempt rows, each with its reason) or `:include`. A row that was never
  evaluated (`ratio: nil`) raises, so an unresolved pair cannot be printed as if it
  had passed.
  """
  @spec report([map()], keyword()) :: String.t()
  def report(evaluations, opts \\ []) do
    mode = Keyword.get(opts, :exempt, :exclude)

    evaluations
    |> Enum.filter(&report_row?(&1, mode))
    |> Enum.sort_by(&margin/1)
    |> Enum.map_join("\n", &report_line/1)
  end

  defp report_row?(_row, :include), do: true
  defp report_row?(row, :exclude), do: is_nil(Map.get(row, :exempt))
  defp report_row?(row, :only), do: not is_nil(Map.get(row, :exempt))

  defp margin(%{ratio: ratio, minimum: minimum}) when is_number(ratio), do: ratio - minimum

  defp margin(row) do
    raise ArgumentError, "cannot report an unevaluated row: #{inspect(row)}"
  end

  defp report_line(row) do
    line =
      [
        row.id |> to_string() |> String.pad_trailing(20),
        row.theme |> to_string() |> String.pad_trailing(5),
        row |> Map.get(:scope) |> scope_label() |> String.pad_trailing(20),
        "ratio=#{fixed(row.ratio)}",
        "min=#{fixed(row.minimum)}",
        "margin=#{signed(margin(row))}"
      ]
      |> Enum.join(" ")

    case Map.get(row, :exempt) do
      nil -> line
      reason -> "#{line} [exempt: #{reason}]"
    end
  end

  defp fixed(number), do: :erlang.float_to_binary(number * 1.0, decimals: 2)
  defp signed(number) when number >= 0, do: "+" <> fixed(number)
  defp signed(number), do: fixed(number)

  # -- shared -------------------------------------------------------------------

  defp collapse(string), do: string |> String.replace(~r/\s+/, " ") |> String.trim()
end
