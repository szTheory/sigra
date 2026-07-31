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

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end
end
