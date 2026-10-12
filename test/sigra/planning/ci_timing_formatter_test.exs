defmodule Sigra.Planning.CITimingFormatterTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.CITimingFormatter

  test "writes distinct completed test results only after the suite finishes" do
    assert Code.ensure_loaded?(CITimingFormatter)

    path = timing_path()
    on_exit(fn -> File.rm(path) end)
    state = CITimingFormatter.new_state(path)

    {:noreply, state} = CITimingFormatter.handle_cast({:suite_started, []}, state)

    {:noreply, state} =
      CITimingFormatter.handle_cast(
        {:test_finished, event_test(:first, nil, 17)},
        state
      )

    {:noreply, state} =
      CITimingFormatter.handle_cast(
        {:test_finished,
         event_test(:second, {:failed, [{:error, "private assertion data", []}]}, 29)},
        state
      )

    {:noreply, state} =
      CITimingFormatter.handle_cast(
        {:test_finished, event_test(:third, {:skipped, "not run"}, 7)},
        state
      )

    {:noreply, state} =
      CITimingFormatter.handle_cast(
        {:test_finished, event_test(:fourth, {:excluded, "filtered"}, nil)},
        state
      )

    refute File.exists?(path)

    {:noreply, _state} =
      CITimingFormatter.handle_cast(
        {:suite_finished, %{run: 120, async: 40, load: 70}},
        state
      )

    report = path |> File.read!() |> Jason.decode!()

    assert report["complete"]
    assert report["unit"] == "microsecond"
    assert report["run_us"] == 120
    assert report["async_us"] == 40
    assert report["load_us"] == 70
    assert report["skipped_count"] == 1
    assert report["excluded_count"] == 1

    assert report["counts"] == %{
             "passed" => 1,
             "failed" => 1,
             "skipped" => 1,
             "excluded" => 1
           }

    assert report["test_duration_sum_us"] == 53

    assert Enum.map(report["tests"], & &1["test_id"]) == [
             "Example.first",
             "Example.second",
             "Example.third"
           ]

    assert Enum.map(report["tests"], & &1["result"]) == ["passed", "failed", "skipped"]
    assert Enum.map(report["tests"], & &1["duration_us"]) == [17, 29, 7]
    assert Enum.all?(report["tests"], &(&1["unit"] == "microsecond"))
    refute File.read!(path) =~ "private assertion data"
  end

  test "keeps missing duration visible as incomplete without inventing a zero-time row" do
    assert Code.ensure_loaded?(CITimingFormatter)

    path = timing_path()
    on_exit(fn -> File.rm(path) end)
    state = CITimingFormatter.new_state(path)
    {:noreply, state} = CITimingFormatter.handle_cast({:suite_started, []}, state)

    {:noreply, state} =
      CITimingFormatter.handle_cast(
        {:test_finished, event_test(:unknown_duration, nil, nil)},
        state
      )

    {:noreply, _state} =
      CITimingFormatter.handle_cast(
        {:suite_finished, %{run: 1, async: nil, load: nil}},
        state
      )

    report = path |> File.read!() |> Jason.decode!()

    refute report["complete"]
    assert report["tests"] == []
    assert report["diagnostics"] == ["test_duration_unavailable:Example.unknown_duration"]
  end

  defp timing_path do
    filename =
      "sigra-ci-timing-#{System.system_time(:nanosecond)}-#{System.unique_integer([:positive])}.json"

    Path.join(System.tmp_dir!(), filename)
  end

  defp event_test(name, state, time) do
    %ExUnit.Test{module: Example, name: name, state: state, time: time}
  end
end
