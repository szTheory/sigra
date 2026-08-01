defmodule Sigra.CI.ExUnitTimingFormatterTest do
  use ExUnit.Case, async: true

  alias Sigra.CI.ExUnitTimingFormatter

  test "build_receipt turns completed tests into a deterministic timing receipt" do
    receipt =
      ExUnitTimingFormatter.build_receipt("1", [
        completed_test(Sigra.ZTimingTest, :later, "test/z_timing_test.exs", 10, nil),
        completed_test(Sigra.ATimingTest, :first, "test/a_timing_test.exs", 20, {:failed, []})
      ])

    assert receipt.schema_version == 1
    assert receipt.partition == "1"
    assert receipt.total == 2
    assert receipt.passed == 1
    assert receipt.failed == 1

    assert receipt.tests == [
             %{
               file: "test/a_timing_test.exs",
               module: "Sigra.ATimingTest",
               name: "first",
               outcome: "failed",
               time_us: 20
             },
             %{
               file: "test/z_timing_test.exs",
               module: "Sigra.ZTimingTest",
               name: "later",
               outcome: "passed",
               time_us: 10
             }
           ]
  end

  test "equal durations retain lexical file module and name order" do
    receipt =
      ExUnitTimingFormatter.build_receipt("2", [
        completed_test(Sigra.ATimingTest, :zeta, "test/z_test.exs", 10, nil),
        completed_test(Sigra.ZTimingTest, :alpha, "test/a_test.exs", 10, {:skipped, "reason"}),
        completed_test(Sigra.ATimingTest, :alpha, "test/a_test.exs", 10, {:excluded, "filter"})
      ])

    assert Enum.map(receipt.tests, &{&1.file, &1.module, &1.name, &1.outcome}) == [
             {"test/a_test.exs", "Sigra.ATimingTest", "alpha", "excluded"},
             {"test/a_test.exs", "Sigra.ZTimingTest", "alpha", "skipped"},
             {"test/z_test.exs", "Sigra.ATimingTest", "zeta", "passed"}
           ]
  end

  test "malformed completed-test data is rejected rather than recorded as timing" do
    assert_raise ArgumentError, ~r/completed ExUnit.Test events/, fn ->
      ExUnitTimingFormatter.build_receipt("1", [%{time: 10}])
    end
  end

  test "only fixed CI-owned timing receipt paths are accepted" do
    for path <- [
          nil,
          "",
          "relative.json",
          "/tmp/../sigra-library-1-timings.json",
          "/tmp/other.json"
        ] do
      assert_raise Sigra.CI.ExUnitTimingFormatter.InvalidOutputPathError, fn ->
        ExUnitTimingFormatter.validate_output_path!(path)
      end
    end
  end

  test "write_receipt writes a JSON object only to the selected CI receipt path" do
    path = "/tmp/sigra-library-1-timings.json"
    on_exit(fn -> File.rm(path) end)

    receipt = ExUnitTimingFormatter.build_receipt("1", [])
    :ok = ExUnitTimingFormatter.write_receipt!(path, receipt)

    assert File.read!(path) ==
             "{\"failed\":0,\"excluded\":0,\"invalid\":0,\"partition\":\"1\",\"passed\":0,\"schema_version\":1,\"skipped\":0,\"tests\":[],\"total\":0}\n"
  end

  defp completed_test(module, name, file, time, state) do
    %ExUnit.Test{
      module: module,
      name: name,
      state: state,
      tags: %{file: file},
      time: time
    }
  end
end
