defmodule Sigra.Planning.Phase233LibraryEconomicsContractTest do
  use ExUnit.Case, async: true

  @default_workflow_path ".github/workflows/ci.yml"

  test "library execution universe is fail-closed and has one full-suite owner" do
    workflow = subject!()
    bodies = library_job_bodies!(workflow)

    full_suite_invocations =
      Enum.flat_map(bodies, fn {job_id, body} ->
        List.duplicate(job_id, length(Regex.scan(~r/MIX_ENV=test mix ci/, body)))
      end)

    assert length(full_suite_invocations) == 1,
           full_suite_owner_failure(full_suite_invocations)
  end

  test "derived library job bodies do not retain bare mix test invocations" do
    subject!()
    |> library_job_bodies!()
    |> Enum.each(fn {job_id, body} ->
      refute Regex.match?(~r/(?:^|\n)\s*(?:-\s+)?run:\s+mix test\b|(?:^|\n)\s*mix test\b/m, body),
             "#{job_id} must not retain a bare mix test command"
    end)
  end

  test "derived library job universe has unique non-empty bodies" do
    workflow = subject!()
    job_ids = library_job_ids(workflow)

    assert job_ids != [], "the parse broke, this is not a pass"
    assert length(job_ids) == MapSet.size(MapSet.new(job_ids)), "the parse duplicated a job id"

    Enum.each(job_ids, fn job_id ->
      assert String.trim(job_body(workflow, job_id)) != "",
             "the parse broke, this is not a pass for #{job_id}"
    end)
  end

  test "library job parser includes the complete hyphen-and-digit suffix grammar" do
    fixture_path = "test/fixtures/prohibitions/phase241-library-economics-two-owners.yml"
    workflow = File.read!(fixture_path)

    assert library_job_ids(workflow) == ["library_tests", "library_tests-canary_2"]
    assert job_body(workflow, "library_tests-canary_2") =~ "MIX_ENV=test mix ci"
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
    Regex.scan(~r/^  (library_tests[A-Za-z0-9_-]*):$/m, workflow, capture: :all_but_first)
    |> List.flatten()
  end

  defp library_job_bodies!(workflow) do
    job_ids = library_job_ids(workflow)

    assert job_ids != [], "the parse broke, this is not a pass"

    Map.new(job_ids, fn job_id -> {job_id, job_body(workflow, job_id)} end)
  end

  defp subject_path do
    case System.get_env("SIGRA_CONTRACT_SUBJECT") do
      nil -> @default_workflow_path
      "" -> @default_workflow_path
      path -> path
    end
  end

  defp subject! do
    path = subject_path()

    unless File.exists?(path) do
      flunk(
        "subject not found at #{path} — a missing subject is a broken run, never an absent violation"
      )
    end

    File.read!(path)
  end

  defp full_suite_owner_failure([]), do: "no owner of the full library suite was found"

  defp full_suite_owner_failure(full_suite_invocations) do
    phrase = Enum.join(["more than one", "owner of the full", "library suite"], " ")

    "#{phrase}: found #{length(full_suite_invocations)} full-suite invocations in job ids #{inspect(full_suite_invocations)}; expected exactly 1"
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
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [A-Za-z0-9_-]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end
end
