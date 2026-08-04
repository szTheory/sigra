defmodule Sigra.Planning.Phase236CloseoutEvidenceReconciliationContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @summary_paths %{
    "231-11" => ".planning/phases/231-gate-honesty-nightly-revival/231-11-SUMMARY.md",
    "231-06" => ".planning/phases/231-gate-honesty-nightly-revival/231-06-SUMMARY.md",
    "233-05" => ".planning/phases/233-library-suite-economics/233-05-SUMMARY.md"
  }
  @summary_ownership %{
    "231-11" => ["GATE-01"],
    "231-06" => ["GATE-04"],
    "233-05" => ["TEST-02", "TEST-03"]
  }
  @reconciled_ids ~w(TEST-01 TEST-02 TEST-03 DX-01 DX-02 DX-03 DX-04 DX-06)
  @traceability_ownership %{
    "FAST-01" => "Phase 235",
    "FAST-02" => "Phase 230",
    "FAST-03" => "Phase 230",
    "FAST-04" => "Phase 230",
    "FAST-05" => "Phase 230",
    "FAST-06" => "Phase 230",
    "FAST-07" => "Phase 230",
    "GATE-01" => "Phase 231",
    "GATE-02" => "Phase 231",
    "GATE-03" => "Phase 231",
    "GATE-04" => "Phase 231",
    "GATE-05" => "Phase 235",
    "PW-01" => "Phase 232",
    "PW-02" => "Phase 232",
    "PW-03" => "Phase 232",
    "TEST-01" => "Phase 233",
    "TEST-02" => "Phase 233",
    "TEST-03" => "Phase 233",
    "DX-01" => "Phase 234",
    "DX-02" => "Phase 234",
    "DX-03" => "Phase 234",
    "DX-04" => "Phase 234",
    "DX-05" => "Phase 231",
    "DX-06" => "Phase 234"
  }
  @immutable_digests %{
    ".planning/phases/230-tier-1-critical-path-reclamation/230-VERIFICATION.md" =>
      "3cb5a657bc9a6ec1edbbf3a2476c6f5a48f355f32039e753a72dfbd02f4990e3",
    ".planning/phases/231-gate-honesty-nightly-revival/231-VERIFICATION.md" =>
      "57037036c74174a73a1b9595114ab8fa3d89bd0e8336143c6f9d090a245aa59b",
    ".planning/phases/232-playwright-economics-authenticate-once-then-shard/232-VERIFICATION.md" =>
      "90e77fd13ed854d40d3bb15992a0da93f83d16e74180e12f44f9a3fca301cd90",
    ".planning/phases/233-library-suite-economics/233-VERIFICATION.md" =>
      "5e7a9bcca71991f024413c0cff7e63a69cf29f14f23c87ed4ec3da6a13481bbc",
    ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VERIFICATION.md" =>
      "4306e522908502b9636edf6a417c878b6fbbbd09d4f8606091e1336919ff0ceb",
    ".planning/phases/235-terminal-ratification-measured-not-read/235-VERIFICATION.md" =>
      "0c94fad944ed00c2ac13865f687d432c46bdd3b9d42c664686d4f7c6ecfe53a4",
    ".planning/phases/233-library-suite-economics/233-VALIDATION.md" =>
      "4dba95b2167c432010a9fc7b066ede325f48e3db2946f9709b27812dc11e3b6b",
    ".planning/phases/235-terminal-ratification-measured-not-read/235-VALIDATION.md" =>
      "d5ea7296ecf1eb765491e2c8fc250e4ab90469861a5c82147f7963784bec4fe1",
    ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.json" =>
      "022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244",
    ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl" =>
      "6ab19fd1b85c442185a30f7f5819b1258f26fb635dbb91e22d2526f89b10fa17",
    ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT.attestation.jsonl" =>
      "4134c0a9f38bc68dc84eecb8afe0db33ffdf209cc40d6bb7a51c79bda5ad01c9",
    ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.attestation.jsonl" =>
      "af49fd36b603adbdfdeb8698141cea2e8749c1edc3f9b88764e3465b6f84215f"
  }

  @tag :summary_reconciliation
  test "SUMMARY requirement ownership is exact and rejects wrong owners or extra IDs" do
    summaries = summary_contents()

    assert validate_summary_ownership!(summaries) == :ok

    wrong_owner =
      Map.update!(summaries, "231-11", &String.replace(&1, "[GATE-01]", "[GATE-04]"))

    assert_raise ArgumentError, ~r/SUMMARY ownership/, fn ->
      validate_summary_ownership!(wrong_owner)
    end

    extra_id =
      Map.update!(
        summaries,
        "233-05",
        &String.replace(&1, "[TEST-02, TEST-03]", "[TEST-02, TEST-03, TEST-01]")
      )

    assert_raise ArgumentError, ~r/SUMMARY ownership/, fn ->
      validate_summary_ownership!(extra_id)
    end
  end

  @tag :summary_reconciliation
  test "immutable verification, validation, and protected receipt evidence retains exact digests" do
    Enum.each(@immutable_digests, fn {path, expected_digest} ->
      assert sha256!(path) == expected_digest, "immutable evidence changed: #{path}"
    end)
  end

  test "traceability is exact, reconciles only the approved eight IDs, and requires three sources" do
    requirements = File.read!(Path.join(@root, ".planning/REQUIREMENTS.md"))

    assert validate_traceability!(requirements) == :ok

    checkbox_only =
      String.replace(
        requirements,
        "| TEST-01 | Phase 233 | Complete |",
        "| TEST-01 | Phase 233 | Gaps Found |"
      )

    assert_raise ArgumentError, ~r/approved traceability/, fn ->
      validate_traceability!(checkbox_only)
    end

    unapproved =
      String.replace(
        requirements,
        "| PW-01 | Phase 232 | Complete |",
        "| PW-01 | Phase 232 | Gaps Found |"
      )

    assert_raise ArgumentError, ~r/approved traceability/, fn ->
      validate_traceability!(unapproved)
    end
  end

  defp summary_contents do
    Map.new(@summary_paths, fn {summary, path} ->
      {summary, File.read!(Path.join(@root, path))}
    end)
  end

  defp validate_summary_ownership!(summaries) do
    ownership = Map.new(summaries, fn {summary, body} -> {summary, completed_ids!(body)} end)

    unless ownership == @summary_ownership do
      raise ArgumentError, "SUMMARY ownership must exactly match the D-01 declaration map"
    end

    :ok
  end

  defp completed_ids!(summary) do
    with [frontmatter] <- Regex.run(~r/\A---\n(.*?)\n---/s, summary, capture: :all_but_first),
         [ids] <-
           Regex.run(~r/^requirements-completed:\s*\[([^\]]*)\]\s*$/m, frontmatter,
             capture: :all_but_first
           ) do
      ids
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
    else
      _ -> raise ArgumentError, "SUMMARY is missing a narrow requirements-completed field"
    end
  end

  defp validate_traceability!(requirements) do
    rows = traceability_rows(requirements)
    ownership = Map.new(rows, fn [id, phase, _status] -> {id, phase} end)
    statuses = Map.new(rows, fn [id, _phase, status] -> {id, status} end)

    unless ownership == @traceability_ownership and length(rows) == 24 do
      raise ArgumentError, "traceability must retain the exact 24-row ownership map"
    end

    complete_ids =
      statuses
      |> Enum.filter(fn {_id, status} -> String.starts_with?(status, "Complete") end)
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    expected_complete_ids =
      @traceability_ownership
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(@reconciled_ids))
      |> MapSet.union(MapSet.new(@reconciled_ids))

    unless complete_ids == expected_complete_ids and
             Enum.all?(@reconciled_ids, &(Map.fetch!(statuses, &1) == "Complete")) do
      raise ArgumentError, "approved traceability completion set changed"
    end

    assert_three_source_support!()
    :ok
  end

  defp traceability_rows(requirements) do
    Regex.scan(~r/^\| ([A-Z]+-\d+) \| (Phase \d+) \| (.+) \|$/m, requirements,
      capture: :all_but_first
    )
  end

  defp assert_three_source_support! do
    checked_requirements = File.read!(Path.join(@root, ".planning/REQUIREMENTS.md"))

    verification_233 =
      File.read!(
        Path.join(@root, ".planning/phases/233-library-suite-economics/233-VERIFICATION.md")
      )

    verification_234 =
      File.read!(
        Path.join(
          @root,
          ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VERIFICATION.md"
        )
      )

    contracts = [
      "test/sigra/planning/phase_233_library_economics_contract_test.exs",
      "test/sigra/planning/phase_234_evidence_contract_test.exs"
    ]

    Enum.each(@reconciled_ids, fn id ->
      verification =
        if String.starts_with?(id, "TEST"), do: verification_233, else: verification_234

      unless checked_requirements =~ "- [x] **#{id}**" and verification =~ "| #{id} |" and
               verification =~ "✓ SATISFIED" and
               Enum.all?(contracts, &File.exists?(Path.join(@root, &1))) do
        raise ArgumentError, "three-source support is incomplete for #{id}"
      end
    end)
  end

  defp sha256!(path) do
    path
    |> then(&Path.join(@root, &1))
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
