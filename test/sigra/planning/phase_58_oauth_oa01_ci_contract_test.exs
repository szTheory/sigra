defmodule Sigra.Planning.Phase58OauthOa01CiContractTest do
  @moduledoc """
  **D-58-11** structural lock for **OA-01** / phase **58**: the `library_tests` job
  in `.github/workflows/ci.yml` must keep a **Run library tests** step whose `run:`
  line is plain **`mix test`** (no OAuth-related `--exclude` flags). If the
  workflow intentionally changes, update this file deliberately.

  Anchors: `library_tests`, `Run library tests`, `run: mix test`, boundary job
  `example_unit_smoke` (used only to delimit the job body — update if renamed).
  """

  use ExUnit.Case, async: true

  defp read_ci! do
    Path.expand("../../..", __DIR__)
    |> Path.join(".github/workflows/ci.yml")
    |> File.read!()
  end

  defp library_tests_job(yml) do
    case String.split(yml, "library_tests:", parts: 2) do
      [_, tail] ->
        case String.split(tail, "\n  example_unit_smoke:", parts: 2) do
          [body, _] -> body
          _ -> tail
        end

      _ ->
        flunk("expected library_tests job in .github/workflows/ci.yml")
    end
  end

  test "58-01: library_tests job runs plain mix test without oauth excludes" do
    yml = read_ci!()
    assert yml =~ "library_tests:"

    job = library_tests_job(yml)
    assert job =~ "Run library tests"
    assert job =~ "run: mix test"
    refute job =~ ~r/--exclude.*oauth/i
  end
end
