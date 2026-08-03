defmodule Sigra.Planning.Phase233LibraryEconomicsContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"
  @library_jobs ["library_tests_shard", "library_tests", "library_tests_dep_off"]

  test "library execution universe is fail-closed and has one full-suite owner" do
    workflow = File.read!(@workflow_path)

    assert library_job_ids(workflow) == @library_jobs

    bodies = Map.new(@library_jobs, &{&1, job_body(workflow, &1)})
    shard = Map.fetch!(bodies, "library_tests_shard")

    assert length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1
    assert length(Regex.scan(~r/MIX_ENV=test mix ci/, Enum.join(Map.values(bodies), "\n"))) == 1

    Enum.each(bodies, fn {job_id, body} ->
      refute body =~ "mix test", "#{job_id} must not retain a second test command"
    end)

    refute workflow =~ "library_tests_scaffold:"
  end

  test "protected Library tests aggregation preserves the sole owner and ci-gate link" do
    workflow = File.read!(@workflow_path)
    aggregate = job_body(workflow, "library_tests")
    ci_gate = job_body(workflow, "ci-gate")

    assert aggregate =~ "name: Library tests"
    assert aggregate =~ "needs: [library_tests_shard]"
    assert aggregate =~ "if: always()"
    assert aggregate =~ "SHARD: ${{ needs.library_tests_shard.result }}"
    assert aggregate =~ "\"$SHARD\" != \"success\""
    assert ci_gate =~ "- library_tests"
    assert ci_gate =~ "- library_tests_dep_off"
  end

  test "dep-off lane remains the docs owner but no longer duplicates alias work" do
    dep_off = job_body(File.read!(@workflow_path), "library_tests_dep_off")

    assert dep_off =~ "mix docs --warnings-as-errors"
    refute dep_off =~ "mix deps.unlock threadline"
    refute dep_off =~ "mix deps.clean threadline"
    refute dep_off =~ "mix compile --warnings-as-errors --no-deps-check"
    refute dep_off =~ "mix test --only threadline_guard --no-deps-check"
  end

  test "scaffold modules have one explicit ci.install_golden receiver and are excluded from broad test" do
    mix_exs = File.read!("mix.exs")
    expected_paths = canonical_scaffold_paths()
    live_paths = live_scaffold_paths()

    assert live_paths == expected_paths,
           "canonical scaffold paths must equal the live @tag :scaffold universe"

    assert ci_legs(mix_exs) == [
             "format --check-formatted",
             "deps.get --check-locked",
             "deps.unlock --check-unused",
             "compile --warnings-as-errors",
             "test --exclude scaffold",
             "ci.install_golden",
             "sigra.dep_off"
           ]

    receiver_paths = install_golden_paths(mix_exs)

    assert receiver_paths == expected_paths,
           "ci.install_golden must run every live scaffold module exactly once"

    assert length(receiver_paths) == MapSet.size(MapSet.new(receiver_paths)),
           "ci.install_golden must not duplicate scaffold paths"
  end

  defp library_job_ids(workflow) do
    Regex.scan(~r/^  (library_tests(?:_[a-z_]+)?):$/m, workflow, capture: :all_but_first)
    |> List.flatten()
  end

  defp ci_legs(mix_exs) do
    mix_exs
    |> alias_body("ci")
    |> quoted_values()
  end

  defp install_golden_paths(mix_exs) do
    mix_exs
    |> alias_body("ci.install_golden")
    |> quoted_values()
    |> Enum.flat_map(fn command ->
      command
      |> String.replace_prefix("test ", "")
      |> String.split(" ", trim: true)
      |> Enum.filter(&String.ends_with?(&1, "_test.exs"))
    end)
  end

  defp alias_body(mix_exs, alias_name) do
    escaped_name = Regex.escape(alias_name)

    case Regex.run(~r/"?#{escaped_name}"?:\s*\[(.*?)\]/s, mix_exs) do
      [_, body] -> body
      _ -> flunk("missing #{alias_name} alias")
    end
  end

  defp quoted_values(body) do
    Regex.scan(~r/"([^"]+)"/, body, capture: :all_but_first)
    |> List.flatten()
  end

  defp canonical_scaffold_paths do
    [_, scaffold_set] =
      Regex.run(
        ~r/@scaffold_paths\s+MapSet\.new\(\[(.*?)\]\)/s,
        File.read!("test/support/ci/library_test_partitions.exs")
      )

    Regex.scan(~r/"(test\/[^\"]+_test\.exs)"/, scaffold_set, capture: :all_but_first)
    |> List.flatten()
    |> Enum.sort()
  end

  defp live_scaffold_paths do
    "test/**/*_test.exs"
    |> Path.wildcard()
    |> Enum.filter(fn path -> File.read!(path) =~ ~r/^\s*@moduletag\s+:scaffold\b/m end)
    |> Enum.sort()
  end

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end
end
