defmodule Sigra.Planning.Phase235Fast01SourceCompleteContractTest do
  use ExUnit.Case, async: true

  @workflow ".github/workflows/fast-01-gap-closure-evidence.yml"
  @collector "scripts/ci/capture-fast-01-gap-closure.sh"
  @verifier "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh"

  test "protected workflow attests only the source-complete subject from main" do
    workflow = File.read!(@workflow)

    assert workflow =~ "github.ref == 'refs/heads/main'"
    assert workflow =~ "fast-01-source-complete-remeasurement.json"
    assert workflow =~ "sigra.fast-01-source-complete-remeasurement/1"
    assert workflow =~ "actions/attest-build-provenance@0f67c3f4856b2e3261c31976d6725780e5e4c373"
    refute workflow =~ "fast-01-gap-closure-remeasurement.json"
  end

  test "collector delegates terminal statistics to the wall-mode instrument" do
    collector = File.read!(@collector)

    assert collector =~ "scripts/ci/ci-run-metrics.sh"
    assert collector =~ "--source-pages"
    assert collector =~ "--mode wall"
    assert collector =~ "instrument_receipt"
    assert collector =~ "binding_poles"
  end

  test "new offline verifier is fixed-path, network denied, and fail-closed on Plan 17 pins" do
    verifier = File.read!(@verifier)

    assert verifier =~ "235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json"
    assert verifier =~ "deny network"
    assert verifier =~ ~s("$GH_BIN" attestation verify)
    assert verifier =~ "UNSET_PLAN_17"
    assert verifier =~ "source_collection"
    assert verifier =~ "instrument_receipt"
  end

  test "completed ownership proof and contributor topology remain immutable" do
    pins = %{
      ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.json" =>
        "022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244",
      ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json" =>
        "c667836535ae1141fe4419b6675777a6aa865dd99da528c33caa5ac16794a27e",
      "CONTRIBUTING.md" => "33d045c1fe8940a050db76d087ab1e8b45020b404d2f122032c50c170d11760b"
    }

    for {path, expected} <- pins do
      actual = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
      assert actual == expected, "immutable digest drift: #{path}"
    end
  end
end
