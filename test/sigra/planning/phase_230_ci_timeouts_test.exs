defmodule Sigra.Planning.Phase230CiTimeoutsTest do
  use ExUnit.Case, async: true

  # Phase 230 (FAST-07): enforces that every job in ci.yml declares exactly one
  # `timeout-minutes`, so a hung job fails in bounded time instead of burning
  # the 360-minute GitHub Actions default, and that the two D-20 pole values
  # (example_playwright_smoke / generated_admin_playwright_smoke) stay pinned.
  #
  # No YAML parser is added (mix.exs carries none) -- this is a File.read! plus
  # a per-job-block string walk, matching the phase_153 contract-test idiom.
  @ci ".github/workflows/ci.yml"

  @min_timeout 5
  @max_timeout 60

  # Splits ci.yml's `jobs:` section into {job_id, block} pairs by walking the
  # file after the top-level `jobs:` line and breaking right before every
  # 2-space-indented job-id header (e.g. "  fast_checks:"). A zero-width
  # lookahead means the split point does not consume the header line, so each
  # returned block starts with its own job-id line and runs through (but not
  # including) the next one. The `on:` block's own 2-space-indented keys
  # (workflow_dispatch, schedule, push, pull_request) are excluded because the
  # walk only begins after `jobs:`.
  defp job_blocks do
    content = File.read!(@ci)

    after_jobs =
      case String.split(content, ~r/\njobs:\s*\n/, parts: 2) do
        [_before, rest] ->
          rest

        _ ->
          flunk("could not find top-level `jobs:` line in #{@ci} — the parse broke, this is not a pass")
      end

    after_jobs
    |> String.split(~r/(?=^  [a-zA-Z0-9_-]+:\s*$)/m)
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.map(fn block ->
      [header | _] = String.split(block, "\n", parts: 2)
      id = header |> String.trim_leading() |> String.trim_trailing(":")
      {id, block}
    end)
  end

  # timeout-minutes lives at job-header indentation (4 spaces, sibling to
  # runs-on:/needs:/if:) — never nested deeper under strategy/matrix/services.
  defp timeout_declarations(block) do
    Regex.scan(~r/^    timeout-minutes:\s*(-?\d+)\s*$/m, block)
  end

  test "job walk finds at least 20 job blocks (non-vacuous)" do
    blocks = job_blocks()
    count = length(blocks)

    assert count >= 20,
           "job walk found #{count} jobs — the parse broke, this is not a pass"
  end

  test "every job declares exactly one timeout-minutes" do
    for {job_id, block} <- job_blocks() do
      declarations = timeout_declarations(block)

      assert length(declarations) == 1,
             "job `#{job_id}` has #{length(declarations)} timeout-minutes declarations " <>
               "at job-header indentation (expected exactly 1) — a job without a timeout " <>
               "can burn the 360-minute GitHub Actions default, and 22 declarations " <>
               "concentrated in one job would satisfy a file-wide count but not this " <>
               "per-block one"
    end
  end

  test "Playwright shard/terminal and generated-host timeout values are pinned" do
    blocks = Map.new(job_blocks())

    shard_block =
      blocks["example_playwright_shard"] ||
        flunk("example_playwright_shard job block not found")

    [[_, shard_value]] = timeout_declarations(shard_block)

    assert String.to_integer(shard_value) == 30,
           "example_playwright_shard's timeout-minutes is #{shard_value}, expected 30"

    terminal_block =
      blocks["example_playwright_smoke"] ||
        flunk("example_playwright_smoke terminal job block not found")

    [[_, terminal_value]] = timeout_declarations(terminal_block)
    assert String.to_integer(terminal_value) == 5

    generated_admin_block =
      blocks["generated_admin_playwright_smoke"] ||
        flunk(
          "generated_admin_playwright_smoke job block not found — cannot verify its timeout is 15"
        )

    [[_, generated_admin_value]] = timeout_declarations(generated_admin_block)

    assert String.to_integer(generated_admin_value) == 15,
           "generated_admin_playwright_smoke's timeout-minutes is #{generated_admin_value}, " <>
             "expected 15 — it replaces a prior value of 60, about 16x its 3.73m measured " <>
             "duration (230-EVIDENCE.md)"
  end

  test "every declared timeout-minutes value is a positive integer between #{@min_timeout} and #{@max_timeout}" do
    for {job_id, block} <- job_blocks() do
      for [_, raw_value] <- timeout_declarations(block) do
        value = String.to_integer(raw_value)

        assert value >= @min_timeout and value <= @max_timeout,
               "job `#{job_id}` declares timeout-minutes: #{value}, outside the sane band " <>
                 "[#{@min_timeout}, #{@max_timeout}] — a zero, a negative, or an accidental " <>
                 "360 (the GitHub Actions default) must be a named failure, not a silent pass"
      end
    end
  end
end
