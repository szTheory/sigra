defmodule Sigra.Planning.Phase236CloseoutEvidenceReconciliationContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @summary_directories [
    ".planning/phases/231-gate-honesty-nightly-revival",
    ".planning/phases/233-library-suite-economics"
  ]
  @summary_ownership %{
    "GATE-01" => "231-11",
    "GATE-04" => "231-06",
    "TEST-02" => "233-05",
    "TEST-03" => "233-05"
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
  @three_source_support %{
    "TEST-01" => %{
      verification_path: ".planning/phases/233-library-suite-economics/233-VERIFICATION.md",
      verification_row:
        "| TEST-01 | 233-01, 02, 05, 06 | Slow-test visibility does not force serial library execution. | ✓ SATISFIED | Parallel same-run formatter wiring, timing receipt tests, and retry-free PR run evidence. |",
      contract_path: "test/sigra/planning/phase_233_library_economics_contract_test.exs",
      contract_test: "library execution universe is fail-closed and has one full-suite owner"
    },
    "TEST-02" => %{
      verification_path: ".planning/phases/233-library-suite-economics/233-VERIFICATION.md",
      verification_row:
        "| TEST-02 | 233-02, 04, 05, 06 | Two library shards finish in comparable time. | ✓ SATISFIED | Cost-based deterministic split and observed 115s/114s final PR durations (1s gap versus 192s baseline). |",
      contract_path: "test/sigra/planning/phase_233_library_economics_contract_test.exs",
      contract_test:
        "remediation receipt is closed, retry-free, source-bound, and preserves the strict prior miss"
    },
    "TEST-03" => %{
      verification_path: ".planning/phases/233-library-suite-economics/233-VERIFICATION.md",
      verification_row:
        "| TEST-03 | 233-03, 04, 05, 06 | Subprocess-heavy install tests no longer dominate ordinary shard wall-clock. | ✓ SATISFIED | Exact scaffold extraction, unconditional 909s PR receiver, preserved named coverage, and ordinary receipts without scaffold paths. |",
      contract_path: "test/sigra/planning/phase_233_library_economics_contract_test.exs",
      contract_test:
        "scaffold modules have one explicit ci.install_golden receiver and are excluded from broad test"
    },
    "DX-01" => %{
      verification_path:
        ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VERIFICATION.md",
      verification_row:
        "| DX-01 | 01-05, 09, 11-16, 18, 20-21 | `mix ci` reproduces the PR gate with formatting and lock checks | ✓ SATISFIED | Alias/workflow parity, complete formatting, clean-worktree receipt, and exact final authorization. |",
      contract_path: "test/sigra/planning/phase_198_contributor_dx_contract_test.exs",
      contract_test: "198-01: mix ci has the ordered seven-leg contributor gate exactly once"
    },
    "DX-02" => %{
      verification_path:
        ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VERIFICATION.md",
      verification_row:
        "| DX-02 | 06, 10, 14, 18, 20-21 | Release-critical Actions use immutable SHAs | ✓ SATISFIED | Current pins, mutation-backed pinning contract, and successful Release Please run. |",
      contract_path: "test/sigra/planning/phase_234_action_pinning_contract_test.exs",
      contract_test: "every third-party release action is immutable and version-annotated"
    },
    "DX-03" => %{
      verification_path:
        ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VERIFICATION.md",
      verification_row:
        "| DX-03 | 07, 10, 14, 17-18, 20-21 | Dependabot covers GitHub Actions, Mix, and npm | ✓ SATISFIED | Exact config, manifests/locks, and three processed update-job receipts. |",
      contract_path: "test/sigra/planning/phase_234_dependabot_contract_test.exs",
      contract_test: "Dependabot owns exactly the three locked weekly ecosystems"
    },
    "DX-04" => %{
      verification_path:
        ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VERIFICATION.md",
      verification_row:
        "| DX-04 | 08, 10, 14, 18-21 | No live Playwright spec is unowned | ✓ SATISFIED | Exact inventory, CI/harness wiring, and mutation-backed reconciliation. |",
      contract_path: "test/sigra/planning/phase_234_playwright_inventory_contract_test.exs",
      contract_test:
        "inventory validation rejects missing, stale, duplicate, unowned, and broken lane tokens"
    },
    "DX-06" => %{
      verification_path:
        ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VERIFICATION.md",
      verification_row:
        "| DX-06 | 10, 14, 18, 20-21 | SEED-006 is delivered or residual filed | ✓ SATISFIED | Current successful gallery job and isolated non-gating diagnostic. |",
      contract_path: "test/sigra/planning/phase_234_evidence_contract_test.exs",
      contract_test:
        "gallery receipt proves the retry-free shared-boot consumer and isolates a non-gating evaluation diagnostic"
    }
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

    duplicate_field =
      Map.update!(summaries, "231-11", fn summary ->
        String.replace(
          summary,
          "\n---\n",
          "\nrequirements-completed: [GATE-04]\n---\n",
          global: false
        )
      end)

    assert_raise ArgumentError, ~r/exactly one narrow requirements-completed field/, fn ->
      validate_summary_ownership!(duplicate_field)
    end

    non_owner =
      Map.update!(summaries, "231-01", &String.replace(&1, "[DX-05]", "[DX-05, GATE-01]"))

    assert_raise ArgumentError, ~r/SUMMARY ownership/, fn ->
      validate_summary_ownership!(non_owner)
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

    unchecked_requirement =
      String.replace(
        requirements,
        "- [x] **TEST-01**",
        "- [ ] **TEST-01**"
      )

    assert_raise ArgumentError, ~r/checked requirement/, fn ->
      validate_traceability!(unchecked_requirement)
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

  @tag :validation_replay_baseline
  test "validation replay baseline derives historical lifecycles and preserves retained bodies" do
    baseline = validation_replay_baseline!()

    assert historical_lifecycle!("d93bb10a^", 230) == %{
             "status" => "validated",
             "nyquist_compliant" => "true",
             "wave_0_complete" => "true"
           }

    Enum.each(baseline["replay_targets"], fn target ->
      assert historical_lifecycle!(target["source_commit"], target["phase"]) ==
               target["expected_lifecycle"]

      assert lifecycle!(target["staged_baseline_path"]) == target["current_expected_lifecycle"]
    end)

    assert baseline["claim_limit"] ==
             "This committed replay proves a bounded forward lifecycle transition; it cannot authenticate an earlier LLM invocation or retroactively authenticate disputed 2026-08-04 edits."
  end

  @tag :validation_replay_recovery
  test "recovery ledger pins the accepted mixed Phase 231 validator boundary" do
    baseline = validation_replay_baseline!()

    assert baseline["planning_anchor_sha"] == "4980446683c5badf3f75f38b00b7960c05aad5e0"
    assert baseline["red_only_commit_sha"] == "814b778336fce5a1b927dcad8d1cb844870301ae"
    assert baseline["task_1_predecessor_sha"] == "f4f1c8674d77b25cba7ed832062d8e91b8795a3b"

    assert direct_parent!(baseline["red_only_commit_sha"]) == baseline["planning_anchor_sha"]
    assert direct_parent!(baseline["task_1_predecessor_sha"]) == baseline["red_only_commit_sha"]

    assert changed_paths!(baseline["red_only_commit_sha"]) == [
             "M\ttest/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs"
           ]

    assert changed_paths!(baseline["task_1_predecessor_sha"]) == [
             "M\t.planning/phases/236-closeout-evidence-reconciliation/236-04-PLAN.md"
           ]

    assert git_lines!("rev-list", [
             "--count",
             "#{baseline["planning_anchor_sha"]}..#{baseline["task_1_predecessor_sha"]}"
           ]) == ["2"]

    recovery = baseline["phase_231_recovery"]
    assert recovery["validator_commit_sha"] == "fe8e4305cbfa1ede8bd2c0424202204b9f93f030"
    assert direct_parent!(recovery["validator_commit_sha"]) == recovery["parent_sha"]
    assert recovery["classification"] =~ "successful canonical"
    assert recovery["classification"] =~ "mixed"
    assert recovery["classification"] =~ "not an isolated validator commit"

    assert changed_paths!(recovery["validator_commit_sha"]) ==
             recovery["changed_paths_name_status"]

    Enum.each(recovery["protected_blob_ids"], fn {path, blob} ->
      assert git!("rev-parse", "#{recovery["validator_commit_sha"]}:#{path}") == blob
    end)

    assert historical_lifecycle!(recovery["parent_sha"], 231) == %{
             "status" => "draft",
             "nyquist_compliant" => "false",
             "wave_0_complete" => "false"
           }

    assert historical_lifecycle!(recovery["validator_commit_sha"], 231) == %{
             "status" => "validated",
             "nyquist_compliant" => "true",
             "wave_0_complete" => "true"
           }

    phase_232 = baseline["phase_232_recovery"]
    assert phase_232["parent_sha"] == direct_parent!(phase_232["validator_commit_sha"])

    assert changed_paths!(phase_232["validator_commit_sha"]) ==
             phase_232["changed_paths_name_status"]

    assert historical_lifecycle!(phase_232["parent_sha"], 232) == phase_232["before_lifecycle"]

    assert historical_lifecycle!(phase_232["validator_commit_sha"], 232) ==
             phase_232["after_lifecycle"]

    assert historical_sha256!(phase_232["validator_commit_sha"], validation_path!(232)) ==
             phase_232["after_sha256"]

    assert historical_retained_body_sha256!(
             phase_232["validator_commit_sha"],
             validation_path!(232)
           ) ==
             Enum.find(baseline["replay_targets"], &(&1["phase"] == 232))["retained_body_sha256"]

    assert lifecycle!(
             ".planning/phases/232-playwright-economics-authenticate-once-then-shard/232-VALIDATION.md"
           ) == phase_232["after_lifecycle"]

    phase_234 = baseline["phase_234_recovery"]
    assert phase_234["parent_sha"] == direct_parent!(phase_234["validator_commit_sha"])

    assert changed_paths!(phase_234["validator_commit_sha"]) ==
             phase_234["changed_paths_name_status"]

    assert historical_lifecycle!(phase_234["parent_sha"], 234) == phase_234["before_lifecycle"]

    assert historical_lifecycle!(phase_234["validator_commit_sha"], 234) ==
             phase_234["after_lifecycle"]

    assert historical_sha256!(phase_234["validator_commit_sha"], validation_path!(234)) ==
             phase_234["after_sha256"]

    assert historical_retained_body_sha256!(
             phase_234["validator_commit_sha"],
             validation_path!(234)
           ) ==
             Enum.find(baseline["replay_targets"], &(&1["phase"] == 234))["retained_body_sha256"]

    assert lifecycle!(
             ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VALIDATION.md"
           ) == phase_234["after_lifecycle"]

    assert baseline["claim_limit"] =~ "cannot authenticate an earlier LLM invocation"
  end

  @tag :audit_input_snapshot
  test "audit input snapshot freezes every workflow source class and resolved v1.47 member" do
    snapshot =
      @root
      |> Path.join(
        ".planning/phases/236-closeout-evidence-reconciliation/236-AUDIT-INPUT-SNAPSHOT.json"
      )
      |> File.read!()
      |> :json.decode()

    paths = Enum.map(snapshot["files"], & &1["path"])

    required = [
      "AGENTS.md",
      ".planning/PROJECT.md",
      ".planning/STATE.md",
      ".planning/ROADMAP.md",
      ".planning/REQUIREMENTS.md",
      ".planning/config.json",
      ".planning/phases/236-closeout-evidence-reconciliation/236-04-SUMMARY.md"
    ]

    assert Enum.all?(required, &(&1 in paths))
    assert Enum.map(snapshot["members"], & &1["phase"]) == Enum.to_list(230..235)
    assert Enum.any?(paths, &String.ends_with?(&1, "230-VERIFICATION.md"))
    assert Enum.any?(paths, &String.ends_with?(&1, "235-VALIDATION.md"))
    assert Enum.any?(snapshot["resolvers"], &(&1["command"] == "init.milestone-op"))

    assert Enum.any?(
             snapshot["resolvers"],
             &(&1["command"] == "loop render-hooks verify:post --raw")
           )

    assert "It does not invoke an audit or cryptographically authenticate an LLM or skill invocation." in snapshot[
             "claim_limits"
           ]
  end

  @tag :audit_output_snapshot
  test "canonical audit output remains source-bound, complete, and bounded in provenance" do
    output =
      @root
      |> Path.join(
        ".planning/phases/236-closeout-evidence-reconciliation/236-AUDIT-OUTPUT-SNAPSHOT.json"
      )
      |> File.read!()
      |> :json.decode()

    assert output["result"] == "compliant"

    assert output["scores"] == %{
             "requirements" => "24/24",
             "phases" => "6/6",
             "integration" => "8/8",
             "flows" => "7/7"
           }

    assert output["nyquist"] == %{
             "compliant_phases" => Enum.to_list(230..235),
             "partial_phases" => [],
             "not_validated_phases" => [],
             "missing_phases" => [],
             "overall" => "compliant"
           }

    assert output["gaps"] == %{"requirements" => [], "integration" => [], "flows" => []}
    assert output["claim_limit"] =~ "cannot cryptographically establish LLM identity"
    audit = File.read!(Path.join(@root, ".planning/v1.47-v1.47-MILESTONE-AUDIT.md"))
    assert sha256!(".planning/v1.47-v1.47-MILESTONE-AUDIT.md") == output["audit_sha256"]
    assert audit =~ "status: tech_debt"
    assert audit =~ "The milestone audit has no closure gap"
  end

  defp summary_contents do
    @summary_directories
    |> Enum.flat_map(&Path.wildcard(Path.join(@root, &1 <> "/*-SUMMARY.md")))
    |> Map.new(fn path ->
      {Path.basename(path, "-SUMMARY.md"), File.read!(path)}
    end)
  end

  defp validate_summary_ownership!(summaries) do
    ownership =
      Map.new(summaries, fn {summary, body} ->
        {summary, completed_ids!(body, summary in Map.values(@summary_ownership))}
      end)

    expected_target_declarations =
      @summary_ownership
      |> Enum.group_by(fn {_id, summary} -> summary end, fn {id, _summary} -> id end)
      |> Map.new(fn {summary, ids} -> {summary, Enum.sort(ids)} end)

    target_declarations =
      ownership
      |> Map.take(Map.values(@summary_ownership))
      |> Map.new(fn {summary, ids} -> {summary, Enum.sort(ids)} end)

    declared_target_ownership =
      Enum.reduce(ownership, %{}, fn {summary, ids}, declared ->
        Enum.reduce(ids, declared, fn id, acc ->
          if Map.has_key?(@summary_ownership, id),
            do: Map.update(acc, id, [summary], &[summary | &1]),
            else: acc
        end)
      end)
      |> Map.new(fn {id, summaries} -> {id, Enum.sort(summaries)} end)

    expected_inverted_ownership =
      Map.new(@summary_ownership, fn {id, summary} -> {id, [summary]} end)

    unless target_declarations == expected_target_declarations and
             declared_target_ownership == expected_inverted_ownership do
      raise ArgumentError, "SUMMARY ownership must exactly match the D-01 declaration map"
    end

    :ok
  end

  defp completed_ids!(summary, required?) do
    with [frontmatter] <- Regex.run(~r/\A---\n(.*?)\n---/s, summary, capture: :all_but_first) do
      fields =
        Regex.scan(~r/^requirements-completed:\s*\[([^\]]*)\]\s*$/m, frontmatter,
          capture: :all_but_first
        )

      case fields do
        [[ids]] ->
          ids |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

        [] when not required? ->
          []

        [] ->
          raise ArgumentError, "SUMMARY is missing a narrow requirements-completed field"

        _ ->
          raise ArgumentError,
                "SUMMARY must contain exactly one narrow requirements-completed field"
      end
    else
      _ -> raise ArgumentError, "SUMMARY is missing frontmatter"
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

    assert_three_source_support!(requirements)
    :ok
  end

  defp traceability_rows(requirements) do
    Regex.scan(~r/^\| ([A-Z]+-\d+) \| (Phase \d+) \| (.+) \|$/m, requirements,
      capture: :all_but_first
    )
  end

  defp assert_three_source_support!(requirements) do
    Enum.each(@reconciled_ids, fn id ->
      %{
        verification_path: verification_path,
        verification_row: verification_row,
        contract_path: contract_path,
        contract_test: contract_test
      } =
        Map.fetch!(@three_source_support, id)

      verification = File.read!(Path.join(@root, verification_path))
      contract = File.read!(Path.join(@root, contract_path))

      unless requirements =~ "- [x] **#{id}**" do
        raise ArgumentError, "checked requirement source is incomplete for #{id}"
      end

      unless occurrence_count(verification, verification_row) == 1 do
        raise ArgumentError, "verification row source is incomplete for #{id}"
      end

      unless contract =~ "test \"#{contract_test}\" do" do
        raise ArgumentError, "deterministic contract source is incomplete for #{id}"
      end
    end)
  end

  defp occurrence_count(text, substring), do: length(String.split(text, substring)) - 1

  defp sha256!(path) do
    path
    |> then(&Path.join(@root, &1))
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp validation_replay_baseline! do
    @root
    |> Path.join(
      ".planning/phases/236-closeout-evidence-reconciliation/236-VALIDATION-REPLAY-BASELINE.json"
    )
    |> File.read!()
    |> Jason.decode!()
  end

  defp git!(command, argument) when is_binary(argument), do: git!(command, [argument])

  defp git!(command, arguments) when is_list(arguments) do
    {output, 0} = System.cmd("git", [command | arguments], cd: @root)
    String.trim(output)
  end

  defp git_lines!(command, arguments) do
    command |> git!(arguments) |> String.split("\n", trim: true)
  end

  defp direct_parent!(commit), do: git!("rev-parse", "#{commit}^")

  defp changed_paths!(commit),
    do: git_lines!("diff-tree", ["--no-commit-id", "--name-status", "-r", commit])

  defp historical_lifecycle!(commit, phase) do
    path = validation_path!(phase)

    {contents, 0} = System.cmd("git", ["show", "#{commit}:#{path}"], cd: @root)
    lifecycle_from_contents!(contents)
  end

  defp historical_sha256!(commit, path) do
    {contents, 0} = System.cmd("git", ["show", "#{commit}:#{path}"], cd: @root)

    contents
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp validation_path!(phase),
    do: ".planning/phases/#{phase_directory!(phase)}/#{phase}-VALIDATION.md"

  defp lifecycle!(path) do
    @root |> Path.join(path) |> File.read!() |> lifecycle_from_contents!()
  end

  defp lifecycle_from_contents!(contents) do
    fields = frontmatter!(contents)

    Map.take(fields, ["status", "nyquist_compliant", "wave_0_complete"])
  end

  defp historical_retained_body_sha256!(commit, path) do
    {contents, 0} = System.cmd("git", ["show", "#{commit}:#{path}"], cd: @root)

    contents
    |> retained_body!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp frontmatter!(contents) do
    with [frontmatter] <- Regex.run(~r/\A---\n(.*?)\n---\n/s, contents, capture: :all_but_first) do
      frontmatter
      |> String.split("\n", trim: true)
      |> Enum.reduce(%{}, fn line, fields ->
        case String.split(line, ": ", parts: 2) do
          [key, value] -> Map.put(fields, key, value)
          _ -> fields
        end
      end)
    else
      _ -> raise ArgumentError, "validation artifact is missing first YAML frontmatter"
    end
  end

  defp retained_body!(contents) do
    case Regex.run(~r/\A---\n.*?\n---\n(.*)\z/s, contents, capture: :all_but_first) do
      [body] -> body
      _ -> raise ArgumentError, "validation artifact is missing retained body"
    end
  end

  defp phase_directory!(230), do: "230-tier-1-critical-path-reclamation"
  defp phase_directory!(231), do: "231-gate-honesty-nightly-revival"
  defp phase_directory!(232), do: "232-playwright-economics-authenticate-once-then-shard"
  defp phase_directory!(234), do: "234-hygiene-supply-chain-and-contributor-dx"
end
