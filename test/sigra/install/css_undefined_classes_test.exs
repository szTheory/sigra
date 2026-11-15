defmodule Sigra.Install.CssUndefinedClassesTest do
  @moduledoc """
  BGEN-04: the shipped-CSS gap is a measured, shrink-only baseline.

  Library admin markup and the generated admin shell emit `sg-*` classes that the
  one stylesheet the installer copies (`priv/templates/sigra.install/admin/sigra_admin.css`)
  does not define. Today they are defined only in the example application's
  `app.css`, which a generated host does not have, or nowhere. Moving all of that
  styling into the shipped file is a large shipped-byte change that does not belong
  in this phase, so the gap is recorded in `test/fixtures/brand/css-undefined-classes.txt`
  and held in two directions:

    * the undefined set may not grow (a new class must be defined in the shipped CSS);
    * a baseline entry the shipped CSS now defines must be removed.

  The controls plant a class into the used set and a defined class into the baseline,
  in memory, and prove each check can fail. A clean run of a guard proves nothing until
  the guard has been seen to fire.
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

  describe "the measurement is not vacuous" do
    test "markup emits classes and the shipped CSS defines classes" do
      refute Enum.empty?(CssGap.used_classes())
      refute Enum.empty?(CssGap.defined_classes())
    end

    test "used and defined sets share names, so both extractions use the same spelling" do
      shared = MapSet.intersection(CssGap.used_classes(), CssGap.defined_classes())

      refute Enum.empty?(shared),
             "no class is both emitted and defined: one extractor is reading the wrong text"
    end

    # Drop this assertion together with the baseline once the shipped CSS defines every
    # emitted class. Until then an empty baseline with a non-empty gap fails growth anyway,
    # and an empty baseline with an empty gap would mean the extraction has stopped seeing
    # anything.
    test "the baseline lists at least one class" do
      refute Enum.empty?(CssGap.baseline()),
             "#{CssGap.baseline_path()} has no class lines; was the gap really closed?"
    end

    test "the baseline is sorted, duplicate-free and holds only sg- class names" do
      baseline = CssGap.baseline()

      assert baseline == baseline |> Enum.uniq() |> Enum.sort(),
             "#{CssGap.baseline_path()} must list each class once, sorted"

      assert Enum.all?(baseline, &String.match?(&1, ~r/\Asg-[A-Za-z0-9_-]+\z/)),
             "#{CssGap.baseline_path()} may only list sg-* class names, one per line"
    end
  end

  describe "the shipped-CSS gap" do
    test "does not grow: every undefined class is already in the baseline" do
      assert_ok(CssGap.check_growth(CssGap.baseline(), CssGap.undefined_classes()))
    end

    test "only shrinks: no baseline entry has become defined in the shipped CSS" do
      assert_ok(CssGap.check_stale(CssGap.baseline(), CssGap.undefined_classes()))
    end
  end

  describe "controls: the checks can fail" do
    # The controls start from a baseline that is exactly right today (the real undefined
    # set), not from the committed file, so they stay able to fail whatever that file says.
    test "a class emitted by markup but defined nowhere makes the growth check fail" do
      planted = "sg-planted-new-class"
      exact_baseline = CssGap.undefined_classes()
      used = MapSet.put(CssGap.used_classes(), planted)
      undefined = CssGap.gap(used, CssGap.defined_classes())

      assert planted in undefined
      assert CssGap.check_growth(exact_baseline, CssGap.undefined_classes()) == :ok

      assert {:error, message} = CssGap.check_growth(exact_baseline, undefined)
      assert message =~ "grew by 1 class(es): #{planted}"
    end

    test "a class already defined in the shipped CSS, planted into the baseline, makes the stale check fail" do
      exact_baseline = CssGap.undefined_classes()
      defined = Enum.min(CssGap.defined_classes())

      assert CssGap.check_stale(exact_baseline, CssGap.undefined_classes()) == :ok

      assert {:error, message} =
               CssGap.check_stale([defined | exact_baseline], CssGap.undefined_classes())

      assert message =~ "remove from baseline"
      assert message =~ defined
    end

    test "an in-memory baseline with one real entry removed reports exactly that class as growth" do
      [dropped | rest] = CssGap.undefined_classes()

      assert {:error, message} = CssGap.check_growth(rest, CssGap.undefined_classes())
      assert message =~ "grew by 1 class(es): #{dropped}"
    end
  end

  defp assert_ok(:ok), do: :ok
  defp assert_ok({:error, message}), do: flunk(message)
end
