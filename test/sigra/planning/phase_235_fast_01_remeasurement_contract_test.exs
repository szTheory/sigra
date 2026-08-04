defmodule Sigra.Planning.Phase235Fast01RemeasurementContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @collector Path.join(@root, "scripts/ci/capture-fast-01-remeasurement.sh")
  @readiness Path.join(@root, ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT-READINESS.json")
  @workflow Path.join(@root, ".github/workflows/fast-01-remeasurement-evidence.yml")

  test "pins the fresh protected-main cutoff and leaves readiness non-authoritative" do
    collector = File.read!(@collector)
    readiness = File.read!(@readiness) |> Jason.decode!()
    terminal = File.read!(Path.join(@root, ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json")) |> Jason.decode!()

    assert collector =~ "a282b3deed009e62707b1a01d16da053a53e37d8"
    assert collector =~ "2026-08-03T15:36:12Z"
    assert readiness["schema_version"] == "sigra.fast-01-remeasurement-readiness/v1"
    assert readiness["authority"] == "readiness_only"
    assert readiness["endpoint_source"] == "collector_current_utc"
    assert is_nil(readiness["statistics"])
    assert is_nil(readiness["verdict"])
    assert readiness["status"] in ["insufficient_population", "ready"]
    assert terminal["verdict"]["fast_01"]["eligible_pr_run_count"] == 19
    assert terminal["verdict"]["fast_01"]["observed_p50_seconds"] == 772
    assert terminal["verdict"]["fast_01"]["status"] == "miss"
  end

  test "protects the only measured subject without joining ci.yml" do
    workflow = File.read!(@workflow)
    ci = File.read!(Path.join(@root, ".github/workflows/ci.yml"))
    coverage = File.read!(Path.join(@root, ".planning/phases/235-terminal-ratification-measured-not-read/235-COVERAGE.md"))

    assert workflow =~ "workflow_dispatch:"
    refute workflow =~ "inputs:"
    assert workflow =~ "github.ref == 'refs/heads/main'"
    assert workflow =~ "actions: read"
    assert workflow =~ "id-token: write"
    assert workflow =~ "attestations: write"
    assert workflow =~ "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"
    assert workflow =~ "fetch-depth: 0"
    assert workflow =~ "actions/attest-build-provenance@0f67c3f4856b2e3261c31976d6725780e5e4c373"
    assert workflow =~ "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
    assert workflow =~ "eligible_pr_run_count >= 10"
    assert workflow =~ "--protected-output fast-01-remeasurement.json"
    refute ci =~ "fast-01-remeasurement-evidence.yml"
    assert coverage =~ "fast-01-remeasurement-evidence.yml"
    assert coverage =~ "one 60-second watcher"
  end
end
