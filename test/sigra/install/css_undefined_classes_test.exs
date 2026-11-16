defmodule Sigra.Install.CssUndefinedClassesTest do
  @moduledoc """
  BGEN-04: every `sg-*` class emitted by library admin markup has a selector in
  the stylesheet copied into a generated host. The example app's extra CSS is
  not part of an installed host and cannot satisfy this contract.
  """

  use ExUnit.Case, async: true

  alias Sigra.Test.Brand.CssGap

  describe "gap/2 (pure)" do
    test "reports a used class that is not defined and ignores a defined-only class" do
      assert CssGap.gap(MapSet.new(["sg-a", "sg-b"]), MapSet.new(["sg-b", "sg-c"])) == ["sg-a"]
    end

    test "returns a sorted list and accepts plain lists" do
      assert CssGap.gap(["sg-z", "sg-a", "sg-m"], ["sg-m"]) == ["sg-a", "sg-z"]
    end

    test "an empty used set has an empty gap" do
      assert CssGap.gap([], ["sg-a"]) == []
    end
  end

  describe "the shipped admin CSS coverage" do
    test "markup and helper class strings are covered by the shipped stylesheet" do
      refute Enum.empty?(CssGap.used_classes())
      refute Enum.empty?(CssGap.defined_classes())

      assert MapSet.member?(CssGap.used_classes(), "sg-nav-link")
      assert MapSet.member?(CssGap.used_classes(), "sg-tabs__tab")
      assert MapSet.member?(CssGap.used_classes(), "sg-tabs__tab--active")
      assert MapSet.member?(CssGap.used_classes(), "sg-cmdk__dialog")
      assert MapSet.member?(CssGap.used_classes(), "sg-toast-region")
    end

    test "every class emitted by library and installer markup has a shipped selector" do
      assert :ok == CssGap.check_coverage(CssGap.used_classes(), CssGap.defined_classes())
    end

    test "used and defined sets share names, so both extractions use the same spelling" do
      shared = MapSet.intersection(CssGap.used_classes(), CssGap.defined_classes())

      refute Enum.empty?(shared),
             "no class is both emitted and defined: one extractor is reading the wrong text"
    end
  end

  describe "the check is able to fail" do
    test "a planted used class without a shipped selector reports the missing class" do
      planted = "sg-planted-new-class"
      used = MapSet.put(CssGap.used_classes(), planted)

      assert {:error, message} = CssGap.check_coverage(used, CssGap.defined_classes())
      assert message =~ planted
    end
  end
end
