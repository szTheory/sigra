defmodule Sigra.Planning.Phase236RetryWrapperProhibitionTest do
  use ExUnit.Case, async: true

  # Phase 236 (GREEN-02, SC-4, D-27/D-28): the dead `PLAYWRIGHT_RETRIES: 1` env key at
  # `ci.yml:1460` had zero readers repo-wide outside `.planning/` prose and, if wired instead of
  # deleted, would have made the flagship generated-host parity job actually retry — the exact
  # retry-wrap GREEN-02/SC-4/ARCHITECTURE.md:275-277 prohibit. This is a PARSED contract, not a
  # bare grep count (standing constraint 1): it walks the job block and asserts the surviving
  # `env:` keys and the guard's only CI entry point (the `fast_checks` prohibition glob) survive
  # the deletion untouched.
  #
  # No YAML parser is added (mix.exs carries none) -- this is a File.read! plus a per-job-block
  # string walk, matching the phase_230_ci_timeouts_test.exs contract idiom.

  @ci ".github/workflows/ci.yml"
  @job_id "generated_admin_playwright_smoke"
  @guard_path "scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs"
  @fixture_path "test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts"
  @prohibitions_glob "scripts/ci/prohibitions/*.test.mjs"

  # Ported from phase_230_ci_timeouts_test.exs: split ci.yml's `jobs:` section into
  # {job_id, block} pairs by walking the file after the top-level `jobs:` line and breaking right
  # before every 2-space-indented job-id header.
  defp job_blocks do
    content = File.read!(@ci)

    after_jobs =
      case String.split(content, ~r/\njobs:\s*\n/, parts: 2) do
        [_before, rest] ->
          rest

        _ ->
          flunk(
            "could not find top-level `jobs:` line in #{@ci} — the parse broke, this is not a pass"
          )
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

  defp job_block(job_id) do
    case Enum.find(job_blocks(), fn {id, _block} -> id == job_id end) do
      {^job_id, block} ->
        block

      nil ->
        flunk("job `#{job_id}` not found in #{@ci} — the parse broke, this is not a pass")
    end
  end

  test "the job walk finds at least 20 job blocks (non-vacuity floor)" do
    blocks = job_blocks()
    count = length(blocks)

    assert count >= 20,
           "job walk found #{count} jobs — the parse broke, this is not a pass"
  end

  test "`PLAYWRIGHT_RETRIES` is entirely gone from ci.yml" do
    workflow = File.read!(@ci)

    refute workflow =~ "PLAYWRIGHT_RETRIES",
           "the dead PLAYWRIGHT_RETRIES env key must be deleted, not merely unwired — it had " <>
             "zero readers repo-wide outside .planning/ prose, and wiring it would make the " <>
             "flagship generated-host parity job actually retry, the exact retry-wrap GREEN-02/" <>
             "SC-4 prohibit"
  end

  test "the generated_admin_playwright_smoke job block is located and still declares env keys (non-vacuity floor)" do
    block = job_block(@job_id)

    assert block =~ ~r/^\s+env:\s*$/m,
           "the `#{@job_id}` step's `env:` block is gone entirely — a future edit that deletes " <>
             "the whole step, rather than the one dead PLAYWRIGHT_RETRIES key, must be caught " <>
             "instead of silently reported green"
  end

  test "the surviving env keys are unchanged" do
    block = job_block(@job_id)

    for key <- [
          "PGUSER: postgres",
          "PGPASSWORD: postgres",
          "PGHOST: localhost",
          "GITHUB_WORKSPACE:"
        ] do
      assert block =~ key,
             "expected `#{@job_id}` to still declare `#{key}` — only PLAYWRIGHT_RETRIES was " <>
               "supposed to be removed"
    end
  end

  test "the p17 guard and its committed known-bad fixture both exist on disk" do
    assert File.exists?(@guard_path), "#{@guard_path} must exist"
    assert File.exists?(@fixture_path), "#{@fixture_path} must exist"
  end

  test "the p17 guard's only route into CI — the fast_checks prohibition glob — survives" do
    workflow = File.read!(@ci)

    assert workflow =~ "node --test --test-reporter=tap #{@prohibitions_glob}",
           "the `#{@prohibitions_glob}` glob inside fast_checks is the guard's only route into " <>
             "CI (D-27) — without it, p17 exists on disk but never runs anywhere"
  end

  test "mix.exs's ci: alias never references scripts/ci/prohibitions" do
    mix_exs = File.read!("mix.exs")

    refute mix_exs =~ "scripts/ci/prohibitions",
           "the prohibition guards must stay reachable only through the fast_checks glob, " <>
             "never through mix ci (standing constraint 5) — mix.exs must not reference " <>
             "scripts/ci/prohibitions at all"
  end
end
