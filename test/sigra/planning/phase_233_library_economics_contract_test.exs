defmodule Sigra.Planning.Phase233LibraryEconomicsContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"

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
    refute receiver =~ "changes"
    refute receiver =~ "docs_only"
    refute receiver =~ "github.event_name"
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
             ":install",
             "timeout: 300_000",
             ":scaffold"
           ]

    assert module_tags("test/sigra/install/idempotency_test.exs") == [
             ":install",
             "timeout: 600_000",
             ":scaffold"
           ]
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
end
