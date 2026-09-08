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

  test "fresh protected population is canonical, disjoint, and strictly passing" do
    receipt =
      File.read!(
        Path.join(@root, Path.join(@phase, "235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json"))
      )
      |> Jason.decode!()

    old_ids =
      File.read!(Path.join(@root, Path.join(@phase, "235-FAST-01-REMEASUREMENT.json")))
      |> Jason.decode!()
      |> Map.fetch!("runs")
      |> Enum.map(&Map.fetch!(&1, "run_id"))
      |> MapSet.new()

    terminal_ids =
      File.read!(Path.join(@root, Path.join(@phase, "235-TERMINAL-RATIFICATION.json")))
      |> Jason.decode!()
      |> get_in(["measurements", "pull_request", "run_ids"])
      |> MapSet.new()

    runs = receipt["runs"]
    run_ids = Enum.map(runs, &Map.fetch!(&1, "run_id"))
    ordered = Enum.sort_by(runs, &{&1["wall_seconds"], &1["run_id"]})
    p50 = ordered |> Enum.at(div(length(ordered), 2)) |> Map.fetch!("wall_seconds")

    assert receipt["schema_version"] == "sigra.fast-01-gap-closure-remeasurement/v1"
    assert receipt["authority"] == "protected_main_attestation"
    assert receipt["repository"] == "szTheory/sigra"
    assert receipt["workflow"] == "ci.yml"
    assert receipt["event"] == "pull_request"
    assert receipt["cutoff"] == %{
             "sha" => "54c33e904155a454255952666711c882afdd06e4",
             "timestamp" => "2026-08-03T21:37:08Z"
           }

    assert receipt["window"] == %{"endpoint" => "2026-09-08T20:05:35Z"}
    assert receipt["eligible_pr_run_count"] == 43
    assert length(runs) == 43
    assert length(Enum.uniq(run_ids)) == 43
    assert runs == ordered
    assert MapSet.disjoint?(MapSet.new(run_ids), old_ids)
    assert MapSet.disjoint?(MapSet.new(run_ids), terminal_ids)
    assert Enum.all?(runs, &(&1["conclusion"] not in [nil, ""]))
    assert receipt["statistics"] == %{
             "mode" => "wall",
             "ordering" => "{wall_seconds, run_id}",
             "p50_seconds" => p50
           }

    assert p50 == 466
    assert p50 < 720
    assert receipt["verdict"] == "pass"
    assert receipt["status"] == "measured"
  end

  test "offline verifier binds exact provenance and rejects adverse mutations" do
    verifier =
      File.read!(Path.join(@root, "scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh"))

    assert verifier =~ "6186f17eae61373f714fda0dd98d4318362de62d7d571d6f05e2e015b26a75ee"
    assert verifier =~ "c6580d793710aaeef01a1f34d7000ead9ebcdcd2"
    assert verifier =~ "--signer-workflow \"$SIGNER_WORKFLOW\""
    assert verifier =~ "--source-ref \"$SOURCE_REF\""
    assert verifier =~ "expect_failure receipt_byte"
    assert verifier =~ "expect_failure bundle_byte"
    assert verifier =~ "expect_failure trusted_root_byte"
    assert verifier =~ "adversarial_case_unexpectedly_verified:signer_workflow"
    assert verifier =~ "adversarial_case_unexpectedly_verified:source_ref"
    assert verifier =~ "mutate_and_reject cutoff"
    assert verifier =~ "mutate_and_reject endpoint"
    assert verifier =~ "mutate_and_reject historical_run_id"
  end
end
