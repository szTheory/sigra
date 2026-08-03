defmodule Sigra.Planning.Phase235Fast01GapClosureContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @phase ".planning/phases/235-terminal-ratification-measured-not-read"

  test "uses immutable remediation-cutoff blobs while retaining later two-PR receipt validation" do
    remediation =
      File.read!(Path.join(@root, Path.join(@phase, "235-FAST-01-REMEDIATION.json")))
      |> Jason.decode!()

    collector = File.read!(Path.join(@root, "scripts/ci/capture-fast-01-gap-closure.sh"))
    receipt = Path.join(@root, Path.join(@phase, "235-FAST-01-REMEASUREMENT.json"))

    assert remediation["evidence_design"]["mode"] == "two_pr"
    assert remediation["population_cutoff"]["sha"] == "54c33e904155a454255952666711c882afdd06e4"
    assert remediation["population_cutoff"]["timestamp"] == "2026-08-03T21:37:08Z"
    assert collector =~ "cutoff_blob_digest_mismatch"
    assert collector =~ "old_population_overlap"

    assert :crypto.hash(:sha256, File.read!(receipt)) |> Base.encode16(case: :lower) ==
             remediation["immutable_prior_receipt"]["sha256"]

    assert remediation["immutable_prior_receipt"]["eligible_pr_run_count"] == 13
    assert remediation["immutable_prior_receipt"]["p50_seconds"] == 724
    assert remediation["immutable_prior_receipt"]["verdict"] == "miss"
  end

  test "readiness stays non-authoritative and protected evidence is separate from ci" do
    readiness =
      File.read!(Path.join(@root, Path.join(@phase, "235-FAST-01-GAP-CLOSURE-READINESS.json")))
      |> Jason.decode!()

    workflow = File.read!(Path.join(@root, ".github/workflows/fast-01-gap-closure-evidence.yml"))
    ci = File.read!(Path.join(@root, ".github/workflows/ci.yml"))

    assert readiness["schema_version"] == "sigra.fast-01-gap-closure-readiness/v1"
    assert readiness["authority"] == "readiness_only"
    assert is_nil(readiness["statistics"])
    assert is_nil(readiness["verdict"])
    assert readiness["status"] in ["insufficient_population", "ready"]
    assert workflow =~ "workflow_dispatch:"
    refute workflow =~ "inputs:"
    assert workflow =~ "github.ref == 'refs/heads/main'"
    assert workflow =~ "fetch-depth: 0"
    assert workflow =~ "--protected-output fast-01-gap-closure-remeasurement.json"
    assert workflow =~ "eligible_pr_run_count >= 10"
    refute workflow =~ "pull_request:"
    refute ci =~ "fast-01-gap-closure-evidence.yml"
  end
end
