defmodule Sigra.CI.LibraryTestPartitions do
  @moduledoc false

  @evidence_path ".planning/phases/233-library-suite-economics/233-EVIDENCE.json"
  @source_run_id 30_666_977_944
  @scaffold_paths MapSet.new([
                    "test/upgrade_test.exs",
                    "test/sigra/install/generator_passkeys_opt_out_test.exs",
                    "test/sigra/install/features/passkeys_js_test.exs",
                    "test/sigra/install/golden_diff_test.exs",
                    "test/sigra/install/idempotency_test.exs",
                    "test/sigra/install/vault_promotion_test.exs"
                  ])

  # Retry-free pull-request probe 30666977944. Candidates are ordered by
  # descending measured microseconds/path; lower cumulative cost wins, with
  # partition 1 winning exact ties. The exported lists are lexical for review.
  @spec source_run_id() :: pos_integer()
  def source_run_id, do: @source_run_id

  @spec partition(String.t() | pos_integer()) :: [String.t()]
  def partition(value) when value in [1, "1"], do: build_partitions!()[1].paths
  def partition(value) when value in [2, "2"], do: build_partitions!()[2].paths

  def partition(value),
    do: raise(ArgumentError, "unknown library test partition: #{inspect(value)}")

  @spec total_us(String.t() | pos_integer()) :: pos_integer()
  def total_us(value) when value in [1, "1"], do: build_partitions!()[1].total_us
  def total_us(value) when value in [2, "2"], do: build_partitions!()[2].total_us

  def total_us(value),
    do: raise(ArgumentError, "unknown library test partition: #{inspect(value)}")

  defp build_partitions! do
    costs =
      @evidence_path
      |> File.read!()
      |> JSON.decode!()
      |> get_in(["timing_probe", "per_file_costs"])
      |> Enum.reject(&MapSet.member?(@scaffold_paths, &1["path"]))
      |> Enum.sort_by(&{-&1["time_us"], &1["path"]})

    costs
    |> Enum.reduce(%{1 => %{paths: [], total_us: 0}, 2 => %{paths: [], total_us: 0}}, fn cost,
                                                                                         partitions ->
      partition = if partitions[1].total_us <= partitions[2].total_us, do: 1, else: 2

      update_in(partitions[partition], fn current ->
        %{
          current
          | paths: [cost["path"] | current.paths],
            total_us: current.total_us + cost["time_us"]
        }
      end)
    end)
    |> Map.new(fn {partition, data} -> {partition, %{data | paths: Enum.sort(data.paths)}} end)
  end
end
