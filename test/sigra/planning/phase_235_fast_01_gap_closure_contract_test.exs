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
    assert collector =~ "remediation_receipt_digest_mismatch"
    assert collector =~ "remediation_digest_schema_invalid"
    assert collector =~ "d77d3be877bfd8d75693ca57535caad54c35981deeba45089811482156e22c5a"
    assert collector =~ "old_population_overlap"

    assert :crypto.hash(:sha256, File.read!(receipt)) |> Base.encode16(case: :lower) ==
             remediation["immutable_prior_receipt"]["sha256"]

    assert remediation["immutable_prior_receipt"]["eligible_pr_run_count"] == 13
    assert remediation["immutable_prior_receipt"]["p50_seconds"] == 724
    assert remediation["immutable_prior_receipt"]["verdict"] == "miss"
  end

  test "terminal offline verifier never resolves sudo through PATH" do
    verifier =
      File.read!(
        Path.join(@root, "scripts/ci/verify-terminal-ratification-attestation-offline.sh")
      )

    assert verifier =~ "test -x /usr/bin/sudo && /usr/bin/sudo -n /usr/bin/unshare --net true"
    assert verifier =~ "isolation=(/usr/bin/sudo -n /usr/bin/unshare --net)"
    assert verifier =~ "/usr/bin/sudo -n /usr/bin/rm -rf -- \"$work\""
    refute verifier =~ "command -v sudo"
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

  test "independently recomputes the protected strict pass and rejects provenance or population drift" do
    receipt = gap_closure_receipt()

    assert validate_gap_closure!(receipt) == %{n: 15, p50: 486, verdict: "pass"}

    assert_raise ArgumentError, ~r/authority/, fn ->
      receipt |> Map.put("authority", "receipt_only") |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/cutoff/, fn ->
      put_in(receipt, ["cutoff", "timestamp"], "2026-08-03T21:37:09Z") |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/endpoint/, fn ->
      put_in(receipt, ["window", "endpoint"], "2026-08-04T00:19:11Z") |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/at least ten/, fn ->
      receipt |> Map.put("runs", Enum.take(receipt["runs"], 9)) |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/unique/, fn ->
      [first | rest] = receipt["runs"]
      receipt |> Map.put("runs", [first, first | rest]) |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/old receipt/, fn ->
      [first | rest] = receipt["runs"]
      old_id = old_run_ids!() |> Enum.at(0)
      old_row = Map.put(first, "run_id", old_id)
      receipt |> Map.put("runs", [old_row | rest]) |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/terminal conclusion/, fn ->
      put_in(receipt, ["runs", Access.at(0), "conclusion"], nil) |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/canonical ordering/, fn ->
      put_in(receipt, ["statistics", "ordering"], "wall_seconds") |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/stored statistic/, fn ->
      put_in(receipt, ["statistics", "p50_seconds"], 487) |> validate_gap_closure!()
    end

    assert_raise ArgumentError, ~r/strict comparator/, fn ->
      receipt |> Map.put("verdict", "miss") |> validate_gap_closure!()
    end

    assert %{p50: 719, verdict: "pass"} = strict_result!(List.duplicate(719, 10))
    assert %{p50: 720, verdict: "miss"} = strict_result!(List.duplicate(720, 10))
    assert %{p50: 721, verdict: "miss"} = strict_result!(List.duplicate(721, 10))
    assert %{p50: 720, verdict: "miss"} = strict_result!([719, 720, 720, 721])
  end

  test "reconciles FAST only and locks the independent GATE-05 protected evidence" do
    requirements = File.read!(Path.join(@root, ".planning/REQUIREMENTS.md"))

    residual =
      File.read!(
        Path.join(@root, ".planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md")
      )

    terminal =
      File.read!(Path.join(@root, Path.join(@phase, "235-TERMINAL-RATIFICATION.json")))
      |> Jason.decode!()

    gate_receipt = Path.join(@root, Path.join(@phase, "235-PROTECTED-RECEIPTS.json"))

    gate_verifier =
      Path.join(@root, "scripts/ci/verify-terminal-ratification-attestation-offline.sh")

    assert validate_reconciliation!(requirements, residual, terminal, gate_receipt, gate_verifier) ==
             :ok

    assert_raise ArgumentError, ~r/FAST-01/, fn ->
      String.replace(requirements, "- [x] **FAST-01**", "- [ ] **FAST-01")
      |> validate_reconciliation!(residual, terminal, gate_receipt, gate_verifier)
    end

    assert_raise ArgumentError, ~r/GATE-05 requirement/, fn ->
      String.replace(requirements, "30782184713", "30782184714")
      |> validate_reconciliation!(residual, terminal, gate_receipt, gate_verifier)
    end

    assert_raise ArgumentError, ~r/GATE-05 ownership/, fn ->
      put_in(terminal, ["ownership", "rows"], Enum.take(terminal["ownership"]["rows"], 92))
      |> then(&validate_reconciliation!(requirements, residual, &1, gate_receipt, gate_verifier))
    end

    assert_raise ArgumentError, ~r/GATE-05 verifier/, fn ->
      validate_reconciliation!(
        requirements,
        residual,
        terminal,
        gate_receipt,
        gate_verifier <> ".mutated"
      )
    end
  end

  defp gap_closure_receipt do
    Path.join(@root, Path.join(@phase, "235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json"))
    |> File.read!()
    |> Jason.decode!()
  end

  defp old_run_ids! do
    Path.join(@root, Path.join(@phase, "235-FAST-01-REMEASUREMENT.json"))
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("runs")
    |> Enum.map(& &1["run_id"])
    |> MapSet.new()
  end

  defp validate_gap_closure!(receipt) do
    unless receipt["authority"] == "protected_main_attestation" and
             receipt["repository"] == "szTheory/sigra" and
             receipt["workflow"] == "ci.yml" and receipt["event"] == "pull_request" do
      raise ArgumentError, "protected authority metadata"
    end

    unless receipt["cutoff"] == %{
             "sha" => "54c33e904155a454255952666711c882afdd06e4",
             "timestamp" => "2026-08-03T21:37:08Z"
           } do
      raise ArgumentError, "immutable cutoff"
    end

    unless get_in(receipt, ["window", "endpoint"]) == "2026-08-04T00:19:10Z" do
      raise ArgumentError, "protected endpoint"
    end

    runs = receipt["runs"] || []
    if length(runs) < 10, do: raise(ArgumentError, "at least ten terminal rows")

    ids = Enum.map(runs, & &1["run_id"])
    if MapSet.size(MapSet.new(ids)) != length(ids), do: raise(ArgumentError, "unique run IDs")

    if not MapSet.disjoint?(MapSet.new(ids), old_run_ids!()),
      do: raise(ArgumentError, "old receipt overlap")

    unless Enum.all?(
             runs,
             &(&1["conclusion"] in ["success", "failure", "cancelled", "timed_out", "skipped"])
           ) do
      raise ArgumentError, "terminal conclusion"
    end

    unless get_in(receipt, ["statistics", "mode"]) == "wall" and
             get_in(receipt, ["statistics", "ordering"]) == "{wall_seconds, run_id}" do
      raise ArgumentError, "canonical ordering"
    end

    computed = strict_result!(Enum.map(runs, & &1["wall_seconds"]))

    unless receipt["eligible_pr_run_count"] == computed.n and
             get_in(receipt, ["statistics", "p50_seconds"]) == computed.p50 do
      raise ArgumentError, "stored statistic disagrees with independent recomputation"
    end

    if receipt["verdict"] != computed.verdict or receipt["status"] != "measured" do
      raise ArgumentError, "strict comparator or stored verdict"
    end

    computed
  end

  defp strict_result!(wall_seconds) do
    ordered = Enum.sort(wall_seconds)

    %{
      n: length(ordered),
      p50: Enum.at(ordered, div(length(ordered), 2)),
      verdict: if(Enum.at(ordered, div(length(ordered), 2)) < 720, do: "pass", else: "miss")
    }
  end

  defp validate_reconciliation!(requirements, residual, terminal, gate_receipt, gate_verifier) do
    unless requirements =~ "- [x] **FAST-01**" and requirements =~ "run `30865183650`" and
             requirements =~ "15 terminal `pull_request` runs" and
             requirements =~ "p50 486 seconds" and
             requirements =~ "2026-08-04T00:19:10Z" and
             requirements =~ "235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json" do
      raise ArgumentError, "FAST-01 pass reconciliation"
    end

    unless residual =~ "772 seconds" and residual =~ "724 seconds" and residual =~ "486 seconds" and
             residual =~ "Closed" do
      raise ArgumentError, "historical residual preservation"
    end

    unless requirements =~ "- [x] **GATE-05**" and requirements =~ "30782184713" and
             requirements =~ "93 ownership rows" do
      raise ArgumentError, "GATE-05 requirement"
    end

    unless length(terminal["ownership"]["rows"]) == 93 and File.exists?(gate_receipt) do
      raise ArgumentError, "GATE-05 ownership"
    end

    unless File.exists?(gate_verifier) and
             File.read!(gate_verifier) =~ "offline_attestation_verified" do
      raise ArgumentError, "GATE-05 verifier"
    end

    :ok
  end
end
