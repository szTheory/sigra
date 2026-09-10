defmodule Sigra.Planning.Phase235Fast01SourceCompleteContractTest do
  use ExUnit.Case, async: false

  @workflow ".github/workflows/fast-01-gap-closure-evidence.yml"
  @collector "scripts/ci/capture-fast-01-gap-closure.sh"
  @verifier "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh"
  @correlation ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json"
  @requirements ".planning/REQUIREMENTS.md"
  @residual ".planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md"
  @seed ".planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md"
  @milestone_arc ".planning/MILESTONE-ARC.md"

  @source_complete_fragments [
    "2026-08-03T21:37:08Z",
    "54c33e904155a454255952666711c882afdd06e4",
    "2026-09-09T12:22:29Z",
    "n=52",
    "469 seconds",
    "https://github.com/szTheory/sigra/actions/runs/34350618761",
    "235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json",
    "235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.attestation.jsonl",
    "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh",
    "source_complete_offline_attestation_verified",
    "FAST-01 Complete"
  ]

  @correlation_keys ~w(schema_version status repository protected_main readiness rate_limit workflow_id protected_sha projection pre_dispatch dispatch_not_before)
  @dispatched_correlation_keys @correlation_keys ++ ~w(post_dispatch selected candidate_count)
  @forbidden_preflight_keys ~w(post_dispatch selected candidate_count watcher subject attestation)
  @protected_blob_files ~w(scripts/ci/ci-run-metrics.sh scripts/ci/ci-run-metrics.test.sh scripts/ci/capture-fast-01-gap-closure.sh scripts/ci/capture-fast-01-gap-closure.test.sh .github/workflows/fast-01-gap-closure-evidence.yml scripts/ci/verify-fast-01-source-complete-attestation-offline.sh test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs)

  test "offline verifier paths remain serialized with fail-closed Linux cleanup" do
    source = File.read!(__ENV__.file)

    module_header =
      source
      |> String.split("\n")
      |> Enum.take(3)
      |> Enum.join("\n")

    assert module_header =~ "use ExUnit.Case, async: false"
    refute module_header =~ "use ExUnit.Case, async: true"

    assert length(Regex.scan(~r/run_offline_verifier\(@verifier\)/, source)) == 2

    assert source =~
             ~s|{:unix, :linux} -> System.cmd("sudo", ["-n", "bash", path], stderr_to_stdout: true)|

    assert source =~ ~s|_ -> System.cmd("bash", [path], stderr_to_stdout: true)|

    assert source =~
             ~s|System.cmd("bash", [@verifier, "--semantic-fixture", path], stderr_to_stdout: true)|
  end

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

  test "offline verifier is fixed-path, network denied, and pinned to the retained subject" do
    verifier = File.read!(@verifier)

    assert verifier =~ "235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json"
    assert verifier =~ "deny network"
    assert verifier =~ ~s("$GH_BIN" attestation verify)
    refute verifier =~ ~s(SUBJECT_DIGEST="UNSET_PLAN_17)
    refute verifier =~ ~s(TRUSTED_ROOT_DIGEST="UNSET_PLAN_17)
    refute verifier =~ ~s(EXPECTED_WORKFLOW_SHA="UNSET_PLAN_17)
    refute verifier =~ ~s(EXPECTED_ENDPOINT="UNSET_PLAN_17)
    assert verifier =~ "a5f4f6d5335755fcac14e9de8827f47f2b04ad3a143df4b6f283ebfc20853594"
    assert verifier =~ "65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c"
    assert verifier =~ "158aca14b11de13cbc5ab2fdea1bff790cc7ab29"
    assert verifier =~ "2026-09-09T12:22:29Z"
    assert verifier =~ "source_collection"
    assert verifier =~ "instrument_receipt"
  end

  test "retained source pages independently reproduce the authoritative wall result" do
    subject =
      ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json"
      |> File.read!()
      |> Jason.decode!()

    assert :ok = validate_subject(subject)
  end

  test "semantic fixture preserves literal conclusions and strict wall semantics" do
    fixture = semantic_fixture()
    path = write_semantic_fixture!(fixture)

    {banner, 0} =
      System.cmd("bash", [@verifier, "--semantic-fixture", path], stderr_to_stdout: true)

    assert banner =~ "source_complete_semantic_fixture_verified"
    assert Enum.map(fixture["runs"], & &1["run_id"]) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    assert fixture["statistics"]["p50_seconds"] == 719

    assert fixture["statistics"]["outcomes"] == %{
             "cancelled" => 2,
             "failure" => 3,
             "success" => 5
           }

    collapsed_outcomes = %{"failure" => 5, "success" => 5}

    collapsed =
      fixture
      |> put_in(["statistics", "outcomes"], collapsed_outcomes)
      |> put_in(["instrument_receipt", "output", "statistics", "outcomes"], collapsed_outcomes)
      |> write_semantic_fixture!()

    {collapsed_output, collapsed_status} =
      System.cmd("bash", [@verifier, "--semantic-fixture", collapsed], stderr_to_stdout: true)

    assert collapsed_status != 0
    assert collapsed_output =~ "source_first_semantic_validation_failed"

    boundary =
      fixture
      |> put_in(
        ["source_collection", "pages", Access.at(0), "runs", Access.at(5), "updated_at"],
        "2026-08-04T00:12:00Z"
      )
      |> put_in(
        ["source_collection", "pages", Access.at(0), "runs", Access.at(6), "updated_at"],
        "2026-08-04T00:12:00Z"
      )
      |> put_in(["runs", Access.at(5), "wall_seconds"], 720)
      |> put_in(["runs", Access.at(6), "wall_seconds"], 720)
      |> put_in(["instrument_receipt", "output", "runs", Access.at(5), "wall_seconds"], 720)
      |> put_in(["instrument_receipt", "output", "runs", Access.at(6), "wall_seconds"], 720)
      |> put_in(["statistics", "mean_seconds"], 564)
      |> put_in(["statistics", "p50_seconds"], 720)
      |> put_in(["instrument_receipt", "output", "statistics", "mean_seconds"], 564)
      |> put_in(["instrument_receipt", "output", "statistics", "p50_seconds"], 720)
      |> write_semantic_fixture!()

    {boundary_output, boundary_status} =
      System.cmd("bash", [@verifier, "--semantic-fixture", boundary], stderr_to_stdout: true)

    assert boundary_status != 0
    assert boundary_output =~ "source_first_semantic_validation_failed"
  end

  test "semantic fixture parsing stays isolated from the authenticated default path" do
    path = semantic_fixture() |> write_semantic_fixture!()

    assert {"source_complete_semantic_fixture_verified\n", 0} =
             System.cmd("bash", [@verifier, "--semantic-fixture", path], stderr_to_stdout: true)

    assert {"source_complete_offline_attestation_verified\n", 0} =
             run_offline_verifier(@verifier)

    malformed_arguments = [
      {["--unknown"], "unknown_argument:--unknown"},
      {["--semantic-fixture"], "missing_semantic_fixture_path"},
      {["--semantic-fixture", ""], "empty_semantic_fixture_path"},
      {["--semantic-fixture", path, "extra"], "extra_arguments_after_semantic_fixture"}
    ]

    for {arguments, diagnostic} <- malformed_arguments do
      {output, status} = System.cmd("bash", [@verifier | arguments], stderr_to_stdout: true)

      assert status != 0
      assert output =~ diagnostic
      refute output =~ "source_complete_semantic_fixture_verified"
      refute output =~ "source_complete_offline_attestation_verified"
    end
  end

  test "authenticated strict pass is reconciled exactly into FAST-01 and its residual" do
    {banner, 0} = run_offline_verifier(@verifier)
    assert banner =~ "source_complete_offline_attestation_verified"

    requirements = File.read!(@requirements)
    residual = File.read!(@residual)

    assert requirements =~ "- [x] **FAST-01**"
    assert requirements =~ "| FAST-01 | Phase 235 | Complete ("
    assert_exact_source_complete_record(requirements)
    assert_exact_source_complete_record(residual)

    for historical <- ["772", "724", "466", "692", "148", "470"] do
      assert residual =~ historical, "missing historical FAST fact: #{historical}"
    end
  end

  test "strict reconciliation refuses undersized, unauthenticated, contradictory, and boundary results" do
    assert {:ok, :complete} =
             reconcile_fixture(%{verified?: true, n: 10, p50: 719, agreement?: true})

    assert {:ok, :gaps_found} =
             reconcile_fixture(%{verified?: true, n: 10, p50: 720, agreement?: true})

    assert {:error, :verifier_required} =
             reconcile_fixture(%{verified?: false, n: 52, p50: 469, agreement?: true})

    assert {:error, :population_undersized} =
             reconcile_fixture(%{verified?: true, n: 9, p50: 469, agreement?: true})

    assert {:error, :source_disagreement} =
             reconcile_fixture(%{verified?: true, n: 52, p50: 469, agreement?: false})
  end

  test "SEED-005 and CI-PERF carry the identical authenticated terminal pass" do
    seed = File.read!(@seed)
    milestone_arc = File.read!(@milestone_arc)

    assert_exact_source_complete_record(seed)
    assert_exact_source_complete_record(milestone_arc)

    for record <- [seed, milestone_arc],
        historical <- ["772", "724", "466", "692", "148", "470"] do
      assert record =~ historical, "terminal record lost historical FAST fact: #{historical}"
    end
  end

  test "terminal record fixtures reject pass/miss contradictions" do
    pass = "FAST-01 Complete; n=52; p50=469; disposition=pass"
    miss = "FAST-01 Gaps Found; n=10; p50=720; disposition=miss"

    assert :ok = validate_record_fixtures([pass, pass], :complete, 52, 469)
    assert :ok = validate_record_fixtures([miss, miss], :gaps_found, 10, 720)

    assert {:error, :record_contradiction} =
             validate_record_fixtures([pass, miss], :complete, 52, 469)

    assert {:error, :record_contradiction} =
             validate_record_fixtures(
               [pass, "FAST-01 Complete; n=51; p50=469; disposition=pass"],
               :complete,
               52,
               469
             )
  end

  test "source replay rejects page, timestamp, event, identity, order, median, and boundary mutations" do
    subject =
      ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json"
      |> File.read!()
      |> Jason.decode!()

    mutations = [
      {"source_pages_invalid", put_in(subject, ["source_collection", "exhausted"], false)},
      {"source_pages_invalid",
       put_in(subject, ["source_collection", "pages", Access.at(0), "page"], 2)},
      {"run_chronology_invalid",
       put_in(
         subject,
         ["source_collection", "pages", Access.at(0), "runs", Access.at(0), "updated_at"],
         "2026-01-01T00:00:00Z"
       )},
      {"derived_runs_mismatch",
       put_in(
         subject,
         ["source_collection", "pages", Access.at(0), "runs", Access.at(0), "event"],
         "pull_request"
       )},
      {"source_identity_invalid",
       put_in(
         subject,
         ["source_collection", "pages", Access.at(0), "runs", Access.at(0), "run_id"],
         subject["runs"] |> hd() |> Map.fetch!("run_id")
       )},
      {"derived_runs_mismatch", update_in(subject, ["runs"], &Enum.reverse/1)},
      {"statistics_mismatch", put_in(subject, ["statistics", "p50_seconds"], 720)},
      {"window_invalid", put_in(subject, ["window", "endpoint"], "2026-08-03T21:37:07Z")}
    ]

    for {diagnostic, mutated} <- mutations do
      assert {:error, ^diagnostic} = validate_subject(mutated), diagnostic
    end
  end

  test "completed ownership proof and contributor topology remain immutable" do
    pins = %{
      ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.json" =>
        "022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244",
      ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json" =>
        "c667836535ae1141fe4419b6675777a6aa865dd99da528c33caa5ac16794a27e",
      ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.attestation.jsonl" =>
        "af49fd36b603adbdfdeb8698141cea2e8749c1edc3f9b88764e3465b6f84215f",
      ".planning/phases/235-terminal-ratification-measured-not-read/235-TRUSTED-ROOT.jsonl" =>
        "65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c",
      "scripts/ci/verify-terminal-ratification-attestation-offline.sh" =>
        "6c0805e0386186f017215ea7bf10bf450c9aafb68ef6742afa2f9e75b0463367",
      "CONTRIBUTING.md" => "33d045c1fe8940a050db76d087ab1e8b45020b404d2f122032c50c170d11760b"
    }

    for {path, expected} <- pins do
      actual = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
      assert actual == expected, "immutable digest drift: #{path}"
    end

    terminal =
      ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
      |> File.read!()
      |> Jason.decode!()

    assert length(get_in(terminal, ["ownership", "rows"])) == 93

    requirements = File.read!(@requirements)
    assert length(Regex.scan(~r/^- \[x\] \*\*GATE-05\*\*:/m, requirements)) == 1

    assert length(
             Regex.scan(
               ~r/^\| GATE-05 \| Phase 235 \| Complete \(protected run `30782184713`; 93-row execution proof\) \|$/m,
               requirements
             )
           ) == 1
  end

  test "reversible dispatch preflight is complete and ready for exact authorization" do
    receipt = File.read!(@correlation) |> Jason.decode!()

    preflight =
      receipt |> Map.take(@correlation_keys) |> Map.put("status", "ready_for_authorization")

    assert :ok = validate_preflight(preflight)
  end

  test "dispatched correlation selects exactly one protected-main run before watching" do
    receipt = File.read!(@correlation) |> Jason.decode!()

    assert :ok = validate_dispatched(receipt)
  end

  test "dispatched correlation rejects cardinality, identity, and boundary mutations" do
    receipt = File.read!(@correlation) |> Jason.decode!()

    if receipt["status"] == "dispatched" do
      mutations = [
        {"dispatched_keys_invalid", Map.delete(receipt, "post_dispatch")},
        {"candidate_count_invalid", Map.put(receipt, "candidate_count", 2)},
        {"post_projection_invalid",
         put_in(receipt, ["post_dispatch", Access.at(0), "workflow_id"], 0)},
        {"selected_run_invalid", put_in(receipt, ["selected", "id"], 342_727_466_47)},
        {"selected_sha_invalid",
         put_in(receipt, ["selected", "head_sha"], String.duplicate("0", 40))},
        {"selected_boundary_invalid",
         put_in(receipt, ["selected", "created_at"], "2026-09-09T01:00:00Z")}
      ]

      for {diagnostic, mutated} <- mutations do
        assert {:error, ^diagnostic} = validate_dispatched(mutated), diagnostic
      end
    else
      assert {:error, "dispatched_keys_invalid"} = validate_dispatched(receipt)
    end
  end

  test "preflight contract rejects identity, readiness, rate, and projection mutations with named diagnostics" do
    receipt =
      File.read!(@correlation)
      |> Jason.decode!()
      |> Map.take(@correlation_keys)
      |> Map.put("status", "ready_for_authorization")

    mutations = [
      {"unexpected_keys", Map.put(receipt, "selected", %{})},
      {"protected_merge_sha_invalid", put_in(receipt, ["protected_main", "merge_sha"], "bad")},
      {"protected_ancestry_unproven",
       put_in(receipt, ["protected_main", "ancestry_proven"], false)},
      {"protected_sha_mismatch", Map.put(receipt, "protected_sha", String.duplicate("0", 40))},
      {"protected_blob_set_invalid", put_in(receipt, ["protected_main", "blobs"], [])},
      {"protected_blob_mismatch",
       put_in(
         receipt,
         ["protected_main", "blobs", Access.at(0), "protected_blob"],
         String.duplicate("0", 40)
       )},
      {"readiness_authority_invalid", put_in(receipt, ["readiness", "authority"], "collector")},
      {"readiness_purpose_invalid",
       put_in(receipt, ["readiness", "purpose"], "terminal_verdict")},
      {"readiness_command_invalid", put_in(receipt, ["readiness", "command"], "echo nope")},
      {"readiness_population_undersized",
       put_in(receipt, ["readiness", "eligible_pr_run_count"], 9)},
      {"readiness_receipt_mismatch",
       put_in(receipt, ["readiness", "receipt", "eligible_pr_run_count"], 9)},
      {"rate_limit_budget_low", put_in(receipt, ["rate_limit", "core_remaining"], 250)},
      {"rate_limit_blocked", put_in(receipt, ["rate_limit", "http_status"], 429)},
      {"workflow_id_invalid", Map.put(receipt, "workflow_id", "workflow.yml")},
      {"projection_query_invalid", put_in(receipt, ["projection", "query"], "event=push")},
      {"projection_limit_invalid", put_in(receipt, ["projection", "limit"], 0)},
      {"projection_row_invalid",
       put_in(receipt, ["pre_dispatch", Access.at(0), "html_url"], "http://example.test/run")},
      {"projection_duplicate_run_id",
       Map.update!(receipt, "pre_dispatch", fn [first | _] = rows -> [first | rows] end)},
      {"dispatch_boundary_invalid", Map.put(receipt, "dispatch_not_before", "not-a-time")}
    ]

    for {diagnostic, mutated} <- mutations do
      assert {:error, ^diagnostic} = validate_preflight(mutated), diagnostic
    end
  end

  defp validate_preflight(receipt) do
    with :ok <- exact_keys(receipt),
         :ok <- protected_main(receipt),
         :ok <- readiness(receipt),
         :ok <- rate_limit(receipt),
         :ok <- workflow(receipt),
         :ok <- projection(receipt),
         :ok <- boundary(receipt) do
      :ok
    end
  end

  defp semantic_fixture do
    rows = [
      semantic_run(1, "success", 100),
      semantic_run(2, "failure", 200),
      semantic_run(3, "cancelled", 300),
      semantic_run(4, "success", 400),
      semantic_run(5, "failure", 500),
      semantic_run(7, "success", 719),
      semantic_run(6, "cancelled", 719),
      semantic_run(8, "success", 800),
      semantic_run(9, "failure", 900),
      semantic_run(10, "success", 1000)
    ]

    runs =
      rows
      |> Enum.map(fn row -> Map.put(row, "wall_seconds", wall_seconds(row)) end)
      |> Enum.sort_by(&{&1["wall_seconds"], &1["run_id"]})

    statistics = %{
      "mode" => "wall",
      "ordering" => "{wall_seconds, run_id}",
      "mean_seconds" => 563.8,
      "p50_seconds" => 719,
      "max_seconds" => 1000,
      "outcomes" => %{"cancelled" => 2, "failure" => 3, "success" => 5}
    }

    selected_poles = %{"median_run_id" => 6, "maximum_run_id" => 10}

    output = %{
      "runs" => runs,
      "eligible_pr_run_count" => 10,
      "statistics" => statistics,
      "selected_poles" => selected_poles,
      "verdict" => "pass",
      "status" => "measured",
      "diagnostics" => []
    }

    %{
      "schema_version" => "sigra.fast-01-source-complete-remeasurement/1",
      "authority" => "protected_main_attestation",
      "cutoff" => %{
        "sha" => "54c33e904155a454255952666711c882afdd06e4",
        "timestamp" => "2026-08-03T21:37:08Z"
      },
      "window" => %{"endpoint" => "2026-09-09T12:22:29Z"},
      "source_collection" => %{
        "resource" => "GET /repos/szTheory/sigra/actions/workflows/ci.yml/runs",
        "query" => %{
          "created" => "2026-08-03T21:37:08Z..2026-09-09T12:22:29Z",
          "per_page" => 100
        },
        "requested_pages" => [1, 2],
        "terminal_page" => 2,
        "exhausted" => true,
        "pages" => [
          %{"page" => 1, "returned_count" => 10, "runs" => rows},
          %{"page" => 2, "returned_count" => 0, "runs" => []}
        ]
      },
      "runs" => runs,
      "eligible_pr_run_count" => 10,
      "statistics" => statistics,
      "selected_poles" => selected_poles,
      "verdict" => "pass",
      "status" => "measured",
      "binding_poles" => nil,
      "instrument_receipt" => %{
        "mode" => "wall",
        "command" => "bash scripts/ci/ci-run-metrics.sh --source-pages fixture --mode wall",
        "output" => output
      }
    }
  end

  defp semantic_run(run_id, conclusion, wall_seconds) do
    %{
      "run_id" => run_id,
      "event" => "pull_request",
      "conclusion" => conclusion,
      "created_at" => "2026-08-04T00:00:00Z",
      "updated_at" =>
        DateTime.add(~U[2026-08-04 00:00:00Z], wall_seconds, :second) |> DateTime.to_iso8601()
    }
  end

  defp wall_seconds(run) do
    DateTime.diff(parse_utc!(run["updated_at"]), parse_utc!(run["created_at"]))
  end

  defp write_semantic_fixture!(fixture) do
    path =
      Path.join(
        System.tmp_dir!(),
        "phase-235-19-semantic-#{System.unique_integer([:positive, :monotonic])}.json"
      )

    File.write!(path, Jason.encode!(fixture))
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp validate_dispatched(receipt) do
    preflight =
      receipt |> Map.take(@correlation_keys) |> Map.put("status", "ready_for_authorization")

    post = receipt["post_dispatch"]
    selected = receipt["selected"] || %{}

    cond do
      Map.keys(receipt) |> Enum.sort() != Enum.sort(@dispatched_correlation_keys) or
          receipt["status"] != "dispatched" ->
        {:error, "dispatched_keys_invalid"}

      validate_preflight(preflight) != :ok ->
        {:error, "preflight_preservation_invalid"}

      receipt["candidate_count"] != 1 ->
        {:error, "candidate_count_invalid"}

      not is_list(post) or Enum.any?(post, &(not projection_row?(&1, receipt))) or
          Enum.uniq_by(post, & &1["run_id"]) != post ->
        {:error, "post_projection_invalid"}

      Map.keys(selected) |> Enum.sort() != ~w(created_at head_sha html_url id) or
          selected["html_url"] !=
            "https://github.com/szTheory/sigra/actions/runs/#{selected["id"]}" ->
        {:error, "selected_run_invalid"}

      selected["head_sha"] != receipt["protected_sha"] ->
        {:error, "selected_sha_invalid"}

      not utc?(selected["created_at"]) or
          DateTime.compare(
            parse_utc!(selected["created_at"]),
            parse_utc!(receipt["dispatch_not_before"])
          ) == :lt ->
        {:error, "selected_boundary_invalid"}

      true ->
        pre_ids = MapSet.new(receipt["pre_dispatch"], & &1["run_id"])

        candidates =
          Enum.filter(post, fn row ->
            not MapSet.member?(pre_ids, row["run_id"]) and
              row["workflow_id"] == receipt["workflow_id"] and
              row["event"] == "workflow_dispatch" and row["head_branch"] == "main" and
              row["head_sha"] == receipt["protected_sha"] and
              DateTime.compare(
                parse_utc!(row["created_at"]),
                parse_utc!(receipt["dispatch_not_before"])
              ) != :lt
          end)

        if length(candidates) == 1 and hd(candidates)["run_id"] == selected["id"] and
             hd(candidates)["html_url"] == selected["html_url"] and
             hd(candidates)["created_at"] == selected["created_at"] do
          :ok
        else
          {:error, "selected_run_invalid"}
        end
    end
  end

  defp validate_subject(subject) do
    source = subject["source_collection"] || %{}
    pages = source["pages"] || []
    cutoff = get_in(subject, ["cutoff", "timestamp"])
    endpoint = get_in(subject, ["window", "endpoint"])

    cond do
      not utc?(cutoff) or not utc?(endpoint) or parse_utc!(endpoint) < parse_utc!(cutoff) ->
        {:error, "window_invalid"}

      source["exhausted"] != true or pages == [] or
        Enum.map(pages, & &1["page"]) != Enum.to_list(1..length(pages)) or
        source["requested_pages"] != Enum.to_list(1..length(pages)) or
        source["terminal_page"] != length(pages) or
        List.last(pages)["returned_count"] != 0 or
          Enum.any?(pages, &(&1["returned_count"] != length(&1["runs"]))) ->
        {:error, "source_pages_invalid"}

      true ->
        raw = Enum.flat_map(pages, & &1["runs"])
        raw_ids = Enum.map(raw, & &1["run_id"])

        cond do
          Enum.uniq(raw_ids) != raw_ids ->
            {:error, "source_identity_invalid"}

          Enum.any?(raw, fn run ->
            parse_utc!(run["updated_at"]) < parse_utc!(run["created_at"])
          end) ->
            {:error, "run_chronology_invalid"}

          true ->
            oracle =
              raw
              |> Enum.filter(fn run ->
                run["event"] == "pull_request" and is_binary(run["conclusion"]) and
                  run["created_at"] >= cutoff and run["created_at"] <= endpoint
              end)
              |> Enum.map(fn run ->
                Map.put(
                  run,
                  "wall_seconds",
                  DateTime.diff(parse_utc!(run["updated_at"]), parse_utc!(run["created_at"]))
                )
              end)
              |> Enum.sort_by(&{&1["wall_seconds"], &1["run_id"]})

            n = length(oracle)
            median = Enum.at(oracle, div(n, 2))
            maximum = List.last(oracle)
            verdict = if median["wall_seconds"] < 720, do: "pass", else: "miss"

            cond do
              n < 10 ->
                {:error, "source_membership_invalid"}

              oracle != subject["runs"] or
                  oracle != get_in(subject, ["instrument_receipt", "output", "runs"]) ->
                {:error, "derived_runs_mismatch"}

              subject["eligible_pr_run_count"] != n or subject["verdict"] != verdict or
                get_in(subject, ["statistics", "p50_seconds"]) != median["wall_seconds"] or
                get_in(subject, ["statistics", "max_seconds"]) != maximum["wall_seconds"] or
                  subject["selected_poles"] != %{
                    "median_run_id" => median["run_id"],
                    "maximum_run_id" => maximum["run_id"]
                  } ->
                {:error, "statistics_mismatch"}

              true ->
                :ok
            end
        end
    end
  rescue
    _ -> {:error, "source_membership_invalid"}
  end

  defp exact_keys(receipt) do
    if Map.keys(receipt) |> Enum.sort() == Enum.sort(@correlation_keys) and
         Enum.all?(@forbidden_preflight_keys, &(not Map.has_key?(receipt, &1))) and
         receipt["schema_version"] == "sigra.fast-01-dispatch-correlation/1" and
         receipt["status"] == "ready_for_authorization" and
         receipt["repository"] == "szTheory/sigra" do
      :ok
    else
      {:error, "unexpected_keys"}
    end
  end

  defp protected_main(receipt) do
    protected = receipt["protected_main"] || %{}
    merge_sha = protected["merge_sha"]

    cond do
      not sha?(merge_sha) ->
        {:error, "protected_merge_sha_invalid"}

      protected["ancestry_proven"] != true ->
        {:error, "protected_ancestry_unproven"}

      receipt["protected_sha"] != protected["fetched_sha"] ->
        {:error, "protected_sha_mismatch"}

      not sha?(receipt["protected_sha"]) ->
        {:error, "protected_sha_mismatch"}

      not is_list(protected["blobs"]) or length(protected["blobs"]) != 7 ->
        {:error, "protected_blob_set_invalid"}

      Enum.map(protected["blobs"], & &1["file"]) |> Enum.sort() !=
          Enum.sort(@protected_blob_files) ->
        {:error, "protected_blob_set_invalid"}

      Enum.any?(protected["blobs"], fn blob ->
        Map.keys(blob) |> Enum.sort() != ~w(file merge_blob protected_blob) or
          not sha?(blob["merge_blob"]) or blob["merge_blob"] != blob["protected_blob"]
      end) ->
        {:error, "protected_blob_mismatch"}

      true ->
        :ok
    end
  end

  defp readiness(receipt) do
    readiness = receipt["readiness"] || %{}
    instrument = readiness["receipt"] || %{}

    cond do
      readiness["authority"] != "scripts/ci/ci-run-metrics.sh" ->
        {:error, "readiness_authority_invalid"}

      readiness["purpose"] != "dispatch_predicate_only" ->
        {:error, "readiness_purpose_invalid"}

      not is_binary(readiness["command"]) or
        not String.contains?(readiness["command"], "scripts/ci/ci-run-metrics.sh") or
          not String.contains?(readiness["command"], "--mode wall") ->
        {:error, "readiness_command_invalid"}

      not is_integer(readiness["eligible_pr_run_count"]) or
          readiness["eligible_pr_run_count"] < 10 ->
        {:error, "readiness_population_undersized"}

      instrument["eligible_pr_run_count"] != readiness["eligible_pr_run_count"] or
        instrument["mode"] != "wall" or instrument["event"] != "pull_request" or
        instrument["schema_version"] != "sigra.ci-run-metrics/source-pages-v1" or
        instrument["status"] != "measured" or
          Enum.any?(instrument["runs"], fn run ->
            run["url"] != "https://github.com/szTheory/sigra/actions/runs/#{run["run_id"]}"
          end) ->
        {:error, "readiness_receipt_mismatch"}

      true ->
        :ok
    end
  end

  defp rate_limit(receipt) do
    rate = receipt["rate_limit"] || %{}

    cond do
      rate["http_status"] in [403, 429] ->
        {:error, "rate_limit_blocked"}

      rate["http_status"] != 200 ->
        {:error, "rate_limit_status_invalid"}

      not is_integer(rate["core_remaining"]) or rate["core_remaining"] <= 250 ->
        {:error, "rate_limit_budget_low"}

      not utc?(rate["observed_at"]) or not utc?(rate["core_reset_at"]) ->
        {:error, "rate_limit_time_invalid"}

      DateTime.compare(parse_utc!(rate["core_reset_at"]), parse_utc!(rate["observed_at"])) == :lt ->
        {:error, "rate_limit_time_invalid"}

      not is_nil(rate["retry_after"]) and not utc?(rate["retry_after"]) ->
        {:error, "rate_limit_retry_invalid"}

      true ->
        :ok
    end
  end

  defp workflow(receipt) do
    if is_integer(receipt["workflow_id"]) and receipt["workflow_id"] > 0 do
      :ok
    else
      {:error, "workflow_id_invalid"}
    end
  end

  defp projection(receipt) do
    projection = receipt["projection"] || %{}
    rows = receipt["pre_dispatch"]

    cond do
      projection["resource"] != "GET /repos/szTheory/sigra/actions/workflows/{workflow_id}/runs" or
          projection["query"] != "branch=main&event=workflow_dispatch" ->
        {:error, "projection_query_invalid"}

      not is_integer(projection["limit"]) or projection["limit"] < 1 or projection["limit"] > 100 ->
        {:error, "projection_limit_invalid"}

      not is_list(rows) or Enum.any?(rows, &(not projection_row?(&1, receipt))) ->
        {:error, "projection_row_invalid"}

      Enum.uniq_by(rows, & &1["run_id"]) != rows ->
        {:error, "projection_duplicate_run_id"}

      true ->
        :ok
    end
  end

  defp projection_row?(row, receipt) do
    Map.keys(row) |> Enum.sort() ==
      ~w(conclusion created_at event head_branch head_sha html_url run_id status workflow_id) and
      is_integer(row["run_id"]) and row["workflow_id"] == receipt["workflow_id"] and
      row["html_url"] == "https://github.com/szTheory/sigra/actions/runs/#{row["run_id"]}" and
      row["event"] == "workflow_dispatch" and row["head_branch"] == "main" and
      sha?(row["head_sha"]) and
      row["status"] in ~w(queued in_progress completed pending requested waiting) and
      (is_nil(row["conclusion"]) or is_binary(row["conclusion"])) and utc?(row["created_at"])
  end

  defp boundary(receipt) do
    boundary = receipt["dispatch_not_before"]
    observed = get_in(receipt, ["rate_limit", "observed_at"])

    if utc?(boundary) and utc?(observed) and
         DateTime.compare(parse_utc!(boundary), parse_utc!(observed)) in [:eq, :gt] do
      :ok
    else
      {:error, "dispatch_boundary_invalid"}
    end
  end

  defp assert_exact_source_complete_record(record) do
    for fragment <- @source_complete_fragments do
      assert record =~ fragment, "source-complete closeout missing #{fragment}"
    end
  end

  defp reconcile_fixture(%{verified?: false}), do: {:error, :verifier_required}
  defp reconcile_fixture(%{n: n}) when n < 10, do: {:error, :population_undersized}
  defp reconcile_fixture(%{agreement?: false}), do: {:error, :source_disagreement}
  defp reconcile_fixture(%{p50: p50}) when p50 < 720, do: {:ok, :complete}
  defp reconcile_fixture(%{p50: _p50}), do: {:ok, :gaps_found}

  defp validate_record_fixtures(records, status, n, p50) do
    expected_status = if status == :complete, do: "FAST-01 Complete", else: "FAST-01 Gaps Found"

    expected_disposition =
      if status == :complete, do: "disposition=pass", else: "disposition=miss"

    if Enum.all?(records, fn record ->
         record =~ expected_status and record =~ "n=#{n}" and record =~ "p50=#{p50}" and
           record =~ expected_disposition
       end) do
      :ok
    else
      {:error, :record_contradiction}
    end
  end

  # GitHub-hosted Linux requires sudo for the verifier's network namespace.
  # Elevating the complete verifier keeps gh's state owned by its EXIT cleanup.
  defp run_offline_verifier(path) do
    case :os.type() do
      {:unix, :linux} -> System.cmd("sudo", ["-n", "bash", path], stderr_to_stdout: true)
      _ -> System.cmd("bash", [path], stderr_to_stdout: true)
    end
  end

  defp sha?(value), do: is_binary(value) and Regex.match?(~r/^[0-9a-f]{40}$/, value)

  defp utc?(value) when is_binary(value) do
    match?({:ok, %DateTime{}, 0}, DateTime.from_iso8601(value)) and String.ends_with?(value, "Z")
  end

  defp utc?(_), do: false
  defp parse_utc!(value), do: elem(DateTime.from_iso8601(value), 1)
end
