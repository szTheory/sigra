defmodule Sigra.CI.ExUnitTimingFormatterTest do
  use ExUnit.Case, async: true

  alias Sigra.CI.ExUnitTimingFormatter

  test "build_receipt turns completed tests into a deterministic timing receipt" do
    receipt =
      ExUnitTimingFormatter.build_receipt("1", [
        completed_test(Sigra.ZTimingTest, :later, "test/z_timing_test.exs", 10, :passed),
        completed_test(Sigra.ATimingTest, :first, "test/a_timing_test.exs", 20, :failed)
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

  test "write_receipt writes a JSON object only to the selected CI receipt path" do
    path = "/tmp/sigra-library-1-timings.json"
    on_exit(fn -> File.rm(path) end)

    receipt = ExUnitTimingFormatter.build_receipt("1", [])
    :ok = ExUnitTimingFormatter.write_receipt!(path, receipt)

    assert File.read!(path) ==
             "{\"failed\":0,\"partition\":\"1\",\"passed\":0,\"schema_version\":1,\"tests\":[],\"total\":0}\n"
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
