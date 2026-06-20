defmodule Sigra.Planning.Phase58OauthOa01CiContractTest do
  @moduledoc """
  **D-58-11** structural lock for **OA-01** / phase **58**: the library test lane
  in `.github/workflows/ci.yml` must keep a **Run library tests** step whose `run:`
  command is plain **`mix test`** (no OAuth-related `--exclude` flags).

  Phase 195 (TEST-01) partitioned the lane: the actual `mix test` run moved out of
  the `library_tests:` job (now a thin name-preserving aggregator) into the
  `library_tests_shard:` matrix worker, which runs `mix test --partitions 2`. The
  OA-01 contract (library tests run `mix test`, never excluding OAuth) is unchanged —
  this lock now anchors on the worker that performs the run. If the workflow
  intentionally changes, update this file deliberately.

  Anchors: `library_tests_shard`, `Run library tests`, `mix test`, boundary job
  `library_tests:` (the aggregator that follows the worker — used only to delimit
  the worker body; update if renamed).
  """

  use ExUnit.Case, async: true

  defp read_ci! do
    Path.expand("../../..", __DIR__)
    |> Path.join(".github/workflows/ci.yml")
    |> File.read!()
  end

  defp library_tests_shard_job(yml) do
    case String.split(yml, "library_tests_shard:", parts: 2) do
      [_, tail] ->
        case String.split(tail, "\n  library_tests:", parts: 2) do
          [body, _] -> body
          _ -> tail
        end

      _ ->
        flunk("expected library_tests_shard job in .github/workflows/ci.yml")
    end
  end

  test "58-01: library_tests shard worker runs mix test without oauth excludes" do
    yml = read_ci!()
    assert yml =~ "library_tests_shard:"

    job = library_tests_shard_job(yml)
    assert job =~ "Run library tests"
    # Phase 195: the run is the partitioned invocation `mix test --partitions 2`.
    assert job =~ "mix test --partitions 2"
    refute job =~ ~r/--exclude.*oauth/i
  end
end
