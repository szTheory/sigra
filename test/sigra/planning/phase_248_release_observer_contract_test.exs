defmodule Sigra.Planning.Phase248ReleaseObserverContractTest do
  use ExUnit.Case, async: true

  defp root, do: Path.expand("../../..", __DIR__)

  defp read!(path), do: root() |> Path.join(path) |> File.read!()

  defp job!(workflow, name) do
    [_before, rest] = String.split(workflow, "  #{name}:\n", parts: 2)

    case String.split(rest, ~r/^  [a-zA-Z_][a-zA-Z0-9_-]*:\s*$/m, parts: 2) do
      [job, _after] -> job
      [job] -> job
    end
  end

  test "trusted completion observer is main-source filtered, read-only, and artifact-free" do
    workflow = read!(".github/workflows/release-run-observer.yml")
    observer = job!(workflow, "record-cancellation")

    assert workflow =~ "workflow_run:"
    assert workflow =~ "workflows: [\"Release Please\", \"Release Receipt Canary\"]"
    assert workflow =~ "types: [completed]"
    assert workflow =~ "branches: [main]"
    assert workflow =~ "cancel-in-progress: false"
    assert workflow =~ ~r/^  group: .*workflow_run\.id.*github\.run_id.*github\.run_attempt/m
    assert workflow =~ ~r/^permissions:\n  actions: read\n  contents: read\n/m
    assert observer =~ "permissions:"
    assert observer =~ "actions: read"
    assert observer =~ "contents: read"
    assert observer =~ "ref: main"
    assert observer =~ "scripts/ci/release-observer.sh"
    assert observer =~ "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
    assert observer =~ "retention-days: 90"
    refute workflow =~ "actions/download-artifact"
    refute workflow =~ ~r/contents: write|actions: write|issues: write|pull-requests: write/
    refute workflow =~ ~r/secrets\.[A-Z0-9_]+/
    refute observer =~ ~r/ref: \$\{\{.*head_sha/
  end

  test "observer re-queries and validates source identity before shared cancellation receipts" do
    helper = read!("scripts/ci/release-observer.sh")
    receipt = read!("scripts/ci/release-receipt.sh")

    for assertion <- [
          "actions/runs/${EVENT_RUN_ID}",
          "actions/workflows/release-please.yml",
          ".repository.full_name",
          ".workflow_id",
          ".name",
          ".path",
          ".event",
          ".head_branch",
          ".conclusion",
          ".head_sha",
          "push",
          "workflow_dispatch",
          "main",
          "cancelled",
          "contents/.release-please-manifest.json?ref=${API_SHA}",
          "commits/${EXPECTED_TAG}",
          "release-receipt.sh",
          "observer_run",
          "--arg event \"$API_EVENT\"",
          "source_event:$event"
        ] do
      assert helper =~ assertion
    end

    assert receipt =~ ".source_event"
    assert helper =~ "tag_sha_mismatch"
    assert helper =~ "tag_not_found"
    refute helper =~ "download-artifact"
    refute helper =~ "git checkout"
    refute helper =~ "secrets."
  end

  test "cross-workflow contracts retain exact-source, credential, concurrency, receipt, and timeout guards" do
    ci = read!(".github/workflows/ci.yml")
    merge = read!(".github/workflows/release-pr-automerge.yml")
    release = read!(".github/workflows/release-please.yml")
    recovery = read!(".github/workflows/hex-publish.yml")
    poller = read!("scripts/ci/wait-for-ci-gate.sh")

    assert merge =~ "gh run view \"$SOURCE_RUN_ID\""
    assert merge =~ "--match-head-commit \"$PR_HEAD_SHA\""
    assert merge =~ "workflow_run.id"
    assert release =~ "workflow_dispatch:"
    assert job!(release, "release-please") =~ "if: ${{ github.ref == 'refs/heads/main' }}"
    assert release =~ "concurrency:"
    assert release =~ "cancel-in-progress: false"
    assert release =~ "secrets.RELEASE_PLEASE_TOKEN"
    assert release =~ "record-release-result"
    assert release =~ "notify-release-failure"
    assert recovery =~ "SOURCE_EVENT: ${{ github.event_name }}"
    assert recovery =~ "workflow_dispatch"
    assert recovery =~ "record-recovery-result"
    assert recovery =~ "release_input_rejection"
    assert ci =~ "ci-gate:"
    assert release =~ "--max-attempts 120"
    assert release =~ "timeout-minutes: 75"
    assert poller =~ "WAIT_SECONDS=30"
    ci_without_comments = String.replace(ci, ~r/^\s*#.*$/m, "")
    refute ci_without_comments =~ ~r/(RELEASE_PLEASE_TOKEN|HEX_(?:DRY_RUN_)?API_KEY)/
  end
end
