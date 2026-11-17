defmodule Sigra.Brand.InstallSnippetTest do
  @moduledoc """
  BCOPY-05 install-snippet contract.

  Every documented sigra dependency tuple (`{:sigra, "<requirement>"}`) in the
  README, the guides, `docs/` and the generator templates must use a
  three-segment requirement, and all of them must be identical.

  A two-segment requirement such as `~> 1.7` can still select the retired stray
  1.20.0 Hex release because retirement is advisory. Use the three-segment
  `~> 1.7.1` requirement to bound resolution below 1.8.0.

  The test checks SHAPE and cross-file EQUALITY, never a specific version. Phase
  263 sets the documented value to `~> 1.7.1`; a separate remote pull-request CI
  scratch-project check verifies it selects a non-retired release. This module
  remains green for any equal three-segment set and does not pin the value.

  There is no allow-list, exemption or per-file skip. If a doc ever carries a
  non-conforming tuple, the fix is the doc.

  The scan is non-vacuous by construction: the scan roots must exist and both
  the README and `guides/` must contribute at least one occurrence, so a
  renamed directory cannot turn this into a silent green. The pure helpers
  (`collect/1`, `violations/1`) are exercised against planted inputs so the
  suite proves it can go red.

  Pure filesystem; no database is touched. The repo root is resolved from
  `__DIR__`, never from the working directory.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)

  @why "A two-segment requirement such as ~> 1.7 can select retired 1.20.0; " <>
         "use a three-segment requirement such as ~> X.Y.Z."

  # A sigra dependency tuple with a quoted requirement. The ellipsis form used
  # in prose (a tuple whose second element is `...`) has no quote after the
  # comma and never matches. Regexes live in functions, not module attributes,
  # so they are not escaped into function bodies at compile time.
  defp snippet_regex, do: ~r/\{:sigra,\s*"([^"]*)"/

  # Anchored: exactly `~> digits.digits.digits`.
  defp three_segment_regex, do: ~r/\A~> \d+\.\d+\.\d+\z/

  # --- pure helpers -------------------------------------------------------

  # Quoted requirements found in a block of text, in order of appearance.
  defp scan_requirements(text) do
    snippet_regex()
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
  end

  # Every file the contract covers, as absolute paths under `root`.
  defp candidate_files(root) do
    readme = Path.join(root, "README.md")
    guides = Path.wildcard(Path.join(root, "guides/**/*.md"), match_dot: true)
    docs = Path.wildcard(Path.join(root, "docs/**/*.md"), match_dot: true)
    templates = Path.wildcard(Path.join(root, "priv/templates/**/*"), match_dot: true)

    [readme | guides ++ docs ++ templates]
    |> Enum.filter(&File.regular?/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Binary-looking files (anything that is not valid UTF-8) cannot carry a
  # documented snippet and are skipped.
  defp read_text(path) do
    contents = File.read!(path)
    if String.valid?(contents), do: {:ok, contents}, else: :skip
  end

  # `[{relative_path, requirement}]` for every occurrence under `root`.
  defp collect(root) do
    for path <- candidate_files(root),
        {:ok, text} <- [read_text(path)],
        requirement <- scan_requirements(text) do
      {Path.relative_to(path, root), requirement}
    end
  end

  # Findings for a `[{path, requirement}]` list: one `{:shape, path, req}` per
  # requirement that is not three-segment, plus one `{:mismatch, [reqs]}` when
  # the distinct requirements are not a single value.
  defp violations(pairs) do
    shape =
      for {path, requirement} <- pairs,
          not Regex.match?(three_segment_regex(), requirement),
          do: {:shape, path, requirement}

    distinct = pairs |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.sort()

    mismatch = if length(distinct) > 1, do: [{:mismatch, distinct}], else: []

    shape ++ mismatch
  end

  defp describe({:shape, path, requirement}),
    do: "#{path}: requirement #{inspect(requirement)} is not three-segment"

  defp describe({:mismatch, requirements}),
    do: "documented requirements disagree: #{Enum.map_join(requirements, ", ", &inspect/1)}"

  defp files_for(pairs, requirement) do
    pairs
    |> Enum.filter(fn {_path, req} -> req == requirement end)
    |> Enum.map_join("\n", fn {path, _req} -> "    #{path}" end)
  end

  # --- the contract over the real docs ------------------------------------

  describe "install snippets in the repository" do
    test "the scan cannot pass vacuously" do
      assert File.regular?(Path.join(@root, "README.md")),
             "README.md not found under #{@root}; the install-snippet scan has no anchor"

      assert File.dir?(Path.join(@root, "guides")),
             "guides/ not found under #{@root}; the install-snippet scan would pass vacuously"

      assert File.dir?(Path.join(@root, "priv/templates")),
             "priv/templates/ not found under #{@root}; the install-snippet scan would " <>
               "skip the generator templates"

      pairs = collect(@root)

      assert Enum.any?(pairs, fn {path, _req} -> path == "README.md" end),
             "README.md carries no {:sigra, \"...\"} snippet; the scan would no longer " <>
               "protect the first thing adopters copy"

      assert Enum.any?(pairs, fn {path, _req} -> String.starts_with?(path, "guides/") end),
             "no guide carries a {:sigra, \"...\"} snippet; the scan would pass vacuously"
    end

    test "every documented requirement is three-segment" do
      offenders =
        @root
        |> collect()
        |> violations()
        |> Enum.filter(&match?({:shape, _path, _requirement}, &1))

      assert offenders == [],
             """
             Install snippets must use a three-segment requirement.
             #{@why}

             #{Enum.map_join(offenders, "\n", &describe/1)}
             """
    end

    test "all documented requirements are identical" do
      pairs = collect(@root)
      distinct = pairs |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.sort()

      assert [_single] = distinct,
             """
             Every documented install snippet must carry the same requirement.
             Found #{length(distinct)} distinct requirements:

             #{Enum.map_join(distinct, "\n", fn req -> "  #{inspect(req)}\n#{files_for(pairs, req)}" end)}
             """
    end

    test "the real docs report no findings at all" do
      assert violations(collect(@root)) == []
    end
  end

  # --- positive controls: the checks can actually go red ------------------

  describe "positive controls" do
    test "a planted two-segment requirement is flagged" do
      planted = [{"planted/a.md", "~> 1.7"}, {"planted/b.md", "~> 1.7"}]

      assert violations(planted) == [
               {:shape, "planted/a.md", "~> 1.7"},
               {:shape, "planted/b.md", "~> 1.7"}
             ]
    end

    test "other loose or malformed requirement shapes are flagged" do
      for requirement <- [">= 1.5.0", "~> 1", "== 1.5.0", "~> 1.5.0-rc.1", "~>1.5.0", ""] do
        assert [{:shape, "planted/x.md", ^requirement}] =
                 violations([{"planted/x.md", requirement}]),
               "#{inspect(requirement)} should have been flagged as not three-segment"
      end
    end

    test "planted mismatching three-segment requirements are flagged as a disagreement" do
      planted = [{"planted/a.md", "~> 1.5.0"}, {"planted/b.md", "~> 1.7.0"}]

      assert violations(planted) == [{:mismatch, ["~> 1.5.0", "~> 1.7.0"]}]
    end

    test "an equal three-segment set, repeated across files, is clean" do
      planted = [{"planted/a.md", "~> 1.5.0"}, {"planted/b.md", "~> 1.5.0"}]

      assert violations(planted) == []
    end

    @tag :tmp_dir
    test "collect/1 finds a planted bad snippet in every scan root", %{tmp_dir: tmp_dir} do
      write!(tmp_dir, "README.md", "```elixir\n{:sigra, \"~> 1.5.0\"}\n```\n")
      write!(tmp_dir, "guides/deep/nested/page.md", "    {:sigra, \"~> 1.7\"},\n")
      write!(tmp_dir, "docs/reference.md", "{:sigra,\n \"~> 1.5.0\"}\n")
      write!(tmp_dir, "priv/templates/sigra.install/mix.exs.eex", "{:sigra, \"~> 2\"}\n")
      write!(tmp_dir, "priv/templates/sigra.install/.dotfile", "{:sigra, \"~> 1.9.9\"}\n")

      # Not valid UTF-8, so it cannot carry a snippet and must be skipped, not crash.
      write!(tmp_dir, "priv/templates/sigra.install/blob.bin", <<255, 254, 0, 1, 2, 253>>)

      # Outside the scan roots: must be ignored.
      write!(tmp_dir, "lib/ignored.md", "{:sigra, \"~> 9\"}\n")
      write!(tmp_dir, "CHANGELOG.md", "{:sigra, \"~> 9\"}\n")

      pairs = collect(tmp_dir)

      assert Enum.sort(pairs) ==
               Enum.sort([
                 {"README.md", "~> 1.5.0"},
                 {"guides/deep/nested/page.md", "~> 1.7"},
                 {"docs/reference.md", "~> 1.5.0"},
                 {"priv/templates/sigra.install/mix.exs.eex", "~> 2"},
                 {"priv/templates/sigra.install/.dotfile", "~> 1.9.9"}
               ])

      assert violations(pairs) == [
               {:shape, "guides/deep/nested/page.md", "~> 1.7"},
               {:shape, "priv/templates/sigra.install/mix.exs.eex", "~> 2"},
               {:mismatch, ["~> 1.5.0", "~> 1.7", "~> 1.9.9", "~> 2"]}
             ]
    end

    test "the ellipsis form used in prose is not collected" do
      assert scan_requirements("You are on an older **`{:sigra, ...}`** line.") == []
      assert scan_requirements("`{:sigra, ...}`") == []
      assert scan_requirements("{:sigra, path: \"../sigra\"}") == []
      assert scan_requirements("{:other, \"~> 1.5.0\"}") == []
    end

    test "any ellipsis line in the real troubleshooting guide is not collected" do
      path = Path.join(@root, "guides/introduction/troubleshooting-install.md")

      assert File.regular?(path), "troubleshooting-install.md not found at #{path}"

      ellipsis_lines =
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "{:sigra, ..."))

      for line <- ellipsis_lines do
        assert scan_requirements(line) == [],
               "ellipsis prose must not be read as an install snippet: #{line}"
      end
    end
  end

  defp write!(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end
end
