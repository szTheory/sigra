defmodule Sigra.Test.CITimingFormatter do
  @moduledoc false

  use GenServer

  @unit "microsecond"
  @count_keys [:passed, :failed, :skipped, :excluded]

  @doc false
  def new_state(path, invocation \\ System.get_env("SIGRA_EXUNIT_TIMING_INVOCATION")) do
    %{
      path: path,
      invocation: invocation,
      tests: [],
      counts: Map.new(@count_keys, &{&1, 0}),
      test_duration_sum_us: 0,
      diagnostics: [],
      started_at_us: nil,
      seed: nil,
      aborted?: false
    }
  end

  @impl true
  def init(_opts) do
    path = System.get_env("SIGRA_EXUNIT_TIMING_JSON")
    state = new_state(path, System.get_env("SIGRA_EXUNIT_TIMING_INVOCATION"))

    case clear_previous_report(path) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        report_write_error(reason)
        {:ok, add_diagnostic(state, "previous_output_unavailable")}
    end
  end

  @impl true
  def handle_cast({:suite_started, opts}, state) do
    {:noreply,
     %{state | started_at_us: System.monotonic_time(:microsecond), seed: suite_seed(opts)}}
  end

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, state) do
    id = test_id(test)
    result = result(test.state)
    state = update_in(state.counts[result], &(&1 + 1))

    if result == :excluded do
      {:noreply, state}
    else
      case test.time do
        time when is_integer(time) and time >= 0 ->
          row = %{
            invocation: state.invocation,
            test_id: id,
            module: inspect(test.module),
            name: Atom.to_string(test.name),
            result: Atom.to_string(result),
            duration_us: time,
            unit: @unit
          }

          state =
            state
            |> update_in([:tests], &[row | &1])
            |> update_in([:test_duration_sum_us], &(&1 + time))

          {:noreply, state}

        _ ->
          {:noreply, add_diagnostic(state, "test_duration_unavailable:#{id}")}
      end
    end
  end

  def handle_cast({:max_failures_reached, _}, state) do
    {:noreply, state |> Map.put(:aborted?, true) |> add_diagnostic("max_failures_reached")}
  end

  def handle_cast(:max_failures_reached, state) do
    {:noreply, state |> Map.put(:aborted?, true) |> add_diagnostic("max_failures_reached")}
  end

  def handle_cast({:suite_finished, times_us}, state) do
    report = build_report(state, times_us, true)
    write_report(state.path, report)
    {:noreply, state}
  end

  def handle_cast({:sigquit, _current}, state) do
    state = state |> Map.put(:aborted?, true) |> add_diagnostic("suite_interrupted")
    write_report(state.path, build_report(state, %{}, false))
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp build_report(state, times_us, suite_finished?) do
    {run_us, diagnostics} = measured_time(times_us, :run, state.diagnostics)
    {async_us, diagnostics} = measured_time(times_us, :async, diagnostics, optional: true)
    {load_us, diagnostics} = measured_time(times_us, :load, diagnostics, optional: true)

    suite_elapsed_us =
      case {state.started_at_us, suite_finished?} do
        {started_at_us, true} when is_integer(started_at_us) ->
          max(System.monotonic_time(:microsecond) - started_at_us, 0)

        _ ->
          nil
      end

    diagnostics =
      if is_nil(suite_elapsed_us) and suite_finished? do
        ["suite_elapsed_unavailable" | diagnostics]
      else
        diagnostics
      end

    %{
      unit: @unit,
      invocation: state.invocation,
      seed: state.seed,
      tests: Enum.reverse(state.tests),
      failed_test_ids:
        state.tests
        |> Enum.filter(&(&1.result == "failed"))
        |> Enum.map(& &1.test_id)
        |> Enum.reverse(),
      counts: Map.new(state.counts, fn {key, value} -> {Atom.to_string(key), value} end),
      passed_count: state.counts.passed,
      failed_count: state.counts.failed,
      skipped_count: state.counts.skipped,
      excluded_count: state.counts.excluded,
      suite_elapsed_us: suite_elapsed_us,
      run_us: run_us,
      async_us: async_us,
      load_us: load_us,
      test_duration_sum_us: state.test_duration_sum_us,
      complete: suite_finished? and not state.aborted? and diagnostics == [],
      diagnostics: Enum.reverse(diagnostics)
    }
  end

  defp measured_time(times_us, key, diagnostics, opts \\ []) do
    case {Map.get(times_us, key), opts[:optional]} do
      {value, _optional} when is_integer(value) and value >= 0 ->
        {value, diagnostics}

      {nil, true} ->
        {nil, diagnostics}

      _ ->
        {nil, ["#{key}_time_unavailable" | diagnostics]}
    end
  end

  defp result(nil), do: :passed
  defp result({:failed, _}), do: :failed
  defp result({:invalid, _}), do: :failed
  defp result({:skipped, _}), do: :skipped
  defp result({:excluded, _}), do: :excluded
  defp result(_), do: :failed

  defp suite_seed(opts) when is_list(opts), do: Keyword.get(opts, :seed)
  defp suite_seed(opts) when is_map(opts), do: Map.get(opts, :seed)
  defp suite_seed(_), do: nil

  defp test_id(%ExUnit.Test{module: module, name: name}),
    do: "#{inspect(module)}.#{Atom.to_string(name)}"

  defp add_diagnostic(state, diagnostic),
    do: update_in(state.diagnostics, &[diagnostic | &1])

  defp clear_previous_report(path) when is_binary(path) and path != "" do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp clear_previous_report(_path), do: :ok

  defp write_report(path, report) when is_binary(path) and path != "" do
    temporary_path = path <> ".tmp." <> Integer.to_string(System.unique_integer([:positive]))
    contents = Jason.encode!(report)

    case File.write(temporary_path, contents, [:binary, :exclusive]) do
      :ok ->
        case File.rename(temporary_path, path) do
          :ok ->
            :ok

          {:error, reason} ->
            File.rm(temporary_path)
            report_write_error(reason)
        end

      {:error, reason} ->
        report_write_error(reason)
    end
  rescue
    _ -> report_write_error(:encoding_failed)
  end

  defp write_report(_path, _report), do: report_write_error(:output_path_missing)

  defp report_write_error(reason) do
    diagnostic =
      if reason == :output_path_missing, do: "output_path_missing", else: "write_failed"

    message =
      Jason.encode!(%{
        complete: false,
        diagnostic: diagnostic,
        reason: reason |> :file.format_error() |> List.to_string()
      })

    IO.puts(:stderr, "SIGRA_EXUNIT_TIMING_JSON: #{message}")

    :error
  end
end
