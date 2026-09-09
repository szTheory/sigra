defmodule Sigra.Planning.Phase235Fast01GapClosureContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @phase ".planning/phases/235-terminal-ratification-measured-not-read"
  @requirements Path.join(@root, ".planning/REQUIREMENTS.md")
  @residual Path.join(@root, ".planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md")
  @cutoff_sha "54c33e904155a454255952666711c882afdd06e4"
  @cutoff "2026-08-03T21:37:08Z"
  @endpoint "2026-09-08T20:05:35Z"
  @producer_run_id "34272746647"
  @producer_run_url "https://github.com/szTheory/sigra/actions/runs/34272746647"
  @subject "235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json"
  @attestation "235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl"
  @gate_05_requirement "- [x] **GATE-05**: A maintainer can see, from a single artifact, which specs run on PR vs main vs nightly before and after this milestone, proving no test was silently dropped. (Protected receipt `235-PROTECTED-RECEIPTS.json`, attested by protected main run `30782184713`, reconciles all 93 ownership rows.)"
  @gate_05_trace "| GATE-05 | Phase 235 | Complete (protected run `30782184713`; 93-row execution proof) |"
  @gate_05_artifacts %{
    "235-PROTECTED-RECEIPTS.json" =>
      "022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244",
    "235-PROTECTED-RECEIPTS.attestation.jsonl" =>
      "af49fd36b603adbdfdeb8698141cea2e8749c1edc3f9b88764e3465b6f84215f",
    "235-TRUSTED-ROOT.jsonl" =>
      "65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c",
    "235-TERMINAL-RATIFICATION.json" =>
      "c667836535ae1141fe4419b6675777a6aa865dd99da528c33caa5ac16794a27e"
  }
  @gate_05_verifier_sha256 "6c0805e0386186f017215ea7bf10bf450c9aafb68ef6742afa2f9e75b0463367"

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
    assert workflow =~ "--protected-output fast-01-source-complete-remeasurement.json"
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

    assert verifier =~
             "TRUSTED_ROOT_DIGEST=\"65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c\""

    assert verifier =~ "trusted_root_digest_mismatch"
    assert verifier =~ "expect_population_failure cutoff"
    assert verifier =~ "expect_population_failure endpoint"
    assert verifier =~ "expect_population_failure historical_run_id"
    assert verifier =~ "expect_population_failure undersized"
    assert verifier =~ "expect_population_failure duplicate_run_id"
    assert verifier =~ "expect_population_failure empty_conclusion"
    assert verifier =~ "expect_population_failure noncanonical_order"
    assert verifier =~ "expect_population_failure stored_p50"
    assert verifier =~ "expect_population_failure strict_verdict"
  end

  test "independently derives canonical population, poles, and strict 719/720/721 verdicts" do
    result = validate_population!(receipt!())

    assert result == %{
             n: 43,
             p50: 466,
             verdict: "pass",
             median_run_id: 33_449_097_115,
             maximum_run_id: 30_855_541_236,
             maximum_seconds: 1331
           }

    assert synthetic_receipt(719) |> validate_population!() |> Map.fetch!(:verdict) == "pass"
    assert synthetic_receipt(720) |> validate_population!() |> Map.fetch!(:verdict) == "miss"
    assert synthetic_receipt(721) |> validate_population!() |> Map.fetch!(:verdict) == "miss"

    all_success =
      synthetic_receipt(719)
      |> update_in(["runs"], fn runs -> Enum.map(runs, &Map.put(&1, "conclusion", "success")) end)

    assert all_success |> validate_population!() |> Map.fetch!(:verdict) == "pass"

    for conclusion <-
          ~w(cancelled timed_out neutral skipped stale action_required startup_failure) do
      assert synthetic_receipt(719)
             |> put_in(["runs", Access.at(0), "conclusion"], conclusion)
             |> validate_population!()
             |> Map.fetch!(:verdict) == "pass"
    end
  end

  test "rejects undersized, duplicate, overlapping, filtered, and noncanonical populations" do
    receipt = receipt!()

    for size <- [0, 1, 9] do
      assert_raise ArgumentError, ~r/insufficient population/, fn ->
        receipt |> with_runs(Enum.take(receipt["runs"], size)) |> validate_population!()
      end
    end

    assert_raise ArgumentError, ~r/duplicate run id/, fn ->
      receipt
      |> with_runs([hd(receipt["runs"]) | receipt["runs"]])
      |> validate_population!()
    end

    assert_raise ArgumentError, ~r/historical overlap/, fn ->
      receipt
      |> put_in(["runs", Access.at(0), "run_id"], 30_828_457_128)
      |> validate_population!()
    end

    assert_raise ArgumentError, ~r/all terminal conclusions/, fn ->
      receipt |> put_in(["runs", Access.at(0), "conclusion"], "") |> validate_population!()
    end

    assert_raise ArgumentError, ~r/canonical ordering/, fn ->
      receipt |> update_in(["runs"], &Enum.reverse/1) |> validate_population!()
    end

    assert_raise ArgumentError, ~r/fixed measurement bounds/, fn ->
      put_in(receipt, ["cutoff", "timestamp"], "2026-08-03T21:37:09Z")
      |> validate_population!()
    end

    assert_raise ArgumentError, ~r/fixed measurement bounds/, fn ->
      put_in(receipt, ["window", "endpoint"], "2026-09-08T20:05:36Z")
      |> validate_population!()
    end

    assert_raise ArgumentError, ~r/stored p50 contradiction/, fn ->
      put_in(receipt, ["statistics", "p50_seconds"], 720) |> validate_population!()
    end

    assert_raise ArgumentError, ~r/strict verdict contradiction/, fn ->
      put_in(receipt, ["verdict"], "miss") |> validate_population!()
    end
  end

  test "derived pass stays open without signed source rows and leaves GATE-05 byte-exact" do
    requirements = File.read!(@requirements)
    result = validate_population!(receipt!())

    assert result.verdict == "pass"
    assert requirements =~ "- [ ] **FAST-01**:"
    assert requirements =~ "| FAST-01 | Phase 235 | Gaps Found ("
    assert requirements =~ "43 derived rows"
    assert requirements =~ "stored p50 466 seconds"
    assert requirements =~ "omitted source timestamps and pagination/exhaustion evidence"
    assert requirements =~ @producer_run_id
    assert requirements =~ @producer_run_url
    assert requirements =~ @subject
    assert requirements =~ @gate_05_requirement
    assert requirements =~ @gate_05_trace
    assert requirements |> String.split("\n") |> Enum.count(&(&1 == @gate_05_requirement)) == 1
    assert requirements |> String.split("\n") |> Enum.count(&(&1 == @gate_05_trace)) == 1

    assert requirements
           |> String.split("\n")
           |> Enum.count(
             &(String.starts_with?(&1, "- [") and String.contains?(&1, "**GATE-05**"))
           ) == 1

    assert requirements
           |> String.split("\n")
           |> Enum.count(&String.starts_with?(&1, "| GATE-05 |")) == 1

    for {name, digest} <- @gate_05_artifacts do
      assert sha256!(Path.join(@root, Path.join(@phase, name))) == digest
    end

    assert sha256!(
             Path.join(@root, "scripts/ci/verify-terminal-ratification-attestation-offline.sh")
           ) ==
             @gate_05_verifier_sha256

    refute requirements =~ "| FAST-01 | Phase 235 | Complete ("
  end

  test "rejected candidate retains both misses and measured remediation evidence" do
    residual = File.read!(@residual)

    assert residual =~ "772 seconds"
    assert residual =~ "724 seconds"
    assert residual =~ "692 seconds"
    assert residual =~ "148 seconds"
    assert residual =~ "470 seconds"
    assert residual =~ "2026-09-08"
    assert residual =~ "Open residual"
    assert residual =~ "Candidate measurement rejected for closure"
    assert residual =~ @cutoff_sha
    assert residual =~ @endpoint
    assert residual =~ "n=43"
    assert residual =~ "p50=466 seconds"
    assert residual =~ @producer_run_id
    assert residual =~ @subject
    assert residual =~ @attestation
    assert residual =~ "cannot independently prove"
    assert residual =~ "FAST-01\nremains open"
    refute residual =~ "**Status:** Closed"
  end

  defp receipt! do
    File.read!(Path.join(@root, Path.join(@phase, @subject))) |> Jason.decode!()
  end

  defp sha256!(path) do
    :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
  end

  defp with_runs(receipt, runs) do
    receipt
    |> Map.put("runs", runs)
    |> Map.put("eligible_pr_run_count", length(runs))
  end

  defp synthetic_receipt(median) do
    runs =
      for index <- 0..10 do
        %{
          "run_id" => 40_000_000_000 + index,
          "wall_seconds" => median - 5 + index,
          "conclusion" => if(rem(index, 2) == 0, do: "success", else: "failure"),
          "url" => "https://github.com/szTheory/sigra/actions/runs/#{40_000_000_000 + index}"
        }
      end

    receipt!()
    |> with_runs(runs)
    |> put_in(["statistics", "p50_seconds"], median)
    |> Map.put("verdict", if(median < 720, do: "pass", else: "miss"))
  end

  defp validate_population!(receipt) do
    unless receipt["authority"] == "protected_main_attestation" and
             receipt["cutoff"] == %{"sha" => @cutoff_sha, "timestamp" => @cutoff} and
             receipt["window"] == %{"endpoint" => @endpoint},
           do: raise(ArgumentError, "fixed measurement bounds")

    runs = receipt["runs"]
    n = length(runs)

    unless n >= 10 and receipt["eligible_pr_run_count"] == n,
      do: raise(ArgumentError, "insufficient population")

    ids = Enum.map(runs, &Map.fetch!(&1, "run_id"))
    unless length(Enum.uniq(ids)) == n, do: raise(ArgumentError, "duplicate run id")

    historical_ids =
      ["235-FAST-01-REMEASUREMENT.json", "235-TERMINAL-RATIFICATION.json"]
      |> Enum.flat_map(fn
        "235-FAST-01-REMEASUREMENT.json" = name ->
          Path.join(@root, Path.join(@phase, name))
          |> File.read!()
          |> Jason.decode!()
          |> Map.fetch!("runs")
          |> Enum.map(&Map.fetch!(&1, "run_id"))

        name ->
          Path.join(@root, Path.join(@phase, name))
          |> File.read!()
          |> Jason.decode!()
          |> get_in(["measurements", "pull_request", "run_ids"])
      end)
      |> MapSet.new()

    unless MapSet.disjoint?(MapSet.new(ids), historical_ids),
      do: raise(ArgumentError, "historical overlap")

    conclusions = Enum.map(runs, & &1["conclusion"])

    terminal_conclusions =
      ~w(success failure cancelled timed_out neutral skipped stale action_required startup_failure)

    unless Enum.all?(conclusions, &(&1 in terminal_conclusions)),
      do: raise(ArgumentError, "all terminal conclusions")

    ordered = Enum.sort_by(runs, &{&1["wall_seconds"], &1["run_id"]})
    unless runs == ordered, do: raise(ArgumentError, "canonical ordering")

    median_run = Enum.at(ordered, div(n, 2))
    maximum_run = Enum.max_by(ordered, &{&1["wall_seconds"], &1["run_id"]})
    p50 = median_run["wall_seconds"]

    unless receipt["statistics"] == %{
             "mode" => "wall",
             "ordering" => "{wall_seconds, run_id}",
             "p50_seconds" => p50
           },
           do: raise(ArgumentError, "stored p50 contradiction")

    verdict = if p50 < 720, do: "pass", else: "miss"
    unless receipt["verdict"] == verdict, do: raise(ArgumentError, "strict verdict contradiction")

    %{
      n: n,
      p50: p50,
      verdict: verdict,
      median_run_id: median_run["run_id"],
      maximum_run_id: maximum_run["run_id"],
      maximum_seconds: maximum_run["wall_seconds"]
    }
  end
end
