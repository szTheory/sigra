defmodule Sigra.Planning.Phase222ReleaseLaneHardeningTest do
  @moduledoc """
  Nyquist validation for Phase 222 Plan 02 (HARD-01/HARD-02): the shared
  loud-signal mechanism (D-07) and its two consumer jobs.

  Structural assertions only -- proves the workflow YAML shape (gating,
  permissions, not-in-ci-gate posture) without dispatching a real workflow
  run. The red-probe (a forced failure actually opening a GitHub Issue) is a
  documented manual/operator step (see 222-VALIDATION.md), not covered here.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "222-01: notify_release_lane_rot (ci.yml) gates on a red ci-gate on non-PR events, with job-level issues: write, and is absent from ci-gate.needs" do
    ci = read!(".github/workflows/ci.yml")

    assert ci =~ ~r/^  notify_release_lane_rot:$/m
    assert ci =~ "needs: [ci-gate]"

    assert ci =~
             "if: always() && github.event_name != 'pull_request' && needs.ci-gate.result == 'failure'"

    # Job-level issues: write override (ci.yml workflow default is contents: read).
    notify_job =
      ci
      |> String.split(~r/^  notify_release_lane_rot:$/m)
      |> Enum.at(1)
      |> String.split(~r/^  [a-zA-Z_][a-zA-Z0-9_-]*:$/m)
      |> Enum.at(0)

    assert notify_job =~ "permissions:"
    assert notify_job =~ "issues: write"
    assert notify_job =~ "GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}"
    assert notify_job =~ "bash scripts/ci/notify-failure-issue.sh"

    # Not-in-ci-gate posture: notify_release_lane_rot must never appear inside
    # ci-gate's own `needs:` list (that block ends at the `if: always()` line).
    ci_gate_block =
      ci
      |> String.split(~r/^  ci-gate:$/m)
      |> Enum.at(1)
      |> String.split(~r/^    if: always\(\)$/m)
      |> Enum.at(0)

    refute ci_gate_block =~ "notify_release_lane_rot"
  end

  test "222-02: both workflows invoke the shared scripts/ci/notify-failure-issue.sh" do
    ci = read!(".github/workflows/ci.yml")
    release_please = read!(".github/workflows/release-please.yml")

    assert ci =~ "bash scripts/ci/notify-failure-issue.sh"
    assert release_please =~ "bash scripts/ci/notify-failure-issue.sh"
  end

  test "222-03: notify-release-failure (release-please.yml) aggregates gate-ci-green/publish-hex failure under the release_created guard, and workflow-level issues: write is preserved" do
    release_please = read!(".github/workflows/release-please.yml")

    assert release_please =~ ~r/^  notify-release-failure:$/m
    assert release_please =~ "needs: [release-please, gate-ci-green, publish-hex]"
    assert release_please =~ "needs.release-please.outputs.release_created == 'true'"
    assert release_please =~ "needs.gate-ci-green.result == 'failure'"
    assert release_please =~ "needs.publish-hex.result == 'failure'"

    # Workflow-level issues: write (release-please.yml:22) is unchanged, still present.
    assert release_please =~ ~r/^permissions:$/m
    assert release_please =~ ~r/^  issues: write$/m
  end

  test "222-04: MAINTAINING.md documents the release-lane rot signals & recovery runbook (HARD-01/HARD-02)" do
    maintaining = read!("MAINTAINING.md")

    assert maintaining =~ "### Release-lane rot signals & recovery (HARD-01/HARD-02)"

    # hex-publish.yml manual dispatch command with all three inputs.
    assert maintaining =~ ~s|gh workflow run "Hex publish (manual recovery)"|
    assert maintaining =~ "-f tag=<tag>"
    assert maintaining =~ "-f release_version=<version>"
    assert maintaining =~ "-f dry_run=true"

    # The release-lane-rot tracking-issue signal.
    assert maintaining =~ "release-lane-rot"

    # Cross-reference to the canonical runbook -- no matrix duplication.
    assert maintaining =~ "docs/release-runbook-v1-0.md"

    # The new subsection appears after the existing Recovery / one-off publish line
    # and before the First public launch section (correct insertion point per
    # 222-RESEARCH.md Finding 5).
    [_, after_recovery] =
      String.split(maintaining, "**Recovery / one-off publish:**", parts: 2)

    assert after_recovery =~ "### Release-lane rot signals & recovery (HARD-01/HARD-02)"

    [before_launch, _] =
      String.split(after_recovery, "## First public launch (announcement checklist)", parts: 2)

    assert before_launch =~ "### Release-lane rot signals & recovery (HARD-01/HARD-02)"
  end
end
