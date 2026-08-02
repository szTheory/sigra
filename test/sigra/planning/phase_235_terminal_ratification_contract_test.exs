defmodule Sigra.Planning.Phase235TerminalRatificationContractTest do
  use ExUnit.Case, async: true

  @ledger_path ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
  @workflow_path ".github/workflows/ci.yml"
  @contributing_path "CONTRIBUTING.md"
  @mix_path "mix.exs"
  @playwright_config_path "test/example/priv/playwright/playwright.config.ts"
  @playwright_package_path "test/example/priv/playwright/package.json"
  @inventory_path ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json"
  @cutoff_sha "6c57d7b4a22aa87a757a6f508f2cf4fdb414e40a"
  @top_level_keys MapSet.new(~w(schema_version topology_cutoff capture_endpoint baseline measurements ownership receipts verdict closeout))
  @events ~w(pull_request push schedule)

  test "the terminal ratification ledger is a captured, versioned ledger with an immutable cutoff" do
    ledger = ledger!()

    assert validate_ledger!(ledger) == :ok
    assert MapSet.new(Map.keys(ledger)) == @top_level_keys
    assert ledger["schema_version"] == "sigra.terminal-ratification/v1"
    assert ledger["topology_cutoff"]["source_commit_sha"] == @cutoff_sha
    assert ledger["topology_cutoff"]["committed_at"] == "2026-08-01T02:06:30Z"
    assert ledger["capture_endpoint"]["status"] == "captured"
    assert ledger["verdict"]["status"] == "measured"
    assert ledger["closeout"]["status"] == "pending_records_reconciliation"
  end

  test "baseline-compatible measurements preserve the committed seconds without recomputation" do
    assert ledger!()["baseline"] == %{
             "pull_request" => %{"n" => 21, "mean_seconds" => 1770, "p50_seconds" => 1638, "max_seconds" => 2502, "pass" => 17, "fail" => 4},
             "push" => %{"n" => 7, "mean_seconds" => 1830, "p50_seconds" => 1656, "max_seconds" => 2538, "pass" => 6, "fail" => 1},
             "schedule" => %{"n" => 9, "mean_seconds" => 1638, "p50_seconds" => 1626, "max_seconds" => 1764, "pass" => 0, "fail" => 9}
           }
  end

  test "library scaffold and golden ownership has one explicit executable row per terminal event" do
    ledger = ledger!()
    rows = Enum.filter(ledger["ownership"]["rows"], &(&1["family"] == "library_scaffold_golden"))

    assert Enum.map(rows, & &1["event"]) == @events

    for row <- rows do
      assert row["family"] == "library_scaffold_golden"
      assert row["after"]["direct_owner"] == "library_tests_shard"
      assert row["after"]["invocation"] == "MIX_ENV=test mix ci"
      assert row["after"]["terminal_aggregate"] == %{"id" => "library_tests", "name" => "Library tests"}
      assert row["receiver"] == "library_tests_shard"
      assert row["receipt"] == "phase_233_library_suite"
    end

    workflow = File.read!(@workflow_path)
    assert workflow =~ "library_tests_shard:"
    assert workflow =~ "Run contributor CI gate"
    assert workflow =~ "MIX_ENV=test mix ci"
    assert workflow =~ "name: Library tests"
  end

  test "complete ownership consumes the Phase 234 inventory without copying its lane model" do
    ledger = ledger!()
    inventory = @inventory_path |> File.read!() |> Jason.decode!()
    rows = ledger["ownership"]["rows"]

    assert ledger["ownership"]["source_inventory"] == %{
             "path" => @inventory_path,
             "schema_version" => "sigra.playwright-ownership/v1",
             "phase_235_gate_input" => true,
             "sha256" => inventory_sha256!()
           }

    inventory_specs = Enum.map(inventory["specs"], & &1["spec"])
    assert length(inventory_specs) == 20
    assert inventory_specs == Enum.sort(inventory_specs)

    assert Enum.map(rows, &row_key/1) == Enum.sort_by(rows, &row_key/1) |> Enum.map(&row_key/1)

    for spec <- inventory_specs do
      assert Enum.count(rows, &(&1["family"] == "playwright_spec" and &1["spec"] == spec)) == 3
    end

    for family <- required_non_playwright_families() do
      assert Enum.count(rows, &(&1["family"] == family)) == 3
    end
  end

  test "validation fails closed for malformed captured-window mutations" do
    ledger = ledger!()

    assert_raise ArgumentError, ~r/exact top-level keys/, fn ->
      validate_ledger!(Map.delete(ledger, "closeout"))
    end

    assert_raise ArgumentError, ~r/exact top-level keys/, fn ->
      validate_ledger!(Map.put(ledger, "extra", %{}))
    end

    assert_raise ArgumentError, ~r/cutoff SHA/, fn ->
      put_in(ledger, ["topology_cutoff", "source_commit_sha"], "short") |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/direct owner/, fn ->
      put_in(ledger, ["ownership", "rows", Access.at(0), "after", "direct_owner"], nil) |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/aggregate-only/, fn ->
      put_in(ledger, ["ownership", "rows", Access.at(0), "after", "direct_owner"], "library_tests") |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/captured wall measurement/, fn ->
      put_in(ledger, ["measurements", "pull_request", "status"], "pending") |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/missing ownership events/, fn ->
      update_in(ledger, ["ownership", "rows"], &Enum.drop(&1, 1)) |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/duplicate ownership row/, fn ->
      update_in(ledger, ["ownership", "rows"], &[hd(&1) | &1]) |> validate_ledger!()
    end

    playwright_row_index = Enum.find_index(ledger["ownership"]["rows"], &(&1["family"] == "playwright_spec" and &1["event"] == "pull_request"))

    assert_raise ArgumentError, ~r/stale Playwright spec/, fn ->
      put_in(ledger, ["ownership", "rows", Access.at(playwright_row_index), "spec"], "test/example/priv/playwright/tests/admin-aardvark.spec.ts") |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/receipt or receiver/, fn ->
      put_in(ledger, ["ownership", "rows", Access.at(0), "receipt"], "") |> validate_ledger!()
    end
  end

  test "captured windows require one immutable bounded terminal population and literal wall-mode provenance" do
    ledger = ledger!()

    assert validate_captured_ledger!(ledger) == :ok

    assert_raise ArgumentError, ~r/pre-cutoff/, fn ->
      update_in(ledger, ["measurements", "pull_request", "runs", Access.at(0), "created_at"], fn _ -> "2026-08-01T02:06:29Z" end) |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/post-endpoint/, fn ->
      update_in(ledger, ["measurements", "pull_request", "runs", Access.at(0), "updated_at"], fn _ -> "2026-08-02T18:07:05Z" end) |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/duplicate run id/, fn ->
      update_in(ledger, ["measurements", "pull_request", "run_ids"], fn ids -> [hd(ids) | ids] end) |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/wrong event/, fn ->
      put_in(ledger, ["measurements", "pull_request", "runs", Access.at(0), "event"], "push") |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/nonterminal/, fn ->
      put_in(ledger, ["measurements", "pull_request", "runs", Access.at(0), "conclusion"], nil) |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/captured wall measurement/, fn ->
      put_in(ledger, ["measurements", "pull_request", "command"], "bash scripts/ci/ci-run-metrics.sh --mode jobspan") |> validate_captured_ledger!()
    end
  end

  test "FAST-01 uses a strict sub-720 comparator and an evidence-backed miss diagnosis" do
    ledger = ledger!()

    assert validate_verdict!(ledger) == :ok

    assert strict_fast_01_status(10, 719) == "pass"
    assert strict_fast_01_status(10, 720) == "miss"
    assert strict_fast_01_status(10, 721) == "miss"

    assert_raise ArgumentError, ~r/stored metrics output/, fn ->
      put_in(ledger, ["verdict", "fast_01", "observed_p50_seconds"], 719) |> validate_verdict!()
    end

    assert_raise ArgumentError, ~r/strict verdict/, fn ->
      ledger
      |> put_in(["verdict", "fast_01", "eligible_pr_run_count"], 9)
      |> put_in(["verdict", "fast_01", "observed_p50_seconds"], 719)
      |> put_in(["measurements", "pull_request", "statistics", "p50_seconds"], 719)
      |> put_in(["verdict", "fast_01", "status"], "pass")
      |> validate_verdict!()
    end

    assert_raise ArgumentError, ~r/miss receipt/, fn ->
      put_in(ledger, ["receipts", "binding_pole"], []) |> validate_verdict!()
    end
  end

  test "contributor topology names live direct owners, aggregates, reproduction, and non-PR signals" do
    contributing = File.read!(@contributing_path)

    assert validate_contributor_topology!(
             contributing,
             File.read!(@workflow_path),
             File.read!(@mix_path),
             File.read!(@playwright_config_path),
             File.read!(@playwright_package_path)
           ) == :ok
  end

  test "contributor topology contract rejects aggregate ownership, missing seams, commands, paths, and false PR ownership" do
    contributing = File.read!(@contributing_path)
    workflow = File.read!(@workflow_path)
    mix_exs = File.read!(@mix_path)
    playwright_config = File.read!(@playwright_config_path)
    playwright_package = File.read!(@playwright_package_path)

    assert_raise ArgumentError, ~r/direct owner example_playwright_shard/, fn ->
      String.replace(contributing, "example_playwright_shard", "example_playwright_smoke", global: false)
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    assert_raise ArgumentError, ~r/Playwright seam demo_showcase/, fn ->
      String.replace(contributing, "demo_showcase", "demo-showcase-removed", global: false)
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    assert_raise ArgumentError, ~r/local parity command/, fn ->
      String.replace(contributing, "MIX_ENV=test mix ci", "mix ci", global: false)
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    assert_raise ArgumentError, ~r/Playwright reproduction path/, fn ->
      String.replace(contributing, "test/example/priv/playwright", "test/example/priv/browser", global: false)
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    for signal <- ~w(admin_eval_render admin_design_recapture) do
      assert_raise ArgumentError, ~r/non-PR signal #{signal}/, fn ->
        String.replace(contributing, "#{signal} is intentionally non-PR", "#{signal} is a PR executor", global: false)
        |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
      end
    end
  end

  defp ledger!, do: @ledger_path |> File.read!() |> Jason.decode!()

  defp validate_ledger!(ledger) do
    unless MapSet.new(Map.keys(ledger)) == @top_level_keys, do: raise(ArgumentError, "exact top-level keys required")
    unless ledger["schema_version"] == "sigra.terminal-ratification/v1", do: raise(ArgumentError, "schema version")
    validate_cutoff!(ledger["topology_cutoff"])
    validate_capture!(ledger)
    validate_baseline!(ledger["baseline"])
    validate_inventory!(ledger["ownership"]["source_inventory"])
    validate_rows!(ledger["ownership"]["rows"])
    :ok
  end

  defp validate_cutoff!(%{"source_commit_sha" => @cutoff_sha, "committed_at" => "2026-08-01T02:06:30Z"}) do
    {output, 0} = System.cmd("git", ["show", "-s", "--format=%H%n%cI", @cutoff_sha])
    [sha, committed_at] = String.split(String.trim(output), "\n")
    unless sha == @cutoff_sha and same_instant?(committed_at, "2026-08-01T02:06:30Z"), do: raise(ArgumentError, "cutoff Git timestamp")
  end
  defp validate_cutoff!(_), do: raise(ArgumentError, "cutoff SHA or timestamp")

  defp validate_capture!(ledger) do
    unless ledger["capture_endpoint"]["status"] == "captured", do: raise(ArgumentError, "capture endpoint")
    unless ledger["verdict"]["status"] == "measured" and ledger["closeout"]["status"] == "pending_records_reconciliation", do: raise(ArgumentError, "measured verdict or closeout")

    for event <- @events do
      measurement = ledger["measurements"][event]
      unless measurement["status"] == "captured", do: raise(ArgumentError, "captured wall measurement #{event}")
    end
  end

  defp validate_baseline!(baseline) do
    unless MapSet.new(Map.keys(baseline)) == MapSet.new(@events), do: raise(ArgumentError, "baseline events")
  end

  defp validate_inventory!(source_inventory) do
    unless source_inventory == %{
             "path" => @inventory_path,
             "schema_version" => "sigra.playwright-ownership/v1",
             "phase_235_gate_input" => true,
             "sha256" => inventory_sha256!()
           }, do: raise(ArgumentError, "source inventory")
  end

  defp validate_rows!(rows) when is_list(rows) do
    keys = Enum.map(rows, &row_key/1)
    duplicates = keys -- Enum.uniq(keys)
    if duplicates != [], do: raise(ArgumentError, "duplicate ownership row #{inspect(hd(duplicates))}")

    expected_playwright_specs = @inventory_path |> File.read!() |> Jason.decode!() |> Map.fetch!("specs") |> Enum.map(& &1["spec"])
    actual_playwright_specs = rows |> Enum.filter(&(&1["family"] == "playwright_spec")) |> Enum.map(& &1["spec"]) |> Enum.uniq() |> Enum.sort()
    missing = expected_playwright_specs -- actual_playwright_specs
    stale = actual_playwright_specs -- expected_playwright_specs
    if missing != [], do: raise(ArgumentError, "missing Playwright spec #{hd(missing)}")
    if stale != [], do: raise(ArgumentError, "stale Playwright spec #{hd(stale)}")

    unless keys == Enum.sort(keys), do: raise(ArgumentError, "sorted ownership rows")

    expected_identifiers = Enum.map(expected_playwright_specs, &{"playwright_spec", &1}) ++ Enum.map(required_non_playwright_families(), &{&1, nil})

    for {family, spec} <- expected_identifiers do
      present_events = rows |> Enum.filter(&(&1["family"] == family and &1["spec"] == spec)) |> Enum.map(& &1["event"]) |> Enum.sort()
      unless present_events == @events, do: raise(ArgumentError, "missing ownership events #{family}/#{spec || "aggregate"}")
    end

    for row <- rows do
      after_row = row["after"] || %{}
      direct_owner = after_row["direct_owner"]
      unless is_binary(direct_owner) and direct_owner != "", do: raise(ArgumentError, "direct owner #{row["event"]}")
      if direct_owner == "library_tests", do: raise(ArgumentError, "aggregate-only ownership #{row["event"]}")
      unless is_binary(row["receiver"]) and row["receiver"] != "" and is_binary(row["receipt"]) and row["receipt"] != "", do: raise(ArgumentError, "receipt or receiver #{row["event"]}")
    end
  end
  defp validate_rows!(_), do: raise(ArgumentError, "ownership rows")

  defp validate_captured_ledger!(ledger) do
    unless ledger["capture_endpoint"]["status"] == "captured", do: raise(ArgumentError, "captured endpoint")

    cutoff = ledger["topology_cutoff"]["committed_at"]
    endpoint = ledger["capture_endpoint"]["captured_at"]

    for event <- @events do
      measurement = ledger["measurements"][event]
      command = measurement["command"] || ""

      unless measurement["status"] == "captured" and is_list(measurement["run_ids"]) and
               command =~ "--mode wall" and command =~ "--since '2026-08-01T02:06:30Z'" and
               command =~ "--event #{event}" and command =~ "--limit 100" and command =~ "--format json" and
               measurement["immutable_cutoff"] == cutoff and measurement["capture_endpoint"] == endpoint and
               is_map(measurement["statistics"]) and is_binary(measurement["output_sha256"]) do
        raise(ArgumentError, "captured wall measurement #{event}")
      end

      ids = measurement["run_ids"]
      runs = measurement["runs"]
      unless ids == Enum.map(runs, & &1["id"]) and length(ids) == length(Enum.uniq(ids)), do: raise(ArgumentError, "duplicate run id")

      for run <- runs do
        unless run["event"] == event, do: raise(ArgumentError, "wrong event")
        unless is_binary(run["conclusion"]), do: raise(ArgumentError, "nonterminal")
        unless run["created_at"] >= cutoff, do: raise(ArgumentError, "pre-cutoff")
        unless run["created_at"] <= endpoint and run["updated_at"] <= endpoint, do: raise(ArgumentError, "post-endpoint")
      end
    end

    pull_request = ledger["measurements"]["pull_request"]
    unless length(pull_request["run_ids"]) >= 10, do: raise(ArgumentError, "eligible pull request count")
    :ok
  end

  defp validate_verdict!(ledger) do
    fast_01 = ledger["verdict"]["fast_01"]
    unless fast_01["threshold_seconds"] == 720 and fast_01["comparator"] == "lt", do: raise(ArgumentError, "strict comparator")

    expected = ledger["measurements"]["pull_request"]["statistics"]["p50_seconds"]
    unless fast_01["observed_p50_seconds"] == expected, do: raise(ArgumentError, "stored metrics output")

    status = strict_fast_01_status(fast_01["eligible_pr_run_count"], expected)
    unless fast_01["status"] == status, do: raise(ArgumentError, "strict verdict")

    receipts = ledger["receipts"]["binding_pole"]
    if status == "miss" do
      unless is_list(receipts) and receipts != [] and Enum.all?(receipts, fn receipt ->
               receipt["command"] =~ "--jobs #{receipt["run_id"]}" and is_binary(receipt["output_sha256"]) and
                 is_map(receipt["binding_pole"]) and is_binary(receipt["binding_pole"]["name"])
             end), do: raise(ArgumentError, "miss receipt")
    else
      unless receipts == [], do: raise(ArgumentError, "pass receipt")
    end

    closeout = ledger["closeout"]
    unless closeout["measurement_ready"] and closeout["performance_target_achieved"] == (status == "pass") and not closeout["records_reconciled"], do: raise(ArgumentError, "closeout verdict")
    :ok
  end

  defp validate_contributor_topology!(contributing, workflow, mix_exs, playwright_config, playwright_package) do
    require_text!(contributing, "MIX_ENV=test mix ci", "local parity command")
    require_text!(contributing, "library_tests_shard", "direct owner library_tests_shard")
    require_text!(contributing, "library_tests / Library tests", "terminal aggregate Library tests")
    require_text!(contributing, "example_playwright_shard", "direct owner example_playwright_shard")
    require_text!(contributing, "example_playwright_smoke / Example Playwright smoke (full lifecycle)", "terminal aggregate Example Playwright smoke")

    for seam <- ~w(admin_behavior admin_checkpoints design_gallery non_admin_smoke demo_showcase) do
      require_text!(contributing, seam, "Playwright seam #{seam}")
      require_text!(workflow, "seam: #{seam}", "workflow Playwright seam #{seam}")
    end

    require_text!(contributing, "test/example/priv/playwright", "Playwright reproduction path")
    require_text!(contributing, "npm test", "Playwright reproduction command")
    require_text!(contributing, "playwright.config.ts", "Playwright reproduction config")

    require_text!(workflow, "library_tests_shard:", "workflow library direct owner")
    require_text!(workflow, "library_tests:", "workflow library aggregate")
    require_text!(workflow, "example_playwright_shard:", "workflow Playwright direct owner")
    require_text!(workflow, "example_playwright_smoke:", "workflow Playwright aggregate")
    require_text!(mix_exs, "ci:", "mix ci alias")
    require_text!(playwright_config, "projects:", "Playwright config projects")
    require_text!(playwright_package, "\"test\": \"playwright test\"", "Playwright package test command")

    for signal <- ~w(admin_eval_render admin_design_recapture) do
      require_text!(contributing, "#{signal} is intentionally non-PR", "non-PR signal #{signal}")
      require_text!(contributing, "push, schedule, and workflow_dispatch", "non-PR event conditions")
      require_text!(workflow, "#{signal}:", "workflow non-PR signal #{signal}")
    end

    :ok
  end

  defp require_text!(text, expected, diagnostic) do
    unless text =~ expected, do: raise(ArgumentError, diagnostic)
  end

  defp strict_fast_01_status(count, p50) when count >= 10 and p50 < 720, do: "pass"
  defp strict_fast_01_status(_count, _p50), do: "miss"

  defp same_instant?(left, right) do
    {:ok, left, _} = DateTime.from_iso8601(left)
    {:ok, right, _} = DateTime.from_iso8601(right)
    DateTime.compare(left, right) == :eq
  end

  defp row_key(row), do: {row["family"], row["spec"] || "", row["event"]}

  defp inventory_sha256! do
    {output, 0} = System.cmd("shasum", ["-a", "256", @inventory_path])
    output |> String.split() |> hd()
  end

  defp required_non_playwright_families do
    ~w(design_gallery_snapshots design_gallery_axe admin_eval_render admin_eval_harness_guards generated_host_acceptance library_ordinary_shards library_scaffold_golden library_dep_off library_tests_aggregate example_playwright_aggregate ci_gate_aggregate)
  end
end
