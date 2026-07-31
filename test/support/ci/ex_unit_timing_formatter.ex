defmodule Sigra.CI.ExUnitTimingFormatter do
  @moduledoc false

  use GenServer

  @allowed_output_paths MapSet.new([
                          "/tmp/sigra-library-1-timings.json",
                          "/tmp/sigra-library-2-timings.json",
                          "/tmp/sigra-library-scaffold-timings.json"
                        ])

  defmodule InvalidOutputPathError do
    defexception [:path]

    @impl true
    def message(%{path: path}) do
      "SIGRA_EXUNIT_TIMING_PATH must be one of the fixed CI timing receipt paths, got: #{inspect(path)}"
    end
  end

  @impl GenServer
  def init(_opts) do
    path = System.fetch_env!("SIGRA_EXUNIT_TIMING_PATH")

    {:ok,
     %{
       output_path: validate_output_path!(path),
       partition: System.get_env("MIX_TEST_PARTITION", "scaffold"),
       tests: []
     }}
  end

  @impl GenServer
  def handle_cast({:test_finished, %ExUnit.Test{} = test}, state) do
    {:noreply, %{state | tests: [test | state.tests]}}
  end

  def handle_cast({:suite_finished, _times_us}, state) do
    state.partition
    |> build_receipt(state.tests)
    |> then(&write_receipt!(state.output_path, &1))

    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  @spec build_receipt(String.t(), [ExUnit.Test.t()]) :: map()
  def build_receipt(partition, tests) when is_binary(partition) and is_list(tests) do
    entries =
      Enum.map(tests, &test_entry!/1) |> Enum.sort_by(&{-&1.time_us, &1.file, &1.module, &1.name})

    %{
      schema_version: 1,
      partition: partition,
      tests: entries,
      total: length(entries),
      passed: Enum.count(entries, &(&1.outcome == "passed")),
      failed: Enum.count(entries, &(&1.outcome == "failed"))
    }
  end

  def build_receipt(_partition, _tests),
    do: raise(ArgumentError, "timing receipt requires a partition and completed tests")

  @spec validate_output_path!(String.t()) :: String.t()
  def validate_output_path!(path) when is_binary(path) do
    if MapSet.member?(@allowed_output_paths, path) do
      path
    else
      raise InvalidOutputPathError, path: path
    end
  end

  def validate_output_path!(path), do: raise(InvalidOutputPathError, path: path)

  @spec write_receipt!(String.t(), map()) :: :ok
  def write_receipt!(path, receipt) do
    path = validate_output_path!(path)
    temp_path = "#{path}.tmp-#{System.unique_integer([:positive])}"

    File.write!(temp_path, encode_receipt(receipt) <> "\n")
    File.rename!(temp_path, path)
    :ok
  end

  defp test_entry!(%ExUnit.Test{module: module, name: name, state: state, tags: tags, time: time})
       when is_atom(module) and is_atom(name) and is_map(tags) and is_integer(time) and time >= 0 do
    file = Map.fetch!(tags, :file)

    unless is_binary(file) do
      raise ArgumentError, "completed test has a non-binary :file tag"
    end

    %{
      file: file,
      module: inspect(module),
      name: Atom.to_string(name),
      time_us: time,
      outcome: normalize_outcome!(state)
    }
  end

  defp test_entry!(_test),
    do: raise(ArgumentError, "timing receipt requires completed ExUnit.Test events")

  defp normalize_outcome!(:passed), do: "passed"
  defp normalize_outcome!(:failed), do: "failed"
  defp normalize_outcome!(:skipped), do: "skipped"
  defp normalize_outcome!(:excluded), do: "excluded"

  defp normalize_outcome!(state),
    do: raise(ArgumentError, "unknown completed test state: #{inspect(state)}")

  defp encode_receipt(%{
         schema_version: schema_version,
         partition: partition,
         tests: tests,
         total: total,
         passed: passed,
         failed: failed
       }) do
    "{" <>
      "\"failed\":#{failed}," <>
      "\"partition\":#{JSON.encode!(partition)}," <>
      "\"passed\":#{passed}," <>
      "\"schema_version\":#{schema_version}," <>
      "\"tests\":[#{Enum.map_join(tests, ",", &encode_test/1)}]," <>
      "\"total\":#{total}" <>
      "}"
  end

  defp encode_test(%{file: file, module: module, name: name, outcome: outcome, time_us: time_us}) do
    "{" <>
      "\"file\":#{JSON.encode!(file)}," <>
      "\"module\":#{JSON.encode!(module)}," <>
      "\"name\":#{JSON.encode!(name)}," <>
      "\"outcome\":#{JSON.encode!(outcome)}," <>
      "\"time_us\":#{time_us}" <>
      "}"
  end
end
