defmodule Sigra.Planning.Phase235TerminalRatificationContractTest do
  use ExUnit.Case, async: true

  @ledger_path ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
  @protected_receipt_path ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.json"
  @workflow_path ".github/workflows/ci.yml"
  @evidence_workflow_path ".github/workflows/terminal-ratification-evidence.yml"
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

  test "protected terminal-ratification evidence workflow exists" do
    workflow = File.read!(@evidence_workflow_path)

    assert workflow =~ "workflow_dispatch:"
    assert workflow =~ "refs/heads/main"
    assert workflow =~ "actions/attest-build-provenance@0f67c3f4856b2e3261c31976d6725780e5e4c373"
  end

  test "captured measurements require protected offline provenance" do
    provenance = ledger!()["capture_endpoint"]["protected_provenance"]

    assert provenance == %{
             "artifact_path" =>
               ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.json",
             "attestation_path" =>
               ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.attestation.jsonl",
             "trusted_root_path" =>
               ".planning/phases/235-terminal-ratification-measured-not-read/235-TRUSTED-ROOT.jsonl",
             "signer_workflow" =>
               "szTheory/sigra/.github/workflows/terminal-ratification-evidence.yml",
             "source_ref" => "refs/heads/main",
             "subject_sha256" =>
               "022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244",
             "workflow_sha" => "83ef9f5d7b00a99aa945cf9839c056283c3e6c65",
             "workflow_run_id" => 30_782_184_713,
             "workflow_run_url" => "https://github.com/szTheory/sigra/actions/runs/30782184713"
           }
  end

  test "required fast checks continuously verify retained offline provenance" do
    workflow = File.read!(@workflow_path)
    verifier = File.read!("scripts/ci/verify-terminal-ratification-attestation-offline.sh")

    assert workflow =~ "bash scripts/ci/verify-terminal-ratification-attestation-offline.test.sh"
    assert workflow =~ "bash scripts/ci/verify-terminal-ratification-attestation-offline.sh"
    assert verifier =~ ~s(\"$GH_BIN\" attestation verify)
    refute verifier =~ ~r/\n\s+gh attestation verify/
  end

  test "terminal verifier pins bash and trusted staging before input copies" do
    verifier = File.read!("scripts/ci/verify-terminal-ratification-attestation-offline.sh")

    runtime_test =
      File.read!("scripts/ci/verify-terminal-ratification-attestation-offline.test.sh")

    assert String.starts_with?(verifier, "#!/bin/bash\n")
    assert verifier =~ "BASH_SOURCE[0]"
    refute verifier =~ "command -v"
    assert verifier =~ "TMPDIR= TMP= TEMP="
    assert verifier =~ "trusted_staging_failed"

    assert runtime_test =~
             "bash dirname uname mktemp realpath readlink stat env gh jq mkdir cp rm sandbox-exec unshare sudo true dd"

    assert runtime_test =~ "offline_attestation_verified"
  end

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

  test "ownership receipts bind each terminal event to retained jobs bytes" do
    ledger = ledger!()

    assert_raise ArgumentError, ~r/ownership receipt/, fn ->
      update_in(
        ledger,
        ["receipts", "ownership", "pull_request"],
        &Map.delete(&1, "jobs_receipt")
      )
      |> validate_ledger!()
    end
  end

  test "ownership semantics reject live-but-wrong destinations across every class" do
    ledger = ledger!()

    for family <- required_non_playwright_families() ++ ["playwright_spec"] do
      index =
        Enum.find_index(
          ledger["ownership"]["rows"],
          &(&1["family"] == family and &1["event"] == "pull_request")
        )

      assert_raise ArgumentError, ~r/ownership semantics/, fn ->
        put_in(ledger, ["ownership", "rows", Access.at(index), "receiver"], "wrong-receiver")
        |> validate_ledger!()
      end

      assert_raise ArgumentError, ~r/ownership semantics/, fn ->
        put_in(
          ledger,
          ["ownership", "rows", Access.at(index), "after", "direct_owner"],
          "fast_checks"
        )
        |> validate_ledger!()
      end
    end
  end

  test "ownership semantics reject direct jobs whose event guards cannot execute" do
    ledger = ledger!()
    workflow = File.read!(@workflow_path)

    assert_raise ArgumentError, ~r/ownership event execution library_ordinary_shards/, fn ->
      String.replace(
        workflow,
        "  library_tests_shard:\n",
        "  library_tests_shard:\n    if: false\n",
        global: false
      )
      |> then(&validate_ownership_semantics!(ledger["ownership"]["rows"], &1))
    end

    assert_raise ArgumentError, ~r/ownership event execution library_ordinary_shards/, fn ->
      String.replace(
        workflow,
        "  library_tests_shard:\n",
        "  library_tests_shard:\n    if: github.event_name != 'pull_request'\n",
        global: false
      )
      |> then(&validate_ownership_semantics!(ledger["ownership"]["rows"], &1))
    end

    assert_raise ArgumentError, ~r/ownership event execution library_ordinary_shards/, fn ->
      String.replace(
        workflow,
        "  library_tests_shard:\n",
        "  library_tests_shard:\n    if: github.event_name == 'push'\n",
        global: false
      )
      |> then(&validate_ownership_semantics!(ledger["ownership"]["rows"], &1))
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

    assert_raise ArgumentError, ~r/inverted run timestamps/, fn ->
      ledger
      |> put_in(
        ["measurements", "pull_request", "runs", Access.at(0), "created_at"],
        "2026-08-02T18:00:00Z"
      )
      |> put_in(
        ["measurements", "pull_request", "runs", Access.at(0), "updated_at"],
        "2026-08-02T17:59:59Z"
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

  test "protected receipt digest, measured run fields, and job manifests are bound to the ledger" do
    ledger = ledger!()
    receipt = protected_receipt!()

    assert validate_protected_receipt!(ledger, receipt) == :ok

    assert_raise ArgumentError, ~r/protected receipt population/, fn ->
      receipt
      |> put_in(
        [
          "workflow_runs",
          "pages",
          Access.at(0),
          "body",
          "workflow_runs",
          Access.at(0),
          "conclusion"
        ],
        "cancelled"
      )
      |> then(&validate_protected_receipt!(ledger, &1))
    end

    assert_raise ArgumentError, ~r/protected receipt jobs manifest/, fn ->
      update_in(receipt, ["jobs"], &Enum.drop(&1, 1))
      |> then(&validate_protected_receipt!(ledger, &1))
    end

    push_run_id = protected_event_run_ids(receipt, "push") |> hd()

    assert_raise ArgumentError, ~r/protected ownership job/, fn ->
      update_in(receipt, ["jobs"], fn manifests ->
        Enum.map(manifests, fn manifest ->
          if manifest["run_id"] == push_run_id do
            update_in(manifest, ["pages", Access.at(0), "body", "jobs"], fn jobs ->
              Enum.map(jobs, fn job ->
                if String.starts_with?(job["name"], "Admin eval render + probe"),
                  do: Map.put(job, "name", "Removed protected owner"),
                  else: job
              end)
            end)
          else
            manifest
          end
        end)
      end)
      |> then(&validate_protected_receipt!(ledger, &1))
    end

    schedule_run_id = protected_event_run_ids(receipt, "schedule") |> hd()

    assert_raise ArgumentError, ~r/protected ownership job/, fn ->
      update_in(receipt, ["jobs"], fn manifests ->
        Enum.map(manifests, fn manifest ->
          if manifest["run_id"] == schedule_run_id do
            update_in(manifest, ["pages", Access.at(0), "body", "jobs"], fn jobs ->
              Enum.map(jobs, fn job ->
                if String.starts_with?(job["name"], "Library tests shard"),
                  do: Map.put(job, "conclusion", "skipped"),
                  else: job
              end)
            end)
          else
            manifest
          end
        end)
      end)
      |> then(&validate_protected_receipt!(ledger, &1))
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
  defp protected_receipt!, do: @protected_receipt_path |> File.read!() |> Jason.decode!()

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
    validate_ownership_receipts!(ledger["receipts"]["ownership"])
    validate_ownership_semantics!(ledger["ownership"]["rows"])
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

    unless Map.take(
             capture["protected_provenance"] || %{},
             ~w(artifact_path attestation_path trusted_root_path signer_workflow source_ref subject_sha256 workflow_sha workflow_run_id workflow_run_url)
           ) == %{
             "artifact_path" =>
               ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.json",
             "attestation_path" =>
               ".planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.attestation.jsonl",
             "trusted_root_path" =>
               ".planning/phases/235-terminal-ratification-measured-not-read/235-TRUSTED-ROOT.jsonl",
             "signer_workflow" =>
               "szTheory/sigra/.github/workflows/terminal-ratification-evidence.yml",
             "source_ref" => "refs/heads/main",
             "subject_sha256" =>
               "022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244",
             "workflow_sha" => "83ef9f5d7b00a99aa945cf9839c056283c3e6c65",
             "workflow_run_id" => 30_782_184_713,
             "workflow_run_url" => "https://github.com/szTheory/sigra/actions/runs/30782184713"
           },
           do: raise(ArgumentError, "protected provenance")

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
                 get_in(after_row, ["terminal_aggregate", "id"]) == expected and
                 row["receiver"] == expected,
               do: raise(ArgumentError, "ci-gate ownership semantics")
      end
    end
  end

  defp validate_rows!(_), do: raise(ArgumentError, "ownership rows")

  defp validate_ownership_receipts!(receipts) when is_map(receipts) do
    unless MapSet.new(Map.keys(receipts)) == MapSet.new(@events),
      do: raise(ArgumentError, "ownership receipt events")

    for event <- @events do
      receipt = receipts[event] || %{}
      jobs_receipt = receipt["jobs_receipt"] || %{}

      unless is_integer(receipt["run_id"]) and receipt["run_id"] > 0 and
               receipt["run_url"] ==
                 "https://github.com/szTheory/sigra/actions/runs/#{receipt["run_id"]}" and
               receipt["jobs_command"] ==
                 "gh run view #{receipt["run_id"]} --repo szTheory/sigra --json databaseId,event,createdAt,updatedAt,conclusion,url,headSha,jobs" and
               MapSet.new(Map.keys(jobs_receipt)) == MapSet.new(~w(command output sha256)) and
               jobs_receipt["command"] == receipt["jobs_command"] and
               is_binary(jobs_receipt["output"]) and
               jobs_receipt["sha256"] == receipt["jobs_sha256"] and
               jobs_receipt["sha256"] == sha256_hex(jobs_receipt["output"]),
             do: raise(ArgumentError, "ownership receipt #{event}")

      source = Jason.decode!(jobs_receipt["output"])

      unless source["databaseId"] == receipt["run_id"] and source["event"] == event and
               source["url"] == receipt["run_url"] and
               source["conclusion"] == receipt["conclusion"] and
               is_list(source["jobs"]),
             do: raise(ArgumentError, "ownership receipt identity #{event}")
    end
  end

  defp validate_ownership_receipts!(_), do: raise(ArgumentError, "ownership receipts")

  defp validate_ownership_semantics!(rows, workflow \\ File.read!(@workflow_path)) do
    inventory = @inventory_path |> File.read!() |> Jason.decode!() |> Map.fetch!("specs")

    for row <- rows do
      expected = expected_ownership_row!(row, inventory)
      after_row = row["after"]

      unless Map.take(after_row, ~w(direct_owner seam invocation terminal_aggregate state)) ==
               expected.after and
               row["receiver"] == expected.receiver and row["phase"] == expected.phase and
               row["receipt"] == expected.receipt,
             do: raise(ArgumentError, "ownership semantics #{row["family"]}/#{row["event"]}")

      direct = workflow_job_block!(workflow, after_row["direct_owner"])
      aggregate = workflow_job_block!(workflow, after_row["terminal_aggregate"]["id"])

      require_text!(direct, "name:", "ownership direct job")

      require_text!(
        aggregate,
        "name: #{after_row["terminal_aggregate"]["name"]}",
        "ownership aggregate name"
      )

      case after_row["state"] do
        "executed" ->
          unless event_job_executed?(row["event"], direct),
            do: raise(ArgumentError, "ownership event execution #{row["family"]}")

        "intentionally_absent" ->
          require_text!(direct, "github.event_name != 'pull_request'", "ownership absent guard")

        _ ->
          raise ArgumentError, "ownership state"
      end
    end
  end

  defp expected_ownership_row!(
         %{"family" => "playwright_spec", "spec" => spec, "event" => event},
         inventory
       ) do
    lanes = inventory |> Enum.find(&(&1["spec"] == spec)) |> Map.fetch!("lanes")
    lane = Enum.find(lanes, &(event in &1["events"])) || hd(lanes)
    owner = lane["job"]

    {owner, seam, invocation} =
      case spec do
        "test/example/priv/playwright/tests/admin-eval.spec.ts" ->
          {"admin_eval_render", "Run admin-eval harness", "scripts/ci/admin-eval-harness.sh"}

        "test/example/priv/playwright/tests/admin-generated.spec.ts" ->
          {"generated_admin_playwright_smoke", "generated_admin_playwright_smoke",
           "scripts/ci/admin-acceptance-smoke.sh --test all"}

        _ ->
          {owner, owner, lane["command_marker"]}
      end

    state =
      if event == "pull_request" and owner == "admin_eval_render",
        do: "intentionally_absent",
        else: "executed"

    %{
      after: %{
        "direct_owner" => owner,
        "seam" => seam,
        "invocation" => invocation,
        "terminal_aggregate" => %{
          "id" => "example_playwright_smoke",
          "name" => "Example Playwright smoke (full lifecycle)"
        },
        "state" => state
      },
      receiver: owner,
      phase: "232-playwright-economics-authenticate-once-then-shard",
      receipt: "phase_232_playwright_suite"
    }
  end

  defp expected_ownership_row!(%{"family" => family, "event" => event}, _inventory) do
    {owner, seam, invocation, aggregate, phase, receipt} =
      case family do
        f when f in ~w(admin_eval_harness_guards admin_eval_render) ->
          {"admin_eval_render", "Run admin-eval harness", "scripts/ci/admin-eval-harness.sh",
           "example_playwright_smoke", "231-gate-honesty-nightly-revival",
           "phase_232_playwright_suite"}

        "ci_gate_aggregate" ->
          {"ci-gate", "ci-gate", "ci-gate", "ci-gate", "231-gate-honesty-nightly-revival",
           "phase_232_playwright_suite"}

        "design_gallery_snapshots" ->
          {"admin_design_recapture", "admin_design_recapture", "tests/admin-design.spec.ts",
           "example_playwright_smoke", "232-playwright-economics-authenticate-once-then-shard",
           "phase_232_playwright_suite"}

        f when f in ~w(design_gallery_axe example_playwright_aggregate) ->
          {"example_playwright_shard", "example_playwright_shard", "tests/*.spec.ts",
           "example_playwright_smoke", "232-playwright-economics-authenticate-once-then-shard",
           "phase_232_playwright_suite"}

        "generated_host_acceptance" ->
          {"generated_admin_playwright_smoke", "generated_admin_playwright_smoke",
           "scripts/ci/admin-acceptance-smoke.sh --test all", "example_playwright_smoke",
           "231-gate-honesty-nightly-revival", "phase_232_playwright_suite"}

        "library_dep_off" ->
          {"library_tests_dep_off", "library_tests_dep_off", "ci-gate", "library_tests",
           "233-library-suite-economics", "phase_233_library_suite"}

        f when f in ~w(library_ordinary_shards library_scaffold_golden library_tests_aggregate) ->
          {"library_tests_shard", "Run contributor CI gate", "MIX_ENV=test mix ci",
           "library_tests", "233-library-suite-economics", "phase_233_library_suite"}
      end

    state =
      if event == "pull_request" and owner in ~w(admin_eval_render admin_design_recapture),
        do: "intentionally_absent",
        else: "executed"

    aggregate_name =
      if aggregate == "library_tests",
        do: "Library tests",
        else:
          if(aggregate == "ci-gate",
            do: "ci-gate",
            else: "Example Playwright smoke (full lifecycle)"
          )

    %{
      after: %{
        "direct_owner" => owner,
        "seam" => seam,
        "invocation" => invocation,
        "terminal_aggregate" => %{"id" => aggregate, "name" => aggregate_name},
        "state" => state
      },
      receiver: owner,
      phase: phase,
      receipt: receipt
    }
  end

  defp event_job_executed?(event, job_block) do
    case Regex.named_captures(~r/^    if:\s*(?<condition>.+?)\s*$/m, job_block) do
      nil -> true
      %{"condition" => condition} -> event_condition_allows?(condition, event)
    end
  end

  defp event_condition_allows?(condition, event) do
    condition
    |> String.trim()
    |> String.replace_prefix("${{", "")
    |> String.replace_suffix("}}", "")
    |> String.split("#", parts: 2)
    |> hd()
    |> String.trim()
    |> String.split("||", trim: true)
    |> Enum.map(&event_condition_and_allows?(&1, event))
    |> Enum.any?(& &1)
  end

  defp event_condition_and_allows?(condition, event) do
    condition
    |> String.split("&&", trim: true)
    |> Enum.map(&event_condition_atom_allows?(&1, event))
    |> Enum.all?(& &1)
  end

  defp event_condition_atom_allows?(atom, event) do
    atom = String.trim(atom)

    cond do
      atom in ["true", "always()", "!cancelled()"] ->
        true

      atom in [
        "needs.release_ref_guard.result == 'success'",
        "needs.changes.outputs.docs_only != 'true'"
      ] ->
        true

      captures =
          Regex.named_captures(
            ~r/^github\.event_name\s*(?<operator>==|!=)\s*['\"](?<expected>[^'\"]+)['\"]$/,
            atom
          ) ->
        case captures do
          %{"operator" => "==", "expected" => expected} -> event == expected
          %{"operator" => "!=", "expected" => expected} -> event != expected
        end

      true ->
        false
    end
  end

  defp validate_captured_ledger!(ledger) do
    unless ledger["capture_endpoint"]["status"] == "captured",
      do: raise(ArgumentError, "captured endpoint")

    cutoff = ledger["topology_cutoff"]["committed_at"]
    endpoint = ledger["capture_endpoint"]["captured_at"]

    unless endpoint == @capture_instant and
             ledger["capture_endpoint"]["population_sha256"] == @population_sha,
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
                 is_binary(run["head_sha"]) and
                 Regex.match?(~r/\A[0-9a-f]{40}\z/, run["head_sha"])
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

    source_runs = validate_source_receipt!(ledger["capture_endpoint"], cutoff, endpoint)
    cutoff_at = parse_timestamp!(cutoff)
    endpoint_at = parse_timestamp!(endpoint)

    bounded_source =
      source_runs
      |> Enum.filter(fn run ->
        source_run_within_window?(run, cutoff_at, endpoint_at) and run["event"] in @events
      end)
      |> Map.new(&{&1["databaseId"], source_run_to_ledger_run(&1)})

    measured_runs =
      for event <- @events,
          run <- ledger["measurements"][event]["runs"],
          into: %{},
          do: {run["id"], run}

    unless bounded_source == measured_runs,
      do: raise(ArgumentError, "source receipt population")

    validate_protected_receipt!(ledger, protected_receipt!())

    :ok
  end

  defp validate_protected_receipt!(ledger, receipt) do
    provenance = ledger["capture_endpoint"]["protected_provenance"]
    receipt_bytes = File.read!(@protected_receipt_path)

    unless sha256_hex(receipt_bytes) == provenance["subject_sha256"],
      do: raise(ArgumentError, "protected receipt digest")

    unless receipt["schema_version"] == "sigra.terminal-ratification-receipt/v1" and
             receipt["repository"] == "szTheory/sigra" and receipt["workflow"] == "ci.yml" and
             receipt["window"] == %{
               "cutoff" => ledger["topology_cutoff"]["committed_at"],
               "endpoint" => @capture_instant
             },
           do: raise(ArgumentError, "protected receipt identity")

    runs_receipt = receipt["workflow_runs"] || %{}
    pages = runs_receipt["pages"] || []

    unless runs_receipt["requested_pages"] == [1, 2] and runs_receipt["data_page_count"] == 1 and
             runs_receipt["terminal_page"] == 2 and runs_receipt["exhausted"] and
             runs_receipt["total_count"] == 24 and
             Enum.map(pages, & &1["page"]) == [1, 2] and
             is_list(get_in(pages, [Access.at(0), "body", "workflow_runs"])) and
             get_in(pages, [Access.at(0), "body", "total_count"]) == 24 and
             get_in(pages, [Access.at(1), "body", "workflow_runs"]) == [] and
             get_in(pages, [Access.at(1), "body", "total_count"]) == 24,
           do: raise(ArgumentError, "protected receipt workflow manifest")

    protected_runs = get_in(pages, [Access.at(0), "body", "workflow_runs"])
    normalized_runs = Enum.map(protected_runs, &protected_run_to_ledger_run!/1)
    cutoff_at = parse_timestamp!(ledger["topology_cutoff"]["committed_at"])
    endpoint_at = parse_timestamp!(@capture_instant)

    unless length(normalized_runs) == 24 and
             Enum.map(normalized_runs, & &1["id"]) |> Enum.uniq() |> length() == 24,
           do: raise(ArgumentError, "protected receipt workflow population")

    protected_measurements =
      normalized_runs
      |> Enum.filter(
        &(&1["event"] in @events and ledger_run_within_window?(&1, cutoff_at, endpoint_at))
      )
      |> Map.new(&{&1["id"], &1})

    measured_runs =
      for event <- @events,
          run <- ledger["measurements"][event]["runs"],
          into: %{},
          do: {run["id"], run}

    unless protected_measurements == measured_runs,
      do: raise(ArgumentError, "protected receipt population")

    validate_protected_job_manifests!(receipt["jobs"], Map.keys(measured_runs))

    validate_protected_ownership_jobs!(
      ledger["ownership"]["rows"],
      receipt["jobs"],
      protected_runs
    )

    :ok
  end

  defp protected_event_run_ids(receipt, event) do
    receipt["workflow_runs"]["pages"]
    |> Enum.flat_map(& &1["body"]["workflow_runs"])
    |> Enum.filter(&(&1["event"] == event))
    |> Enum.map(& &1["id"])
  end

  defp protected_run_to_ledger_run!(run) do
    normalized = %{
      "id" => run["id"],
      "event" => run["event"],
      "created_at" => run["created_at"],
      "updated_at" => run["updated_at"],
      "conclusion" => run["conclusion"],
      "url" => run["html_url"],
      "head_sha" => run["head_sha"]
    }

    unless is_integer(normalized["id"]) and normalized["id"] > 0 and
             normalized["event"] in (@events ++ ["workflow_dispatch"]) and
             is_binary(normalized["created_at"]) and is_binary(normalized["updated_at"]) and
             is_binary(normalized["conclusion"]) and
             normalized["url"] ==
               "https://github.com/szTheory/sigra/actions/runs/#{normalized["id"]}" and
             is_binary(normalized["head_sha"]) and
             Regex.match?(~r/\A[0-9a-f]{40}\z/, normalized["head_sha"]),
           do: raise(ArgumentError, "protected receipt run fields")

    normalized
  end

  defp ledger_run_within_window?(run, cutoff_at, endpoint_at) do
    created_at = parse_timestamp!(run["created_at"])
    updated_at = parse_timestamp!(run["updated_at"])

    DateTime.compare(created_at, cutoff_at) != :lt and
      DateTime.compare(created_at, endpoint_at) != :gt and
      DateTime.compare(updated_at, created_at) != :lt and
      DateTime.compare(updated_at, endpoint_at) != :gt
  end

  defp validate_protected_job_manifests!(jobs, measurement_ids) when is_list(jobs) do
    manifests = Map.new(jobs, &{&1["run_id"], &1})

    unless MapSet.new(Map.keys(manifests)) == MapSet.new(measurement_ids) and
             length(jobs) == length(measurement_ids),
           do: raise(ArgumentError, "protected receipt jobs manifest")

    for {run_id, manifest} <- manifests do
      pages = manifest["pages"] || []

      unless Enum.map(pages, & &1["page"]) == [1, 2] and
               is_list(get_in(pages, [Access.at(0), "body", "jobs"])) and
               get_in(pages, [Access.at(0), "body", "jobs"]) != [] and
               is_integer(get_in(pages, [Access.at(0), "body", "total_count"])) and
               get_in(pages, [Access.at(1), "body", "jobs"]) == [] and
               get_in(pages, [Access.at(1), "body", "total_count"]) ==
                 get_in(pages, [Access.at(0), "body", "total_count"]) and
               length(get_in(pages, [Access.at(0), "body", "jobs"])) ==
                 get_in(pages, [Access.at(0), "body", "total_count"]) and
               Enum.all?(
                 get_in(pages, [Access.at(0), "body", "jobs"]),
                 &(is_integer(&1["id"]) and &1["run_id"] == run_id)
               ),
             do: raise(ArgumentError, "protected receipt jobs manifest")
    end
  end

  defp validate_protected_job_manifests!(_, _),
    do: raise(ArgumentError, "protected receipt jobs manifest")

  defp validate_protected_ownership_jobs!(rows, jobs, protected_runs) do
    events_by_run = Map.new(protected_runs, &{&1["id"], &1["event"]})
    manifests = Map.new(jobs, &{&1["run_id"], &1})

    runs_by_event =
      protected_runs
      |> Enum.filter(&(&1["event"] in @events))
      |> Enum.group_by(& &1["event"], & &1["id"])

    for row <- rows do
      event = row["event"]
      state = row["after"]["state"]
      name_prefix = workflow_job_name_prefix!(row["after"]["direct_owner"])

      for run_id <- Map.fetch!(runs_by_event, event) do
        jobs_for_owner =
          manifests
          |> Map.fetch!(run_id)
          |> get_in(["pages", Access.at(0), "body", "jobs"])
          |> Enum.filter(
            &(events_by_run[&1["run_id"]] == event and
                String.starts_with?(&1["name"], name_prefix))
          )

        valid? =
          case state do
            "executed" ->
              Enum.any?(jobs_for_owner, fn job ->
                is_binary(job["conclusion"]) and job["conclusion"] not in ["", "skipped"] and
                  is_binary(job["completed_at"])
              end)

            "intentionally_absent" ->
              jobs_for_owner != [] and Enum.all?(jobs_for_owner, &(&1["conclusion"] == "skipped"))

            _ ->
              false
          end

        unless valid?,
          do: raise(ArgumentError, "protected ownership job #{row["family"]}/#{event}/#{run_id}")
      end
    end
  end

  defp workflow_job_name_prefix!(job_id) do
    block = workflow_job_block!(File.read!(@workflow_path), job_id)

    case Regex.run(~r/^    name:\s*(.+?)\s*$/m, block, capture: :all_but_first) do
      [name] -> name |> String.split("${{") |> hd() |> String.trim()
      _ -> raise ArgumentError, "protected ownership job name #{job_id}"
    end
  end

  defp validate_source_receipt!(capture, cutoff, endpoint) do
    receipt = capture["source_receipt"] || %{}

    unless MapSet.new(Map.keys(receipt)) == MapSet.new(~w(command output sha256)) and
             receipt["command"] == capture["source_command"] and is_binary(receipt["output"]) and
             receipt["sha256"] == @population_sha and
             receipt["sha256"] == sha256_hex(receipt["output"]),
           do: raise(ArgumentError, "source receipt")

    runs = Jason.decode!(receipt["output"])
    cutoff_at = parse_timestamp!(cutoff)
    endpoint_at = parse_timestamp!(endpoint)

    unless is_list(runs) and
             Enum.all?(runs, fn run ->
               MapSet.new(Map.keys(run)) ==
                 MapSet.new(~w(databaseId event createdAt updatedAt conclusion url headSha)) and
                 is_integer(run["databaseId"]) and run["databaseId"] > 0 and
                 run["event"] in (@events ++ ["workflow_dispatch"]) and
                 is_binary(run["createdAt"]) and is_binary(run["updatedAt"]) and
                 is_binary(run["conclusion"]) and
                 run["url"] ==
                   "https://github.com/szTheory/sigra/actions/runs/#{run["databaseId"]}" and
                 is_binary(run["headSha"]) and Regex.match?(~r/\A[0-9a-f]{40}\z/, run["headSha"]) and
                 source_run_chronological?(run)
             end) and
             runs |> Enum.map(& &1["databaseId"]) |> Enum.uniq() |> length() == length(runs) and
             Enum.any?(runs, &source_run_within_window?(&1, cutoff_at, endpoint_at)),
           do: raise(ArgumentError, "source receipt fields")

    runs
  end

  defp source_run_chronological?(run) do
    created_at = parse_timestamp!(run["createdAt"])
    updated_at = parse_timestamp!(run["updatedAt"])

    if DateTime.compare(updated_at, created_at) == :lt,
      do: raise(ArgumentError, "inverted source run timestamps")

    true
  end

  defp source_run_within_window?(run, cutoff_at, endpoint_at) do
    created_at = parse_timestamp!(run["createdAt"])
    updated_at = parse_timestamp!(run["updatedAt"])

    DateTime.compare(created_at, cutoff_at) != :lt and
      DateTime.compare(created_at, endpoint_at) != :gt and
      DateTime.compare(updated_at, endpoint_at) != :gt
  end

  defp source_run_to_ledger_run(source) do
    %{
      "id" => source["databaseId"],
      "event" => source["event"],
      "created_at" => source["createdAt"],
      "updated_at" => source["updatedAt"],
      "conclusion" => source["conclusion"],
      "url" => source["url"],
      "head_sha" => source["headSha"]
    }
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
                   is_map(receipt["metrics_receipt"]) and
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
    expected =
      pr_runs
      |> Enum.map(&Map.put(&1, "wall_seconds", wall_seconds!(&1)))
      |> Enum.sort_by(&{&1["wall_seconds"], &1["id"]})
      |> then(fn runs ->
        %{
          "median_neighbor" => Enum.at(runs, div(length(runs), 2)),
          "maximum_duration" => List.last(runs)
        }
      end)

    unless MapSet.new(Enum.map(receipts, & &1["selection"])) == MapSet.new(Map.keys(expected)) and
             length(receipts) == map_size(expected),
           do: raise(ArgumentError, "binding selections")

    for receipt <- receipts do
      run = Map.fetch!(expected, receipt["selection"])
      source = receipt["source_receipt"] || %{}

      unless source["command"] ==
               "gh run view #{receipt["run_id"]} --repo szTheory/sigra --json jobs --jq .jobs" and
               is_binary(source["output"]) and is_binary(source["sha256"]) and
               source["sha256"] == sha256_hex(source["output"]),
             do: raise(ArgumentError, "binding source receipt")

      jobs = Jason.decode!(source["output"])
      pole = receipt["binding_pole"]

      unless receipt["run_url"] == run["url"] and is_list(jobs) and
               Enum.count(jobs, &(&1["name"] == pole["name"])) == 1,
             do: raise(ArgumentError, "binding source identity or job")

      unless receipt["run_id"] == run["id"] and receipt["wall_seconds"] == run["wall_seconds"],
        do: raise(ArgumentError, "binding selection or wall seconds")

      job = Enum.find(jobs, &(&1["name"] == pole["name"]))

      duration =
        max(
          DateTime.diff(
            parse_timestamp!(job["completedAt"]),
            parse_timestamp!(job["startedAt"]),
            :second
          ),
          0
        )

      unless job["conclusion"] == pole["conclusion"] and duration == pole["duration_seconds"],
        do: raise(ArgumentError, "binding job duration")

      metrics = receipt["metrics_receipt"] || %{}

      expected_jobs =
        jobs
        |> Enum.map(fn candidate ->
          %{
            "name" => candidate["name"],
            "conclusion" => candidate["conclusion"],
            "duration_seconds" =>
              max(
                DateTime.diff(
                  parse_timestamp!(candidate["completedAt"]),
                  parse_timestamp!(candidate["startedAt"]),
                  :second
                ),
                0
              )
          }
        end)

      unless MapSet.new(Map.keys(metrics)) == MapSet.new(~w(command output sha256)) and
               metrics["command"] == receipt["command"] and
               metrics["command"] ==
                 "bash scripts/ci/ci-run-metrics.sh --jobs #{run["id"]} --format json" and
               is_binary(metrics["output"]) and Jason.decode!(metrics["output"]) == expected_jobs and
               metrics["sha256"] == sha256_hex(metrics["output"]),
             do: raise(ArgumentError, "binding metrics receipt")
    end
  end

  defp wall_seconds!(run) do
    max(
      DateTime.diff(
        parse_timestamp!(run["updated_at"]),
        parse_timestamp!(run["created_at"]),
        :second
      ),
      0
    )
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

        if DateTime.compare(updated_at, created_at) == :lt,
          do: raise(ArgumentError, "inverted run timestamps")

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

      if DateTime.compare(updated_at, created_at) == :lt,
        do: raise(ArgumentError, "inverted run timestamps")

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
