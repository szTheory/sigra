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

  @timing_paths %{
    1 => "/tmp/sigra-library-1-timings.json",
    2 => "/tmp/sigra-library-2-timings.json"
  }

  # Retry-free pull-request probe 30666977944. Candidates are ordered by
  # descending measured microseconds/path; lower cumulative cost wins, with
  # partition 1 winning exact ties. The exported lists are lexical for review.
  @spec source_run_id() :: pos_integer()
  def source_run_id, do: @source_run_id

  @spec scaffold_paths() :: [String.t()]
  def scaffold_paths, do: @scaffold_paths |> Enum.sort()

  @spec timing_path(String.t() | pos_integer()) :: String.t()
  def timing_path(value) when value in [1, "1"], do: @timing_paths[1]
  def timing_path(value) when value in [2, "2"], do: @timing_paths[2]

  def timing_path(value),
    do: raise(ArgumentError, "unknown library test partition: #{inspect(value)}")

  @spec manifest_sha256([String.t()]) :: String.t()
  def manifest_sha256(paths) when is_list(paths) do
    paths
    |> Enum.join("\n")
    |> Kernel.<>("\n")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

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

  def assign!(costs) when is_list(costs) do
    unless Enum.all?(costs, fn cost ->
             is_binary(cost["path"]) and is_integer(cost["time_us"]) and cost["time_us"] >= 0
           end) do
      raise ArgumentError, "partition assignment requires non-negative measured cost and path"
    end

    duplicate_paths =
      costs
      |> Enum.frequencies_by(& &1["path"])
      |> Enum.filter(fn {_path, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))

    if duplicate_paths != [] do
      raise ArgumentError,
            "duplicate measured paths are forbidden: #{Enum.join(Enum.sort(duplicate_paths), ", ")}"
    end

    costs
    |> Enum.sort_by(&{-&1["time_us"], &1["path"]})
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

  def validate!(partitions) when is_map(partitions) do
    paths = List.wrap(partitions[1]) ++ List.wrap(partitions[2])

    if partitions[1] in [nil, []] or partitions[2] in [nil, []],
      do: raise(ArgumentError, "partitions must be non-empty")

    if length(paths) != MapSet.size(MapSet.new(paths)),
      do: raise(ArgumentError, "paths must be assigned exactly once")

    partitions
  end

  @spec build_partitions!(keyword()) :: %{1 => map(), 2 => map()}
  def build_partitions!(opts \\ []) do
    ordinary_paths =
      Keyword.get_lazy(opts, :ordinary_paths, fn -> current_ordinary_paths!(opts) end)

    ordinary_set = MapSet.new(ordinary_paths)
    supplied_costs? = Keyword.has_key?(opts, :costs)
    raw_costs = Keyword.get_lazy(opts, :costs, &measured_costs/0)

    duplicate_paths =
      raw_costs
      |> Enum.frequencies_by(& &1["path"])
      |> Enum.filter(fn {_path, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))

    if duplicate_paths != [],
      do: raise(ArgumentError, "duplicate measured paths: #{format_paths(duplicate_paths)}")

    scaffold_leaks = Enum.filter(raw_costs, &MapSet.member?(@scaffold_paths, &1["path"]))

    if supplied_costs? and scaffold_leaks != [],
      do:
        raise(
          ArgumentError,
          "scaffold paths must not be measured: #{format_paths(Enum.map(scaffold_leaks, & &1["path"]))}"
        )

    ordinary_costs = Enum.reject(raw_costs, &MapSet.member?(@scaffold_paths, &1["path"]))
    cost_paths = MapSet.new(ordinary_costs, & &1["path"])
    stale_paths = MapSet.difference(cost_paths, ordinary_set)
    missing_paths = MapSet.difference(ordinary_set, cost_paths)

    if MapSet.size(stale_paths) > 0,
      do: raise(ArgumentError, "stale manifest paths: #{format_paths(stale_paths)}")

    if supplied_costs? and MapSet.size(missing_paths) > 0,
      do: raise(ArgumentError, "missing current paths: #{format_paths(missing_paths)}")

    costs =
      ordinary_costs ++ Enum.map(missing_paths, &%{"path" => &1, "time_us" => 0})

    partitions = assign!(costs)
    validate_current_universe!(partitions, Keyword.put(opts, :ordinary_paths, ordinary_paths))
    partitions
  end

  @spec current_ordinary_paths!(keyword()) :: [String.t()]
  def current_ordinary_paths!(opts \\ []) do
    case Keyword.fetch(opts, :ordinary_paths) do
      {:ok, paths} -> Enum.sort(paths)
      :error -> discover_current_ordinary_paths!(opts)
    end
  end

  defp discover_current_ordinary_paths!(opts) do
    root = Keyword.get(opts, :root, File.cwd!())

    {tracked_paths, 0} =
      System.cmd("git", ["-C", root, "ls-files", "--", "test/**/*_test.exs", "test/*_test.exs"],
        stderr_to_stdout: true
      )

    eligible_paths =
      tracked_paths
      |> String.split("\n", trim: true)
      |> Enum.filter(&matches_load_filters?/1)
      |> Enum.sort()

    missing_scaffold_paths = MapSet.difference(@scaffold_paths, MapSet.new(eligible_paths))

    unless MapSet.size(missing_scaffold_paths) == 0 do
      raise ArgumentError,
            "configured scaffold paths are missing or excluded: #{format_paths(missing_scaffold_paths)}"
    end

    eligible_paths
    |> Enum.reject(&MapSet.member?(@scaffold_paths, &1))
  end

  @spec validate_current_universe!(map(), keyword()) :: map()
  def validate_current_universe!(partitions, opts \\ []) when is_map(partitions) do
    assigned_paths = List.wrap(partitions[1].paths) ++ List.wrap(partitions[2].paths)

    validate!(%{1 => partitions[1].paths, 2 => partitions[2].paths})

    scaffold_leaks = Enum.filter(assigned_paths, &MapSet.member?(@scaffold_paths, &1))

    if scaffold_leaks != [] do
      raise ArgumentError,
            "scaffold paths must not be assigned: #{Enum.join(Enum.sort(scaffold_leaks), ", ")}"
    end

    current_paths = MapSet.new(current_ordinary_paths!(opts))
    assigned_path_set = MapSet.new(assigned_paths)
    missing_paths = MapSet.difference(current_paths, assigned_path_set)
    stale_paths = MapSet.difference(assigned_path_set, current_paths)

    if MapSet.size(missing_paths) > 0 or MapSet.size(stale_paths) > 0 do
      raise ArgumentError,
            "current ordinary test manifest mismatch; missing current paths: #{format_paths(missing_paths)}; stale manifest paths: #{format_paths(stale_paths)}"
    end

    partitions
  end

  defp measured_costs do
    @evidence_path
    |> File.read!()
    |> JSON.decode!()
    |> get_in(["timing_probe", "per_file_costs"])
  end

  defp matches_load_filters?(path) do
    Mix.Project.config()
    |> Keyword.fetch!(:test_load_filters)
    |> Enum.any?(fn
      %Regex{} = filter -> Regex.match?(filter, path)
      filter when is_function(filter, 1) -> filter.(path)
      filter when is_binary(filter) -> filter == path
    end)
  end

  defp format_paths(paths) do
    paths
    |> Enum.sort()
    |> Enum.join(", ")
  end
end
