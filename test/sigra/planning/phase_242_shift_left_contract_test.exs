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

  defp section(content, start_marker, end_marker) do
    [_before, rest] = String.split(content, start_marker, parts: 2)
    [section | _after] = String.split(rest, end_marker, parts: 2)
    section
  end

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

  test "public safety guidance makes no unproven registry or documentation repair claim" do
    changelog = root() |> Path.join("CHANGELOG.md") |> File.read!()

    changelog_unreleased = section(changelog, "## Unreleased", "## [1.5.0]")

    troubleshooting =
      root()
      |> Path.join("guides/introduction/troubleshooting-install.md")
      |> File.read!()
      |> section("## Selecting the maintained dependency line", "## Upgrading between Sigra versions")

    assert String.trim(changelog_unreleased) ==
             """
             <!--
             MAINTAINER WARNING — Release Please inserts each generated version section BELOW this
             block, never into it. Anything written here must be folded by hand into the new version
             section while the Release PR is still open. If it is not, these notes ship inside a
             released package that still carries the \"Unreleased\" heading — and CHANGELOG.md is
             packaged into the Hex tarball, so the mistake is permanent for that release.
             -->

             - Installation guidance now uses `{:sigra, \"~> 1.5.0\"}` to select the maintained 1.5 line.
             - The bounded source guidance does not claim a registry retirement, HexDocs revert, resolver
               observation, or release outcome.
             """
             |> String.trim()

    assert String.trim(troubleshooting) ==
             """
             **Symptom:** Your `mix.lock` records a Sigra version outside the maintained 1.5 line.

             **Fix:** Use `{:sigra, \"~> 1.5.0\"}` in `mix.exs`. Remove or update only Sigra's stale
             lock entry through normal Mix dependency resolution, then run `mix deps.get` again.
             The three-segment requirement constrains Mix to `>= 1.5.0 and < 1.6.0`; it does not depend on
             registry metadata to rewrite an existing lockfile or resolver result.
             """
             |> String.trim()

    for {name, content} <- [changelog: changelog_unreleased, troubleshooting: troubleshooting] do
      refute Regex.match?(~r/1\.20\.0.{0,120}\bretir(?:ed|ement)\b/is, content),
             "#{name} claims an unproven retirement"

      refute Regex.match?(~r/\b(?:current|now)\b.{0,80}\bhexdocs\b/is, content),
             "#{name} claims an unproven HexDocs outcome"

      refute Regex.match?(~r/\bhexdocs\b.{0,40}\b(?:has|was|is|now|successfully)\b.{0,40}\brevert(?:ed)?\b/is, content),
             "#{name} claims an unproven HexDocs repair"

      refute Regex.match?(~r/\b(?:registry|resolver|lockfile)\b.{0,80}\b(?:repair(?:ed)?|fix(?:ed)?)\b/is, content),
             "#{name} claims an unproven resolver repair"

      refute Regex.match?(~r/\b(?:1\.5\.1|release)\b.{0,80}\b(?:publish(?:ed)?|complet(?:ed|ion)|cut)\b/is, content),
             "#{name} claims an unproven release outcome"

      refute Regex.match?(~r/\b1\.5\.1\b.{0,80}\brelease(?:d)?\b/is, content),
             "#{name} claims an unproven 1.5.1 release"
    end
  end
end
