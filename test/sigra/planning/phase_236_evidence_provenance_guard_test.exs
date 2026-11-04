defmodule Sigra.Planning.Phase236EvidenceProvenanceGuardTest do
  use ExUnit.Case, async: true

  @p12 "scripts/ci/prohibitions/p12-run-id-provenance.test.mjs"
  @phase_230_ledger ".planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md"
  @phase_236_ledger "test/fixtures/prohibitions/retained-236-evidence.md"
  @phase_236_origin "test/fixtures/prohibitions/retained-236-evidence.json"
  @phase_236_fixture "test/fixtures/prohibitions/p12-phase236-claim-without-run-id.md"
  @workflow ".github/workflows/ci.yml"
  @prohibitions_glob "scripts/ci/prohibitions/*.test.mjs"

  test "p12 names both evidence ledgers" do
    source = File.read!(@p12)

    assert source =~ @phase_230_ledger,
           "p12 must retain the exact Phase 230 evidence path so the original provenance guard stays covered"

    assert source =~ @phase_236_ledger,
           "p12 must use the source-pinned Phase 236 fixture in Fast checks"
  end

  test "p12 retains asymmetric positive floors and the Phase 236 known-bad fixture" do
    source = File.read!(@p12)

    assert source =~ "minSlots: 4,\n    minCaptured: 3",
           "Phase 230 must retain its explicit four-slot/three-captured floor"

    assert source =~ "minSlots: 3,\n    minCaptured: 3",
           "Phase 236 must retain its explicit three-slot/three-captured floor"

    assert File.exists?(@phase_236_fixture),
           "the Phase 236 known-bad fixture must exist so p12 has a committed RED subject"
  end

  test "every p12 structural floor is positive and failure messages reject vacuous parses" do
    source = File.read!(@p12)

    floors =
      Regex.scan(~r/min(?:Slots|Captured):\s*(\d+)/, source)
      |> Enum.map(fn [_match, floor] -> String.to_integer(floor) end)

    assert length(floors) >= 4,
           "p12 must expose floors for both default ledgers — the parse broke, this is not a pass"

    assert Enum.all?(floors, &(&1 > 0)),
           "every p12 structural floor must be positive — the parse broke, this is not a pass"

    assert source =~ "the parse broke, this is not a pass.",
           "p12 floor failures must end by rejecting a vacuous parse as a pass"
  end

  test "Phase 236 retains exactly three run-backed evidence slots" do
    evidence = File.read!(@phase_236_ledger)
    origin = @phase_236_origin |> File.read!() |> JSON.decode!()

    assert origin["source_commit"] == "16800f4319cdd0e2554938071d4ebc48caa969ac"

    assert origin["source_path"] ==
             ".planning/milestones/v1.48-phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md"

    assert origin["sha256"] == Base.encode16(:crypto.hash(:sha256, evidence), case: :lower)

    headings =
      Regex.scan(~r/^##\s+((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$/m, evidence)
      |> Enum.map(fn [_match, heading] -> heading end)

    assert headings == ["BEFORE-FLAKE-RED", "AFTER-P17-GUARD-OBSERVED", "AFTER-FIX-GREEN"],
           "Phase 236 must retain exactly its three parsed evidence slots, not an unverified heading set"

    [p17_slot] = Regex.run(~r/^## AFTER-P17-GUARD-OBSERVED\s*$[\s\S]*?(?=^## |\z)/m, evidence)

    assert p17_slot =~ "Status: captured (run `35034938082`)",
           "AFTER-P17-GUARD-OBSERVED must retain the Fast checks run-backed Status receipt"
  end

  test "the guard stays on the existing Fast checks route and out of mix ci" do
    workflow = File.read!(@workflow)
    mix_exs = File.read!("mix.exs")

    assert workflow =~ "node --test --test-reporter=tap #{@prohibitions_glob}",
           "the existing Fast checks prohibition glob is p12's only CI route"

    refute mix_exs =~ "scripts/ci/prohibitions",
           "prohibition guards must not be added to mix ci"
  end
end
