defmodule Sigra.Branding.ContrastTest do
  use ExUnit.Case, async: true

  alias Sigra.Branding.Contrast

  describe "relative_luminance/1 and contrast_ratio/2" do
    test "anchors at the WCAG extremes" do
      assert Contrast.relative_luminance("#000000") == 0.0
      assert Contrast.relative_luminance("#ffffff") == 1.0
      assert_in_delta Contrast.contrast_ratio("#000000", "#ffffff"), 21.0, 0.001
      assert_in_delta Contrast.contrast_ratio("#ffffff", "#ffffff"), 1.0, 0.001
    end

    test "is symmetric in its arguments" do
      assert Contrast.contrast_ratio("#c2410c", "#211f1c") ==
               Contrast.contrast_ratio("#211f1c", "#c2410c")
    end

    test "raises a helpful error on a malformed hex" do
      assert_raise ArgumentError, ~r/6-digit hex/, fn -> Contrast.relative_luminance("teal") end

      assert_raise ArgumentError, ~r/6-digit hex/, fn ->
        Contrast.relative_luminance("#ggg000")
      end
    end
  end

  describe "readable_foreground/1" do
    test "picks the legible extreme for light and dark backgrounds" do
      assert Contrast.readable_foreground("#ffffff") == "#000000"
      assert Contrast.readable_foreground("#000000") == "#ffffff"
      assert Contrast.readable_foreground("#1a2b5c") == "#ffffff"
    end
  end

  describe "fit_to_surface/3" do
    test "returns the accent byte-identical and unadjusted when it already passes" do
      # Brand fidelity wins wherever the colour is not actually broken -- an
      # untouched return is what tells the caller the host's paired foreground
      # is still valid.
      assert {"#ffd400", false} = Contrast.fit_to_surface("#ffd400", "#211f1c", 4.5)
    end

    test "lightens a too-dark accent on a dark surface until it meets the target" do
      {fitted, adjusted?} = Contrast.fit_to_surface("#1a2b5c", "#211f1c", 4.5)

      assert adjusted?
      assert fitted != "#1a2b5c"
      assert Contrast.contrast_ratio(fitted, "#211f1c") >= 4.5
    end

    test "darkens a too-light accent on a light surface" do
      {fitted, adjusted?} = Contrast.fit_to_surface("#fff3b0", "#ffffff", 4.5)

      assert adjusted?
      assert Contrast.contrast_ratio(fitted, "#ffffff") >= 4.5
      assert Contrast.relative_luminance(fitted) < Contrast.relative_luminance("#fff3b0")
    end

    test "preserves hue and saturation so the result still reads as the brand colour" do
      {fitted, true} = Contrast.fit_to_surface("#1a2b5c", "#211f1c", 4.5)

      {hue, saturation, _lightness} = Contrast.to_hsl("#1a2b5c")
      {fitted_hue, fitted_saturation, _} = Contrast.to_hsl(fitted)

      assert_in_delta fitted_hue, hue, 0.01
      assert_in_delta fitted_saturation, saturation, 0.05
    end

    test "returns a best-effort accent rather than raising when the target is unreachable" do
      # A mid-grey surface can make 4.5:1 genuinely impossible in either direction.
      # This runs on the pre-auth render path, so a best-effort colour beats an
      # exception on the login page.
      {fitted, adjusted?} = Contrast.fit_to_surface("#808080", "#808080", 21.0)

      assert adjusted?
      assert is_binary(fitted)
      assert fitted =~ ~r/^#[0-9a-f]{6}$/
    end

    test "is deterministic" do
      assert Contrast.fit_to_surface("#1a2b5c", "#211f1c", 4.5) ==
               Contrast.fit_to_surface("#1a2b5c", "#211f1c", 4.5)
    end
  end

  describe "hsl round-tripping" do
    test "survives a conversion round trip for representative hues" do
      for hex <- ~w(#c2410c #1a2b5c #ffd400 #0f766e #ffffff #000000 #808080) do
        {h, s, l} = Contrast.to_hsl(hex)
        assert Contrast.from_hsl(h, s, l) == hex
      end
    end
  end
end
