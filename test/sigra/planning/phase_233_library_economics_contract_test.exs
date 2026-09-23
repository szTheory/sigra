defmodule Sigra.Planning.Phase233LibraryEconomicsContractTest do
  use ExUnit.Case, async: true

  test "library execution universe is fail-closed and has one full-suite owner" do
    workflow = subject!()
    ids = library_job_ids(workflow)

    assert ids != [], "library_tests* parse found no jobs — the workflow parse broke, not a pass"

    bodies = Map.new(ids, &{&1, job_body(workflow, &1)})

    owners =
      Enum.flat_map(bodies, fn {job_id, body} ->
        if Regex.match?(~r/MIX_ENV=test\s+mix ci\b/, body), do: [job_id], else: []
      end)

    assert length(owners) == 1,
           "more than one owner of the full library suite: found #{length(owners)} owner(s): #{inspect(owners)}"

    Enum.each(bodies, fn {job_id, body} ->
      refute Regex.match?(~r/(?<![\w-])mix test\b/, body),
             "#{job_id} retains a bare mix test command"
    end)
  end

  test "ci-gate aggregates the derived library job universe" do
    workflow = subject!()
    ids = library_job_ids(workflow)

    assert ids != [], "library_tests* parse found no jobs — the workflow parse broke, not a pass"

    terminal_jobs =
      Enum.reject(ids, fn id ->
        Enum.any?(ids, fn parent_id ->
          parent_id != id and
            Regex.match?(~r/\b#{Regex.escape(id)}\b/, job_body(workflow, parent_id))
        end)
      end)

    gate = job_body(workflow, "ci-gate")
    missing = Enum.reject(terminal_jobs, &(gate =~ &1))

    assert missing == [],
           "ci-gate omits derived library_tests* job(s): #{inspect(missing)}"
  end

  test "documentation generation has exactly one derived library-lane owner" do
    workflow = subject!()
    ids = library_job_ids(workflow)

    assert ids != [], "library_tests* parse found no jobs — the workflow parse broke, not a pass"

    owners =
      Enum.filter(ids, fn id ->
        workflow |> job_body(id) |> then(&Regex.match?(~r/\bmix docs\b/, &1))
      end)

    assert length(owners) == 1,
           "documentation generation must have one library-lane owner; found #{inspect(owners)}"
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

  defp subject_path do
    case System.get_env("SIGRA_CONTRACT_SUBJECT") do
      nil -> ".github/workflows/ci.yml"
      "" -> ".github/workflows/ci.yml"
      path -> path
    end
  end

  defp subject! do
    path = subject_path()

    unless File.regular?(path) do
      flunk(
        "subject not found at #{path} — missing subject is a broken run, never an absent violation"
      )
    end

    File.read!(path)
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
