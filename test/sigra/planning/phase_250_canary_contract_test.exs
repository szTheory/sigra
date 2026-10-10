defmodule Sigra.Planning.Phase250CanaryContractTest do
  use ExUnit.Case, async: true

  defp root, do: Path.expand("../../..", __DIR__)
  defp read!(path), do: root() |> Path.join(path) |> File.read!()

  test "canary source is an on-demand isolated failure and cancellation probe" do
    workflow = read!(".github/workflows/release-receipt-canary.yml")

    assert workflow =~ "workflow_dispatch:"
    assert workflow =~ "options: [failure, cancellation]"
    assert workflow =~ "Controlled failure before release operations"
    assert workflow =~ "Bounded cancellation wait"
    assert workflow =~ "contents: none"
    assert workflow =~ "actions: read"
    assert workflow =~ "retention-days: 30"
    refute workflow =~ "schedule:"
    refute workflow =~ "environment:"
    refute workflow =~ ~r/secrets\.[A-Z0-9_]+/
    refute workflow =~ ~r/contents: write|pull-requests: write|issues: write|packages: write/
    refute workflow =~ ~r/hex-publish|gh release|git tag|gh pr merge/
  end

  test "controller uses only exact canary run identity and bounded ordinary cancellation" do
    workflow = read!(".github/workflows/release-receipt-canary-controller.yml")
    script = read!("scripts/ci/release-canary.sh")

    assert workflow =~ "actions: write"
    assert workflow =~ "contents: read"
    assert workflow =~ "--run --proof"
    assert script =~ "find_exact_run"
    assert script =~ "wait_for_cancellation_stage \"$cancel_id\""
    assert script =~ "actions/runs/${id}/cancel"
    assert script =~ "--interval 60 --exit-status"
    refute script =~ "gh run cancel --force"
    refute script =~ "actions/runs/latest/cancel"
    refute workflow =~ ~r/(RELEASE_PLEASE_TOKEN|HEX_API_KEY|environment:)/
  end

  test "receipt validator separates canary identity from production receipts" do
    receipt = read!("scripts/ci/release-receipt.sh")
    canary = read!("scripts/ci/release-canary.sh")

    assert receipt =~ "--mode production|canary"
    assert receipt =~ "receipt_kind == \"canary\""
    assert receipt =~ "source.repository == \"szTheory/sigra\""
    assert receipt =~ "source_repository"
    assert receipt =~ "source_run.workflow_id"
    assert receipt =~ "no_credential_keys"
    assert canary =~ "--validate-proof"
    assert canary =~ "artifact.digest"
    assert canary =~ "source_cancellation.observer_run_id"
  end

  test "trusted observer allowlists canary identity while retaining production checks" do
    workflow = read!(".github/workflows/release-run-observer.yml")
    observer = read!("scripts/ci/release-observer.sh")

    assert workflow =~ "workflows: [\"Release Please\", \"Release Receipt Canary\"]"
    assert workflow =~ "github.event.workflow.name == 'Release Receipt Canary'"
    assert workflow =~ "release-canary-cancellation-"
    assert observer =~ "release-receipt-canary.yml"
    assert observer =~ "API_WORKFLOW_NAME\" == \"Release Receipt Canary\""
    assert observer =~ "source_workflow_id"
    assert observer =~ "release-please.yml"
    refute observer =~ "download-artifact"
    refute observer =~ "git checkout"
  end
end
