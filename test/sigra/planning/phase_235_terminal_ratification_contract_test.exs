defmodule Sigra.Planning.Phase235TerminalRatificationContractTest do
  use ExUnit.Case, async: true

  @ledger_path ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
  @workflow_path ".github/workflows/ci.yml"
  @contributing_path "CONTRIBUTING.md"
  @mix_path "mix.exs"
  @playwright_config_path "test/example/priv/playwright/playwright.config.ts"
  @playwright_package_path "test/example/priv/playwright/package.json"
  @seed_path ".planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md"
  @milestone_arc_path ".planning/MILESTONE-ARC.md"
  @residual_path ".planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md"
  @inventory_path ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json"
  @cutoff_sha "6c57d7b4a22aa87a757a6f508f2cf4fdb414e40a"
  @capture_instant "2026-08-02T18:07:04Z"
  @population_sha "6462b127e09de5a017e4b718e4928341ab81be33f627dcef6d637560bc74a530"
  @top_level_keys MapSet.new(
                    ~w(schema_version topology_cutoff capture_endpoint baseline measurements ownership receipts verdict closeout)
                  )
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
    assert ledger["closeout"]["status"] == "records_reconciled"
  end

  test "baseline-compatible measurements preserve the committed seconds without recomputation" do
    assert ledger!()["baseline"] == %{
             "pull_request" => %{
               "n" => 21,
               "mean_seconds" => 1770,
               "p50_seconds" => 1638,
               "max_seconds" => 2502,
               "pass" => 17,
               "fail" => 4
             },
             "push" => %{
               "n" => 7,
               "mean_seconds" => 1830,
               "p50_seconds" => 1656,
               "max_seconds" => 2538,
               "pass" => 6,
               "fail" => 1
             },
             "schedule" => %{
               "n" => 9,
               "mean_seconds" => 1638,
               "p50_seconds" => 1626,
               "max_seconds" => 1764,
               "pass" => 0,
               "fail" => 9
             }
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

      assert row["after"]["terminal_aggregate"] == %{
               "id" => "library_tests",
               "name" => "Library tests"
             }

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
    assert MapSet.size(expected_ownership_keys!()) == 93
    assert MapSet.new(Enum.map(rows, &row_key/1)) == expected_ownership_keys!()

    assert Enum.map(rows, &row_key/1) == Enum.sort_by(rows, &row_key/1) |> Enum.map(&row_key/1)

    for spec <- inventory_specs do
      assert Enum.count(rows, &(&1["family"] == "playwright_spec" and &1["spec"] == spec)) == 3
    end

    for family <- required_non_playwright_families() do
      assert Enum.count(rows, &(&1["family"] == family)) == 3
    end
  end

  test "ownership validation rejects otherwise valid keys outside the reviewed universe" do
    ledger = ledger!()
    rows = ledger["ownership"]["rows"]
    last_row = List.last(rows)

    assert_raise ArgumentError, ~r/unexpected ownership key.*workflow_dispatch/, fn ->
      extra_event =
        last_row
        |> Map.put("family", "unclassified_event_family")
        |> Map.put("spec", nil)
        |> Map.put("event", "workflow_dispatch")

      put_in(ledger, ["ownership", "rows"], rows ++ [extra_event]) |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/unexpected ownership key.*unclassified_family/, fn ->
      extra_family = last_row |> Map.put("family", "unclassified_family") |> Map.put("spec", nil)
      put_in(ledger, ["ownership", "rows"], rows ++ [extra_family]) |> validate_ledger!()
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
      put_in(ledger, ["ownership", "rows", Access.at(0), "after", "direct_owner"], nil)
      |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/aggregate-only/, fn ->
      put_in(
        ledger,
        ["ownership", "rows", Access.at(0), "after", "direct_owner"],
        "library_tests"
      )
      |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/captured wall measurement/, fn ->
      put_in(ledger, ["measurements", "pull_request", "status"], "pending") |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/missing ownership key/, fn ->
      update_in(ledger, ["ownership", "rows"], &Enum.drop(&1, 1)) |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/duplicate ownership row/, fn ->
      update_in(ledger, ["ownership", "rows"], &[hd(&1) | &1]) |> validate_ledger!()
    end

    playwright_row_index =
      Enum.find_index(
        ledger["ownership"]["rows"],
        &(&1["family"] == "playwright_spec" and &1["event"] == "pull_request")
      )

    assert_raise ArgumentError, ~r/stale Playwright spec/, fn ->
      put_in(
        ledger,
        ["ownership", "rows", Access.at(playwright_row_index), "spec"],
        "test/example/priv/playwright/tests/admin-aardvark.spec.ts"
      )
      |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/receipt or receiver/, fn ->
      put_in(ledger, ["ownership", "rows", Access.at(0), "receipt"], "") |> validate_ledger!()
    end
  end

  test "captured windows require one immutable bounded terminal population and literal wall-mode provenance" do
    ledger = ledger!()

    assert validate_captured_ledger!(ledger) == :ok

    assert_raise ArgumentError, ~r/source receipt/, fn ->
      ledger
      |> put_in(["capture_endpoint", "source_receipt"], nil)
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/pre-cutoff/, fn ->
      update_in(
        ledger,
        ["measurements", "pull_request", "runs", Access.at(0), "created_at"],
        fn _ -> "2026-08-01T02:06:29Z" end
      )
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/post-endpoint/, fn ->
      update_in(
        ledger,
        ["measurements", "pull_request", "runs", Access.at(0), "updated_at"],
        fn _ -> "2026-08-02T18:07:05Z" end
      )
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/duplicate run id/, fn ->
      update_in(ledger, ["measurements", "pull_request", "run_ids"], fn ids -> [hd(ids) | ids] end)
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/wrong event/, fn ->
      put_in(ledger, ["measurements", "pull_request", "runs", Access.at(0), "event"], "push")
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/nonterminal/, fn ->
      put_in(ledger, ["measurements", "pull_request", "runs", Access.at(0), "conclusion"], nil)
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/captured wall measurement/, fn ->
      put_in(
        ledger,
        ["measurements", "pull_request", "command"],
        "bash scripts/ci/ci-run-metrics.sh --mode jobspan"
      )
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/recomputed statistics/, fn ->
      put_in(ledger, ["measurements", "pull_request", "statistics", "p50_seconds"], 719)
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/output receipt/, fn ->
      put_in(ledger, ["measurements", "pull_request", "output_receipt"], "[]\n")
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/output SHA-256/, fn ->
      put_in(ledger, ["measurements", "pull_request", "output_sha256"], String.duplicate("x", 64))
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/recomputed statistics/, fn ->
      put_in(
        ledger,
        ["measurements", "pull_request", "runs", Access.at(0), "conclusion"],
        "failure"
      )
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/capture instant/, fn ->
      put_in(ledger, ["capture_endpoint", "captured_at"], "2026-08-02T18:07:05Z")
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/population SHA-256/, fn ->
      put_in(ledger, ["capture_endpoint", "population_sha256"], String.duplicate("0", 64))
      |> validate_captured_ledger!()
    end

    assert_raise ArgumentError, ~r/duplicate run id/, fn ->
      put_in(ledger, ["measurements", "pull_request", "runs", Access.at(0), "id"], "30729540659")
      |> validate_captured_ledger!()
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

    assert_raise ArgumentError, ~r/eligible pull request count/, fn ->
      put_in(ledger, ["verdict", "fast_01", "eligible_pr_run_count"], 10) |> validate_verdict!()
    end

    assert_raise ArgumentError, ~r/same-window measurements/, fn ->
      put_in(ledger, ["verdict", "same_window_measurements", "pull_request", "pass"], 19)
      |> validate_verdict!()
    end

    assert_raise ArgumentError, ~r/stored metrics output/, fn ->
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

  test "recomputation fails closed for missing populations and preserves deterministic median edges" do
    assert_raise ArgumentError, ~r/runs must be a non-empty list/, fn ->
      recompute_statistics!(nil, "pull_request")
    end

    assert_raise ArgumentError, ~r/runs must be a non-empty list/, fn ->
      recompute_statistics!([], "pull_request")
    end

    single_run = %{
      "event" => "pull_request",
      "created_at" => "2026-08-02T00:00:00Z",
      "updated_at" => "2026-08-02T00:00:00Z",
      "conclusion" => "cancelled"
    }

    assert recompute_statistics!([single_run], "pull_request") == %{
             "trigger" => "pull_request",
             "n" => 1,
             "mean_seconds" => 0,
             "p50_seconds" => 0,
             "max_seconds" => 0,
             "pass" => 0,
             "fail" => 1
           }

    equal_runs =
      for _ <- 1..10 do
        %{
          "event" => "pull_request",
          "created_at" => "2026-08-02T00:00:00Z",
          "updated_at" => "2026-08-02T00:12:00Z",
          "conclusion" => "success"
        }
      end

    assert recompute_statistics!(equal_runs, "pull_request")["p50_seconds"] == 720
    assert strict_fast_01_status(10, 720) == "miss"
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

    assert_raise ArgumentError, ~r/Playwright topology statement/, fn ->
      String.replace(contributing, "example_playwright_shard", "example_playwright_smoke",
        global: false
      )
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    assert_raise ArgumentError, ~r/Playwright topology statement/, fn ->
      String.replace(contributing, "demo_showcase", "demo-showcase-removed", global: false)
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    assert_raise ArgumentError, ~r/library topology statement/, fn ->
      String.replace(contributing, "MIX_ENV=test mix ci", "mix ci")
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    assert_raise ArgumentError, ~r/Playwright topology statement/, fn ->
      String.replace(contributing, "test/example/priv/playwright", "test/example/priv/browser")
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    assert_raise ArgumentError, ~r/aggregate executor contradiction/, fn ->
      String.replace(
        contributing,
        "## Reviewing admin Playwright artifacts",
        "- `library_tests / Library tests` executes `MIX_ENV=test mix ci`.\n\n## Reviewing admin Playwright artifacts",
        global: false
      )
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    assert_raise ArgumentError, ~r/non-PR executor contradiction admin_eval_render/, fn ->
      String.replace(
        contributing,
        "## Reviewing admin Playwright artifacts",
        "- `admin_eval_render` executes on pull requests.\n\n## Reviewing admin Playwright artifacts",
        global: false
      )
      |> validate_contributor_topology!(workflow, mix_exs, playwright_config, playwright_package)
    end

    for signal <- ~w(admin_eval_render admin_design_recapture) do
      assert_raise ArgumentError, ~r/#{signal} topology statement/, fn ->
        String.replace(
          contributing,
          "`#{signal}` is intentionally non-PR",
          "`#{signal}` is a PR executor",
          global: false
        )
        |> validate_contributor_topology!(
          workflow,
          mix_exs,
          playwright_config,
          playwright_package
        )
      end
    end
  end

  test "terminal closeout reconciles the completed audit and the measured FAST-01 miss" do
    ledger = ledger!()
    seed = File.read!(@seed_path)
    milestone_arc = File.read!(@milestone_arc_path)
    contributing = File.read!(@contributing_path)
    residual = File.read!(@residual_path)

    assert validate_closeout_records!(ledger, contributing, seed, milestone_arc, residual) == :ok
  end

  test "terminal closeout contract rejects contradicted verdict prose, artifacts, residuals, and stale active framing" do
    ledger = ledger!()
    contributing = File.read!(@contributing_path)
    seed = File.read!(@seed_path)
    milestone_arc = File.read!(@milestone_arc_path)
    residual = File.read!(@residual_path)

    assert_raise ArgumentError, ~r/seed terminal addendum/, fn ->
      validate_closeout_records!(
        ledger,
        contributing,
        String.replace(seed, "Phase 235 terminal addendum", "terminal note"),
        milestone_arc,
        residual
      )
    end

    assert_raise ArgumentError, ~r/FAST-01 miss claim/, fn ->
      validate_closeout_records!(
        ledger,
        contributing,
        seed,
        String.replace(milestone_arc, "FAST-01 remains unmet", "FAST-01 target achieved"),
        residual
      )
    end

    assert_raise ArgumentError, ~r/exact PR p50/, fn ->
      validate_closeout_records!(
        ledger,
        contributing,
        seed,
        String.replace(milestone_arc, "772 seconds", "719 seconds"),
        residual
      )
    end

    assert_raise ArgumentError, ~r/terminal artifact link/, fn ->
      validate_closeout_records!(
        ledger,
        contributing,
        String.replace(seed, @ledger_path, "terminal-ledger-removed"),
        milestone_arc,
        residual
      )
    end

    assert_raise ArgumentError, ~r/residual path/, fn ->
      validate_closeout_records!(ledger, contributing, seed, milestone_arc, nil)
    end

    assert_raise ArgumentError, ~r/binding-pole receipt/, fn ->
      validate_closeout_records!(
        ledger,
        contributing,
        seed,
        milestone_arc,
        String.replace(residual, "30723593560", "removed-receipt")
      )
    end

    assert_raise ArgumentError, ~r/stale ACTIVE status/, fn ->
      validate_closeout_records!(
        ledger,
        contributing,
        seed,
        "### ACTIVE — promoted to milestone v1.40\n" <> milestone_arc,
        residual
      )
    end

    assert_raise ArgumentError, ~r/contributor topology/, fn ->
      validate_closeout_records!(ledger, nil, seed, milestone_arc, residual)
    end

    pass_ledger =
      ledger
      |> put_in(["verdict", "fast_01", "status"], "pass")
      |> put_in(["closeout", "performance_target_achieved"], true)
      |> put_in(["closeout", "residual_path"], nil)

    pass_seed = String.replace(seed, "FAST-01 remains unmet", "FAST-01 target achieved")
    pass_arc = String.replace(milestone_arc, "FAST-01 remains unmet", "FAST-01 target achieved")

    assert_raise ArgumentError, ~r/residual present on pass/, fn ->
      validate_closeout_records!(pass_ledger, contributing, pass_seed, pass_arc, residual)
    end
  end

  defp ledger!, do: @ledger_path |> File.read!() |> Jason.decode!()

  defp validate_ledger!(ledger) do
    unless MapSet.new(Map.keys(ledger)) == @top_level_keys,
      do: raise(ArgumentError, "exact top-level keys required")

    unless ledger["schema_version"] == "sigra.terminal-ratification/v1",
      do: raise(ArgumentError, "schema version")

    validate_cutoff!(ledger["topology_cutoff"])
    validate_capture!(ledger)
    validate_baseline!(ledger["baseline"])
    validate_inventory!(ledger["ownership"]["source_inventory"])
    validate_rows!(ledger["ownership"]["rows"])
    validate_captured_ledger!(ledger)
    validate_verdict!(ledger)
    :ok
  end

  defp validate_cutoff!(%{
         "source_commit_sha" => @cutoff_sha,
         "committed_at" => "2026-08-01T02:06:30Z"
       }) do
    {output, 0} = System.cmd("git", ["show", "-s", "--format=%H%n%cI", @cutoff_sha])
    [sha, committed_at] = String.split(String.trim(output), "\n")

    unless sha == @cutoff_sha and same_instant?(committed_at, "2026-08-01T02:06:30Z"),
      do: raise(ArgumentError, "cutoff Git timestamp")
  end

  defp validate_cutoff!(_), do: raise(ArgumentError, "cutoff SHA or timestamp")

  defp validate_capture!(ledger) do
    unless ledger["capture_endpoint"]["status"] == "captured",
      do: raise(ArgumentError, "capture endpoint")

    unless ledger["verdict"]["status"] == "measured" and
             ledger["closeout"]["status"] == "records_reconciled",
           do: raise(ArgumentError, "measured verdict or closeout")

    capture = ledger["capture_endpoint"]

    unless capture["captured_at"] == @capture_instant and
             capture["population_sha256"] == @population_sha and
             capture["source_command"] ==
               "gh run list --repo szTheory/sigra --workflow ci.yml --limit 100 --json databaseId,event,createdAt,updatedAt,conclusion,url,headSha" and
             same_instant?(capture["captured_at"], @capture_instant),
           do: raise(ArgumentError, "capture instant or source population")

    for event <- @events do
      measurement = ledger["measurements"][event]

      unless measurement["status"] == "captured",
        do: raise(ArgumentError, "captured wall measurement #{event}")
    end
  end

  defp validate_baseline!(baseline) do
    unless MapSet.new(Map.keys(baseline)) == MapSet.new(@events),
      do: raise(ArgumentError, "baseline events")
  end

  defp validate_inventory!(source_inventory) do
    unless source_inventory == %{
             "path" => @inventory_path,
             "schema_version" => "sigra.playwright-ownership/v1",
             "phase_235_gate_input" => true,
             "sha256" => inventory_sha256!()
           },
           do: raise(ArgumentError, "source inventory")
  end

  defp validate_rows!(rows) when is_list(rows) do
    keys = Enum.map(rows, &row_key/1)
    duplicates = keys -- Enum.uniq(keys)

    if duplicates != [],
      do: raise(ArgumentError, "duplicate ownership row #{inspect(hd(duplicates))}")

    expected_playwright_specs =
      @inventory_path
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("specs")
      |> Enum.map(& &1["spec"])

    actual_playwright_specs =
      rows
      |> Enum.filter(&(&1["family"] == "playwright_spec"))
      |> Enum.map(& &1["spec"])
      |> Enum.uniq()
      |> Enum.sort()

    missing = expected_playwright_specs -- actual_playwright_specs
    stale = actual_playwright_specs -- expected_playwright_specs
    if missing != [], do: raise(ArgumentError, "missing Playwright spec #{hd(missing)}")
    if stale != [], do: raise(ArgumentError, "stale Playwright spec #{hd(stale)}")

    expected_keys = expected_ownership_keys!()
    actual_keys = MapSet.new(keys)

    missing_keys =
      MapSet.difference(expected_keys, actual_keys) |> MapSet.to_list() |> Enum.sort()

    unexpected_keys =
      MapSet.difference(actual_keys, expected_keys) |> MapSet.to_list() |> Enum.sort()

    if missing_keys != [],
      do: raise(ArgumentError, "missing ownership key #{inspect(hd(missing_keys))}")

    if unexpected_keys != [],
      do: raise(ArgumentError, "unexpected ownership key #{inspect(hd(unexpected_keys))}")

    unless keys == Enum.sort(keys), do: raise(ArgumentError, "sorted ownership rows")

    expected_identifiers =
      Enum.map(expected_playwright_specs, &{"playwright_spec", &1}) ++
        Enum.map(required_non_playwright_families(), &{&1, nil})

    for {family, spec} <- expected_identifiers do
      present_events =
        rows
        |> Enum.filter(&(&1["family"] == family and &1["spec"] == spec))
        |> Enum.map(& &1["event"])
        |> Enum.sort()

      unless present_events == @events,
        do: raise(ArgumentError, "missing ownership events #{family}/#{spec || "aggregate"}")
    end

    for row <- rows do
      after_row = row["after"] || %{}
      direct_owner = after_row["direct_owner"]

      unless is_binary(direct_owner) and direct_owner != "",
        do: raise(ArgumentError, "direct owner #{row["event"]}")

      if direct_owner == "library_tests",
        do: raise(ArgumentError, "aggregate-only ownership #{row["event"]}")

      unless is_binary(row["receiver"]) and row["receiver"] != "" and is_binary(row["receipt"]) and
               row["receipt"] != "",
             do: raise(ArgumentError, "receipt or receiver #{row["event"]}")

      if row["family"] == "ci_gate_aggregate" do
        expected = "ci-gate"

        unless after_row["direct_owner"] == expected and after_row["seam"] == expected and
                 get_in(after_row, ["terminal_aggregate", "id"]) == expected and row["receiver"] == expected,
               do: raise(ArgumentError, "ci-gate ownership semantics")
      end
    end
  end

  defp validate_rows!(_), do: raise(ArgumentError, "ownership rows")

  defp validate_captured_ledger!(ledger) do
    unless ledger["capture_endpoint"]["status"] == "captured",
      do: raise(ArgumentError, "captured endpoint")

    cutoff = ledger["topology_cutoff"]["committed_at"]
    endpoint = ledger["capture_endpoint"]["captured_at"]

    unless endpoint == @capture_instant and ledger["capture_endpoint"]["population_sha256"] == @population_sha,
      do: raise(ArgumentError, "capture instant or population SHA-256")

    for event <- @events do
      measurement = ledger["measurements"][event]
      command = measurement["command"] || ""

      unless measurement["status"] == "captured" and is_list(measurement["run_ids"]) and
               is_list(measurement["runs"]) and
               command =~ "--mode wall" and command =~ "--since '2026-08-01T02:06:30Z'" and
               command =~ "--event #{event}" and command =~ "--limit 100" and
               command =~ "--format json" and
               measurement["immutable_cutoff"] == cutoff and
               measurement["capture_endpoint"] == endpoint and
               is_map(measurement["statistics"]) and is_binary(measurement["output_receipt"]) and
               is_binary(measurement["output_sha256"]) do
        raise(ArgumentError, "captured wall measurement #{event}")
      end

      ids = measurement["run_ids"]
      runs = measurement["runs"]

      unless ids == Enum.map(runs, & &1["id"]) and length(ids) == length(Enum.uniq(ids)) and
               Enum.all?(ids, &(is_integer(&1) and &1 > 0)),
        do: raise(ArgumentError, "duplicate run id")

      unless Enum.all?(runs, fn run ->
               is_integer(run["id"]) and run["id"] > 0 and
                 run["url"] == "https://github.com/szTheory/sigra/actions/runs/#{run["id"]}" and
                 is_binary(run["head_sha"]) and Regex.match?(~r/\A[0-9a-f]{40}\z/, run["head_sha"])
             end),
             do: raise(ArgumentError, "positive run id or canonical URL")

      validate_window_bounds!(runs, event, cutoff, endpoint)
      statistics = recompute_statistics!(runs, event)

      unless measurement["statistics"] == statistics,
        do: raise(ArgumentError, "recomputed statistics #{event}")

      receipt = measurement["output_receipt"]

      unless receipt == canonical_output_receipt(statistics) and
               Jason.decode!(receipt) == [statistics],
             do: raise(ArgumentError, "output receipt #{event}")

      digest = measurement["output_sha256"]

      unless Regex.match?(~r/\A[0-9a-f]{64}\z/, digest) and digest == sha256_hex(receipt),
        do: raise(ArgumentError, "output SHA-256 #{event}")
    end

    :ok
  end

  defp validate_verdict!(ledger) do
    fast_01 = ledger["verdict"]["fast_01"]

    unless fast_01["threshold_seconds"] == 720 and fast_01["comparator"] == "lt",
      do: raise(ArgumentError, "strict comparator")

    recomputed =
      Map.new(@events, fn event ->
        {event, recompute_statistics!(ledger["measurements"][event]["runs"], event)}
      end)

    expected = recomputed["pull_request"]["p50_seconds"]

    unless fast_01["observed_p50_seconds"] == expected,
      do: raise(ArgumentError, "stored metrics output")

    unless fast_01["eligible_pr_run_count"] == recomputed["pull_request"]["n"],
      do: raise(ArgumentError, "eligible pull request count")

    same_window =
      Map.new(recomputed, fn {event, statistics} ->
        {event, Map.take(statistics, ["n", "p50_seconds", "pass", "fail"])}
      end)

    unless ledger["verdict"]["same_window_measurements"] == same_window,
      do: raise(ArgumentError, "same-window measurements")

    status = strict_fast_01_status(fast_01["eligible_pr_run_count"], expected)
    unless fast_01["status"] == status, do: raise(ArgumentError, "strict verdict")

    receipts = ledger["receipts"]["binding_pole"]

    if status == "miss" do
      unless is_list(receipts) and receipts != [] and
               Enum.all?(receipts, fn receipt ->
                 receipt["command"] =~ "--jobs #{receipt["run_id"]}" and
                   is_binary(receipt["output_sha256"]) and
                   is_map(receipt["binding_pole"]) and is_binary(receipt["binding_pole"]["name"])
               end),
             do: raise(ArgumentError, "miss receipt")

      validate_binding_pole_receipts!(receipts, ledger["measurements"]["pull_request"]["runs"])
    else
      unless receipts == [], do: raise(ArgumentError, "pass receipt")
    end

    closeout = ledger["closeout"]

    unless closeout["measurement_ready"] and
             closeout["performance_target_achieved"] == (status == "pass") and
             closeout["records_reconciled"],
           do: raise(ArgumentError, "closeout verdict")

    :ok
  end

  defp validate_binding_pole_receipts!(receipts, pr_runs) do
    for receipt <- receipts do
      run = Enum.find(pr_runs, &(&1["id"] == receipt["run_id"])) || raise(ArgumentError, "binding run id")
      source = receipt["source_receipt"] || %{}

      unless source["command"] == "gh run view #{receipt["run_id"]} --repo szTheory/sigra --json databaseId,event,url,jobs" and
               is_binary(source["output"]) and is_binary(source["sha256"]) and
               source["sha256"] == sha256_hex(source["output"]),
             do: raise(ArgumentError, "binding source receipt")

      source_run = Jason.decode!(source["output"])
      pole = receipt["binding_pole"]

      unless source_run["databaseId"] == run["id"] and source_run["event"] == "pull_request" and
               source_run["url"] == run["url"] and receipt["run_url"] == run["url"] and
               is_list(source_run["jobs"]) and
               Enum.count(source_run["jobs"], &(&1["name"] == pole["name"])) == 1,
             do: raise(ArgumentError, "binding source identity or job")

      job = Enum.find(source_run["jobs"], &(&1["name"] == pole["name"]))
      duration = max(DateTime.diff(parse_timestamp!(job["completedAt"]), parse_timestamp!(job["startedAt"]), :second), 0)

      unless job["conclusion"] == pole["conclusion"] and duration == pole["duration_seconds"],
        do: raise(ArgumentError, "binding job duration")
    end
  end

  defp validate_closeout_records!(ledger, contributing, seed, milestone_arc, residual) do
    unless is_binary(contributing), do: raise(ArgumentError, "contributor topology")

    validate_contributor_topology!(
      contributing,
      File.read!(@workflow_path),
      File.read!(@mix_path),
      File.read!(@playwright_config_path),
      File.read!(@playwright_package_path)
    )

    fast_01 = ledger["verdict"]["fast_01"]
    closeout = ledger["closeout"]

    unless closeout["contributing_path"] == @contributing_path and
             closeout["seed_path"] == @seed_path and
             closeout["milestone_arc_path"] == @milestone_arc_path and
             closeout["records_reconciled"],
           do: raise(ArgumentError, "closeout paths")

    require_text!(
      seed,
      "## Addendum 2026-08-02 — Phase 235 terminal addendum",
      "seed terminal addendum"
    )

    require_text!(seed, "audit was completed in 2026", "completed audit claim")
    require_text!(seed, "Phases 230–235", "executed phase sequence")

    for record <- [seed, milestone_arc] do
      require_text!(record, @ledger_path, "terminal artifact link")

      require_text!(
        record,
        "#{fast_01["eligible_pr_run_count"]} retained pull_request runs",
        "exact PR count"
      )

      require_text!(record, "#{fast_01["observed_p50_seconds"]} seconds", "exact PR p50")
      require_text!(record, "push: 1 success / 1 non-success", "push outcomes")
      require_text!(record, "schedule: 0 success / 2 non-success", "schedule outcomes")
    end

    unless not String.contains?(milestone_arc, "### ACTIVE — promoted to milestone v1.40"),
      do: raise(ArgumentError, "stale ACTIVE status")

    case fast_01["status"] do
      "miss" ->
        require_text!(milestone_arc, "FAST-01 remains unmet", "FAST-01 miss claim")

        unless closeout["residual_path"] == @residual_path and is_binary(residual),
          do: raise(ArgumentError, "residual path")

        require_text!(seed, @residual_path, "seed residual link")
        require_text!(milestone_arc, @residual_path, "arc residual link")
        require_text!(residual, @ledger_path, "residual terminal artifact link")

        require_text!(
          residual,
          "#{fast_01["eligible_pr_run_count"]} retained pull_request runs",
          "residual exact PR count"
        )

        require_text!(
          residual,
          "#{fast_01["observed_p50_seconds"]} seconds",
          "residual exact PR p50"
        )

        for receipt <- ledger["receipts"]["binding_pole"] do
          require_text!(residual, Integer.to_string(receipt["run_id"]), "binding-pole receipt")
          require_text!(residual, receipt["command"], "binding-pole command")
        end

      "pass" ->
        require_text!(milestone_arc, "FAST-01 target achieved", "FAST-01 pass claim")

        if String.contains?(milestone_arc, "FAST-01 remains unmet"),
          do: raise(ArgumentError, "miss prose on pass")

        unless is_nil(closeout["residual_path"]) and is_nil(residual),
          do: raise(ArgumentError, "residual present on pass")

      _ ->
        raise ArgumentError, "FAST-01 status"
    end

    :ok
  end

  defp validate_contributor_topology!(
         contributing,
         workflow,
         mix_exs,
         playwright_config,
         playwright_package
       ) do
    overview = ci_overview!(contributing)
    library_shard = workflow_job_block!(workflow, "library_tests_shard")
    library_aggregate = workflow_job_block!(workflow, "library_tests")
    playwright_shard = workflow_job_block!(workflow, "example_playwright_shard")
    playwright_aggregate = workflow_job_block!(workflow, "example_playwright_smoke")

    require_text!(library_shard, "run: MIX_ENV=test mix ci", "library direct-owner command")
    require_text!(library_aggregate, "needs: [library_tests_shard]", "library aggregate needs")
    require_text!(playwright_shard, "npx playwright test", "Playwright direct-owner command")
    require_text!(playwright_aggregate, "example_playwright_shard", "Playwright aggregate needs")

    if library_aggregate =~ "MIX_ENV=test mix ci" or playwright_aggregate =~ "npx playwright test" do
      raise ArgumentError, "aggregate executes suite"
    end

    for signal <- ~w(admin_eval_render admin_design_recapture) do
      workflow
      |> workflow_job_block!(signal)
      |> require_text!(
        "if: github.event_name != 'pull_request'",
        "workflow non-PR signal #{signal}"
      )
    end

    require_unique_statement!(
      overview,
      "- **Library/scaffold/golden parity** — `MIX_ENV=test mix ci` remains the literal local parity command for the seven-leg library, scaffold, and golden gate. `library_tests_shard` is the direct executor; `library_tests / Library tests` is its byte-stable terminal aggregate and protected check, not a second executor.",
      "library topology statement"
    )

    require_unique_statement!(
      overview,
      "- **Playwright** — `example_playwright_shard` is the direct five-seam executor for `admin_behavior`, `admin_checkpoints`, `design_gallery`, `non_admin_smoke`, and `demo_showcase`. `example_playwright_smoke / Example Playwright smoke (full lifecycle)` reads those seam results as the terminal aggregate; it does not execute the browser seams itself. Curated admin checkpoint PNGs are collected under `test/example/priv/playwright/artifacts/admin-checkpoints/`.",
      "Playwright topology statement"
    )

    require_unique_statement!(
      overview,
      "- **Intentional non-PR signal: admin eval** — `admin_eval_render` is intentionally non-PR and runs on push, schedule, and workflow_dispatch; it is a hard diagnostic signal rather than a PR executor or protected required check.",
      "admin_eval_render topology statement"
    )

    require_unique_statement!(
      overview,
      "- **Intentional non-PR signal: design recapture** — `admin_design_recapture` is intentionally non-PR and runs on push, schedule, and workflow_dispatch for its guarded baseline-recapture conditions; it is likewise not a PR executor or protected required check.",
      "admin_design_recapture topology statement"
    )

    if overview =~ "`library_tests / Library tests` executes" or
         overview =~
           "`example_playwright_smoke / Example Playwright smoke (full lifecycle)` executes" do
      raise ArgumentError, "aggregate executor contradiction"
    end

    for signal <- ~w(admin_eval_render admin_design_recapture) do
      if Regex.match?(~r/`#{Regex.escape(signal)}`[^\n.]*executes on pull requests/i, overview) do
        raise ArgumentError, "non-PR executor contradiction #{signal}"
      end
    end

    require_text!(contributing, "MIX_ENV=test mix ci", "local parity command")
    require_text!(contributing, "library_tests_shard", "direct owner library_tests_shard")

    require_text!(
      contributing,
      "library_tests / Library tests",
      "terminal aggregate Library tests"
    )

    require_text!(
      contributing,
      "example_playwright_shard",
      "direct owner example_playwright_shard"
    )

    require_text!(
      contributing,
      "example_playwright_smoke / Example Playwright smoke (full lifecycle)",
      "terminal aggregate Example Playwright smoke"
    )

    for seam <- ~w(admin_behavior admin_checkpoints design_gallery non_admin_smoke demo_showcase) do
      require_text!(contributing, seam, "Playwright seam #{seam}")
      require_text!(workflow, "seam: #{seam}", "workflow Playwright seam #{seam}")
    end

    require_text!(contributing, "test/example/priv/playwright", "Playwright reproduction path")
    require_text!(contributing, "npm test", "Playwright reproduction command")
    require_text!(contributing, "playwright.config.ts", "Playwright reproduction config")

    require_text!(mix_exs, "ci:", "mix ci alias")
    require_text!(playwright_config, "projects:", "Playwright config projects")

    require_text!(
      playwright_package,
      "\"test\": \"playwright test\"",
      "Playwright package test command"
    )

    for signal <- ~w(admin_eval_render admin_design_recapture) do
      require_text!(
        contributing,
        "`#{signal}` is intentionally non-PR",
        "non-PR signal #{signal}"
      )

      require_text!(
        contributing,
        "push, schedule, and workflow_dispatch",
        "non-PR event conditions"
      )
    end

    :ok
  end

  defp require_text!(text, expected, diagnostic) do
    unless text =~ expected, do: raise(ArgumentError, diagnostic)
  end

  defp ci_overview!(contributing) do
    case Regex.named_captures(~r/^## CI overview\n(?<overview>.*?)(?=^## |\z)/ms, contributing) do
      %{"overview" => overview} -> overview
      _ -> raise ArgumentError, "CI overview section"
    end
  end

  defp require_unique_statement!(overview, statement, diagnostic) do
    count = overview |> String.split("\n") |> Enum.count(&(String.trim(&1) == statement))
    unless count == 1, do: raise(ArgumentError, diagnostic)
  end

  defp workflow_job_block!(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> raise ArgumentError, "workflow job block #{job_id}"
    end
  end

  defp strict_fast_01_status(count, p50) when count >= 10 and p50 < 720, do: "pass"
  defp strict_fast_01_status(_count, _p50), do: "miss"

  defp recompute_statistics!(runs, event) when is_list(runs) and runs != [] do
    {durations, pass} =
      Enum.map_reduce(runs, 0, fn run, pass ->
        unless is_map(run) and run["event"] == event, do: raise(ArgumentError, "wrong event")

        unless is_binary(run["conclusion"]) and run["conclusion"] != "",
          do: raise(ArgumentError, "nonterminal")

        created_at = parse_timestamp!(run["created_at"])
        updated_at = parse_timestamp!(run["updated_at"])
        duration = max(DateTime.diff(updated_at, created_at, :second), 0)
        {duration, pass + if(run["conclusion"] == "success", do: 1, else: 0)}
      end)

    sorted = Enum.sort(durations)
    n = length(sorted)

    mean_seconds = Enum.sum(sorted) / n

    %{
      "trigger" => event,
      "n" => n,
      "mean_seconds" =>
        if(mean_seconds == trunc(mean_seconds), do: trunc(mean_seconds), else: mean_seconds),
      "p50_seconds" => Enum.at(sorted, div(n, 2)),
      "max_seconds" => Enum.max(sorted),
      "pass" => pass,
      "fail" => n - pass
    }
  end

  defp recompute_statistics!(_, _), do: raise(ArgumentError, "runs must be a non-empty list")

  defp validate_window_bounds!(runs, event, cutoff, endpoint) do
    cutoff_at = parse_timestamp!(cutoff)
    endpoint_at = parse_timestamp!(endpoint)

    for run <- runs do
      unless is_map(run) and run["event"] == event, do: raise(ArgumentError, "wrong event")

      unless is_binary(run["conclusion"]) and run["conclusion"] != "",
        do: raise(ArgumentError, "nonterminal")

      created_at = parse_timestamp!(run["created_at"])
      updated_at = parse_timestamp!(run["updated_at"])
      if DateTime.compare(created_at, cutoff_at) == :lt, do: raise(ArgumentError, "pre-cutoff")

      if DateTime.compare(created_at, endpoint_at) == :gt or
           DateTime.compare(updated_at, endpoint_at) == :gt,
         do: raise(ArgumentError, "post-endpoint")
    end
  end

  defp parse_timestamp!(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, timestamp, _offset} -> timestamp
      _ -> raise ArgumentError, "malformed timestamp"
    end
  end

  defp parse_timestamp!(_), do: raise(ArgumentError, "malformed timestamp")

  defp canonical_output_receipt(statistics) do
    trigger = Map.fetch!(statistics, "trigger")
    n = Map.fetch!(statistics, "n")
    mean_seconds = Map.fetch!(statistics, "mean_seconds")
    p50_seconds = Map.fetch!(statistics, "p50_seconds")
    max_seconds = Map.fetch!(statistics, "max_seconds")
    pass = Map.fetch!(statistics, "pass")
    fail = Map.fetch!(statistics, "fail")

    "[\n" <>
      "  {\n" <>
      "    \"trigger\": #{Jason.encode!(trigger)},\n" <>
      "    \"n\": #{n},\n" <>
      "    \"mean_seconds\": #{Jason.encode!(mean_seconds)},\n" <>
      "    \"p50_seconds\": #{p50_seconds},\n" <>
      "    \"max_seconds\": #{max_seconds},\n" <>
      "    \"pass\": #{pass},\n" <>
      "    \"fail\": #{fail}\n" <>
      "  }\n" <>
      "]\n"
  end

  defp sha256_hex(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp same_instant?(left, right) do
    {:ok, left, _} = DateTime.from_iso8601(left)
    {:ok, right, _} = DateTime.from_iso8601(right)
    DateTime.compare(left, right) == :eq
  end

  defp row_key(row), do: {row["family"], row["spec"] || "", row["event"]}

  defp expected_ownership_keys! do
    playwright_specs =
      @inventory_path
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("specs")
      |> Enum.map(&Map.fetch!(&1, "spec"))

    (Enum.map(playwright_specs, &{"playwright_spec", &1}) ++
       Enum.map(required_non_playwright_families(), &{&1, nil}))
    |> Enum.flat_map(fn {family, spec} ->
      Enum.map(@events, &{family, spec || "", &1})
    end)
    |> MapSet.new()
  end

  defp inventory_sha256! do
    {output, 0} = System.cmd("shasum", ["-a", "256", @inventory_path])
    output |> String.split() |> hd()
  end

  defp required_non_playwright_families do
    ~w(design_gallery_snapshots design_gallery_axe admin_eval_render admin_eval_harness_guards generated_host_acceptance library_ordinary_shards library_scaffold_golden library_dep_off library_tests_aggregate example_playwright_aggregate ci_gate_aggregate)
  end
end
