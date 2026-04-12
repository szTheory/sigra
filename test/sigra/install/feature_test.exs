defmodule Sigra.Install.FeatureTest do
  use ExUnit.Case, async: true

  defmodule TestFeature do
    @behaviour Sigra.Install.Feature

    @impl true
    def enabled?(_opts), do: true

    @impl true
    def files(_binding), do: []

    @impl true
    def injections(_binding), do: []

    @impl true
    def migrations(_binding), do: []

    @impl true
    def post_instructions(_binding, _report), do: []
  end

  test "behaviour defines exactly 5 @callbacks with correct arities" do
    callbacks = Sigra.Install.Feature.behaviour_info(:callbacks)
    assert length(callbacks) == 5

    names = Enum.sort(callbacks)

    assert names == [
             {:enabled?, 1},
             {:files, 1},
             {:injections, 1},
             {:migrations, 1},
             {:post_instructions, 2}
           ]
  end

  test "a minimal implementation compiles and all callbacks return sane values" do
    assert TestFeature.enabled?([]) == true
    assert TestFeature.files([]) == []
    assert TestFeature.injections([]) == []
    assert TestFeature.migrations([]) == []
    assert TestFeature.post_instructions([], %Sigra.Install.Report{}) == []
  end
end
