defmodule Sigra.Planning.Phase235Fast01RemeasurementContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @collector Path.join(@root, "scripts/ci/capture-fast-01-remeasurement.sh")
  @readiness Path.join(@root, ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT-READINESS.json")

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
    assert terminal["eligible_pr_run_count"] == 19
    assert terminal["observed_p50_seconds"] == 772
  end
end
