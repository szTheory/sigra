defmodule Sigra.Planning.Phase235Fast01SourceCompleteContractTest do
  use ExUnit.Case, async: true

  @workflow ".github/workflows/fast-01-gap-closure-evidence.yml"
  @collector "scripts/ci/capture-fast-01-gap-closure.sh"
  @verifier "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh"
  @correlation ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json"

  @correlation_keys ~w(schema_version status repository protected_main readiness rate_limit workflow_id protected_sha projection pre_dispatch dispatch_not_before)
  @forbidden_preflight_keys ~w(post_dispatch selected candidate_count watcher subject attestation)
  @protected_blob_files ~w(scripts/ci/ci-run-metrics.sh scripts/ci/ci-run-metrics.test.sh scripts/ci/capture-fast-01-gap-closure.sh scripts/ci/capture-fast-01-gap-closure.test.sh .github/workflows/fast-01-gap-closure-evidence.yml scripts/ci/verify-fast-01-source-complete-attestation-offline.sh test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs)

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

  test "reversible dispatch preflight is complete and ready for exact authorization" do
    receipt = File.read!(@correlation) |> Jason.decode!()

    assert :ok = validate_preflight(receipt)
  end

  test "preflight contract rejects identity, readiness, rate, and projection mutations with named diagnostics" do
    receipt = File.read!(@correlation) |> Jason.decode!()

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

  defp sha?(value), do: is_binary(value) and Regex.match?(~r/^[0-9a-f]{40}$/, value)

  defp utc?(value) when is_binary(value) do
    match?({:ok, %DateTime{}, 0}, DateTime.from_iso8601(value)) and String.ends_with?(value, "Z")
  end

  defp utc?(_), do: false
  defp parse_utc!(value), do: elem(DateTime.from_iso8601(value), 1)
end
