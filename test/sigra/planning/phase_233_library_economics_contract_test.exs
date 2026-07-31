defmodule Sigra.Planning.Phase233LibraryEconomicsContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"
  @partition_manifest_path "test/support/ci/library_test_partitions.exs"

  test "ordinary library shards use one parallel test invocation with both formatters" do
    shard = job_body(File.read!(@workflow_path), "library_tests_shard")

    assert shard =~ "partition: [1, 2]"
    assert shard =~ "SIGRA_EXUNIT_TIMING_PATH"
    assert shard =~ "test -s \"$SIGRA_EXUNIT_TIMING_PATH\""
    assert shard =~ "Sigra.CI.ExUnitTimingFormatter"
    assert shard =~ "ExUnit.CLIFormatter"
    assert length(Regex.scan(~r/^          mix test\b/m, shard)) == 1
    refute shard =~ "--slowest"
    refute shard =~ "--trace"
  end

  test "timing output path is selected only by the two shard identities" do
    shard = job_body(File.read!(@workflow_path), "library_tests_shard")

    assert shard =~ "/tmp/sigra-library-${{ matrix.partition }}-timings.json"
    refute shard =~ "timing output unavailable"
  end

  test "timing receipts are retained from the same shard job" do
    shard = job_body(File.read!(@workflow_path), "library_tests_shard")

    assert shard =~ "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
    assert shard =~ "library-test-timings-"
    assert shard =~ "SIGRA_EXUNIT_TIMING_PATH"
  end

  test "scaffold receiver is unconditional, selected by tag, and required by the aggregate" do
    workflow = File.read!(@workflow_path)
    shard = job_body(workflow, "library_tests_shard")
    receiver = job_body(workflow, "library_tests_scaffold")
    aggregate = job_body(workflow, "library_tests")

    assert shard =~ "--exclude scaffold"
    assert receiver =~ "runs-on: ubuntu-latest"
    assert receiver =~ "needs: release_ref_guard"
    refute Regex.match?(~r/^    if:.*(?:changes|docs_only|github\.event_name)/m, receiver)
    assert receiver =~ "postgres:"
    assert receiver =~ "version-type: strict"
    assert receiver =~ "mix archive.install --force hex phx_new 1.8.8"
    assert receiver =~ "mix test --only scaffold"
    assert receiver =~ "/tmp/sigra-library-scaffold-timings.json"
    assert receiver =~ "library-test-timings-scaffold"

    assert aggregate =~ "needs: [library_tests_shard, library_tests_scaffold]"
    assert aggregate =~ "if: always()"
    assert aggregate =~ "SHARDS: ${{ needs.library_tests_shard.result }}"
    assert aggregate =~ "SCAFFOLD: ${{ needs.library_tests_scaffold.result }}"
    assert aggregate =~ "\"$SHARDS\" != \"success\""
    assert aggregate =~ "\"$SCAFFOLD\" != \"success\""
  end

  test "upgrade golden and idempotency modules are scaffold-classified without changing tags" do
    assert module_tags("test/upgrade_test.exs") == [":upgrade", "timeout: 600_000", ":scaffold"]

    assert module_tags("test/sigra/install/golden_diff_test.exs") == [
             ":golden",
             "timeout: 300_000",
             ":scaffold"
           ]

    assert module_tags("test/sigra/install/idempotency_test.exs") == [
             ":integration",
             ":idempotency",
             "timeout: 300_000",
             ":scaffold"
           ]
  end

  test "scaffold classification is the canonical exact six-module set" do
    assert scaffold_modules() ==
             MapSet.new([
               "test/upgrade_test.exs",
               "test/sigra/install/generator_passkeys_opt_out_test.exs",
               "test/sigra/install/features/passkeys_js_test.exs",
               "test/sigra/install/golden_diff_test.exs",
               "test/sigra/install/idempotency_test.exs",
               "test/sigra/install/vault_promotion_test.exs"
             ])

    template_render = File.read!("test/sigra/install/template_render_test.exs")

    assert template_render =~ "use ExUnit.Case, async: true"
    assert template_render =~ "@moduletag :install"
    refute template_render =~ "@moduletag :scaffold"
  end

  test "ordinary shards consume a committed measured two-list manifest" do
    manifest = File.read!(@partition_manifest_path)
    shard = job_body(File.read!(@workflow_path), "library_tests_shard")

    assert manifest =~ "@source_run_id 30_666_977_944"
    assert manifest =~ "def partition(value) when value in [1, \"1\"]"
    assert manifest =~ "def partition(value) when value in [2, \"2\"]"
    assert shard =~ "library_test_partitions.exs"
    assert shard =~ "Sigra.CI.LibraryTestPartitions.partition(\"${{ matrix.partition }}\")"
    assert shard =~ "mix compile --quiet"

    assert shard =~
             "mix run --no-start --no-compile --no-deps-check -r test/support/ci/library_test_partitions.exs"

    refute shard =~ "--partitions 2"
  end

  test "partition validation rejects empty, duplicate, missing, and invalid measured costs" do
    Code.require_file(@partition_manifest_path)

    assert_raise ArgumentError, ~r/non-empty/, fn ->
      Sigra.CI.LibraryTestPartitions.validate!(%{1 => [], 2 => ["test/sigra/auth_test.exs"]})
    end

    assert_raise ArgumentError, ~r/exactly once/, fn ->
      Sigra.CI.LibraryTestPartitions.validate!(%{
        1 => ["test/sigra/auth_test.exs"],
        2 => ["test/sigra/auth_test.exs"]
      })
    end

    assert_raise ArgumentError, ~r/non-negative measured cost/, fn ->
      Sigra.CI.LibraryTestPartitions.assign!([%{"path" => "test/a_test.exs", "time_us" => nil}])
    end

    assert %{
             1 => %{paths: ["test/a_test.exs", "test/b_test.exs"], total_us: 0},
             2 => %{paths: [], total_us: 0}
           } =
             Sigra.CI.LibraryTestPartitions.assign!([
               %{"path" => "test/a_test.exs", "time_us" => 0},
               %{"path" => "test/b_test.exs", "time_us" => 0}
             ])
  end

  @tag :partition_universe
  test "rejects an on-disk ordinary test missing from measured ownership" do
    Code.require_file(@partition_manifest_path)

    root =
      Path.join(
        System.tmp_dir!(),
        "sigra-partition-universe-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(root) end)

    write_fixture(root, "test/measured_test.exs")
    write_fixture(root, "test/second_measured_test.exs")
    write_fixture(root, "test/new_ordinary_test.exs")

    for scaffold_path <- scaffold_paths() do
      write_fixture(root, scaffold_path)
    end

    assert_raise ArgumentError, ~r/missing current paths: test\/new_ordinary_test\.exs/, fn ->
      Sigra.CI.LibraryTestPartitions.build_partitions!(
        root: root,
        costs: [
          %{"path" => "test/measured_test.exs", "time_us" => 2},
          %{"path" => "test/second_measured_test.exs", "time_us" => 1}
        ]
      )
    end
  end

  @tag :partition_universe
  test "uses live load filters and subtracts only the exact scaffold paths" do
    Code.require_file(@partition_manifest_path)
    root = temporary_root()

    write_fixture(root, "test/included_test.exs")
    write_fixture(root, "test/sigra/install/template_render_test.exs")
    write_fixture(root, "test/example/ignored_test.exs")
    write_fixture(root, "test/fixtures/ignored_test.exs")

    for scaffold_path <- scaffold_paths() do
      write_fixture(root, scaffold_path)
    end

    ordinary_paths = Sigra.CI.LibraryTestPartitions.current_ordinary_paths!(root: root)

    assert ordinary_paths == [
             "test/included_test.exs",
             "test/sigra/install/template_render_test.exs"
           ]
  end

  @tag :partition_universe
  test "rejects stale, duplicate, and scaffold-leaking ownership with named diagnostics" do
    Code.require_file(@partition_manifest_path)
    root = complete_universe_root(["test/first_test.exs", "test/second_test.exs"])

    assert_raise ArgumentError, ~r/stale manifest paths: test\/stale_test\.exs/, fn ->
      Sigra.CI.LibraryTestPartitions.validate_current_universe!(
        partition_data(["test/first_test.exs", "test/stale_test.exs"], ["test/second_test.exs"]),
        root: root
      )
    end

    assert_raise ArgumentError, ~r/exactly once/, fn ->
      Sigra.CI.LibraryTestPartitions.validate_current_universe!(
        partition_data(["test/first_test.exs"], ["test/first_test.exs", "test/second_test.exs"]),
        root: root
      )
    end

    assert_raise ArgumentError,
                 ~r/scaffold paths must not be assigned: test\/upgrade_test\.exs/,
                 fn ->
                   Sigra.CI.LibraryTestPartitions.validate_current_universe!(
                     partition_data(["test/first_test.exs", "test/upgrade_test.exs"], [
                       "test/second_test.exs"
                     ]),
                     root: root
                   )
                 end
  end

  test "equal measured costs retain lexical ordering and partition one wins exact ties" do
    Code.require_file(@partition_manifest_path)

    assert %{
             1 => %{paths: ["test/a_test.exs"], total_us: 1},
             2 => %{paths: ["test/b_test.exs"], total_us: 1}
           } =
             Sigra.CI.LibraryTestPartitions.assign!([
               %{"path" => "test/b_test.exs", "time_us" => 1},
               %{"path" => "test/a_test.exs", "time_us" => 1}
             ])
  end

  test "ordinary shard shell transport stops before its test command when selector fails" do
    {failed_output, failed_status} = run_selector_harness("exit 19")

    assert failed_status != 0
    assert failed_output == ""
    refute File.exists?(selector_sentinel_path())

    {successful_output, 0} = run_selector_harness("printf 'test/sigra/auth_test.exs\\n'")

    assert successful_output == ""
    assert File.exists?(selector_sentinel_path())
  end

  test "ordinary shard workflow preserves selector status and validates argv before mix test" do
    shard = job_body(File.read!(@workflow_path), "library_tests_shard")

    assert shard =~ "library_test_files_output=\"$(mix run"
    assert shard =~ "library test partition selector returned no paths"
    assert shard =~ "library test partition argv is empty"
    assert shard =~ "library test partition argv contains an empty path"
    assert length(Regex.scan(~r/^          mix test\b/m, shard)) == 1
  end

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end

  defp module_tags(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "  @moduletag "))
    |> Enum.map(&String.replace_prefix(&1, "  @moduletag ", ""))
  end

  defp scaffold_modules do
    "test/**/*.exs"
    |> Path.wildcard()
    |> Enum.filter(fn path -> ":scaffold" in module_tags(path) end)
    |> MapSet.new()
  end

  defp scaffold_paths do
    [
      "test/upgrade_test.exs",
      "test/sigra/install/generator_passkeys_opt_out_test.exs",
      "test/sigra/install/features/passkeys_js_test.exs",
      "test/sigra/install/golden_diff_test.exs",
      "test/sigra/install/idempotency_test.exs",
      "test/sigra/install/vault_promotion_test.exs"
    ]
  end

  defp write_fixture(root, relative_path) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "defmodule Fixture do\nend\n")
  end

  defp complete_universe_root(ordinary_paths) do
    root = temporary_root()

    Enum.each(ordinary_paths, &write_fixture(root, &1))
    Enum.each(scaffold_paths(), &write_fixture(root, &1))
    root
  end

  defp temporary_root do
    root =
      Path.join(
        System.tmp_dir!(),
        "sigra-partition-universe-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(root) end)
    root
  end

  defp partition_data(first_paths, second_paths) do
    %{
      1 => %{paths: first_paths, total_us: 1},
      2 => %{paths: second_paths, total_us: 1}
    }
  end

  defp run_selector_harness(selector) do
    sentinel = selector_sentinel_path()
    File.rm(sentinel)

    script = """
    set -euo pipefail
    selector="$1"
    sentinel="$2"
    library_test_files_output="$(bash -c "$selector")"
    if [[ -z "${library_test_files_output//[[:space:]]/}" ]]; then
      exit 1
    fi
    mapfile -t library_test_files <<< "$library_test_files_output"
    if (( ${#library_test_files[@]} == 0 )); then
      exit 1
    fi
    for library_test_file in "${library_test_files[@]}"; do
      [[ -n "$library_test_file" ]] || exit 1
    done
    touch "$sentinel"
    """

    System.cmd("bash", ["-c", script, "bash", selector, sentinel], stderr_to_stdout: true)
  end

  defp selector_sentinel_path do
    Path.join(System.tmp_dir!(), "sigra-selector-harness-sentinel")
  end
end
