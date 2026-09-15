defmodule Sigra.Branding.Contrast do
  @moduledoc """
  Colour maths for resolving brand tokens against a theme surface.

  Sigra uses this to derive a dark-theme accent when a host has supplied only a
  light-theme one. A host accent is almost always chosen against the host's
  *light* surface; reusing it verbatim against a dark surface is how a perfectly
  legible brand colour turns into an illegible one.

  The rule this module exists to serve: **keep the host's colour when it already
  works, and change it as little as possible when it does not.** A derived colour
  that no longer reads as the brand is its own kind of wrong, so adjustment moves
  lightness only and leaves hue and saturation alone.

  All functions take and return 6-digit hex strings (`"#rrggbb"`), matching the
  token format `Sigra.Branding.Profile` validates.
  """

  @typedoc "A 6-digit hex colour string, e.g. `\"#c2410c\"`."
  @type hex :: String.t()

  @doc """
  WCAG contrast target for a derived accent against its surface.

  4.5:1 is the WCAG AA threshold for normal-size text. The accent is the one
  token that can legitimately appear *as* text (links, inline emphasis) as well
  as behind it (button fills), so it is held to the text-grade threshold rather
  than the 3:1 non-text threshold. Holding it to the lower bar would leave an
  accent that is fine as a button fill and unreadable as a link.
  """
  @spec accent_contrast_target() :: float()
  def accent_contrast_target, do: 4.5

  @doc """
  Relative luminance of a colour, per the WCAG 2.x definition.

  Returns a float in `0.0..1.0`. Raises `ArgumentError` on a malformed hex.
  """
  @spec relative_luminance(hex()) :: float()
  def relative_luminance(hex) do
    {r, g, b} = to_rgb(hex)
    0.2126 * channel_luminance(r) + 0.7152 * channel_luminance(g) + 0.0722 * channel_luminance(b)
  end

  @doc """
  Contrast ratio between two colours, per WCAG 2.x.

  Returns a float in `1.0..21.0`. The order of the arguments does not matter.
  """
  @spec contrast_ratio(hex(), hex()) :: float()
  def contrast_ratio(a, b) do
    la = relative_luminance(a)
    lb = relative_luminance(b)
    {lighter, darker} = if la >= lb, do: {la, lb}, else: {lb, la}
    (lighter + 0.05) / (darker + 0.05)
  end

  @doc """
  Returns whichever of black or white contrasts better against `hex`.

  Used to re-derive `accent_foreground` when an accent has been adjusted and the
  host's original foreground may no longer be the legible choice.
  """
  @spec readable_foreground(hex()) :: hex()
  def readable_foreground(hex) do
    if contrast_ratio(hex, "#000000") >= contrast_ratio(hex, "#ffffff") do
      "#000000"
    else
      "#ffffff"
    end
  end

  @doc """
  Adjusts `accent` just enough to meet `target` contrast against `surface`.

  Returns `{hex, adjusted?}`. When the accent already meets the target it is
  returned **byte-identical and `adjusted?` is `false`** — the caller uses that
  flag to decide whether the host's paired `accent_foreground` is still valid.

  Adjustment walks lightness in small steps, away from the surface (lighter on a
  dark surface, darker on a light one), stopping at the first step that meets the
  target. Hue and saturation are preserved so the result still reads as the brand
  colour. If no step reaches the target — a fully saturated mid-hue against a
  mid-grey surface can be genuinely impossible — the best-contrast candidate found
  is returned rather than failing, because a best-effort accent is more useful to
  a host than a raised exception on a pre-auth render path.

  Deterministic and allocation-light: this runs on the login render path.
  """
  @spec fit_to_surface(hex(), hex(), float()) :: {hex(), boolean()}
  def fit_to_surface(accent, surface, target \\ 4.5) do
    if contrast_ratio(accent, surface) >= target do
      {accent, false}
    else
      {h, s, l} = to_hsl(accent)
      direction = if relative_luminance(surface) < 0.5, do: 1.0, else: -1.0

      case search_lightness(h, s, l, direction, surface, target) do
        {:ok, hex} -> {hex, true}
        {:best, hex} -> {hex, true}
      end
    end
  end

  # Walks lightness in 1% steps away from the surface, returning the first
  # candidate that meets the target. Tracks the best candidate seen so a
  # genuinely unreachable target still yields the most legible option.
  defp search_lightness(h, s, l, direction, surface, target) do
    context = %{h: h, s: s, l: l, direction: direction, surface: surface, target: target}

    1..100
    |> Enum.reduce_while({nil, 0.0}, &step_lightness(&1, &2, context))
    |> case do
      {:found, hex} -> {:ok, hex}
      {nil, _ratio} -> {:best, from_hsl(h, s, l)}
      {hex, _ratio} -> {:best, hex}
    end
  end

  defp step_lightness(step, acc, context) do
    candidate_l = context.l + context.direction * step / 100.0

    if candidate_l < 0.0 or candidate_l > 1.0 do
      {:halt, acc}
    else
      from_hsl(context.h, context.s, candidate_l)
      |> evaluate_candidate(acc, context)
    end
  end

  defp evaluate_candidate(candidate, {_best_hex, best_ratio} = acc, context) do
    ratio = contrast_ratio(candidate, context.surface)

    cond do
      ratio >= context.target -> {:halt, {:found, candidate}}
      ratio > best_ratio -> {:cont, {candidate, ratio}}
      true -> {:cont, acc}
    end
  end

  @doc "Parses a 6-digit hex string into an `{r, g, b}` tuple of `0..255` integers."
  @spec to_rgb(hex()) :: {integer(), integer(), integer()}
  def to_rgb("#" <> rest) when byte_size(rest) == 6 do
    <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>> = rest
    {parse_hex_pair(r), parse_hex_pair(g), parse_hex_pair(b)}
  end

  def to_rgb(other) do
    raise ArgumentError, "expected a 6-digit hex colour like \"#c2410c\", got: #{inspect(other)}"
  end

  @doc "Formats an `{r, g, b}` tuple of `0..255` integers as a lowercase hex string."
  @spec from_rgb({integer(), integer(), integer()}) :: hex()
  def from_rgb({r, g, b}) do
    "#" <>
      pad_hex(clamp_byte(r)) <>
      pad_hex(clamp_byte(g)) <>
      pad_hex(clamp_byte(b))
  end

  @doc "Converts a hex colour to `{hue, saturation, lightness}`, each in `0.0..1.0`."
  @spec to_hsl(hex()) :: {float(), float(), float()}
  def to_hsl(hex) do
    {r255, g255, b255} = to_rgb(hex)
    r = r255 / 255.0
    g = g255 / 255.0
    b = b255 / 255.0

    max = Enum.max([r, g, b])
    min = Enum.min([r, g, b])
    delta = max - min
    l = (max + min) / 2.0

    if delta == 0.0 do
      {0.0, 0.0, l}
    else
      s = delta / (1.0 - abs(2.0 * l - 1.0))

      h =
        cond do
          max == r -> 60.0 * :math.fmod((g - b) / delta, 6.0)
          max == g -> 60.0 * ((b - r) / delta + 2.0)
          true -> 60.0 * ((r - g) / delta + 4.0)
        end

      h = if h < 0.0, do: h + 360.0, else: h
      {h / 360.0, s, l}
    end
  end

  @doc "Converts `{hue, saturation, lightness}` (each `0.0..1.0`) back to a hex colour."
  @spec from_hsl(float(), float(), float()) :: hex()
  def from_hsl(h, s, l) do
    h360 = h * 360.0
    c = (1.0 - abs(2.0 * l - 1.0)) * s
    x = c * (1.0 - abs(:math.fmod(h360 / 60.0, 2.0) - 1.0))
    m = l - c / 2.0

    {r1, g1, b1} =
      cond do
        h360 < 60.0 -> {c, x, 0.0}
        h360 < 120.0 -> {x, c, 0.0}
        h360 < 180.0 -> {0.0, c, x}
        h360 < 240.0 -> {0.0, x, c}
        h360 < 300.0 -> {x, 0.0, c}
        true -> {c, 0.0, x}
      end

    from_rgb({round((r1 + m) * 255), round((g1 + m) * 255), round((b1 + m) * 255)})
  end

  defp channel_luminance(value) do
    c = value / 255.0
    if c <= 0.03928, do: c / 12.92, else: :math.pow((c + 0.055) / 1.055, 2.4)
  end

  defp parse_hex_pair(pair) do
    case Integer.parse(pair, 16) do
      {value, ""} ->
        value

      _ ->
        raise ArgumentError, "expected a 6-digit hex colour, got an invalid pair: #{inspect(pair)}"
    end
  end

  defp clamp_byte(value) when value < 0, do: 0
  defp clamp_byte(value) when value > 255, do: 255
  defp clamp_byte(value), do: value

  defp pad_hex(value) do
    value
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(2, "0")
  end
end
