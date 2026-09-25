defmodule Sigra.Planning.Phase242ShiftLeftContractTest do
  use ExUnit.Case, async: true

  @public_install_files [
    "README.md",
    "guides/introduction/installation.md",
    "guides/introduction/getting-started.md",
    "guides/introduction/first-hour.md",
    "guides/recipes/companion-libs/accrue.md",
    "guides/recipes/companion-libs/lockspire.md",
    "guides/recipes/companion-libs/mailglass.md",
    "guides/recipes/companion-libs/relyra.md",
    "guides/recipes/companion-libs/rulestead.md",
    "guides/recipes/companion-libs/threadline.md"
  ]

  defp root, do: Path.expand("../../..", __DIR__)

  test "public install snippets use the bounded maintained line" do
    Enum.each(@public_install_files, fn relative_path ->
      content = root() |> Path.join(relative_path) |> File.read!()

      assert content =~ "{:sigra, \"~> 1.5.0\"}", "#{relative_path} lacks the supported tuple"
      refute content =~ "{:sigra, \"~> 1.4.0\"}", "#{relative_path} retains the stale tuple"
    end)
  end

  test "retired Hex mutation automation cannot be dispatched from this repository" do
    refute File.exists?(Path.join(root(), ".github/workflows/hex-remediate-phantom.yml"))
    refute File.exists?(Path.join(root(), "scripts/ci/prohibitions/p22-hex-remediation.test.mjs"))
  end
end
