defmodule Sigra.CI.LibraryTestPartitions do
  @moduledoc false

  @calibration_path ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION.json"
  @manifest_path ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION-MANIFEST.json"
  @calibration_schema "sigra.library-partition-calibration/v2"
  @manifest_schema "sigra.library-partition-calibration-manifest/v1"
  @blocked_summary_commit "81afbf0cafcf7dcf380d728a03053c42cdccdaa0"
  @collection_command "ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test bash scripts/ci/library-partitions.sh"
  @aggregation "median(max(1,sum(time_us)))"
  @artifact_max_bytes 8_388_608
  @payload_max_bytes 1_048_576
  @source_run_id 30_666_977_944
  @source_snapshot_commit "b37ac1164cee96be11a5cdeb60b31db560018e04"
  @source_snapshot_tree "02bb907f075b1428d89bb87e519c0e0d8810fcd9"
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

  def ordinary_universe_sha256(paths) when is_list(paths) do
    paths
    |> Enum.join(<<0>>)
    |> Kernel.<>(<<0>>)
    |> sha256()
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
             is_map(cost) and Map.keys(cost) |> Enum.sort() == ["path", "time_us"] and
               valid_ordinary_path?(cost["path"]) and is_integer(cost["time_us"]) and
               cost["time_us"] > 0
           end) do
      raise ArgumentError, "partition assignment requires exact positive measured cost and path"
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

    raw_costs =
      Keyword.get_lazy(opts, :costs, fn ->
        load_calibration!(Keyword.put(opts, :ordinary_paths, ordinary_paths)).costs
      end)

    duplicate_paths =
      raw_costs
      |> Enum.frequencies_by(& &1["path"])
      |> Enum.filter(fn {_path, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))

    if duplicate_paths != [],
      do: raise(ArgumentError, "duplicate measured paths: #{format_paths(duplicate_paths)}")

    scaffold_leaks = Enum.filter(raw_costs, &MapSet.member?(@scaffold_paths, &1["path"]))

    if scaffold_leaks != [],
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

    if MapSet.size(missing_paths) > 0,
      do: raise(ArgumentError, "missing current paths: #{format_paths(missing_paths)}")

    partitions = assign!(ordinary_costs)
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
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()

    {tracked_paths, status} =
      System.cmd("git", ["-C", root, "ls-files", "-z", "--", ":(glob)test/**/*_test.exs"],
        stderr_to_stdout: true
      )

    unless status == 0, do: invalid!("tracked ordinary discovery failed")

    eligible_paths =
      tracked_paths
      |> String.split(<<0>>, trim: true)
      |> validate_tracked_paths!(root)
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

  @spec load_calibration!(keyword()) :: map()
  def load_calibration!(opts \\ []) do
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()
    manifest_path = Keyword.get(opts, :manifest_path, Path.join(root, @manifest_path))
    manifest = load_manifest!(manifest_path)
    validate_manifest_source!(manifest)

    calibration_relative = manifest["calibration"]["path"]

    unless valid_repository_relative_json?(calibration_relative),
      do: invalid!("manifest calibration path")

    if not Keyword.has_key?(opts, :manifest_path) and calibration_relative != @calibration_path,
      do: invalid!("default manifest calibration path")

    expected_path = Path.join(root, calibration_relative)
    path = Keyword.get(opts, :path, expected_path)

    unless Path.expand(path) == Path.expand(expected_path),
      do: invalid!("calibration path differs from manifest")

    ordinary_paths =
      Keyword.get_lazy(opts, :ordinary_paths, fn -> current_ordinary_paths!(opts) end)

    unless regular_non_symlink?(path), do: invalid!("calibration must be a regular non-symlink")

    raw = File.read!(path)

    unless byte_size(raw) == manifest["calibration"]["byte_count"] and
             sha256(raw) == manifest["calibration"]["sha256"],
           do: invalid!("manifest calibration byte binding")

    if byte_size(raw) > @artifact_max_bytes,
      do: invalid!("calibration exceeds artifact byte limit")

    calibration = decode_strict_json!(raw, "calibration")

    exact_keys!(
      calibration,
      ~w(schema_version source ordinary_universe limits samples derived_costs),
      "calibration"
    )

    if calibration["schema_version"] != @calibration_schema, do: invalid!("calibration schema")

    validate_source!(calibration["source"], manifest)
    validate_limits!(calibration["limits"])
    validate_universe!(calibration["ordinary_universe"], ordinary_paths, manifest, root)

    samples = calibration["samples"]

    unless is_list(samples) and length(samples) == 3 and
             Enum.sort(Enum.map(samples, & &1["ordinal"])) == [1, 2, 3],
           do: invalid!("calibration samples")

    sample_costs = Enum.map(samples, &validate_sample!(&1, ordinary_paths))
    expected_costs = replay_medians(ordinary_paths, sample_costs)
    validate_derived_costs!(calibration["derived_costs"], expected_costs)

    %{
      costs: expected_costs,
      ordinary_paths: ordinary_paths,
      source: calibration["source"],
      samples: samples
    }
  rescue
    error in [ArgumentError, File.Error, KeyError, MatchError] ->
      raise ArgumentError, "invalid partition calibration: #{Exception.message(error)}"
  end

  defp validate_source!(source, manifest) do
    exact_keys!(
      source,
      ~w(implementation_commit blocked_summary_commit collection_command sample_count aggregation),
      "source"
    )

    expected = %{
      "implementation_commit" => manifest["source_snapshot"]["commit"],
      "blocked_summary_commit" => @blocked_summary_commit,
      "collection_command" => @collection_command,
      "sample_count" => 3,
      "aggregation" => @aggregation
    }

    if source != expected, do: invalid!("calibration provenance")
  end

  defp validate_limits!(limits) do
    exact_keys!(
      limits,
      ~w(artifact_bytes combined_bytes timing_bytes sample_count combined_per_sample timings_per_sample partitions),
      "limits"
    )

    expected = %{
      "artifact_bytes" => @artifact_max_bytes,
      "combined_bytes" => @payload_max_bytes,
      "timing_bytes" => @payload_max_bytes,
      "sample_count" => 3,
      "combined_per_sample" => 1,
      "timings_per_sample" => 2,
      "partitions" => [1, 2]
    }

    if limits != expected, do: invalid!("calibration limits")
  end

  defp validate_universe!(universe, ordinary_paths, manifest, root) do
    exact_keys!(universe, ~w(paths count nul_manifest_sha256 source_files), "ordinary universe")
    paths = universe["paths"]
    source_files = universe["source_files"]

    unless paths == Enum.sort(paths) and paths == ordinary_paths and
             universe["count"] == length(paths) and
             universe["nul_manifest_sha256"] == ordinary_universe_sha256(paths),
           do: invalid!("ordinary universe")

    unless is_list(source_files) and Enum.map(source_files, & &1["path"]) == paths and
             source_files == Enum.sort_by(source_files, & &1["path"]),
           do: invalid!("ordinary source index")

    Enum.each(source_files, &validate_source_file!(&1, root))

    unless source_index_sha256(source_files) == manifest["ordinary_source_index_sha256"],
      do: invalid!("ordinary source index digest")
  end

  defp load_manifest!(path) do
    unless regular_non_symlink?(path), do: invalid!("manifest must be a regular non-symlink")
    manifest = path |> File.read!() |> decode_strict_json!("manifest")

    exact_keys!(
      manifest,
      ~w(schema_version source_snapshot calibration ordinary_source_index_sha256 sample_count payload_count),
      "manifest"
    )

    exact_keys!(manifest["source_snapshot"], ~w(commit tree), "manifest source snapshot")
    exact_keys!(manifest["calibration"], ~w(path byte_count sha256), "manifest calibration")

    unless manifest["schema_version"] == @manifest_schema and manifest["sample_count"] == 3 and
             manifest["payload_count"] == 9 and hex?(manifest["source_snapshot"]["commit"], 40) and
             hex?(manifest["source_snapshot"]["tree"], 40) and
             hex?(manifest["calibration"]["sha256"], 64) and
             hex?(manifest["ordinary_source_index_sha256"], 64) and
             positive_integer?(manifest["calibration"]["byte_count"]),
           do: invalid!("manifest values")

    manifest
  end

  defp validate_manifest_source!(manifest) do
    unless manifest["source_snapshot"] == %{
             "commit" => @source_snapshot_commit,
             "tree" => @source_snapshot_tree
           },
           do: invalid!("source snapshot commit/tree")
  end

  defp validate_source_file!(row, root) do
    exact_keys!(row, ~w(path byte_count sha256), "ordinary source row")
    path = row["path"]

    unless valid_ordinary_path?(path) and positive_integer?(row["byte_count"]) and
             hex?(row["sha256"], 64),
           do: invalid!("ordinary source row values")

    current = Path.join(root, path)
    unless regular_non_symlink?(current), do: invalid!("ordinary source file")
    bytes = File.read!(current)

    unless byte_size(bytes) == row["byte_count"] and sha256(bytes) == row["sha256"],
      do: invalid!("current ordinary source bytes")
  end

  defp source_index_sha256(rows) do
    rows |> JSON.encode!() |> Kernel.<>("\n") |> sha256()
  end

  defp validate_sample!(sample, ordinary_paths) do
    exact_keys!(sample, ~w(ordinal combined timings), "sample")
    unless sample["ordinal"] in [1, 2, 3], do: invalid!("sample ordinal")

    combined =
      decode_embedded!(sample["combined"], "combined", "/tmp/sigra-library-partitions.json")

    timings = sample["timings"]
    unless is_list(timings) and length(timings) == 2, do: invalid!("sample timing count")

    timing_receipts =
      Enum.zip(timings, [1, 2])
      |> Enum.map(fn {receipt, id} ->
        decoded = decode_embedded!(receipt, "timing-#{id}", timing_path(id))
        {id, validate_timing!(decoded, id, ordinary_paths)}
      end)
      |> Map.new()

    validate_combined!(combined, timing_receipts, ordinary_paths)

    timing_receipts
    |> Map.values()
    |> Enum.flat_map(& &1["tests"])
    |> Enum.group_by(& &1["file"], & &1["time_us"])
    |> Map.new(fn {path, durations} -> {path, max(1, Enum.sum(durations))} end)
    |> then(fn costs ->
      if Enum.sort(Map.keys(costs)) != ordinary_paths, do: invalid!("sample cost universe")
      costs
    end)
  end

  defp decode_embedded!(receipt, role, source_path) do
    exact_keys!(
      receipt,
      ~w(role source_path byte_count sha256 payload_base64),
      "embedded receipt"
    )

    unless receipt["role"] == role and receipt["source_path"] == source_path and
             is_integer(receipt["byte_count"]) and receipt["byte_count"] > 0 and
             receipt["byte_count"] <= @payload_max_bytes and
             is_binary(receipt["sha256"]) and
             Regex.match?(~r/\A[0-9a-f]{64}\z/, receipt["sha256"]) and
             is_binary(receipt["payload_base64"]),
           do: invalid!("embedded receipt metadata")

    payload =
      case Base.decode64(receipt["payload_base64"]) do
        {:ok, bytes} ->
          if Base.encode64(bytes) == receipt["payload_base64"],
            do: bytes,
            else: invalid!("embedded receipt base64")

        _ ->
          invalid!("embedded receipt base64")
      end

    unless byte_size(payload) == receipt["byte_count"] and sha256(payload) == receipt["sha256"],
      do: invalid!("embedded receipt byte binding")

    decode_strict_json!(payload, role)
  end

  defp validate_combined!(combined, timings, ordinary_paths) do
    exact_keys!(
      combined,
      ~w(schema_version execution_mode ordinary_universe partitions),
      "combined receipt"
    )

    unless combined["schema_version"] == "sigra.library-partitions/v1" and
             combined["execution_mode"] == "sequential",
           do: invalid!("combined receipt identity")

    universe = combined["ordinary_universe"]

    exact_keys!(
      universe,
      ~w(paths count missing stale duplicate scaffold_leaks),
      "combined universe"
    )

    unless universe["paths"] == ordinary_paths and universe["count"] == length(ordinary_paths) and
             Enum.all?(~w(missing stale duplicate scaffold_leaks), &(universe[&1] == [])),
           do: invalid!("combined universe")

    partitions = combined["partitions"]
    unless is_list(partitions) and length(partitions) == 2, do: invalid!("combined partitions")

    Enum.zip(partitions, [1, 2])
    |> Enum.each(fn {partition, id} ->
      exact_keys!(
        partition,
        ~w(id paths manifest_sha256 timing_receipt_path start_ms end_ms duration_ms conclusion exit_status),
        "combined partition"
      )

      timing_paths = timings[id]["tests"] |> Enum.map(& &1["file"]) |> Enum.uniq() |> Enum.sort()

      unless partition["id"] == id and partition["paths"] == timing_paths and
               partition["paths"] == Enum.sort(partition["paths"]) and
               partition["manifest_sha256"] == manifest_sha256(partition["paths"]) and
               partition["timing_receipt_path"] == timing_path(id) and
               positive_integer?(partition["start_ms"]) and positive_integer?(partition["end_ms"]) and
               positive_integer?(partition["duration_ms"]) and
               partition["duration_ms"] == partition["end_ms"] - partition["start_ms"] and
               partition["conclusion"] == "success" and partition["exit_status"] == 0,
             do: invalid!("combined partition #{id}")
    end)

    assigned = Enum.flat_map(partitions, & &1["paths"])

    unless Enum.sort(assigned) == ordinary_paths and
             length(assigned) == MapSet.size(MapSet.new(assigned)),
           do: invalid!("combined partition linkage")
  end

  defp validate_timing!(timing, id, ordinary_paths) do
    exact_keys!(
      timing,
      ~w(schema_version partition tests total passed failed skipped excluded invalid),
      "timing receipt"
    )

    tests = timing["tests"]

    unless timing["schema_version"] == 1 and timing["partition"] == Integer.to_string(id) and
             is_list(tests) and tests != [],
           do: invalid!("timing receipt identity")

    Enum.each(tests, fn row ->
      exact_keys!(row, ~w(file module name time_us outcome), "timing row")

      unless row["file"] in ordinary_paths and valid_ordinary_path?(row["file"]) and
               is_binary(row["module"]) and row["module"] != "" and is_binary(row["name"]) and
               row["name"] != "" and is_integer(row["time_us"]) and row["time_us"] >= 0 and
               row["outcome"] in ["passed", "failed", "skipped", "excluded", "invalid"],
             do: invalid!("timing row")
    end)

    identities = Enum.map(tests, &{&1["file"], &1["module"], &1["name"]})

    if length(identities) != MapSet.size(MapSet.new(identities)),
      do: invalid!("duplicate timing test")

    counts = Enum.frequencies_by(tests, & &1["outcome"])

    unless timing["total"] == length(tests) and timing["passed"] == Map.get(counts, "passed", 0) and
             timing["failed"] == Map.get(counts, "failed", 0) and
             timing["skipped"] == Map.get(counts, "skipped", 0) and
             timing["excluded"] == Map.get(counts, "excluded", 0) and
             timing["invalid"] == Map.get(counts, "invalid", 0) and timing["failed"] == 0 and
             timing["excluded"] == 0 and timing["invalid"] == 0,
           do: invalid!("timing receipt arithmetic")

    timing
  end

  defp replay_medians(paths, sample_costs) do
    Enum.map(paths, fn path ->
      values = sample_costs |> Enum.map(&Map.fetch!(&1, path)) |> Enum.sort()
      %{"path" => path, "time_us" => Enum.at(values, 1)}
    end)
  end

  defp validate_derived_costs!(derived, expected) do
    unless is_list(derived) and derived == expected and Enum.all?(derived, &positive_cost?/1),
      do: invalid!("derived costs")
  end

  defp decode_strict_json!(bytes, label) do
    object_push = fn key, value, acc ->
      if List.keymember?(acc, key, 0), do: invalid!("duplicate JSON key in #{label}")
      [{key, value} | acc]
    end

    case JSON.decode(bytes, nil, object_push: object_push) do
      {decoded, nil, ""} -> decoded
      _ -> invalid!("malformed JSON in #{label}")
    end
  rescue
    _ -> invalid!("malformed JSON in #{label}")
  end

  defp exact_keys!(value, keys, label) when is_map(value) do
    if Enum.sort(Map.keys(value)) != Enum.sort(keys), do: invalid!("#{label} keys")
  end

  defp exact_keys!(_value, _keys, label), do: invalid!("#{label} must be an object")

  defp regular_non_symlink?(path) do
    match?({:ok, %File.Stat{type: :regular}}, File.lstat(path))
  end

  defp validate_tracked_paths!(paths, root) do
    if length(paths) != MapSet.size(MapSet.new(paths)), do: invalid!("duplicate tracked path")

    Enum.map(paths, fn path ->
      unless is_binary(path) and String.valid?(path) and String.starts_with?(path, "test/") and
               String.ends_with?(path, "_test.exs") and
               not String.contains?(path, ["../", "/../", "//", "\\", <<0>>]),
             do: invalid!("malformed tracked path")

      unless regular_non_symlink?(Path.join(root, path)),
        do: invalid!("tracked path is not regular")

      path
    end)
  end

  defp valid_ordinary_path?(path) do
    is_binary(path) and String.starts_with?(path, "test/") and
      String.ends_with?(path, "_test.exs") and
      path not in @scaffold_paths and not String.contains?(path, ["..", "//", "\\"])
  end

  defp valid_repository_relative_json?(path) do
    is_binary(path) and path != "" and Path.type(path) != :absolute and
      String.ends_with?(path, ".json") and
      not String.contains?(path, ["..", "//", "\\", <<0>>])
  end

  defp positive_cost?(%{"path" => path, "time_us" => time_us} = row) do
    Map.keys(row) |> Enum.sort() == ["path", "time_us"] and valid_ordinary_path?(path) and
      positive_integer?(time_us)
  end

  defp positive_cost?(_), do: false
  defp positive_integer?(value), do: is_integer(value) and value > 0

  defp hex?(value, length),
    do: is_binary(value) and byte_size(value) == length and Regex.match?(~r/\A[0-9a-f]+\z/, value)

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  defp invalid!(message), do: raise(ArgumentError, message)

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
