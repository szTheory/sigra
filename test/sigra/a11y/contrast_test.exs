defmodule Sigra.A11y.ContrastTest do
  @moduledoc """
  AAA-flat unit tests for WCAG contrast ratio calculations.
  Proofs cover known fg/bg pairs, luminance math, error handling, and the
  thresholds locked by Phase 86 D-86-07.
  """
  use ExUnit.Case, async: true

  alias Sigra.A11y.Contrast

  # -- relative_luminance/1 --

  describe "relative_luminance/1" do
    test "black (#000000) has luminance 0.0" do
      assert Contrast.relative_luminance("#000000") == 0.0
    end

    test "white (#ffffff) has luminance 1.0" do
      assert Contrast.relative_luminance("#ffffff") == 1.0
    end

    test "mid-gray (#808080) is between 0 and 1 and approximately 0.216" do
      lum = Contrast.relative_luminance("#808080")
      assert lum > 0.0 and lum < 1.0
      assert_in_delta lum, 0.2159, 0.001
    end

    test "case-insensitive: #FFFFFF == #ffffff" do
      assert Contrast.relative_luminance("#FFFFFF") == Contrast.relative_luminance("#ffffff")
    end

    test "returns error tuple for malformed color" do
      assert {:error, _} = Contrast.relative_luminance("not-a-color")
      assert {:error, _} = Contrast.relative_luminance("#gggggg")
      assert {:error, _} = Contrast.relative_luminance("#12345")
    end
  end

  # -- ratio/2 --

  describe "ratio/2" do
    test "black on white is 21.0:1" do
      assert_in_delta Contrast.ratio("#000000", "#ffffff"), 21.0, 0.01
    end

    test "white on black is 21.0:1 (symmetric)" do
      assert_in_delta Contrast.ratio("#ffffff", "#000000"), 21.0, 0.01
    end

    test "same color on same color is 1.0:1" do
      assert_in_delta Contrast.ratio("#3f3f3f", "#3f3f3f"), 1.0, 0.01
    end

    test "#1d4ed8 (CTA blue-700) on #ffffff meets WCAG AA (>= 4.5)" do
      # D-86-07: CTA button color bumped to #1d4ed8 to clear 4.5:1 threshold
      ratio = Contrast.ratio("#1d4ed8", "#ffffff")
      assert ratio >= 4.5, "Expected #1d4ed8 on #ffffff to be >= 4.5:1, got #{ratio}"
    end

    test "#2563eb (old CTA blue-600) on #ffffff is below 4.5 normal-text threshold" do
      # D-86-07: old color was an AA edge case for normal text; new default removes it
      ratio = Contrast.ratio("#2563eb", "#ffffff")
      assert ratio < 4.5, "Expected #2563eb on #ffffff to be < 4.5:1 for normal text, got #{ratio}"
    end

    test "#dc2626 (red-emphasis) on #ffffff passes WCAG AA (>= 4.5)" do
      # D-86-07: lock red-emphasis color so 'brighter red' PRs fail the build
      ratio = Contrast.ratio("#dc2626", "#ffffff")
      assert ratio >= 4.5, "Expected #dc2626 on #ffffff to be >= 4.5:1, got #{ratio}"
    end

    test "returns error tuple when a color is malformed" do
      assert {:error, _} = Contrast.ratio("#not-valid", "#ffffff")
      assert {:error, _} = Contrast.ratio("#ffffff", "bad")
    end

    test "is symmetric: ratio(a, b) == ratio(b, a)" do
      r1 = Contrast.ratio("#1d4ed8", "#ffffff")
      r2 = Contrast.ratio("#ffffff", "#1d4ed8")
      assert_in_delta r1, r2, 0.001
    end
  end
end
