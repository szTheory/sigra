defmodule Sigra.Planning.Phase247LanguageTwinBrowserLaneTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"
  @proof_path "scripts/ci/phase-247-language-twin-proof.sh"
  @spec_marker "tests/twin-offline.spec.ts"

  test "the twin proof has one explicit retry-zero Chromium CI owner" do
    workflow = File.read!(@workflow_path)
    shard = job_body(workflow, "example_playwright_shard")
    smoke = run_block(shard, "Run non-admin example browser smoke")
    terminal = job_body(workflow, "example_playwright_smoke")
    smoke_lines = smoke |> String.split("\n") |> Enum.map(&String.trim/1)

    assert occurrences(smoke, @spec_marker) == 1

    assert Enum.chunk_every(smoke_lines, 4, 1, :discard)
           |> Enum.any?(fn lines ->
             lines == [
               "npx playwright test \\",
               "tests/twin-offline.spec.ts \\",
               "--project=chromium \\",
               "--retries=0"
             ]
           end)

    assert shard =~ "uses: ./.github/actions/example-playwright-boot"
    assert shard =~ "seam: non_admin_smoke"
    assert terminal =~ "needs.example_playwright_shard.result"
    assert terminal =~ "exit 1"
  end

  test "the retained Phase 247 proof uses the same bounded Chromium invocation" do
    proof = File.read!(@proof_path)

    assert proof =~
             ~s(npm test -- twin-offline.spec.ts --project=chromium)

    refute proof =~ "waitForTimeout"
    refute proof =~ ~r/\bsleep\s+/
  end

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end

  defp run_block(job, name) do
    pattern =
      ~r/^      - name: #{Regex.escape(name)}\n(?<body>(?:(?!^      - name:|^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, job) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow step #{name}")
    end
  end

  defp occurrences(source, marker), do: source |> String.split(marker) |> length() |> Kernel.-(1)
end
