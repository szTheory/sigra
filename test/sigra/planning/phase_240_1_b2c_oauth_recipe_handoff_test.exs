defmodule Sigra.Planning.Phase240_1B2cOauthRecipeHandoffTest do
  use ExUnit.Case, async: true

  @recipe "guides/recipes/b2c-alpha.md"
  @generator "lib/mix/tasks/sigra.gen.oauth.ex"

  test "the public B2C path states the dependency before OAuth generation" do
    recipe = File.read!(@recipe)

    assert ordered?(recipe, [
             "mix sigra.install --yes Accounts User users",
             "--no-admin --no-organizations --no-passkeys",
             "{:cloak_ecto, \"~> 1.3\"}",
             "mix deps.get",
             "mix sigra.gen.oauth --providers google"
           ])
  end

  test "the generator error and public recipe retain the same host-owned prerequisite" do
    recipe = File.read!(@recipe)
    generator = File.read!(@generator)

    for marker <- ["{:cloak_ecto, \"~> 1.3\"}", "mix deps.get"] do
      assert recipe =~ marker
      assert generator =~ marker
    end
  end

  defp ordered?(source, markers) do
    markers
    |> Enum.reduce_while(-1, fn marker, previous_index ->
      case :binary.match(source, marker) do
        {index, _length} when index > previous_index -> {:cont, index}
        _ -> {:halt, :out_of_order}
      end
    end)
    |> is_integer()
  end
end
