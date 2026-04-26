defmodule Sigra.A11y.Contrast do
  @moduledoc """
  WCAG 2.2 contrast ratio calculator for deterministic accessibility assertions.

  Implements the W3C relative luminance formula and contrast-ratio formula exactly
  as specified in WCAG 2.2 Success Criterion 1.4.3 (Contrast — Minimum).

  ## Usage

      iex> Sigra.A11y.Contrast.ratio("#1d4ed8", "#ffffff")
      5.17...  # >= 4.5 passes WCAG AA for normal text

  ## References

  - https://www.w3.org/TR/WCAG22/#dfn-relative-luminance
  - https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio
  - https://www.w3.org/WAI/GL/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html
  """

  @doc """
  Returns the WCAG relative luminance for a hex color string.

  Accepts `#rrggbb` and `#RRGGBB` forms (6-digit hex with leading `#`).

  Returns a float in `[0.0, 1.0]` on success, or `{:error, reason}` when the
  color string is malformed.

  ## Examples

      iex> Sigra.A11y.Contrast.relative_luminance("#000000")
      0.0

      iex> Sigra.A11y.Contrast.relative_luminance("#ffffff")
      1.0

  """
  @spec relative_luminance(String.t()) :: float() | {:error, String.t()}
  def relative_luminance(hex) do
    case parse_hex(hex) do
      {:ok, r, g, b} ->
        rs = linearize(r / 255)
        gs = linearize(g / 255)
        bs = linearize(b / 255)
        0.2126 * rs + 0.7152 * gs + 0.0722 * bs

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Returns the WCAG contrast ratio between two hex colors.

  The ratio is always `>= 1.0`. Direction (fg vs bg) does not matter — the
  function returns the same value regardless of argument order.

  Returns `{:error, reason}` when either color is malformed.

  ## Thresholds (WCAG 2.2)

  | Standard | Normal text | Large text / bold |
  |----------|-------------|-------------------|
  | AA       | 4.5:1       | 3.0:1             |
  | AAA      | 7.0:1       | 4.5:1             |

  ## Examples

      iex> Sigra.A11y.Contrast.ratio("#000000", "#ffffff")
      21.0

      iex> Sigra.A11y.Contrast.ratio("#1d4ed8", "#ffffff")
      5.17...

  """
  @spec ratio(String.t(), String.t()) :: float() | {:error, String.t()}
  def ratio(fg, bg) do
    with l1 when is_float(l1) <- relative_luminance(fg),
         l2 when is_float(l2) <- relative_luminance(bg) do
      lighter = max(l1, l2)
      darker = min(l1, l2)
      (lighter + 0.05) / (darker + 0.05)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # -- Private helpers --

  # Parse `#rrggbb` or `#RRGGBB` into integer channel values.
  defp parse_hex("#" <> rest) when byte_size(rest) == 6 do
    case Integer.parse(rest, 16) do
      {value, ""} ->
        r = Bitwise.bsr(value, 16) |> Bitwise.band(0xFF)
        g = Bitwise.bsr(value, 8) |> Bitwise.band(0xFF)
        b = value |> Bitwise.band(0xFF)
        {:ok, r, g, b}

      _ ->
        {:error, "invalid hex digits in color: #{inspect("#" <> rest)}"}
    end
  end

  defp parse_hex(value) do
    {:error, "expected a 6-digit hex color like #rrggbb, got: #{inspect(value)}"}
  end

  # WCAG linearization: convert sRGB 0..1 to linear light value.
  # https://www.w3.org/TR/WCAG22/#dfn-relative-luminance
  defp linearize(c) when c <= 0.04045, do: c / 12.92
  defp linearize(c), do: :math.pow((c + 0.055) / 1.055, 2.4)
end
