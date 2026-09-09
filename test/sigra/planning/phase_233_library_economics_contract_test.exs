defmodule Sigra.Planning.Phase233LibraryEconomicsContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"
  @library_jobs ["library_tests_shard", "library_tests", "library_tests_dep_off"]
  @protected_aggregate_sha256 "04308ef8fb56acc65c5730630e1fd3e926da6804068db07f6f15636c2a0890cb"
  @upload_artifact_pin "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
  @remediation_path ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEDIATION.json"

  test "library execution universe is fail-closed and has one full-suite owner" do
    workflow = File.read!(@workflow_path)

    assert library_job_ids(workflow) == @library_jobs

    bodies = Map.new(@library_jobs, &{&1, job_body(workflow, &1)})
    shard = Map.fetch!(bodies, "library_tests_shard")

    assert length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1
    assert length(Regex.scan(~r/MIX_ENV=test mix ci/, Enum.join(Map.values(bodies), "\n"))) == 1
    refute shard =~ "matrix:"
    refute shard =~ "--slowest"
    refute shard =~ "--trace"

    Enum.each(bodies, fn {job_id, body} ->
      refute body =~ "mix test", "#{job_id} must not retain a second test command"
    end)

    refute workflow =~ "library_tests_scaffold:"
  end

  test "protected Library tests aggregation preserves the sole owner and ci-gate link" do
    workflow = File.read!(@workflow_path)
    aggregate = job_body(workflow, "library_tests")
    ci_gate = job_body(workflow, "ci-gate")

    assert aggregate =~ "name: Library tests"
    assert aggregate =~ "needs: [library_tests_shard]"
    assert aggregate =~ "if: always()"
    assert aggregate =~ "SHARD: ${{ needs.library_tests_shard.result }}"
    assert aggregate =~ "\"$SHARD\" != \"success\""
    assert ci_gate =~ "- library_tests"
    assert ci_gate =~ "- library_tests_dep_off"

    assert :crypto.hash(:sha256, aggregate) |> Base.encode16(case: :lower) ==
             @protected_aggregate_sha256
  end

  test "sole owner validates and uploads both fixed receipts fail-closed" do
    shard = @workflow_path |> File.read!() |> job_body("library_tests_shard")

    assert shard =~ "SIGRA_EXUNIT_TIMING_PATH: /tmp/sigra-library-1-timings.json"
    assert shard =~ "SIGRA_LIBRARY_ECONOMICS_PATH: /tmp/sigra-library-economics.json"
    assert shard =~ "Validate per-test timing receipt"
    assert shard =~ "verify-library-economics.sh"
    assert shard =~ "library-test-timings-${{ github.run_id }}-${{ github.run_attempt }}"
    assert shard =~ "library-economics-${{ github.run_id }}-${{ github.run_attempt }}"
    assert length(Regex.scan(~r/if: always\(\)/, shard)) == 4
    assert length(Regex.scan(~r/#{Regex.escape(@upload_artifact_pin)}/, shard)) == 2
    assert length(Regex.scan(~r/if-no-files-found: error/, shard)) == 2
    assert length(Regex.scan(~r/retention-days: 7/, shard)) == 2
  end

  test "dep-off lane remains the docs owner but no longer duplicates alias work" do
    dep_off = job_body(File.read!(@workflow_path), "library_tests_dep_off")

    assert dep_off =~ "mix docs --warnings-as-errors"
    refute dep_off =~ "mix deps.unlock threadline"
    refute dep_off =~ "mix deps.clean threadline"
    refute dep_off =~ "mix compile --warnings-as-errors --no-deps-check"
    refute dep_off =~ "mix test --only threadline_guard --no-deps-check"
  end

  test "mix ci routes both test classes through one economics harness" do
    mix_exs = File.read!("mix.exs")
    harness = File.read!("scripts/ci/library-economics.sh")
    install_runner = File.read!("scripts/ci/install-golden.sh")
    expected_paths = canonical_scaffold_paths()
    live_paths = live_scaffold_paths()

    assert live_paths == expected_paths,
           "canonical scaffold paths must equal the live @tag :scaffold universe"

    assert ci_legs(mix_exs) == [
             "format --check-formatted",
             "deps.get --check-locked",
             "deps.unlock --check-unused",
             "compile --warnings-as-errors",
             "cmd bash scripts/ci/library-economics.sh",
             "sigra.dep_off"
           ]

    assert length(Regex.scan(~r/mix test --exclude scaffold/, harness)) == 1
    assert length(Regex.scan(~r/mix ci\.install_golden/, harness)) == 1
    assert harness =~ "--formatter ExUnit.CLIFormatter"
    assert harness =~ "--formatter Sigra.CI.ExUnitTimingFormatter"
    refute harness =~ "--slowest"
    refute harness =~ "--trace"

    assert install_alias_commands(mix_exs) == ["cmd bash scripts/ci/install-golden.sh"]

    receiver_paths = install_golden_paths(install_runner)

    assert receiver_paths == expected_paths,
           "ci.install_golden must run every live scaffold module exactly once"

    assert length(receiver_paths) == MapSet.size(MapSet.new(receiver_paths)),
           "ci.install_golden must not duplicate scaffold paths"

    Enum.each(receiver_paths, fn path ->
      refute harness =~ path,
             "the harness must call ci.install_golden rather than copy receiver path #{path}"
    end)

    refute mix_exs =~ "test/sigra/install/features/passkeys_js_test.exs"
  end

  test "prepared receivers preserve immutable reads and private mutation ownership" do
    golden = File.read!("test/sigra/install/golden_diff_test.exs")
    idempotency = File.read!("test/sigra/install/idempotency_test.exs")
    upgrade = File.read!("test/upgrade_test.exs")

    assert golden =~ "InstallFixture.variant!(:default_installed)"
    refute golden =~ "InstallFixture.setup_tmp_app()"
    assert idempotency =~ "InstallFixture.checkout!(:default_installed, \"idempotency-rerun\")"
    refute idempotency =~ "InstallFixture.setup_tmp_app()"
    assert length(Regex.scan(~r/InstallFixture\.checkout!\(/, upgrade)) == 3
    assert upgrade =~ "InstallFixture.run_scenarios(scenarios, &run_upgrade_scenario/1)"
    assert upgrade =~ "InstallFixture.checkout!(:no_org_installed, \"upgrade-zero-org\")"
    assert length(Regex.scan(~r/InstallFixture\.checkout!\(:default_installed/, upgrade)) == 2
    refute upgrade =~ "InstallFixture.setup_tmp_app_without_install"
    refute upgrade =~ "@moduletag :upgrade"
  end

  test "remediation receipt is closed, retry-free, source-bound, and preserves the strict prior miss" do
    assert_remediation_receipt!(remediation_receipt!())
  end

  test "remediation receipt rejects altered measurements, timing, source digests, and cutoff" do
    receipt = remediation_receipt!()

    Enum.each(
      [
        put_in(receipt, ["after", "library_job", "duration_seconds"], 692),
        put_in(receipt, ["after", "run_wall_seconds"], 724),
        put_in(receipt, ["after", "run_attempt"], 2),
        put_in(receipt, ["before", "protected_median", "contributor_step_seconds"], 645),
        put_in(receipt, ["file_digests", "mix.exs"], String.duplicate("0", 64)),
        put_in(receipt, ["population_cutoff", "sha"], String.duplicate("a", 40)),
        put_in(receipt, ["immutable_prior_receipt", "verdict"], "pass")
      ],
      fn mutated ->
        assert_raise ExUnit.AssertionError, fn -> assert_remediation_receipt!(mutated) end
      end
    )
  end

  defp library_job_ids(workflow) do
    Regex.scan(~r/^  (library_tests(?:_[a-z_]+)?):$/m, workflow, capture: :all_but_first)
    |> List.flatten()
  end

  defp remediation_receipt!, do: @remediation_path |> File.read!() |> Jason.decode!()

  defp assert_remediation_receipt!(receipt) do
    assert MapSet.new(Map.keys(receipt)) ==
             MapSet.new(
               ~w(schema_version status purpose evidence_design before after immutable_prior_receipt file_digests population_cutoff source_commands)
             )

    assert receipt["schema_version"] == "sigra.fast-01-remediation/v1"
    assert receipt["status"] == "measured_remediation"

    assert receipt["evidence_design"] == %{
             "mode" => "two_pr",
             "measured_remediation_pr" => 195,
             "rule" =>
               "The evidence-only PR records this receipt after the remediation PR merged; its own CI is not the measured remediation run."
           }

    assert receipt["immutable_prior_receipt"] == %{
             "path" =>
               ".planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT.json",
             "sha256" => "1245a469b33af8bed185bc0ffff47612d9866c25f816fd5ae58060736149cd02",
             "eligible_pr_run_count" => 13,
             "p50_seconds" => 724,
             "verdict" => "miss"
           }

    assert receipt["before"]["protected_median"] == %{
             "run_id" => 30_844_334_551,
             "library_job_seconds" => 692,
             "contributor_step_seconds" => 646,
             "run_wall_seconds" => 724
           }

    assert Enum.map(receipt["before"]["source_runs"], & &1["run_id"]) == [
             30_828_457_128,
             30_844_334_551,
             30_840_458_645
           ]

    assert Enum.map(receipt["before"]["source_runs"], & &1["library_job"]["duration_seconds"]) ==
             [673, 692, 698]

    assert Enum.all?(receipt["before"]["source_runs"], &timing_consistent?/1)

    after_run = receipt["after"]

    assert MapSet.new(Map.keys(after_run)) ==
             MapSet.new(
               ~w(run_id pr_number head_sha url event conclusion run_attempt retry_free created_at updated_at run_wall_seconds library_job protected_aggregate)
             )

    assert after_run["run_id"] == 30_854_850_199
    assert after_run["pr_number"] == 195
    assert after_run["head_sha"] == "d034eaa0473f28e60214343673e5f05c36c1460b"
    assert after_run["event"] == "pull_request"
    assert after_run["conclusion"] == "success"
    assert after_run["run_attempt"] == 1
    assert after_run["retry_free"]

    assert duration_seconds(after_run["created_at"], after_run["updated_at"]) ==
             after_run["run_wall_seconds"]

    assert after_run["library_job"]["name"] == "Library tests shard"
    assert after_run["library_job"]["conclusion"] == "success"
    assert timing_consistent?(after_run)
    assert after_run["library_job"]["duration_seconds"] < 692
    assert after_run["run_wall_seconds"] < 724
    assert after_run["protected_aggregate"]["name"] == "Library tests"
    assert after_run["protected_aggregate"]["conclusion"] == "success"

    assert receipt["file_digests"] == %{
             "mix.exs" => "8b96195f50a5b22b33e44620d4c19a49bd039188a15400553a739094581c84ca",
             "CONTRIBUTING.md" =>
               "33d045c1fe8940a050db76d087ab1e8b45020b404d2f122032c50c170d11760b",
             "test/sigra/planning/phase_198_contributor_dx_contract_test.exs" =>
               "f72e3be86a7bf1bbb59572b3d01899b77d37cca8a2112b45d8550d08a5d02b7d",
             "test/sigra/planning/phase_233_library_economics_contract_test.exs" =>
               "cf90ce56cf583f96a98a1bf0b0b517d2cfab8e0986c7c7b3e6564a25d6041010"
           }

    assert receipt["population_cutoff"] == %{
             "sha" => "54c33e904155a454255952666711c882afdd06e4",
             "timestamp" => "2026-08-03T21:37:08Z",
             "source" => "ruleset-governed squash merge of remediation PR #195"
           }
  end

  defp timing_consistent?(run) do
    job = run["library_job"]
    job_ok? = duration_seconds(job["started_at"], job["completed_at"]) == job["duration_seconds"]

    step_ok? =
      case job["contributor_step"] do
        nil ->
          true

        step ->
          duration_seconds(step["started_at"], step["completed_at"]) == step["duration_seconds"]
      end

    job_ok? and step_ok?
  end

  defp duration_seconds(started_at, completed_at) do
    {:ok, start, 0} = DateTime.from_iso8601(started_at)
    {:ok, completed, 0} = DateTime.from_iso8601(completed_at)
    DateTime.diff(completed, start, :second)
  end

  defp ci_legs(mix_exs) do
    mix_exs
    |> alias_body("ci")
    |> quoted_values()
  end

  defp install_alias_commands(mix_exs) do
    mix_exs |> alias_body("ci.install_golden") |> quoted_values()
  end

  defp install_golden_paths(runner) do
    [_, body] = Regex.run(~r/receiver_paths=\(\n(?<body>.*?)\n\)/s, runner)

    body
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.ends_with?(&1, "_test.exs"))
    |> Enum.sort()
  end

  defp alias_body(mix_exs, alias_name) do
    escaped_name = Regex.escape(alias_name)

    case Regex.run(~r/"?#{escaped_name}"?:\s*\[(.*?)\]/s, mix_exs) do
      [_, body] -> body
      _ -> flunk("missing #{alias_name} alias")
    end
  end

  defp quoted_values(body) do
    Regex.scan(~r/"([^"]+)"/, body, capture: :all_but_first)
    |> List.flatten()
  end

  defp canonical_scaffold_paths do
    [_, scaffold_set] =
      Regex.run(
        ~r/@scaffold_paths\s+MapSet\.new\(\[(.*?)\]\)/s,
        File.read!("test/support/ci/library_test_partitions.exs")
      )

    Regex.scan(~r/"(test\/[^\"]+_test\.exs)"/, scaffold_set, capture: :all_but_first)
    |> List.flatten()
    |> Enum.sort()
  end

  defp live_scaffold_paths do
    "test/**/*_test.exs"
    |> Path.wildcard()
    |> Enum.filter(fn path -> File.read!(path) =~ ~r/^\s*@moduletag\s+:scaffold\b/m end)
    |> Enum.sort()
  end

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end
end
