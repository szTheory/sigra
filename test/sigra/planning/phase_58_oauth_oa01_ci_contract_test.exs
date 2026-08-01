defmodule Sigra.Planning.Phase58OauthOa01CiContractTest do
  @moduledoc """
  **D-58-11** structural lock for **OA-01** / phase **58**: the library test lane
  in `.github/workflows/ci.yml` must keep the sole contributor-gate step whose
  `run:` command is **`MIX_ENV=test mix ci`** (no OAuth-related `--exclude` flags).

  Phase 234 (DX-01) made `library_tests_shard:` the sole full-suite owner, invoking
  the same contributor gate used locally. OA-01's no-OAuth-exclusion guarantee is
  unchanged — this lock anchors on that direct CI gate. If the workflow intentionally
  changes, update this file deliberately.

  Anchors: `library_tests_shard`, `Run contributor CI gate`, `MIX_ENV=test mix ci`,
  boundary job `library_tests:` (the aggregator that follows the worker — used only
  to delimit the worker body; update if renamed).
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

  test "58-01: library_tests shard worker runs contributor gate without oauth excludes" do
    yml = read_ci!()
    assert yml =~ "library_tests_shard:"

    job = library_tests_shard_job(yml)
    assert job =~ "Run contributor CI gate"
    # Phase 234: the worker owns the complete suite through the contributor alias;
    # OA-01 continues to prohibit excluding OAuth from that gate.
    assert job =~ "MIX_ENV=test mix ci"
    refute job =~ ~r/--exclude.*oauth/i
  end
end
