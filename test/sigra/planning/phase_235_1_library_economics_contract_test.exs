defmodule Sigra.Planning.Phase2351LibraryEconomicsContractTest do
  use ExUnit.Case, async: false

  @receipt_path "/tmp/sigra-library-economics.json"
  @phase_235_dir ".planning/phases/235-terminal-ratification-measured-not-read"
  @fast_verifier "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh"
  @terminal_verifier "scripts/ci/verify-terminal-ratification-attestation-offline.sh"

  setup do
    File.rm(@receipt_path)
    on_exit(fn -> File.rm(@receipt_path) end)
    :ok
  end

  test "production verifier accepts exact evidence and both equality boundaries" do
    assert_receipt_accepted!(valid_receipt(ordinary_ms: 2_000, install_ms: 1_000))
    assert_receipt_accepted!(valid_receipt(ordinary_ms: 1_000, install_ms: 1_000))
  end

  test "production verifier rejects every truth-bearing mutation and edge shape" do
    receipt = valid_receipt()

    mutations = [
      {Map.delete(receipt, "schema_version"), "top-level keys"},
      {Map.put(receipt, "unexpected", true), "top-level keys"},
      {Map.put(receipt, "schema_version", "sigra.library-economics/v0"), "schema_version"},
      {Map.put(receipt, "timing_receipt_path", "/tmp/forged.json"), "timing_receipt_path"},
      {Map.put(receipt, "install_leg_ran", false), "install_leg_ran"},
      {Map.put(receipt, "install_leg_ran", "true"), "install_leg_ran"},
      {Map.put(receipt, "classes", %{}), "exactly two fixed classes"},
      {put_in(receipt, ["classes", "install_scaffold"], nil), "install_scaffold keys"},
      {update_in(receipt, ["classes"], &Map.delete(&1, "install_scaffold")),
       "exactly two fixed classes"},
      {put_in(receipt, ["classes", "forged"], receipt["classes"]["ordinary"]),
       "exactly two fixed classes"},
      {put_in(receipt, ["classes", "ordinary", "duration_ms"], 0), "raw integer timing"},
      {put_in(receipt, ["classes", "ordinary", "duration_ms"], 1_001), "arithmetic predicate"},
      {put_in(receipt, ["classes", "ordinary", "start_ms"], -1), "raw integer timing"},
      {put_in(receipt, ["classes", "ordinary", "end_ms"], 1_000.5), "raw integer timing"},
      {put_in(receipt, ["classes", "ordinary", "conclusion"], "failure"), "conclusion predicate"},
      {put_in(receipt, ["classes", "ordinary", "exit_status"], 1), "exit-status predicate"},
      {put_in(receipt, ["classes", "ordinary", "verified"], true), "ordinary keys"},
      {put_in(receipt, ["classes", "install_scaffold", "duration_ms"], 2_001),
       "arithmetic predicate"},
      {valid_receipt(ordinary_ms: 1_000, install_ms: 2_001), "comparability predicate"},
      {valid_receipt(ordinary_ms: 1_000, install_ms: 1_001), "non-dominance predicate"}
    ]

    Enum.each(mutations, fn {mutation, diagnostic} ->
      assert_receipt_rejected!(mutation, diagnostic)
    end)

    assert_missing_receipt_rejected!()
    assert_raw_receipt_rejected!("")
    assert_raw_receipt_rejected!("null")

    assert_raw_receipt_rejected!(
      ~s({"schema_version":"sigra.library-economics/v1","schema_version":"sigra.library-economics/v1"})
    )
  end

  test "current contributor and workflow topology has one measured owner and two fail-closed receipts" do
    assert_current_topology!()
  end

  test "same ordinary run consumes the formatter and preserves deterministic unique timing evidence" do
    assert_formatter_contract!()
  end

  test "protected FAST-01 and GATE-05 verifiers remain independently green" do
    assert_protected_verifiers!()
  end

  test "protected digests, semantic tuples, and negative history remain immutable" do
    assert_protected_evidence!()
  end

  defp valid_receipt(opts \\ []) do
    ordinary_ms = Keyword.get(opts, :ordinary_ms, 1_000)
    install_ms = Keyword.get(opts, :install_ms, 500)

    %{
      "schema_version" => "sigra.library-economics/v1",
      "timing_receipt_path" => "/tmp/sigra-library-1-timings.json",
      "install_leg_ran" => true,
      "classes" => %{
        "ordinary" => %{
          "start_ms" => 1_000,
          "end_ms" => 1_000 + ordinary_ms,
          "duration_ms" => ordinary_ms,
          "conclusion" => "success",
          "exit_status" => 0
        },
        "install_scaffold" => %{
          "start_ms" => 10_000,
          "end_ms" => 10_000 + install_ms,
          "duration_ms" => install_ms,
          "conclusion" => "success",
          "exit_status" => 0
        }
      }
    }
  end

  defp assert_receipt_accepted!(receipt) do
    File.write!(@receipt_path, Jason.encode!(receipt))

    assert {"verify-library-economics: PASS\n", 0} =
             System.cmd("bash", ["scripts/ci/verify-library-economics.sh"],
               stderr_to_stdout: true
             )
  end

  defp assert_receipt_rejected!(receipt, diagnostic) do
    File.write!(@receipt_path, Jason.encode!(receipt))

    {output, status} =
      System.cmd("bash", ["scripts/ci/verify-library-economics.sh"], stderr_to_stdout: true)

    assert status != 0
    assert output =~ diagnostic
    refute output =~ "verify-library-economics: PASS"
  end

  defp assert_raw_receipt_rejected!(raw) do
    File.write!(@receipt_path, raw)

    {output, status} =
      System.cmd("bash", ["scripts/ci/verify-library-economics.sh"], stderr_to_stdout: true)

    assert status != 0
    assert output =~ "verify-library-economics: FAIL"
    refute output =~ "verify-library-economics: PASS"
  end

  defp assert_missing_receipt_rejected! do
    File.rm(@receipt_path)

    {output, status} =
      System.cmd("bash", ["scripts/ci/verify-library-economics.sh"], stderr_to_stdout: true)

    assert status != 0
    assert output =~ "receipt must be a regular non-symlink file"
  end

  defp assert_current_topology! do
    workflow = File.read!(".github/workflows/ci.yml")
    mix_exs = File.read!("mix.exs")
    harness = File.read!("scripts/ci/library-economics.sh")
    shard = job_body(workflow, "library_tests_shard")
    aggregate = job_body(workflow, "library_tests")

    assert library_job_ids(workflow) == [
             "library_tests_shard",
             "library_tests",
             "library_tests_dep_off"
           ]

    assert length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1

    assert ci_legs(mix_exs) |> Enum.count(&(&1 == "cmd bash scripts/ci/library-economics.sh")) ==
             1

    assert length(Regex.scan(~r/mix test --exclude scaffold/, harness)) == 1
    assert length(Regex.scan(~r/mix ci\.install_golden/, harness)) == 1
    assert harness =~ "install_leg_ran=true"
    refute shard =~ "matrix:"

    assert length(
             Regex.scan(~r/name: Upload (?:per-test timing|library economics) receipt/, shard)
           ) ==
             2

    assert length(Regex.scan(~r/if-no-files-found: error/, shard)) == 2
    assert length(Regex.scan(~r/if: always\(\)/, shard)) == 4
    assert aggregate =~ "name: Library tests"
    assert aggregate =~ "needs: [library_tests_shard]"
    assert aggregate =~ "if: always()"
    assert aggregate =~ ~s("$SHARD" != "success")

    receiver_paths = install_golden_paths(mix_exs)
    assert length(receiver_paths) == 6
    assert length(receiver_paths) == MapSet.size(MapSet.new(receiver_paths))
    assert receiver_paths == live_scaffold_paths()
  end

  defp assert_formatter_contract! do
    harness = File.read!("scripts/ci/library-economics.sh")
    workflow = File.read!(".github/workflows/ci.yml")
    shard = job_body(workflow, "library_tests_shard")
    formatter = File.read!("test/support/ci/ex_unit_timing_formatter.ex")

    assert harness =~ "MIX_TEST_PARTITION=ordinary"
    assert harness =~ ~s(SIGRA_EXUNIT_TIMING_PATH="$TIMING_PATH")
    assert harness =~ "--formatter ExUnit.CLIFormatter"
    assert harness =~ "--formatter Sigra.CI.ExUnitTimingFormatter"
    refute harness =~ "--slowest"
    refute harness =~ "--trace"

    assert formatter =~ "handle_cast({:test_finished, %ExUnit.Test{} = test}"
    assert formatter =~ "Enum.sort_by(&{-&1.time_us, &1.file, &1.module, &1.name})"
    assert formatter =~ "is_integer(time) and time >= 0"
    assert formatter =~ "do: raise(ArgumentError, \"unknown completed test state:"

    assert shard =~ ".total > 0 and .total <= 100000"
    assert shard =~ "([.tests[] | [.file, .module, .name]] | unique | length) == .total"
    assert shard =~ ".tests == (.tests | sort_by([-(.time_us), .file, .module, .name]))"
  end

  defp assert_protected_verifiers! do
    assert {fast_output, 0} = run_offline_verifier(@fast_verifier)
    assert fast_output == "source_complete_offline_attestation_verified\n"

    assert {terminal_output, 0} = run_offline_verifier(@terminal_verifier)

    assert terminal_output =~ "offline_attestation_verified"
  end

  # GitHub-hosted Linux runners disable unprivileged network namespaces. The
  # protected verifiers therefore use their existing passwordless-sudo fallback;
  # invoking the whole verifier with the same privilege keeps gh's state files
  # removable by its EXIT trap. Darwin uses sandbox-exec and needs no elevation.
  defp run_offline_verifier(path) do
    case :os.type() do
      {:unix, :linux} -> System.cmd("sudo", ["-n", "bash", path], stderr_to_stdout: true)
      _ -> System.cmd("bash", [path], stderr_to_stdout: true)
    end
  end

  defp assert_protected_evidence! do
    pins = %{
      Path.join(@phase_235_dir, "235-PROTECTED-RECEIPTS.json") =>
        "022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244",
      Path.join(@phase_235_dir, "235-TERMINAL-RATIFICATION.json") =>
        "c667836535ae1141fe4419b6675777a6aa865dd99da528c33caa5ac16794a27e",
      Path.join(@phase_235_dir, "235-PROTECTED-RECEIPTS.attestation.jsonl") =>
        "af49fd36b603adbdfdeb8698141cea2e8749c1edc3f9b88764e3465b6f84215f",
      Path.join(@phase_235_dir, "235-TRUSTED-ROOT.jsonl") =>
        "65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c",
      @terminal_verifier => "6c0805e0386186f017215ea7bf10bf450c9aafb68ef6742afa2f9e75b0463367",
      Path.join(@phase_235_dir, "235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json") =>
        "a5f4f6d5335755fcac14e9de8827f47f2b04ad3a143df4b6f283ebfc20853594",
      Path.join(
        @phase_235_dir,
        "235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT-TRUSTED-ROOT.jsonl"
      ) => "65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c"
    }

    Enum.each(pins, fn {path, expected} ->
      actual = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
      assert actual == expected, "immutable digest drift: #{path}"
    end)

    source_complete =
      @phase_235_dir
      |> Path.join("235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json")
      |> File.read!()
      |> Jason.decode!()

    assert source_complete["eligible_pr_run_count"] == 52
    assert source_complete["statistics"]["p50_seconds"] == 469
    assert source_complete["verdict"] == "pass"
    assert source_complete["status"] == "measured"
    assert source_complete["binding_poles"] == nil

    terminal =
      @phase_235_dir
      |> Path.join("235-TERMINAL-RATIFICATION.json")
      |> File.read!()
      |> Jason.decode!()

    assert length(get_in(terminal, ["ownership", "rows"])) == 93

    assert get_in(terminal, ["measurements", "push", "statistics"]) == %{
             "fail" => 1,
             "max_seconds" => 1439,
             "mean_seconds" => 1430,
             "n" => 2,
             "p50_seconds" => 1439,
             "pass" => 1,
             "trigger" => "push"
           }

    assert get_in(terminal, ["measurements", "schedule", "statistics"]) == %{
             "fail" => 2,
             "max_seconds" => 1546,
             "mean_seconds" => 1436.5,
             "n" => 2,
             "p50_seconds" => 1546,
             "pass" => 0,
             "trigger" => "schedule"
           }

    history = File.read!(".planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md")

    for immutable_fact <- ["772", "724", "466", "rejected derived-only"] do
      assert history =~ immutable_fact, "missing immutable FAST-01 history: #{immutable_fact}"
    end

    closeout = File.read!(".planning/REQUIREMENTS.md")
    assert closeout =~ "n=52"
    assert closeout =~ "p50 469 seconds"
    assert closeout =~ "34350618761"
    assert closeout =~ "protected run `30782184713`; 93-row execution proof"
  end

  defp ci_legs(mix_exs) do
    mix_exs
    |> alias_body("ci")
    |> quoted_values()
  end

  defp install_golden_paths(mix_exs) do
    mix_exs
    |> alias_body("ci.install_golden")
    |> quoted_values()
    |> Enum.flat_map(fn command ->
      command
      |> String.replace_prefix("test ", "")
      |> String.split(" ", trim: true)
      |> Enum.filter(&String.ends_with?(&1, "_test.exs"))
    end)
  end

  defp alias_body(mix_exs, alias_name) do
    [_, body] = Regex.run(~r/"?#{Regex.escape(alias_name)}"?:\s*\[(.*?)\]/s, mix_exs)
    body
  end

  defp quoted_values(body) do
    Regex.scan(~r/"([^"]+)"/, body, capture: :all_but_first) |> List.flatten()
  end

  defp live_scaffold_paths do
    "test/**/*_test.exs"
    |> Path.wildcard()
    |> Enum.filter(&(File.read!(&1) =~ ~r/^\s*@moduletag\s+:scaffold\b/m))
    |> Enum.sort()
  end

  defp library_job_ids(workflow) do
    Regex.scan(~r/^  (library_tests(?:_[a-z_]+)?):$/m, workflow, capture: :all_but_first)
    |> List.flatten()
  end

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end
end
