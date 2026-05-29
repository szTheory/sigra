defmodule Sigra.Recipes.CompanionLibContractTest do
  @moduledoc """
  Contract fixture for companion-lib recipes (RCT-01).

  Asserts every recipe under guides/recipes/companion-libs/ carries
  required sections and freshness frontmatter.
  Fails loudly on missing markers AND on empty glob (D-05).
  """

  use ExUnit.Case, async: true

  @recipes_glob "guides/recipes/companion-libs/*.md"

  @required_markers [
    {"## Failure modes", "## Failure modes section"},
    {"## Non-goals", "## Non-goals section"},
    {"Sigra works fully standalone.", "standalone banner"},
    {"validated_against:", "validated_against: frontmatter"},
    {"last_validated:", "last_validated: frontmatter"}
  ]

  defp root, do: Path.expand("../../..", __DIR__)
  defp recipe_files, do: root() |> Path.join(@recipes_glob) |> Path.wildcard()

  test "companion-libs glob is non-empty (D-05 guard)" do
    assert recipe_files() != [],
           "#{@recipes_glob} matched no files — directory missing or glob wrong"
  end

  test "each companion-lib recipe carries all five required contract markers" do
    files = recipe_files()
    assert files != [], "glob returned no files"

    for path <- files do
      name = Path.basename(path)
      content = File.read!(path)

      for {marker, label} <- @required_markers do
        assert String.contains?(content, marker),
               "#{name}: missing #{label} (#{inspect(marker)})"
      end
    end
  end
end
