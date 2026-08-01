defmodule Sigra.Planning.Phase234PlaywrightInventoryContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"
  @config_path "test/example/priv/playwright/playwright.config.ts"

  test "admin_behavior explicitly owns both useful orphan specs on retry-zero chromium" do
    workflow = File.read!(@workflow_path)
    config = File.read!(@config_path)
    shard = job_body(workflow, "example_playwright_shard")
    admin_behavior = run_block(shard, "Run admin behavior browser truth")

    for spec <- ["admin-theme.spec.ts", "admin-coherence-sweep.spec.ts"] do
      assert occurrences(admin_behavior, "tests/#{spec}") == 1,
             "admin_behavior must name tests/#{spec} exactly once"
    end

    assert admin_behavior =~ "--project=chromium"
    assert admin_behavior =~ "--retries=0"
    assert shard =~ "uses: ./.github/actions/example-playwright-boot"
    assert shard =~ "seam: admin_behavior"
    assert config =~ "admin-theme"
    assert config =~ "admin-coherence-sweep"
  end

  test "the terminal Playwright aggregate remains the full-lifecycle guard" do
    terminal = job_body(File.read!(@workflow_path), "example_playwright_smoke")

    assert terminal =~ "name: Example Playwright smoke (full lifecycle)"
    assert terminal =~ "needs.example_playwright_shard.result"
    assert terminal =~ "exit 1"
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
